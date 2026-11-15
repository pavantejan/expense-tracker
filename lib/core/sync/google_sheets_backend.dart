import 'package:googleapis/sheets/v4.dart' as sheets;

import '../auth/google_auth_service.dart';
import 'sync_errors.dart';

/// Classified Google Sheets / Drive API failures.
///
/// The engine and coordinator must never treat an arbitrary error
/// as "no data". Classification is by HTTP status when available,
/// with a network fallback on the error text. Unknown errors stay
/// unknown and propagate so the transaction remains pending.
enum SheetsErrorKind {
  missingWorksheet,
  missingSpreadsheet,
  permissionDenied,
  authentication,
  network,
  unknown,
}

class SheetsApiException implements Exception {
  const SheetsApiException(this.kind, [this.message = '', this.status]);

  final SheetsErrorKind kind;
  final String message;
  final int? status;

  @override
  String toString() => 'SheetsApiException($kind, $status): $message';
}

int? _statusOf(Object error) {
  try {
    final status = (error as dynamic).status;
    return status is int ? status : null;
  } catch (_) {
    return null;
  }
}

/// Classifies a raw API error. A 404 means different things in
/// different contexts, so callers must say what a 404 means for
/// their call via [kindFor404]: a missing worksheet/range for a
/// values read after the spreadsheet was verified, or a missing
/// spreadsheet for a spreadsheet-level call.
SheetsErrorKind classifySheetsError(
  Object error, {
  required SheetsErrorKind kindFor404,
}) {
  final status = _statusOf(error);
  if (status == 401) {
    return SheetsErrorKind.authentication;
  }
  if (status == 403) {
    return SheetsErrorKind.permissionDenied;
  }
  if (status == 404) {
    return kindFor404;
  }
  final text = error.toString().toLowerCase();
  if (text.contains('socketexception') ||
      text.contains('failed host lookup') ||
      text.contains('connection refused') ||
      text.contains('network is unreachable') ||
      text.contains('clientexception')) {
    return SheetsErrorKind.network;
  }
  return SheetsErrorKind.unknown;
}

/// How Sheets should interpret written values (Google Sheets
/// `ValueInputOption`).
///
/// - [raw]: values are stored as-is, not parsed. Text beginning
///   with `=` is stored as literal text, never evaluated as a
///   formula. Numeric values passed as numbers stay numbers.
/// - [userEntered]: values are parsed as if typed into the UI;
///   strings may be converted to numbers or dates and text
///   beginning with `=` is evaluated as a formula.
///
/// Transaction rows and headers are always written with [raw]
/// (see `GoogleSheetsV2Backend`). [userEntered] exists only so a
/// fake client can record which option the production client
/// chose; production code must never write transaction values
/// with it.
enum SheetsValueInputOption { raw, userEntered }

/// Injectable boundary around the Google Sheets + Drive APIs.
///
/// The sync engine and backend never talk to googleapis directly;
/// they talk to this interface, so tests can inject a fake that
/// throws classified errors without a Google account or real
/// files. Implementations must throw [SheetsApiException] with a
/// classified kind, never raw API errors, except for
/// authentication/authorization exceptions from the auth layer,
/// which propagate as [SheetsNotSignedInException] /
/// [SheetsAuthorizationMissingException].
abstract class SheetsApiClient {
  /// Resolves (find-or-create) the one managed spreadsheet and
  /// returns its id. Never creates duplicates on repeated calls
  /// within the app-created set (see `GoogleDriveService`).
  Future<String> resolveSpreadsheetId();

  /// Titles of the worksheets in [spreadsheetId]. Throws
  /// [SheetsApiException] with [SheetsErrorKind.missingSpreadsheet]
  /// when the spreadsheet itself is missing or inaccessible.
  Future<List<String>> sheetTitles(String spreadsheetId);

  /// Raw values for [range] (A1 notation, including sheet title).
  /// Throws [SheetsApiException] with
  /// [SheetsErrorKind.missingWorksheet] when the worksheet/range
  /// does not exist in an otherwise verified spreadsheet.
  Future<List<List<Object?>>> readValues(String spreadsheetId, String range);

  Future<void> updateValues(
    String spreadsheetId,
    String range,
    List<List<Object?>> values, {
    required SheetsValueInputOption valueInputOption,
  });

  Future<void> appendValues(
    String spreadsheetId,
    String range,
    List<List<Object?>> values, {
    required SheetsValueInputOption valueInputOption,
  });

  Future<void> addSheet(String spreadsheetId, String title);
}

typedef SheetsApiClientFactory = SheetsApiClient Function({
  required bool interactive,
});

/// Real [SheetsApiClient] backed by the googleapis client.
///
/// [interactive] selects the authorization mode (see
/// `GoogleAuthService`): in-memory-only background mode never
/// initiates authentication or authorization, interactive mode
/// may prompt and is only used from an explicit Settings action.
class GoogleApisSheetsClient implements SheetsApiClient {
  GoogleApisSheetsClient({
    required this.interactive,
    required this.spreadsheetResolver,
    this.unformattedValues = false,
  });

