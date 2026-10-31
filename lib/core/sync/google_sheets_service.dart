import 'package:expense_tracker/core/auth/google_auth_service.dart';
import 'package:extension_google_sign_in_as_googleapis_auth/extension_google_sign_in_as_googleapis_auth.dart';
import 'package:googleapis/sheets/v4.dart' as sheets;

class GoogleSheetsService {
  GoogleSheetsService._();

  static final GoogleSheetsService instance =
      GoogleSheetsService._();

  static const String _spreadsheetName = 'Expense Tracker';

  static const String _expensesSheetName = 'Expenses';

  static const List<String> _scopes = <String>[
    'https://www.googleapis.com/auth/spreadsheets',
  ];

  Future<sheets.SheetsApi> _getSheetsApi() async {
    final user = GoogleAuthService.instance.currentUser;

    if (user == null) {
      throw StateError(
        'Google account is not signed in.',
      );
    }

    final authorization =
        await user.authorizationClient.authorizeScopes(
      _scopes,
    );

    final authenticatedClient = authorization.authClient(
      scopes: _scopes,
    );

    return sheets.SheetsApi(
      authenticatedClient,
    );
  }

  Future<String> createSpreadsheet() async {
    final sheetsApi = await _getSheetsApi();

    final spreadsheet = sheets.Spreadsheet(
      properties: sheets.SpreadsheetProperties(
        title: _spreadsheetName,
      ),
      sheets: <sheets.Sheet>[
        sheets.Sheet(
          properties: sheets.SheetProperties(
            title: _expensesSheetName,
          ),
        ),
      ],
    );

    final created = await sheetsApi.spreadsheets.create(
      spreadsheet,
    );

    final spreadsheetId = created.spreadsheetId;

    if (spreadsheetId == null || spreadsheetId.isEmpty) {
      throw StateError(
        'Google Sheets spreadsheet could not be created.',
      );
    }

    return spreadsheetId;
  }

  Future<void> writeHeaders(
    String spreadsheetId,
  ) async {
    final sheetsApi = await _getSheetsApi();

    final valueRange = sheets.ValueRange(
      values: <List<Object?>>[
        <Object?>[
          'Date',
          'Type',
          'Category',
          'Description',
          'Amount',
        ],
      ],
    );

    await sheetsApi.spreadsheets.values.update(
      valueRange,
      spreadsheetId,
      '$_expensesSheetName!A1:E1',
      valueInputOption: 'RAW',
    );
  }

  Future<void> appendExpense({
    required String spreadsheetId,
    required String date,
    required String type,
    required String category,
    required String description,
    required double amount,
  }) async {
    final sheetsApi = await _getSheetsApi();

    final valueRange = sheets.ValueRange(
      values: <List<Object?>>[
        <Object?>[
          date,
          type,
          category,
          description,
          amount,
        ],
      ],
    );

    await sheetsApi.spreadsheets.values.append(
      valueRange,
      spreadsheetId,
      '$_expensesSheetName!A:E',
      valueInputOption: 'USER_ENTERED',
      insertDataOption: 'INSERT_ROWS',
    );
  }

  Future<void> backupExpense({
    required String date,
    required String type,
    required String category,
    required String description,
    required double amount,
  }) async {
    final spreadsheetId = await createSpreadsheet();

    await writeHeaders(
      spreadsheetId,
    );

    await appendExpense(
      spreadsheetId: spreadsheetId,
      date: date,
      type: type,
      category: category,
      description: description,
      amount: amount,
    );
  }
}