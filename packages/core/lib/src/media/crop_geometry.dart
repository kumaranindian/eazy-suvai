import 'dart:math' as math;
import 'dart:ui';

import 'package:flutter/foundation.dart';

/// The crop rectangle of a fixed-aspect cropper, in source image pixels.
///
/// At zoom 1 the crop is the largest rectangle of [aspectRatio] that fits
/// in the image. Zooming in shrinks it around [center], down to
/// [minCropSize] so the result never falls below the FR-102 minimum.
@immutable
class CropGeometry {
  factory CropGeometry({
    required Size imageSize,
    required double aspectRatio,
    Size minCropSize = Size.zero,
    double zoomLimit = 8,
  }) {
    assert(aspectRatio > 0, 'aspectRatio must be positive');
    final imageAspect = imageSize.width / imageSize.height;
    final base = imageAspect > aspectRatio
        ? Size(imageSize.height * aspectRatio, imageSize.height)
        : Size(imageSize.width, imageSize.width / aspectRatio);
    final maxZoom = math.max(
      1.0,
      [
        zoomLimit,
        if (minCropSize.width > 0) base.width / minCropSize.width,
        if (minCropSize.height > 0) base.height / minCropSize.height,
      ].reduce(math.min),
    );
    return CropGeometry._(
      imageSize: imageSize,
      aspectRatio: aspectRatio,
      minCropSize: minCropSize,
      baseCrop: base,
      maxZoom: maxZoom,
      zoom: 1,
      center: imageSize.center(Offset.zero),
    );
  }

  const CropGeometry._({
    required this.imageSize,
    required this.aspectRatio,
    required this.minCropSize,
    required this.baseCrop,
    required this.maxZoom,
    required this.zoom,
    required this.center,
  });

  final Size imageSize;

  /// Crop width / height.
  final double aspectRatio;
  final Size minCropSize;

  /// Crop size at zoom 1.
  final Size baseCrop;

  /// Largest zoom that keeps the crop at least [minCropSize].
  final double maxZoom;

  /// 1 (largest crop) to [maxZoom].
  final double zoom;

  /// Centre of the crop in image pixels.
  final Offset center;

  /// False if even the largest crop is below [minCropSize]: the image is
  /// too small for this purpose.
  bool get fitsMinimum =>
      baseCrop.width + 0.5 >= minCropSize.width &&
      baseCrop.height + 0.5 >= minCropSize.height;

  Size get cropSize => baseCrop / zoom;

  /// The crop, always inside the image.
  Rect get cropRect => Rect.fromCenter(
    center: center,
    width: cropSize.width,
    height: cropSize.height,
  );

  /// Moves the crop by [delta] image pixels.
  CropGeometry panBy(Offset delta) => _with(zoom, center + delta);

  /// Sets the zoom (clamped to 1…[maxZoom]), keeping the centre.
  CropGeometry zoomTo(double value) => _with(value.clamp(1.0, maxZoom), center);

  CropGeometry _with(double zoom, Offset center) {
    final half = (baseCrop / zoom) / 2;
    final c = Offset(
      center.dx.clamp(half.width, imageSize.width - half.width),
      center.dy.clamp(half.height, imageSize.height - half.height),
    );
    return CropGeometry._(
      imageSize: imageSize,
      aspectRatio: aspectRatio,
      minCropSize: minCropSize,
      baseCrop: baseCrop,
      maxZoom: maxZoom,
      zoom: zoom,
      center: c,
    );
  }
}