  final bool interactive;

  /// Resolves (find-or-create) the managed spreadsheet. The V2
  /// backend passes the V2 identity resolution; there is no V1
  /// resolution in the app any more.
  final Future<String> Function({required bool interactive})
  spreadsheetResolver;

  /// Reads cells as UNFORMATTED_VALUE so numeric amounts come back as
  /// numbers, not locale-formatted text.
  final bool unformattedValues;
  sheets.SheetsApi? _sheetsApi;

  Future<sheets.SheetsApi> _api() async {
    return _sheetsApi ??= await GoogleAuthService.instance.getSheetsApi(
      allowInteractiveAuthorization: interactive,
    );
  }

  SheetsApiException _wrap(Object error, SheetsErrorKind kindFor404) {
    return SheetsApiException(
      classifySheetsError(error, kindFor404: kindFor404),
      error.toString(),
      _statusOf(error),
    );
  }

  @override
  Future<String> resolveSpreadsheetId() {
    return spreadsheetResolver(interactive: interactive);
  }

  @override
  Future<List<String>> sheetTitles(String spreadsheetId) async {
    try {
      final api = await _api();
      final spreadsheet = await api.spreadsheets.get(
        spreadsheetId,
        $fields: 'sheets(properties(title))',
      );
      final titles = <String>[];
      for (final sheet in spreadsheet.sheets ?? const <sheets.Sheet>[]) {
        final title = sheet.properties?.title;
        if (title != null) {
          titles.add(title);
        }
      }
      return titles;
    } catch (error) {
      if (error is SheetsNotSignedInException ||
          error is SheetsAuthorizationMissingException) {
        rethrow;
      }
      throw _wrap(error, SheetsErrorKind.missingSpreadsheet);
    }
  }

  @override
  Future<List<List<Object?>>> readValues(
    String spreadsheetId,
    String range,
  ) async {
    try {
      final api = await _api();
      final response = await api.spreadsheets.values.get(
        spreadsheetId,
        range,
        valueRenderOption: unformattedValues ? 'UNFORMATTED_VALUE' : null,
      );
      return response.values ?? const <List<Object?>>[];
    } catch (error) {
      if (error is SheetsNotSignedInException ||
          error is SheetsAuthorizationMissingException) {
        rethrow;
      }
      // The caller verifies the spreadsheet first, so a 404 here
      // means the worksheet/range is missing.
      throw _wrap(error, SheetsErrorKind.missingWorksheet);
    }
  }

  @override
  Future<void> updateValues(
    String spreadsheetId,
    String range,
    List<List<Object?>> values, {
    required SheetsValueInputOption valueInputOption,
  }) async {
    try {
      final api = await _api();
      await api.spreadsheets.values.update(
        sheets.ValueRange(values: values),
        spreadsheetId,
        range,
        // RAW: transaction text is stored literally, never
        // parsed as a formula. Amounts are passed as numbers
        // and stay numbers.
        valueInputOption: valueInputOption == SheetsValueInputOption.raw
            ? 'RAW'
            : 'USER_ENTERED',
      );
    } catch (error) {
      if (error is SheetsNotSignedInException ||
          error is SheetsAuthorizationMissingException) {
        rethrow;
      }
      throw _wrap(error, SheetsErrorKind.missingSpreadsheet);
    }
  }

  @override
  Future<void> appendValues(
    String spreadsheetId,
    String range,
    List<List<Object?>> values, {
    required SheetsValueInputOption valueInputOption,
  }) async {
    try {
      final api = await _api();
      await api.spreadsheets.values.append(
        sheets.ValueRange(values: values),
        spreadsheetId,
        range,
        // RAW, for the same reason as updateValues above.
        valueInputOption: valueInputOption == SheetsValueInputOption.raw
            ? 'RAW'
            : 'USER_ENTERED',
        insertDataOption: 'INSERT_ROWS',
      );
    } catch (error) {
      if (error is SheetsNotSignedInException ||
          error is SheetsAuthorizationMissingException) {
        rethrow;
      }
      throw _wrap(error, SheetsErrorKind.missingSpreadsheet);
    }
  }

  @override
  Future<void> addSheet(String spreadsheetId, String title) async {
    try {
      final api = await _api();
      await api.spreadsheets.batchUpdate(
        sheets.BatchUpdateSpreadsheetRequest(
          requests: <sheets.Request>[
            sheets.Request(
              addSheet: sheets.AddSheetRequest(
                properties: sheets.SheetProperties(title: title),
              ),
            ),
          ],
        ),
        spreadsheetId,
      );
    } catch (error) {
      if (error is SheetsNotSignedInException ||
          error is SheetsAuthorizationMissingException) {
        rethrow;
      }
      throw _wrap(error, SheetsErrorKind.missingSpreadsheet);
    }
  }
}
