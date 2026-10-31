import 'package:googleapis/drive/v3.dart' as drive;

import '../auth/google_auth_service.dart';

class GoogleDriveSetupResult {
  const GoogleDriveSetupResult({
    required this.folderId,
    required this.fileId,
    required this.fileName,
    this.webViewLink,
  });

  final String folderId;
  final String fileId;
  final String fileName;
  final String? webViewLink;
}

/// Drive discovery for the one managed spreadsheet.
///
/// Scope limitation (important): this service uses the
/// `drive.file` scope, which grants per-file access only to files
/// the app created (or the user opened with the app). It does NOT
/// guarantee visibility of a folder or spreadsheet the user
/// created manually in Drive, even with the same name. The
/// implementation therefore works only with the app-created
/// folder/spreadsheet it finds or creates below. A manually
/// created "Expense Tracker" folder will generally NOT be found,
/// and the app will create its own app-created folder with the
/// same display name — the user may then see two same-named
/// folders in Drive, and the app uses only its own. Do not claim
/// otherwise, do not silently broaden scopes to fix this, and
/// never delete or merge user files automatically.
///
/// If picking an existing user-created folder becomes required,
/// the safe follow-up is a Google Picker-based flow (user picks
/// the folder, granting access to that file), evaluated
/// separately — it is not implemented here. A more robust
/// long-term fix is to remember the app-created folder and
/// spreadsheet ids persistently (Drift SyncSettings table +
/// build_runner regeneration, see docs/sheets-sync.md), so
/// name-based discovery is not needed at all.
///
/// Within the app-created set, discovery is find-or-create: an
/// existing folder/spreadsheet is reused, and a new one is
/// created only when none is found. When more than one
/// app-created match exists (ambiguous), the first match wins
/// and no new file is created; the ambiguity is documented for
/// manual reconciliation and nothing is deleted or merged.
class GoogleDriveService {
  GoogleDriveService._();

  static final GoogleDriveService instance = GoogleDriveService._();

  static const String _folderName = 'Expense Tracker';

  static const String _spreadsheetName = 'Expense Tracker';

  static const String _spreadsheetMimeType =
      'application/vnd.google-apps.spreadsheet';

  Future<drive.DriveApi> _getDriveApi({
    required bool allowInteractiveAuthorization,
  }) {
    return GoogleAuthService.instance.getDriveApi(
      allowInteractiveAuthorization: allowInteractiveAuthorization,
    );
  }

  Future<GoogleDriveSetupResult> setupExpenseTracker({
    bool allowInteractiveAuthorization = false,
  }) async {
    final api = await _getDriveApi(
      allowInteractiveAuthorization: allowInteractiveAuthorization,
    );

    final folder = await _findOrCreateExpenseTrackerFolder(api);

    final folderId = folder.id;

    if (folderId == null || folderId.isEmpty) {
      throw StateError('Expense Tracker folder could not be created.');
    }

    final spreadsheet =
        await _findSpreadsheet(api, folderId) ??
        await _createSpreadsheet(api, folderId);

    final spreadsheetId = spreadsheet.id;

    if (spreadsheetId == null || spreadsheetId.isEmpty) {
      throw StateError('Expense Tracker Google Sheet could not be created.');
    }

    return GoogleDriveSetupResult(
      folderId: folderId,
      fileId: spreadsheetId,
      fileName: spreadsheet.name ?? _spreadsheetName,
      webViewLink: spreadsheet.webViewLink,
    );
  }

  Future<drive.File> _findOrCreateExpenseTrackerFolder(
    drive.DriveApi api,
  ) async {
    final result = await api.files.list(
      q:
          "name = '$_folderName' "
          "and mimeType = "
          "'application/vnd.google-apps.folder' "
          "and trashed = false",
      spaces: 'drive',
      $fields: 'files(id,name,mimeType,webViewLink)',
      pageSize: 10,
    );

    final files = result.files;

    if (files != null && files.isNotEmpty) {
      // Ambiguous duplicates among app-created folders: reuse
      // the first and create no new folder. Manual reconciliation
      // in Drive is documented in docs/sheets-sync.md.
      return files.first;
    }

    final metadata = drive.File()
      ..name = _folderName
      ..mimeType = 'application/vnd.google-apps.folder';

    return api.files.create(metadata, $fields: 'id,name,mimeType,webViewLink');
  }

  Future<drive.File?> _findSpreadsheet(
    drive.DriveApi api,
    String folderId,
  ) async {
    final result = await api.files.list(
      q:
          "'$folderId' in parents "
          "and name = '$_spreadsheetName' "
          "and mimeType = '$_spreadsheetMimeType' "
          "and trashed = false",
      spaces: 'drive',
      $fields: 'files(id,name,mimeType,webViewLink,parents)',
      pageSize: 10,
    );

    final files = result.files;

    if (files == null || files.isEmpty) {
      return null;
    }

    // Ambiguous duplicates among app-created spreadsheets in this
    // folder: reuse the first and create no new spreadsheet.
    // Manual reconciliation is documented in docs/sheets-sync.md.
    return files.first;
  }

  Future<drive.File> _createSpreadsheet(
    drive.DriveApi api,
    String folderId,
  ) async {
    final metadata = drive.File()
      ..name = _spreadsheetName
      ..mimeType = _spreadsheetMimeType
      ..parents = <String>[folderId];

    return api.files.create(
      metadata,
      $fields: 'id,name,mimeType,webViewLink,parents',
    );
  }
}
