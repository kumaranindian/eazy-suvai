import 'dart:js_interop';
import 'dart:js_interop_unsafe';
import 'dart:typed_data';

import 'package:web/web.dart' as web;

/// Web: a normal browser download (`<a download>` on a Blob URL).
Future<bool> platformSaveFile(
  Uint8List bytes, {
  required String fileName,
  required String mimeType,
}) async {
  final blob = web.Blob([bytes.toJS].toJS, web.BlobPropertyBag(type: mimeType));
  final url = web.URL.createObjectURL(blob);
  final anchor = web.document.createElement('a') as web.HTMLAnchorElement
    ..href = url
    ..download = fileName
    ..style.display = 'none';
  web.document.body!.append(anchor);
  anchor.click();
  anchor.remove();
  // Give the browser time to start the download before revoking.
  Future<void>.delayed(
    const Duration(seconds: 30),
    () => web.URL.revokeObjectURL(url),
  );
  return true;
}

/// Whether the browser has the Web Share API (`navigator.share`).
bool platformCanShareText() => (web.window.navigator as JSObject).has('share');

/// Saving on web is a download.
const platformSavesByDownload = true;
