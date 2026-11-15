// Real V2 backend over the Sheets API client boundary (ADR-015).
//
// Reuses the classified-error [SheetsApiClient] boundary from the V1
// backend so tests inject a fake client. Every value is written with
// RAW input: text stays literal (no formula evaluation) and amounts,
// passed as numbers, are stored as NUMBER cells.

import 'package:flutter/foundation.dart';

import '../google_drive_service.dart';
import '../google_sheets_backend.dart';
import 'sheets_v2_contract.dart';
import 'sheets_v2_engine.dart';

class GoogleSheetsV2Backend implements SheetsV2SyncBackend {
  GoogleSheetsV2Backend._({required this.interactive})
    : _clientFactory = _defaultFactory;

  /// Test constructor: injects a fake client.
  GoogleSheetsV2Backend.forTesting({
    required SheetsApiClient client,
    this.interactive = false,
  }) : _clientFactory = (({required bool interactive}) => client),
       _cachedClient = client;

  /// Test constructor: injects a client factory, so tests can record
  /// the authorization mode a backend requests.
  GoogleSheetsV2Backend.withClientFactory({
    required this.interactive,
    required SheetsApiClientFactory clientFactory,
  }) : _clientFactory = clientFactory;

  /// Background mode: never initiates authentication/authorization.
  static final GoogleSheetsV2Backend instance = GoogleSheetsV2Backend._(
    interactive: false,
  );

  /// Explicit Settings actions only.
  static final GoogleSheetsV2Backend interactiveInstance =
      GoogleSheetsV2Backend._(interactive: true);

  static SheetsApiClient _defaultFactory({required bool interactive}) {
    return GoogleApisSheetsClient(
      interactive: interactive,
      unformattedValues: true,
      spreadsheetResolver: ({required bool interactive}) async {
        final result = await GoogleDriveService.instance.setupExpenseTrackerV2(
          allowInteractiveAuthorization: interactive,
        );
        return result.fileId;
      },
    );
  }

  final bool interactive;
  final SheetsApiClientFactory _clientFactory;
  SheetsApiClient? _cachedClient;

  SheetsApiClient _client() =>
      _cachedClient ??= _clientFactory(interactive: interactive);

  static String _range(String title, String a1) => "'$title'!$a1";

  @override
  Future<String> resolveSpreadsheetId() => _client().resolveSpreadsheetId();

  @override
  Future<void> verifyV2Identity(String spreadsheetId) async {
    final client = _client();
    final titles = await client.sheetTitles(spreadsheetId);
    if (titles.contains(sheetsV2MetaTitle)) {
      final values = await client.readValues(
        spreadsheetId,
        _range(sheetsV2MetaTitle, 'A1:B10'),
      );
      for (final row in values) {
        if (row.length >= 2 && row[0].toString() == sheetsV2MetaVersionKey) {
          if (row[1].toString() == sheetsV2MetaVersionValue) {
            return;
          }
          throw SheetsV2IdentityException(
            'Unsupported sheet schema version: ${row[1]}.',
          );
        }
      }
      throw const SheetsV2IdentityException(
        'The _meta worksheet has no schema version.',
      );
    }
    // No _meta: only a spreadsheet without year data may be claimed.
    // One with data is treated as V1 and never written.
    if (titles.any((title) => int.tryParse(title) != null)) {
      throw const SheetsV2IdentityException(
        'Spreadsheet has data but no _meta worksheet; refusing to write.',
      );
    }
    await client.addSheet(spreadsheetId, sheetsV2MetaTitle);
    await client.updateValues(
      spreadsheetId,
      _range(sheetsV2MetaTitle, 'A1:B2'),
      <List<Object?>>[
        <Object?>[sheetsV2MetaVersionKey, sheetsV2MetaVersionValue],
        <Object?>[sheetsV2MetaWriterKey, sheetsV2WriterVersion],
      ],
      valueInputOption: SheetsValueInputOption.raw,
    );
  }

