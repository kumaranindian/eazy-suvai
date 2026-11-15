import 'image_picker_service.dart';

/// Only the web build opens a browser file dialog.
Future<PickedImageFile?> pickWebImageFile(List<String> mimeTypes) =>
    throw UnsupportedError('pickWebImageFile is web only');
