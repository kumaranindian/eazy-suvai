import 'dart:ui';

import 'package:core/core.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('zoom 1 is the largest crop of the aspect ratio, centred', () {
    final g = CropGeometry(imageSize: const Size(4000, 3000), aspectRatio: 1);
    expect(g.cropRect, const Rect.fromLTWH(500, 0, 3000, 3000));

    final cover = CropGeometry(
      imageSize: const Size(4000, 3000),
      aspectRatio: 3,
    );
    expect(cover.cropRect.width, closeTo(4000, 1e-9));
    expect(cover.cropRect.height, closeTo(4000 / 3, 1e-9));
    expect(cover.cropRect.center.dx, closeTo(2000, 1e-9));
    expect(cover.cropRect.center.dy, closeTo(1500, 1e-9));
  });

  test('max zoom keeps the crop at least the minimum size (FR-102)', () {
    final g = CropGeometry(
      imageSize: const Size(2000, 2000),
      aspectRatio: 1,
      minCropSize: const Size(400, 400),
    );
    expect(g.maxZoom, 5);
    final zoomed = g.zoomTo(100);
    expect(zoomed.zoom, 5);
    expect(zoomed.cropRect.width, 400);

    // Large images are limited by zoomLimit instead.
    final big = CropGeometry(
      imageSize: const Size(6000, 6000),
      aspectRatio: 1,
      minCropSize: const Size(256, 256),
    );
    expect(big.maxZoom, 8);
  });

  test('fitsMinimum is false when the image is too small for the purpose', () {
    expect(
      CropGeometry(
        imageSize: const Size(1199, 1000),
        aspectRatio: 3,
        minCropSize: const Size(1200, 400),
      ).fitsMinimum,
      isFalse,
    );
    final exact = CropGeometry(
      imageSize: const Size(1200, 400),
      aspectRatio: 3,
      minCropSize: const Size(1200, 400),
    );
    expect(exact.fitsMinimum, isTrue);
    expect(exact.maxZoom, 1);
    // A wide photo is too short for a 1200 × 400 cover.
    expect(
      CropGeometry(
        imageSize: const Size(4000, 399),
        aspectRatio: 3,
        minCropSize: const Size(1200, 400),
      ).fitsMinimum,
      isFalse,
    );
  });

  test('panning and zooming keep the crop inside the image', () {
    var g = CropGeometry(
      imageSize: const Size(1000, 500),
      aspectRatio: 1,
    ).zoomTo(2);
    expect(g.cropRect.size, const Size(250, 250));

    g = g.panBy(const Offset(10000, 10000));
    expect(g.cropRect.right, 1000);
    expect(g.cropRect.bottom, 500);

    g = g.panBy(const Offset(-10000, -10000));
    expect(g.cropRect.topLeft, Offset.zero);

    // Zooming out near the edge pulls the centre back inside.
    g = g.zoomTo(1);
    expect(g.cropRect, const Rect.fromLTWH(0, 0, 500, 500));
  });
}
