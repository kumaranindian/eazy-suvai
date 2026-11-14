import 'dart:async';
import 'dart:typed_data';

import 'package:flutter/widgets.dart';

import 'image_picker_service.dart';
import 'image_upload_service.dart';
import 'storage_image_resolver.dart';

/// Returns [next] from [pick] (null = the user cancelled), or throws
/// [error] if set.
class FakeImageFilePicker implements ImageFilePicker {
  FakeImageFilePicker([this.next]);

  PickedImageFile? next;
  Object? error;
  int calls = 0;

  @override
  Future<PickedImageFile?> pick() async {
    calls++;
    if (error != null) throw error!;
    return next;
  }
}

/// An upload the test drives with [emit], [complete] and [fail].
class FakeImageUpload implements ImageUpload {
  FakeImageUpload(this.request, this.path);

  final ImageUploadRequest request;
  @override
  final String path;

  final _progress = StreamController<double>.broadcast();
  final _done = Completer<void>();
  bool canceled = false;

  @override
  Stream<double> get progress => _progress.stream;

  @override
  Future<void> get done => _done.future;

  void emit(double fraction) => _progress.add(fraction);

  void complete() {
    if (!_done.isCompleted) _done.complete();
  }

  void fail([Object error = 'network']) {
    if (!_done.isCompleted) _done.completeError(error);
  }

  @override
  Future<void> cancel() async {
    canceled = true;
    if (!_done.isCompleted) _done.completeError(const ImageUploadCanceled());
  }
}

/// Records every upload. Uploads stay open until the test completes them.
class FakeImageUploader implements ImageUploader {
  final uploads = <FakeImageUpload>[];

  FakeImageUpload get last => uploads.last;

  @override
  ImageUpload start(ImageUploadRequest request) {
    final upload = FakeImageUpload(
      request,
      'restaurants/${request.restaurantId}/images/'
      'fake${uploads.length.toString().padLeft(16, '0')}'
      '/original.${request.format.extension}',
    );
    uploads.add(upload);
    return upload;
  }
}

/// Resolves every path to a 1 × 1 PNG and records the paths asked for.
class FakeStorageImageResolver implements StorageImageResolver {
  final resolved = <String>[];

  @override
  Future<ImageProvider> resolve(String path) async {
    resolved.add(path);
    return MemoryImage(transparentPng);
  }
}

/// A valid 1 × 1 transparent PNG.
final transparentPng = Uint8List.fromList(const [
  0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A, 0x00, 0x00, 0x00, 0x0D, //
  0x49, 0x48, 0x44, 0x52, 0x00, 0x00, 0x00, 0x01, 0x00, 0x00, 0x00, 0x01,
  0x08, 0x06, 0x00, 0x00, 0x00, 0x1F, 0x15, 0xC4, 0x89, 0x00, 0x00, 0x00,
  0x0D, 0x49, 0x44, 0x41, 0x54, 0x78, 0x9C, 0x63, 0x00, 0x01, 0x00, 0x00,
  0x05, 0x00, 0x01, 0x0D, 0x0A, 0x2D, 0xB4, 0x00, 0x00, 0x00, 0x00, 0x49,
  0x45, 0x4E, 0x44, 0xAE, 0x42, 0x60, 0x82,
]);
