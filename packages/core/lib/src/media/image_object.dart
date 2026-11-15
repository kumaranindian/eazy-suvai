import 'dart:ui' show Size;

import 'package:cloud_firestore/cloud_firestore.dart' show Timestamp;
import 'package:flutter/foundation.dart';

/// What an image is for. Sets the minimum size (FR-102), the default crop
/// aspect ratio and the document field `processImage` writes.
///
/// Keep in sync with `functions/src/media/policy.ts` and `storage.rules`.
enum ImagePurpose {
  /// Restaurant logo: `restaurants/{rid}.logo`, at least 256 × 256 px.
  logo('logo', 'logo', 256, 256, 1),

  /// Restaurant cover: `restaurants/{rid}.cover`, at least 1200 × 400 px.
  cover('cover', 'cover', 1200, 400, 3),

  /// Category image: `restaurants/{rid}/categories/{cid}.image`, 400 × 400 px.
  category('category', 'image', 400, 400, 1),

  /// Item image: `restaurants/{rid}/items/{iid}.image`, 400 × 400 px.
  item('item', 'image', 400, 400, 1);

  const ImagePurpose(
    this.wire,
    this.field,
    this.minWidth,
    this.minHeight,
    this.defaultAspectRatio,
  );

  /// Value of the upload's `purpose` metadata.
  final String wire;

  /// Field of the target document that holds the image object.
  final String field;

  final int minWidth;
  final int minHeight;

  /// Width / height used by `ImagePickerField` unless the caller sets one.
  final double defaultAspectRatio;

  Size get minSize => Size(minWidth.toDouble(), minHeight.toDouble());
}

/// `image.status` (architecture §4.4).
enum ImageStatus { processing, ready, rejected }

/// Why an image was refused. Server codes come from `processImage`
/// (`functions/src/media/policy.ts`, `RejectReason`); [uploadFailed] and
/// [pickFailed] and [photoAccessDenied] only happen on the device.
enum ImageRejectReason {
  unsupportedType('unsupported-type'),
  tooLarge('too-large'),
  tooSmall('too-small'),
  invalidImage('invalid-image'),
  processingFailed('processing-failed'),

  /// Device only: the upload failed (network, permission).
  uploadFailed('upload-failed'),

  /// Device only: the photo library or file dialog could not be opened.
  pickFailed('pick-failed'),

  /// Device only (iOS): the user refused access to the photo library.
  photoAccessDenied('photo-access-denied');

  const ImageRejectReason(this.wire);

  final String wire;

  static ImageRejectReason fromWire(String? value) => ImageRejectReason.values
      .firstWhere((r) => r.wire == value, orElse: () => processingFailed);
}

/// Storage paths of the WebP renditions (FR-102).
@immutable
class ImageRenditions {
  const ImageRenditions({
    required this.w320,
    required this.w640,
    required this.w1280,
  });

  final String w320;
  final String w640;
  final String w1280;

  /// The smallest rendition at least [physicalWidth] pixels wide, or the
  /// largest one if none is wide enough.
  String pathFor(double physicalWidth) {
    if (physicalWidth <= 320) return w320;
    if (physicalWidth <= 640) return w640;
    return w1280;
  }

  static ImageRenditions? fromMap(Object? map) {
    if (map is! Map) return null;
    final (a, b, c) = (map['w320'], map['w640'], map['w1280']);
    if (a is! String || b is! String || c is! String) return null;
    return ImageRenditions(w320: a, w640: b, w1280: c);
  }

  @override
  bool operator ==(Object other) =>
      other is ImageRenditions &&
      other.w320 == w320 &&
      other.w640 == w640 &&
      other.w1280 == w1280;

  @override
  int get hashCode => Object.hash(w320, w640, w1280);
}

/// The image object stored in `logo`, `cover` and `image` fields
/// (architecture §4.4). Written only by `processImage`; clients only clear
/// a field (set it to `null`).
///
/// * `processing`: `{path, status, uploadedAt}`
/// * `ready`: `{path, status, contentType, width, height,
///   renditions: {w320, w640, w1280}, uploadedAt}`
/// * `rejected`: `{path, status, reason, uploadedAt}`
@immutable
class ImageObject {
  const ImageObject({
    required this.path,
    required this.status,
    this.contentType,
    this.width,
    this.height,
    this.renditions,
    this.reason,
    this.uploadedAt,
  });

  /// A just-uploaded image that the server has not finished yet.
  const ImageObject.processing(this.path)
    : status = ImageStatus.processing,
      contentType = null,
      width = null,
      height = null,
      renditions = null,
      reason = null,
      uploadedAt = null;

  /// Storage path of the original: `restaurants/{rid}/images/{id}/original.{ext}`.
  final String path;
  final ImageStatus status;
  final String? contentType;
  final int? width;
  final int? height;
  final ImageRenditions? renditions;

  /// Set when [status] is [ImageStatus.rejected].
  final ImageRejectReason? reason;
  final DateTime? uploadedAt;

  bool get isReady => status == ImageStatus.ready && renditions != null;
  bool get isProcessing => status == ImageStatus.processing;
  bool get isRejected => status == ImageStatus.rejected;

  /// Reads a Firestore map. Returns null for `null` or a malformed value.
  static ImageObject? fromMap(Object? map) {
    if (map is! Map) return null;
    final path = map['path'];
    final status = ImageStatus.values.asNameMap()[map['status']];
    if (path is! String || status == null) return null;
    final uploadedAt = map['uploadedAt'];
    return ImageObject(
      path: path,
      status: status,
      contentType: map['contentType'] as String?,
      width: (map['width'] as num?)?.toInt(),
      height: (map['height'] as num?)?.toInt(),
      renditions: ImageRenditions.fromMap(map['renditions']),
      reason: status == ImageStatus.rejected
          ? ImageRejectReason.fromWire(map['reason'] as String?)
          : null,
      uploadedAt: switch (uploadedAt) {
        Timestamp t => t.toDate().toUtc(),
        DateTime d => d.toUtc(),
        _ => null,
      },
    );
  }

  @override
  bool operator ==(Object other) =>
      other is ImageObject &&
      other.path == path &&
      other.status == status &&
      other.contentType == contentType &&
      other.width == width &&
      other.height == height &&
      other.renditions == renditions &&
      other.reason == reason &&
      other.uploadedAt == uploadedAt;

  @override
  int get hashCode => Object.hash(
    path,
    status,
    contentType,
    width,
    height,
    renditions,
    reason,
    uploadedAt,
  );

  @override
  String toString() =>
      'ImageObject($path, ${status.name}'
      '${reason != null ? ', ${reason!.wire}' : ''})';
}
