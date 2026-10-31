import 'package:flutter/foundation.dart';
import 'package:googleapis/sheets/v4.dart' as sheets;

import '../auth/google_auth_service.dart';
import 'google_drive_service.dart';
import 'sheets_sync.dart';

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
/// (see `GoogleSheetsBackend`). [userEntered] exists only so a
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
  GoogleApisSheetsClient({required this.interactive});

  final bool interactive;
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
  Future<String> resolveSpreadsheetId() async {
    final result = await GoogleDriveService.instance.setupExpenseTracker(
      allowInteractiveAuthorization: interactive,
    );
    return result.fileId;
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
      final response = await api.spreadsheets.values.get(spreadsheetId, range);
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

/// Real [SheetsSyncBackend] backed by Google Drive + Sheets APIs.
///
/// Spreadsheet identity is resolved through Drive on every sync
/// run (see docs/sheets-sync.md): the Drive service finds or
/// creates the one app-created "Expense Tracker" folder and
/// spreadsheet, so repeated setup creates no duplicates within
/// the app-created set and a restart re-finds the same file.
/// Nothing here logs tokens, spreadsheet ids, or transaction
/// data — only counts/years at debug level, with no row contents.
///
/// Two authorization modes exist: [instance] is in-memory-only
/// background mode (never initiates authentication or
/// authorization), [interactiveInstance] is for explicit
/// Settings actions only.
class GoogleSheetsBackend implements SheetsSyncBackend {
  GoogleSheetsBackend._({
    required this.interactive,
    SheetsApiClientFactory? clientFactory,
  }) : _clientFactory = clientFactory ?? _defaultFactory;

  /// Test constructor: injects a fake client directly.
  GoogleSheetsBackend.forTesting({
    required SheetsApiClient client,
    this.interactive = false,
  }) : _clientFactory = (({required bool interactive}) => client),
       _cachedClient = client;

  /// Test constructor: injects a client factory directly, so
  /// tests can record the authorization mode a backend requests
  /// without a Google account.
  GoogleSheetsBackend.withClientFactory({
    required this.interactive,
    required SheetsApiClientFactory clientFactory,
  }) : _clientFactory = clientFactory;

  static final GoogleSheetsBackend instance = GoogleSheetsBackend._(
    interactive: false,
  );

  static final GoogleSheetsBackend interactiveInstance = GoogleSheetsBackend._(
    interactive: true,
  );

  static SheetsApiClient _defaultFactory({required bool interactive}) {
    return GoogleApisSheetsClient(interactive: interactive);
  }

  final bool interactive;
  final SheetsApiClientFactory _clientFactory;
  SheetsApiClient? _cachedClient;

  Future<SheetsApiClient> _client() async {
    return _cachedClient ??= _clientFactory(interactive: interactive);
  }

  static String _range(String yearTitle, String a1) => "'$yearTitle'!$a1";

  @override
  Future<String> resolveSpreadsheetId() async {
    final client = await _client();
    return client.resolveSpreadsheetId();
  }

  @override
  Future<List<int>> listYearSheets(String spreadsheetId) async {
    final client = await _client();
    final titles = await client.sheetTitles(spreadsheetId);
    final years = <int>[];
    for (final title in titles) {
      final year = int.tryParse(title);
      if (year != null) {
        years.add(year);
      }
    }
    return years;
  }

  bool _isHeaderRow(List<Object?> row) {
    if (row.length < 6) {
      return false;
    }
    return row[0].toString() == 'Date' && row[5].toString() == 'UUID';
  }

  /// The legacy five-column header written by the previous
  /// implementation: `Date, Type, Category, Description, Amount`
  /// (A:E), with no UUID column. Cells beyond column E, when
  /// present, must be empty for this to count as a legacy
  /// header rather than a data row.
  bool _isLegacyHeaderRow(List<Object?> row) {
    if (row.length < 5) {
      return false;
    }
    const legacy = <String>[
      'Date',
      'Type',
      'Category',
      'Description',
      'Amount',
    ];
    for (var i = 0; i < 5; i++) {
      if (row[i].toString() != legacy[i]) {
        return false;
      }
    }
    for (var i = 5; i < row.length; i++) {
      final value = row[i];
      if (value != null && value.toString().isNotEmpty) {
        return false;
      }
    }
    return true;
  }

  Future<void> _writeHeader(
    SheetsApiClient client,
    String spreadsheetId,
    int year,
  ) async {
    await client.updateValues(
      spreadsheetId,
      _range('$year', 'A1:J1'),
      <List<Object?>>[sheetHeaders],
      // Headers were already written with RAW; unchanged.
      valueInputOption: SheetsValueInputOption.raw,
    );
  }

  @override
  Future<void> ensureYearSheet(String spreadsheetId, int year) async {
    final client = await _client();

    final titles = await client.sheetTitles(spreadsheetId);
    if (!titles.contains('$year')) {
      await client.addSheet(spreadsheetId, '$year');
      await _writeHeader(client, spreadsheetId, year);
      return;
    }

    // Sheet exists: inspect only the header row. A legacy
    // A:E header is extended to A:J in place; data rows are
    // never touched and no UUID is invented for them. A
    // current A:J header needs nothing. An empty first row
    // means an empty sheet, so writing the header is safe. A
    // data row in row 1 with no recognised header is left
    // alone — overwriting it with a header would destroy
    // data.
    final headerValues = await client.readValues(
      spreadsheetId,
      _range('$year', 'A1:J1'),
    );
    final firstRow = headerValues.isEmpty
        ? const <Object?>[]
        : headerValues.first;
    if (_isHeaderRow(firstRow)) {
      return;
    }
    if (_isLegacyHeaderRow(firstRow) ||
        firstRow.every((value) => value == null || value.toString().isEmpty)) {
      await _writeHeader(client, spreadsheetId, year);
    }
  }

  @override
  Future<List<SheetRowData>> readYearSheet(
    String spreadsheetId,
    int year,
  ) async {
    final client = await _client();

    // Positive identification first: if the spreadsheet itself is
    // missing, inaccessible, or unauthorized, sheetTitles throws
    // a classified error and it must propagate — it is never
    // silently converted into "empty worksheet".
    await client.sheetTitles(spreadsheetId);

    late final List<List<Object?>> values;
    try {
      values = await client.readValues(spreadsheetId, _range('$year', 'A:J'));
    } on SheetsApiException catch (error) {
      // Only a verified missing worksheet/range reads as empty.
      // Permission, authentication, network, and missing-
      // spreadsheet errors propagate so the transaction stays
      // pending.
      if (error.kind == SheetsErrorKind.missingWorksheet) {
        return const <SheetRowData>[];
      }
      rethrow;
    }

    final rows = <SheetRowData>[];
    for (var i = 0; i < values.length; i++) {
      final rowValues = values[i];
      if (i == 0 &&
          (_isHeaderRow(rowValues) || _isLegacyHeaderRow(rowValues))) {
        // Current A:J header or legacy A:E header: skipped.
        // Legacy data rows below it keep their (empty) UUID
        // and are never matched or modified by the engine.
        continue;
      }
      if (rowValues.every(
        (value) => value == null || value.toString().isEmpty,
      )) {
        continue;
      }
      rows.add(SheetRowData.fromValues(rowValues, i + 1));
    }
    debugPrint('Sheets sync: read ${rows.length} rows for year $year');
    return rows;
  }

  @override
  Future<void> appendRow(
    String spreadsheetId,
    int year,
    SheetRowData row,
  ) async {
    final client = await _client();
    await client.appendValues(
      spreadsheetId,
      _range('$year', 'A:J'),
      <List<Object?>>[row.toValues()],
      valueInputOption: SheetsValueInputOption.raw,
    );
  }

  @override
  Future<void> updateRow(
    String spreadsheetId,
    int year,
    int rowIndex,
    SheetRowData row,
  ) async {
    final client = await _client();
    await client.updateValues(
      spreadsheetId,
      _range('$year', 'A$rowIndex:J$rowIndex'),
      <List<Object?>>[row.toValues()],
      // RAW: descriptions/notes beginning with `=` stay literal.
      valueInputOption: SheetsValueInputOption.raw,
    );
  }
}