  @override
  Future<List<int>> listYearSheets(String spreadsheetId) async {
    final titles = await _client().sheetTitles(spreadsheetId);
    return <int>[
      for (final title in titles)
        if (int.tryParse(title) != null) int.parse(title),
    ];
  }

  static bool _isV2Header(List<Object?> row) =>
      row.length >= 11 &&
      row[0].toString() == 'Date' &&
      row[5].toString() == 'UUID' &&
      row[10].toString() == 'Kind';

  /// An A:J header with nothing after J: extended to A:Y in place.
  static bool _isAjHeader(List<Object?> row) {
    if (row.length < 10) {
      return false;
    }
    for (var i = 0; i < 10; i++) {
      if (row[i].toString() != sheetV2Headers[i]) {
        return false;
      }
    }
    for (var i = 10; i < row.length; i++) {
      final value = row[i];
      if (value != null && value.toString().isNotEmpty) {
        return false;
      }
    }
    return true;
  }

  Future<void> _writeHeader(String spreadsheetId, int year) {
    return _client().updateValues(
      spreadsheetId,
      _range('$year', 'A1:${sheetV2LastColumn}1'),
      <List<Object?>>[sheetV2Headers],
      valueInputOption: SheetsValueInputOption.raw,
    );
  }

  @override
  Future<void> ensureYearSheet(String spreadsheetId, int year) async {
    final client = _client();
    final titles = await client.sheetTitles(spreadsheetId);
    if (!titles.contains('$year')) {
      await client.addSheet(spreadsheetId, '$year');
      await _writeHeader(spreadsheetId, year);
      return;
    }
    final values = await client.readValues(
      spreadsheetId,
      _range('$year', 'A1:${sheetV2LastColumn}1'),
    );
    final first = values.isEmpty ? const <Object?>[] : values.first;
    if (_isV2Header(first)) {
      return;
    }
    // A data row in row 1 is never overwritten.
    if (_isAjHeader(first) ||
        first.every((value) => value == null || value.toString().isEmpty)) {
      await _writeHeader(spreadsheetId, year);
    }
  }

  @override
  Future<List<SheetV2Row>> readYearSheet(String spreadsheetId, int year) async {
    final client = _client();
    // Spreadsheet-level failures must propagate, never read as empty.
    await client.sheetTitles(spreadsheetId);
    late final List<List<Object?>> values;
    try {
      values = await client.readValues(
        spreadsheetId,
        _range('$year', 'A:$sheetV2LastColumn'),
      );
    } on SheetsApiException catch (error) {
      if (error.kind == SheetsErrorKind.missingWorksheet) {
        return const <SheetV2Row>[];
      }
      rethrow;
    }
    final rows = <SheetV2Row>[];
    for (var i = 0; i < values.length; i++) {
      final rowValues = values[i];
      if (i == 0 && (_isV2Header(rowValues) || _isAjHeader(rowValues))) {
        continue;
      }
      if (rowValues.every(
        (value) => value == null || value.toString().isEmpty,
      )) {
        continue;
      }
      rows.add(SheetV2Row.fromValues(rowValues, i + 1));
    }
    debugPrint('Sheets V2 sync: read ${rows.length} rows for year $year');
    return rows;
  }

  @override
  Future<void> appendRow(String spreadsheetId, int year, SheetV2Row row) {
    return _client().appendValues(
      spreadsheetId,
      _range('$year', 'A:$sheetV2LastColumn'),
      <List<Object?>>[row.toValues()],
      valueInputOption: SheetsValueInputOption.raw,
    );
  }

  @override
  Future<void> updateRow(
    String spreadsheetId,
    int year,
    int rowIndex,
    SheetV2Row row,
  ) {
    return _client().updateValues(
      spreadsheetId,
      _range('$year', 'A$rowIndex:$sheetV2LastColumn$rowIndex'),
      <List<Object?>>[row.toValues()],
      valueInputOption: SheetsValueInputOption.raw,
    );
  }
}
