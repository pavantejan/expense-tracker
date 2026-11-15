import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

/// Where exported files go and where restore files come from. Injected
/// so tests never touch platform plugins.
abstract class FileGateway {
  /// Lets the user choose a location and saves [content] there.
  /// Returns false when the user cancelled.
  Future<bool> saveText({
    required String fileName,
    required String content,
    required String mimeType,
  });

  /// Opens the share sheet with [content] as a file. The temporary copy
  /// needed for sharing is deleted afterwards.
  Future<void> shareText({
    required String fileName,
    required String content,
    required String mimeType,
  });

  /// Lets the user pick a file; returns its text, or null if cancelled.
  Future<String?> pickText({required List<String> extensions});
}

class PlatformFileGateway implements FileGateway {
  const PlatformFileGateway();

  @override
  Future<bool> saveText({
    required String fileName,
    required String content,
    required String mimeType,
  }) async {
    final uri = await FilePicker.saveFile(
      fileName: fileName,
      bytes: Uint8List.fromList(utf8.encode(content)),
      mimeType: mimeType,
    );
    return uri != null;
  }

  @override
  Future<void> shareText({
    required String fileName,
    required String content,
    required String mimeType,
  }) async {
    // App-private temporary directory; removed as soon as the share
    // sheet returns (blueprint section 11.3).
    final dir = await getTemporaryDirectory();
    final file = File('${dir.path}/$fileName');
    await file.writeAsString(content, flush: true);
    try {
      await SharePlus.instance.share(
        ShareParams(files: [XFile(file.path, mimeType: mimeType)]),
      );
    } finally {
      if (await file.exists()) {
        await file.delete();
      }
    }
  }

  @override
  Future<String?> pickText({required List<String> extensions}) async {
    final picked = await FilePicker.pickFile(
      type: FileType.custom,
      allowedExtensions: extensions,
    );
    if (picked == null) {
      return null;
    }
    return utf8.decode(await picked.readAsBytes());
  }
}
