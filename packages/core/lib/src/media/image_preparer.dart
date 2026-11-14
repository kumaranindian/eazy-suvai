import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image/image.dart' as img;

import 'crop_geometry.dart';
import 'image_object.dart';
import 'image_sniffer.dart';

/// Thrown when a picked file is refused on the device. The server checks
/// the same rules again (`processImage`).
class ImageRejectedException implements Exception {
  const ImageRejectedException(this.reason);

  final ImageRejectReason reason;

  @override
  String toString() => 'ImageRejectedException(${reason.wire})';
}

/// A decoded picked image, ready to crop. Call [dispose] when done.
class SourceImage {
  SourceImage(this.image, this.format);

  final ui.Image image;

  /// Format of the picked file.
  final ImageFormat format;

  int get width => image.width;
  int get height => image.height;
  ui.Size get size => ui.Size(width.toDouble(), height.toDouble());

  void dispose() => image.dispose();
}

/// The cropped file to upload.
@immutable
class PreparedImage {
  const PreparedImage({
    required this.bytes,
    required this.format,
    required this.width,
    required this.height,
  });

  final Uint8List bytes;
  final ImageFormat format;
  final int width;
  final int height;
}

/// Checks, decodes, crops and re-encodes images before upload (M02).
///
/// * [load] refuses files over 5 MB, files that are not JPEG, PNG or WebP
///   by content, files over 50 megapixels and images too small for the
///   purpose at the given aspect ratio.
/// * [crop] cuts the chosen rectangle, scales it so the longest side is at
///   most [maxLongSide] (2560 px, to save mobile data) and encodes it: JPEG,
///   or PNG when the source has transparency. Re-encoding also drops EXIF.
class ImagePreparer {
  const ImagePreparer();

  /// FR-102.
  static const maxUploadBytes = 5 * 1024 * 1024;

  /// Same limit as `MAX_INPUT_PIXELS` in `functions/src/media/policy.ts`.
  static const maxPixels = 50000000;
  static const maxLongSide = 2560;
  static const jpegQuality = 85;

  Future<SourceImage> load(
    Uint8List bytes, {
    required ImagePurpose purpose,
    required double aspectRatio,
  }) async {
    if (bytes.length > maxUploadBytes) {
      throw const ImageRejectedException(ImageRejectReason.tooLarge);
    }
    final format = sniffImageFormat(bytes);
    if (format == null) {
      throw const ImageRejectedException(ImageRejectReason.unsupportedType);
    }
    final header = readImageHeaderSize(bytes, format);
    if (header != null && header.width * header.height > maxPixels) {
      throw const ImageRejectedException(ImageRejectReason.tooLarge);
    }

    final ui.Image image;
    try {
      final codec = await ui.instantiateImageCodec(bytes);
      final frame = await codec.getNextFrame();
      codec.dispose();
      image = frame.image;
    } on Object {
      throw const ImageRejectedException(ImageRejectReason.invalidImage);
    }

    final source = SourceImage(image, format);
    final geometry = CropGeometry(
      imageSize: source.size,
      aspectRatio: aspectRatio,
      minCropSize: purpose.minSize,
    );
    if (!geometry.fitsMinimum) {
      source.dispose();
      throw const ImageRejectedException(ImageRejectReason.tooSmall);
    }
    return source;
  }

  Future<PreparedImage> crop(SourceImage source, ui.Rect rect) async {
    final scale = math.min(
      1.0,
      maxLongSide / math.max(rect.width, rect.height),
    );
    final w = math.max(1, (rect.width * scale).round());
    final h = math.max(1, (rect.height * scale).round());

    var out = await _render(source.image, rect, w, h);
    try {
      var rgba = await _rgba(out);
      if (source.format != ImageFormat.jpeg && _hasTransparency(rgba)) {
        final png = await out.toByteData(format: ui.ImageByteFormat.png);
        if (png != null && png.lengthInBytes <= maxUploadBytes) {
          return PreparedImage(
            bytes: png.buffer.asUint8List(png.offsetInBytes, png.lengthInBytes),
            format: ImageFormat.png,
            width: w,
            height: h,
          );
        }
        // Too big as PNG: flatten on white and send a JPEG instead.
        out.dispose();
        out = await _render(
          source.image,
          rect,
          w,
          h,
          background: const ui.Color(0xFFFFFFFF),
        );
        rgba = await _rgba(out);
      }
      var quality = jpegQuality;
      Uint8List jpeg;
      do {
        jpeg = await compute(_encodeJpeg, (rgba, w, h, quality));
        quality -= 15;
      } while (jpeg.length > maxUploadBytes && quality >= 40);
      return PreparedImage(
        bytes: jpeg,
        format: ImageFormat.jpeg,
        width: w,
        height: h,
      );
    } finally {
      out.dispose();
    }
  }

  static Future<ui.Image> _render(
    ui.Image src,
    ui.Rect rect,
    int w,
    int h, {
    ui.Color? background,
  }) {
    final recorder = ui.PictureRecorder();
    final canvas = ui.Canvas(recorder);
    if (background != null) canvas.drawColor(background, ui.BlendMode.src);
    canvas.drawImageRect(
      src,
      rect,
      ui.Rect.fromLTWH(0, 0, w.toDouble(), h.toDouble()),
      // Medium uses mipmaps, which downscales large photos without aliasing.
      ui.Paint()..filterQuality = ui.FilterQuality.medium,
    );
    final picture = recorder.endRecording();
    return picture.toImage(w, h).whenComplete(picture.dispose);
  }

  static Future<Uint8List> _rgba(ui.Image image) async {
    final data = await image.toByteData(format: ui.ImageByteFormat.rawRgba);
    return data!.buffer.asUint8List(data.offsetInBytes, data.lengthInBytes);
  }

  static bool _hasTransparency(Uint8List rgba) {
    for (var i = 3; i < rgba.length; i += 4) {
      if (rgba[i] != 0xFF) return true;
    }
    return false;
  }
}

Uint8List _encodeJpeg((Uint8List, int, int, int) job) {
  final (rgba, w, h, quality) = job;
  final image = img.Image.fromBytes(
    width: w,
    height: h,
    bytes: rgba.buffer,
    bytesOffset: rgba.offsetInBytes,
    numChannels: 4,
    order: img.ChannelOrder.rgba,
  );
  return img.encodeJpg(image, quality: quality);
}

/// The preparer used by `ImagePickerField`.
final imagePreparerProvider = Provider<ImagePreparer>(
  (ref) => const ImagePreparer(),
);
