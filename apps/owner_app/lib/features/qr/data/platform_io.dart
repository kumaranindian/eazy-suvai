import 'dart:typed_data';

import 'package:share_plus/share_plus.dart';

/// Android and iOS: files go to the share sheet, which offers "Save to
/// Files", "Save image", Drive, WhatsApp, printers and so on.
Future<bool> platformSaveFile(
  Uint8List bytes, {
  required String fileName,
  required String mimeType,
}) async {
  final result = await SharePlus.instance.share(
    ShareParams(
      files: [XFile.fromData(bytes, name: fileName, mimeType: mimeType)],
      fileNameOverrides: [fileName],
    ),
  );
  return result.status != ShareResultStatus.dismissed;
}

/// The native share sheet always exists on Android and iOS.
bool platformCanShareText() => true;

/// Saving on mobile opens the share sheet; on web it is a download.
const platformSavesByDownload = false;
