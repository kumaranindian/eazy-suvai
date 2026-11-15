import 'dart:async';
import 'dart:js_interop';

import 'package:web/web.dart' as web;

import 'image_picker_service.dart';

const _inputId = 'eazysuvai-image-input';

/// Opens the browser's file dialog for [mimeTypes] and reads the chosen
/// file's bytes. Null when the user cancels.
///
/// The `<input type=file>` is created and clicked **synchronously**, so the
/// call must come straight from the user's click: browsers only open a file
/// dialog during a user activation. Uses no plugin, so it works even when
/// the build's plugin registrant is out of date.
Future<PickedImageFile?> pickWebImageFile(List<String> mimeTypes) {
  web.document.getElementById(_inputId)?.remove();
  final input = web.HTMLInputElement()
    ..id = _inputId
    ..type = 'file'
    ..accept = mimeTypes.join(',');
  input.style.display = 'none';

  final completer = Completer<PickedImageFile?>();
  void finish(FutureOr<PickedImageFile?> Function() result) {
    if (completer.isCompleted) return;
    input.remove();
    try {
      completer.complete(result());
    } on Object catch (e, s) {
      completer.completeError(e, s);
    }
  }

  input.addEventListener(
    'change',
    (web.Event _) {
      final file = input.files?.item(0);
      if (file == null) {
        finish(() => null);
        return;
      }
      finish(() async {
        final buffer = await file.arrayBuffer().toDart;
        return PickedImageFile(
          bytes: buffer.toDart.asUint8List(),
          name: file.name,
        );
      });
    }.toJS,
  );
  input.addEventListener(
    'cancel',
    (web.Event _) {
      finish(() => null);
    }.toJS,
  );

  web.document.body!.append(input);
  input.click();
  return completer.future;
}
