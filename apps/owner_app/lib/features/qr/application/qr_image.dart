import 'dart:math' as math;
import 'dart:typed_data';

import 'package:image/image.dart' as img;
import 'package:qr/qr.dart';
import 'package:zxing2/qrcode.dart';

/// QR code images for print and download (M08, FR-050, FR-053).
///
/// Pure Dart (packages `qr`, `image` and `zxing2`), so it runs the same on
/// web, Android and iOS, in an isolate where there is one, and in tests.

/// Modules of white around the symbol (the QR spec's quiet zone).
const qrQuietModules = 4;

/// The smallest PNG side offered for download (FR-050).
const qrMinPixels = 1024;

/// The most of the symbol's area the logo (with its white pad) may cover
/// (FR-053: at most 20 %).
const qrMaxLogoArea = 0.20;

/// The share of the symbol the logo pad actually covers. Below the limit,
/// to leave a margin for print and camera blur.
const qrLogoArea = 0.18;

/// What [renderQrPng] produced.
class QrRender {
  const QrRender({
    required this.png,
    required this.size,
    required this.moduleCount,
    required this.modulePixels,
    required this.errorLevel,
    required this.logoArea,
  });

  final Uint8List png;

  /// Side in pixels (square).
  final int size;
  final int moduleCount;
  final int modulePixels;

  /// `QrErrorCorrectLevel.H` with a logo, `M` without.
  final int errorLevel;

  /// Share of the symbol area under the logo pad (0 without a logo).
  final double logoArea;
}

/// Renders [data] as a black-on-white QR code PNG of at least [minPixels]
/// square with a 4-module quiet zone. With [logo] (any format `image`
/// decodes: PNG, JPEG, WebP), the code uses error correction H and the logo
/// sits in the centre on a white pad covering [logoArea] of the symbol.
QrRender renderQrPng(
  String data, {
  Uint8List? logo,
  int minPixels = qrMinPixels,
  double logoArea = qrLogoArea,
}) {
  assert(logoArea > 0 && logoArea <= qrMaxLogoArea);
  final decodedLogo = logo == null ? null : img.decodeImage(logo);
  final level = decodedLogo != null
      ? QrErrorCorrectLevel.H
      : QrErrorCorrectLevel.M;
  final code = QrCode.fromData(data: data, errorCorrectLevel: level);
  final qr = QrImage(code);
  final count = qr.moduleCount;
  final total = count + 2 * qrQuietModules;
  final px = (minPixels / total).ceil();
  final size = px * total;

  final canvas = img.Image(width: size, height: size);
  img.fill(canvas, color: img.ColorRgb8(255, 255, 255));
  final black = img.ColorRgb8(0, 0, 0);
  final offset = qrQuietModules * px;
  for (var r = 0; r < count; r++) {
    for (var c = 0; c < count; c++) {
      if (!qr.isDark(r, c)) continue;
      final x = offset + c * px;
      final y = offset + r * px;
      img.fillRect(
        canvas,
        x1: x,
        y1: y,
        x2: x + px - 1,
        y2: y + px - 1,
        color: black,
      );
    }
  }

  var area = 0.0;
  if (decodedLogo != null) {
    final symbol = count * px;
    final pad = (symbol * math.sqrt(logoArea)).floor();
    area = (pad * pad) / (symbol * symbol);
    final inset = (pad * 0.08).round();
    final box = pad - 2 * inset;
    final scale = math.min(box / decodedLogo.width, box / decodedLogo.height);
    final w = math.max(1, (decodedLogo.width * scale).round());
    final h = math.max(1, (decodedLogo.height * scale).round());
    final resized = img.copyResize(
      decodedLogo,
      width: w,
      height: h,
      interpolation: img.Interpolation.average,
    );
    final px0 = (size - pad) ~/ 2;
    img.fillRect(
      canvas,
      x1: px0,
      y1: px0,
      x2: px0 + pad - 1,
      y2: px0 + pad - 1,
      color: img.ColorRgb8(255, 255, 255),
      radius: pad * 0.12,
    );
    img.compositeImage(
      canvas,
      resized,
      dstX: (size - w) ~/ 2,
      dstY: (size - h) ~/ 2,
    );
  }

  return QrRender(
    png: Uint8List.fromList(img.encodePng(canvas, level: 6)),
    size: size,
    moduleCount: count,
    modulePixels: px,
    errorLevel: level,
    logoArea: area,
  );
}

/// Decodes the QR code in a PNG (or any image `image` reads), or null.
String? decodeQrImage(Uint8List bytes, {int? scaleTo}) {
  var image = img.decodeImage(bytes);
  if (image == null) return null;
  if (scaleTo != null && image.width > scaleTo) {
    image = img.copyResize(
      image,
      width: scaleTo,
      interpolation: img.Interpolation.average,
    );
  }
  final rgba = image.convert(numChannels: 4);
  final source = RGBLuminanceSource(
    rgba.width,
    rgba.height,
    rgba.getBytes(order: img.ChannelOrder.abgr).buffer.asInt32List(),
  );
  for (final bitmap in [
    BinaryBitmap(HybridBinarizer(source)),
    BinaryBitmap(GlobalHistogramBinarizer(source)),
  ]) {
    try {
      return QRCodeReader().decode(bitmap).text;
    } on Exception {
      // Try the next binarizer.
    }
  }
  return null;
}

/// Whether [png] decodes to exactly [expected], at full size and scaled
/// down to about a third (a small print or a distant phone).
bool qrDecodesTo(Uint8List png, String expected) {
  if (decodeQrImage(png) != expected) return false;
  return decodeQrImage(png, scaleTo: 360) == expected;
}

/// The result offered to the owner (FR-053): the logo version only when it
/// decodes back to the URL, otherwise the plain code with [logoRejected].
class QrArtifact {
  const QrArtifact({
    required this.url,
    required this.render,
    required this.withLogo,
    required this.logoRejected,
  });

  final String url;
  final QrRender render;
  final bool withLogo;
  final bool logoRejected;

  Uint8List get png => render.png;
}

/// Input for [buildQrArtifact] (sendable to an isolate).
class QrJob {
  const QrJob(this.url, this.logo);

  final String url;
  final Uint8List? logo;
}

/// Checks that a PNG decodes to a URL; [qrDecodesTo] unless a test swaps it.
typedef QrCheck = bool Function(Uint8List png, String url);

/// Renders the code, with the logo when given, and checks it decodes. A
/// logo version that fails is never returned (FR-053). Throws [StateError]
/// if even the plain code fails, which would be a bug.
QrArtifact buildQrArtifact(QrJob job, {QrCheck check = qrDecodesTo}) {
  if (job.logo != null) {
    final QrRender? withLogo;
    try {
      withLogo = renderQrPng(job.url, logo: job.logo);
    } on Object {
      return _plain(job.url, logoRejected: true, check: check);
    }
    if (check(withLogo.png, job.url)) {
      return QrArtifact(
        url: job.url,
        render: withLogo,
        withLogo: true,
        logoRejected: false,
      );
    }
    return _plain(job.url, logoRejected: true, check: check);
  }
  return _plain(job.url, logoRejected: false, check: check);
}

QrArtifact _plain(
  String url, {
  required bool logoRejected,
  required QrCheck check,
}) {
  final render = renderQrPng(url);
  if (!check(render.png, url)) {
    throw StateError('The plain QR code does not decode to $url');
  }
  return QrArtifact(
    url: url,
    render: render,
    withLogo: false,
    logoRejected: logoRejected,
  );
}
