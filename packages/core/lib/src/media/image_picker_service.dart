import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';

/// A file chosen by the user, before any checks.
@immutable
class PickedImageFile {
  const PickedImageFile({required this.bytes, required this.name});

  final Uint8List bytes;
  final String name;
}

/// Opens the photo library (Android, iOS) or a file dialog (web).
abstract class ImageFilePicker {
  /// The chosen file, or null if the user cancelled.
  Future<PickedImageFile?> pick();
}

/// [ImageFilePicker] backed by `image_picker`. On Android it uses the
/// system photo picker, which needs no storage permission. On iOS it needs
/// `NSPhotoLibraryUsageDescription` in `Info.plist`.
class DeviceImageFilePicker implements ImageFilePicker {
  DeviceImageFilePicker([ImagePicker? picker])
    : _picker = picker ?? ImagePicker();

  final ImagePicker _picker;

  @override
  Future<PickedImageFile?> pick() async {
    // No maxWidth/imageQuality: the original bytes are checked against the
    // FR-102 rules first, then cropped and re-encoded by ImagePreparer.
    final file = await _picker.pickImage(
      source: ImageSource.gallery,
      requestFullMetadata: false,
    );
    if (file == null) return null;
    return PickedImageFile(bytes: await file.readAsBytes(), name: file.name);
  }
}

final imageFilePickerProvider = Provider<ImageFilePicker>(
  (ref) => DeviceImageFilePicker(),
);
