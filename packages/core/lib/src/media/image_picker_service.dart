import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';

import 'web_file_input_stub.dart'
    if (dart.library.js_interop) 'web_file_input.dart';

/// A file chosen by the user, before any checks.
@immutable
class PickedImageFile {
  const PickedImageFile({required this.bytes, required this.name});

  final Uint8List bytes;
  final String name;
}

/// The picker could not be opened. [accessDenied] is true only when the
/// operating system refused access to the photo library (iOS); the browser
/// never asks for a photo permission.
class ImagePickException implements Exception {
  const ImagePickException({this.accessDenied = false, this.cause});

  final bool accessDenied;
  final Object? cause;

  @override
  String toString() =>
      'ImagePickException(accessDenied: $accessDenied, cause: $cause)';
}

/// Opens the photo library (Android, iOS) or a file dialog (web).
abstract class ImageFilePicker {
  /// The chosen file, or null if the user cancelled. Throws
  /// [ImagePickException] when the picker can't be opened.
  ///
  /// Call it straight from the click handler, with no `await` before it:
  /// on the web the file dialog only opens during the user's click.
  Future<PickedImageFile?> pick();
}

/// The types the file dialog offers (FR-102, matches the field hint).
const acceptedImageMimeTypes = ['image/jpeg', 'image/png', 'image/webp'];

/// [ImageFilePicker] for the device.
///
/// * Web: a plain `<input type=file>` limited to JPEG, PNG and WebP. No
///   permission is involved.
/// * Android: the system photo picker through `image_picker`. It needs no
///   storage permission.
/// * iOS: PHPicker through `image_picker` (`requestFullMetadata: false`),
///   which needs no library permission on iOS 14+. Older versions may ask,
///   and a refusal becomes [ImagePickException.accessDenied].
class DeviceImageFilePicker implements ImageFilePicker {
  DeviceImageFilePicker([ImagePicker? picker, bool? web])
    : _picker = picker ?? ImagePicker(),
      _web = web ?? kIsWeb;

  final ImagePicker _picker;
  final bool _web;

  @override
  Future<PickedImageFile?> pick() {
    // Not async: on the web the dialog must open in this call stack.
    if (_web) {
      try {
        return pickWebImageFile(
          acceptedImageMimeTypes,
        ).catchError((Object e) => throw ImagePickException(cause: e));
      } on Object catch (e) {
        return Future.error(ImagePickException(cause: e));
      }
    }
    return _pickDevice();
  }

  Future<PickedImageFile?> _pickDevice() async {
    final XFile? file;
    try {
      // No maxWidth/imageQuality: the original bytes are checked against
      // the FR-102 rules first, then cropped and re-encoded by ImagePreparer.
      file = await _picker.pickImage(
        source: ImageSource.gallery,
        requestFullMetadata: false,
      );
    } on PlatformException catch (e) {
      throw ImagePickException(accessDenied: isAccessDenied(e), cause: e);
    } on Object catch (e) {
      throw ImagePickException(cause: e);
    }
    if (file == null) return null;
    return PickedImageFile(bytes: await file.readAsBytes(), name: file.name);
  }

  /// `image_picker_ios` reports a refused library permission as
  /// `photo_access_denied` (or `..._restricted` under Screen Time).
  @visibleForTesting
  static bool isAccessDenied(PlatformException e) =>
      e.code.endsWith('access_denied') || e.code.endsWith('access_restricted');
}

final imageFilePickerProvider = Provider<ImageFilePicker>(
  (ref) => DeviceImageFilePicker(),
);
