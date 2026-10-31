import 'package:flutter/foundation.dart';
import 'package:googleapis/sheets/v4.dart' as sheets;

import '../auth/google_auth_service.dart';
import 'google_drive_service.dart';
import 'sheets_sync.dart';

/// Real [SheetsSyncBackend] backed by Google Drive + Sheets APIs.
///
/// Spreadsheet identity is resolved through Drive on every sync run
/// (see docs/sheets-sync.md): [GoogleDriveService] finds or creates
/// the one "Expense Tracker" folder and spreadsheet, so repeated
/// setup never duplicates them and a restart re-finds the same file.
/// Nothing here logs tokens, spreadsheet ids, or transaction data —
/// only counts/years at debug level, with no row contents.
class GoogleSheetsBackend implements SheetsSyncBackend {
  GoogleSheetsBackend._();

  static final GoogleSheetsBackend instance = GoogleSheetsBackend._();

  static String _range(String yearTitle, String a1) => "'$yearTitle'!$a1";

  Future<sheets.SheetsApi> _sheetsApi() {
    return GoogleAuthService.instance.getSheetsApi();
  }

  @override
  Future<String> resolveSpreadsheetId() async {
    final result = await GoogleDriveService.instance.setupExpenseTracker();
    return result.fileId;
  }

  @override
  Future<List<int>> listYearSheets(String spreadsheetId) async {
    final api = await _sheetsApi();
    final spreadsheet = await api.spreadsheets.get(
      spreadsheetId,
      $fields: 'sheets(properties(title))',
    );

    final years = <int>[];
    for (final sheet in spreadsheet.sheets ?? const <sheets.Sheet>[]) {
      final year = int.tryParse(sheet.properties?.title ?? '');
      if (year != null) {
        years.add(year);
      }
    }
    return years;
  }

  Future<List<List<Object?>>> _readValues(
    sheets.SheetsApi api,
    String spreadsheetId,
    int year,
  ) async {
    final response = await api.spreadsheets.values.get(
      spreadsheetId,
      _range('$year', 'A:J'),
    );
    final values = response.values;
    if (values == null) {
      return const <List<Object?>>[];
    }
    return values;
  }

  bool _isHeaderRow(List<Object?> row) {
    if (row.length < 6) {
      return false;
    }
    return row[0].toString() == 'Date' && row[5].toString() == 'UUID';
  }

  Future<void> _writeHeader(
    sheets.SheetsApi api,
    String spreadsheetId,
    int year,
  ) async {
    await api.spreadsheets.values.update(
      sheets.ValueRange(values: <List<Object?>>[sheetHeaders]),
      spreadsheetId,
      _range('$year', 'A1:J1'),
      valueInputOption: 'RAW',
    );
  }

  @override
  Future<void> ensureYearSheet(String spreadsheetId, int year) async {
    final api = await _sheetsApi();

    final years = await listYearSheets(spreadsheetId);
    if (!years.contains(year)) {
      await api.spreadsheets.batchUpdate(
        sheets.BatchUpdateSpreadsheetRequest(
          requests: <sheets.Request>[
            sheets.Request(
              addSheet: sheets.AddSheetRequest(
                properties: sheets.SheetProperties(title: '$year'),
              ),
            ),
          ],
        ),
        spreadsheetId,
      );
      await _writeHeader(api, spreadsheetId, year);
      return;
    }

    // Sheet exists: write the header only when it is empty, so
    // existing rows are never touched.
    final values = await _readValues(api, spreadsheetId, year);
    if (values.isEmpty) {
      await _writeHeader(api, spreadsheetId, year);
    }
  }

  @override
  Future<List<SheetRowData>> readYearSheet(
    String spreadsheetId,
    int year,
  ) async {
    final api = await _sheetsApi();

    late final List<List<Object?>> values;
    try {
      values = await _readValues(api, spreadsheetId, year);
    } catch (error) {
      // A missing worksheet reads as empty; ensureYearSheet (called
      // before every read in the engine) creates it. Other errors
      // are surfaced by the caller, not hidden here, except for the
      // not-found case Sheets reports for a sheet that does not
      // exist yet.
      if (error.toString().contains('Unable to parse range') ||
          error.toString().contains('404')) {
        return const <SheetRowData>[];
      }
      rethrow;
    }

    final rows = <SheetRowData>[];
    for (var i = 0; i < values.length; i++) {
      final rowValues = values[i];
      if (i == 0 && _isHeaderRow(rowValues)) {
        continue;
      }
      if (rowValues.every((value) => value == null || value.toString().isEmpty)) {
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
    final api = await _sheetsApi();
    await api.spreadsheets.values.append(
      sheets.ValueRange(values: <List<Object?>>[row.toValues()]),
      spreadsheetId,
      _range('$year', 'A:J'),
      valueInputOption: 'USER_ENTERED',
      insertDataOption: 'INSERT_ROWS',
    );
  }

  @override
  Future<void> updateRow(
    String spreadsheetId,
    int year,
    int rowIndex,
    SheetRowData row,
  ) async {
    final api = await _sheetsApi();
    await api.spreadsheets.values.update(
      sheets.ValueRange(values: <List<Object?>>[row.toValues()]),
      spreadsheetId,
      _range('$year', 'A$rowIndex:J$rowIndex'),
      valueInputOption: 'USER_ENTERED',
    );
  }
}
