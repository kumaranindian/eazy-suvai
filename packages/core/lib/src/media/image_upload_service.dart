import 'dart:async';
import 'dart:math' as math;

import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'image_object.dart';
import 'image_sniffer.dart';

/// What to upload and which document `processImage` should update.
@immutable
class ImageUploadRequest {
  const ImageUploadRequest({
    required this.restaurantId,
    required this.purpose,
    required this.targetPath,
    required this.bytes,
    required this.format,
  });

  final String restaurantId;
  final ImagePurpose purpose;

  /// Firestore document that will hold the image object, inside
  /// `restaurants/{restaurantId}`: the restaurant itself for logo and
  /// cover, `.../categories/{cid}` or `.../items/{iid}` otherwise. The
  /// document must exist before the upload.
  final String targetPath;
  final Uint8List bytes;
  final ImageFormat format;

  /// The upload's custom metadata, checked by `storage.rules` and
  /// `processImage`.
  Map<String, String> get metadata => {
    'purpose': purpose.wire,
    'targetPath': targetPath,
    'field': purpose.field,
  };
}

/// Thrown by [ImageUpload.done] after [ImageUpload.cancel].
class ImageUploadCanceled implements Exception {
  const ImageUploadCanceled();
}

/// One running upload.
abstract class ImageUpload {
  /// Storage path of the original being uploaded.
  String get path;

  /// Fraction sent, 0 to 1.
  Stream<double> get progress;

  /// Completes when the file is stored; throws [ImageUploadCanceled] after
  /// [cancel], or another error if the upload failed.
  Future<void> get done;

  Future<void> cancel();
}

abstract class ImageUploader {
  ImageUpload start(ImageUploadRequest request);
}

/// Storage path for a new upload:
/// `restaurants/{rid}/images/{imageId}/original.{ext}` (architecture §4.4).
String newImagePath(String restaurantId, ImageFormat format) =>
    'restaurants/$restaurantId/images/${newImageId()}/original.${format.extension}';

const _idChars =
    'ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789';

/// A random 20-character id (the format of Firestore auto-IDs).
String newImageId([math.Random? random]) {
  final r = random ?? math.Random.secure();
  return String.fromCharCodes(
    List.generate(20, (_) => _idChars.codeUnitAt(r.nextInt(_idChars.length))),
  );
}

/// [ImageUploader] for Cloud Storage.
class FirebaseImageUploader implements ImageUploader {
  FirebaseImageUploader(this._storage);

  final FirebaseStorage _storage;

  @override
  ImageUpload start(ImageUploadRequest request) {
    final path = newImagePath(request.restaurantId, request.format);
    final task = _storage
        .ref(path)
        .putData(
          request.bytes,
          SettableMetadata(
            contentType: request.format.contentType,
            customMetadata: request.metadata,
          ),
        );
    return _FirebaseImageUpload(path, task);
  }
}

class _FirebaseImageUpload implements ImageUpload {
  _FirebaseImageUpload(this.path, this._task);

  @override
  final String path;
  final UploadTask _task;

  @override
  Stream<double> get progress => _task.snapshotEvents.map(
    (s) => s.totalBytes > 0 ? s.bytesTransferred / s.totalBytes : 0,
  );

  @override
  Future<void> get done async {
    try {
      await _task;
    } on FirebaseException catch (e) {
      if (e.code == 'canceled') throw const ImageUploadCanceled();
      rethrow;
    }
  }

  @override
  Future<void> cancel() => _task.cancel();
}

final imageUploaderProvider = Provider<ImageUploader>(
  (ref) => FirebaseImageUploader(FirebaseStorage.instance),
);
