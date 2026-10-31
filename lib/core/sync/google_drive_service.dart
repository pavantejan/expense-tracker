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

class GoogleDriveService {
  GoogleDriveService._();

  static final GoogleDriveService instance =
      GoogleDriveService._();

  static const String _folderName = 'Expense Tracker';

  static const String _spreadsheetName = 'Expense Tracker';

  static const String _spreadsheetMimeType =
      'application/vnd.google-apps.spreadsheet';

  Future<drive.DriveApi> _getDriveApi() {
    return GoogleAuthService.instance.getDriveApi();
  }

  Future<GoogleDriveSetupResult> setupExpenseTracker() async {
    final api = await _getDriveApi();

    final folder =
        await _findOrCreateExpenseTrackerFolder(api);

    final folderId = folder.id;

    if (folderId == null || folderId.isEmpty) {
      throw StateError(
        'Expense Tracker folder could not be created.',
      );
    }

    final spreadsheet =
        await _findSpreadsheet(api, folderId) ??
            await _createSpreadsheet(
              api,
              folderId,
            );

    final spreadsheetId = spreadsheet.id;

    if (spreadsheetId == null || spreadsheetId.isEmpty) {
      throw StateError(
        'Expense Tracker Google Sheet could not be created.',
      );
    }

    return GoogleDriveSetupResult(
      folderId: folderId,
      fileId: spreadsheetId,
      fileName:
          spreadsheet.name ?? _spreadsheetName,
      webViewLink: spreadsheet.webViewLink,
    );
  }

  Future<drive.File> _findOrCreateExpenseTrackerFolder(
    drive.DriveApi api,
  ) async {
    final result = await api.files.list(
      q: "name = '$_folderName' "
          "and mimeType = "
          "'application/vnd.google-apps.folder' "
          "and trashed = false",
      spaces: 'drive',
      $fields: 'files(id,name,mimeType,webViewLink)',
      pageSize: 10,
    );

    final files = result.files;

    if (files != null && files.isNotEmpty) {
      return files.first;
    }

    final metadata = drive.File()
      ..name = _folderName
      ..mimeType =
          'application/vnd.google-apps.folder';

    return api.files.create(
      metadata,
      $fields: 'id,name,mimeType,webViewLink',
    );
  }

  Future<drive.File?> _findSpreadsheet(
    drive.DriveApi api,
    String folderId,
  ) async {
    final result = await api.files.list(
      q: "'$folderId' in parents "
          "and name = '$_spreadsheetName' "
          "and mimeType = '$_spreadsheetMimeType' "
          "and trashed = false",
      spaces: 'drive',
      $fields:
          'files(id,name,mimeType,webViewLink,parents)',
      pageSize: 10,
    );

    final files = result.files;

    if (files == null || files.isEmpty) {
      return null;
    }

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
      $fields:
          'id,name,mimeType,webViewLink,parents',
    );
  }
}