import 'dart:convert';
import 'dart:typed_data';
import 'dart:ui';

import 'package:core/core.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;

/// A JPEG with EXIF (camera and orientation).
Uint8List exifJpeg(int w, int h) {
  final image = img.Image(width: w, height: h)
    ..clear(img.ColorRgb8(200, 80, 20));
  image.exif.imageIfd['Make'] = img.IfdValueAscii('TestPhone');
  return img.encodeJpg(image);
}

Uint8List png(int w, int h, {bool transparent = false}) {
  final image = img.Image(width: w, height: h, numChannels: 4)
    ..clear(
      transparent
          ? img.ColorRgba8(0, 0, 0, 0)
          : img.ColorRgba8(20, 120, 200, 255),
    );
  return img.encodePng(image);
}

bool hasExif(Uint8List jpeg) {
  final marker = ascii.encode('Exif\u0000\u0000');
  outer:
  for (var i = 0; i + marker.length < jpeg.length; i++) {
    for (var j = 0; j < marker.length; j++) {
      if (jpeg[i + j] != marker[j]) continue outer;
    }
    return true;
  }
  return false;
}

Matcher rejectedWith(ImageRejectReason reason) => throwsA(
  isA<ImageRejectedException>().having((e) => e.reason, 'reason', reason),
);

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  const preparer = ImagePreparer();

  group('load', () {
    test('refuses files over 5 MB before decoding (AC-005)', () {
      final big = Uint8List(5 * 1024 * 1024 + 1)..setAll(0, [0xFF, 0xD8, 0xFF]);
      expect(
        preparer.load(big, purpose: ImagePurpose.item, aspectRatio: 1),
        rejectedWith(ImageRejectReason.tooLarge),
      );
    });

    test('refuses a renamed PDF by content (AC-005)', () {
      final pdf = Uint8List.fromList(utf8.encode('%PDF-1.7\n%âãÏÓ\n1 0 obj'));
      expect(
        preparer.load(pdf, purpose: ImagePurpose.logo, aspectRatio: 1),
        rejectedWith(ImageRejectReason.unsupportedType),
      );
    });

    test('refuses decompression bombs from the header', () {
      final bomb = png(1, 1);
      // Claim 10000 × 10000 in IHDR; the check runs before decoding.
      ByteData.sublistView(bomb)
        ..setUint32(16, 10000)
        ..setUint32(20, 10000);
      expect(
        preparer.load(bomb, purpose: ImagePurpose.item, aspectRatio: 1),
        rejectedWith(ImageRejectReason.tooLarge),
      );
    });

    test('refuses corrupt data', () {
      final broken = png(600, 600).sublist(0, 60);
      expect(
        preparer.load(broken, purpose: ImagePurpose.item, aspectRatio: 1),
        rejectedWith(ImageRejectReason.invalidImage),
      );
    });

    test('refuses images below the purpose minimum at the aspect ratio', () {
      expect(
        preparer.load(
          png(399, 600),
          purpose: ImagePurpose.item,
          aspectRatio: 1,
        ),
        rejectedWith(ImageRejectReason.tooSmall),
      );
      // Wide enough, but too short for a 1200 × 400 cover.
      expect(
        preparer.load(
          png(2000, 390),
          purpose: ImagePurpose.cover,
          aspectRatio: 3,
        ),
        rejectedWith(ImageRejectReason.tooSmall),
      );
    });

    test('decodes valid images', () async {
      final source = await preparer.load(
        exifJpeg(800, 600),
        purpose: ImagePurpose.logo,
        aspectRatio: 1,
      );
      expect(source.format, ImageFormat.jpeg);
      expect(source.size, const Size(800, 600));
      source.dispose();
    });
  });

  group('crop', () {
    test('crops a JPEG and drops its EXIF', () async {
      final input = exifJpeg(800, 600);
      expect(hasExif(input), isTrue);
      final source = await preparer.load(
        input,
        purpose: ImagePurpose.logo,
        aspectRatio: 1,
      );
      final out = await preparer.crop(
        source,
        const Rect.fromLTWH(100, 0, 600, 600),
      );
      source.dispose();
      expect(out.format, ImageFormat.jpeg);
      expect((out.width, out.height), (600, 600));
      expect(sniffImageFormat(out.bytes), ImageFormat.jpeg);
      expect(hasExif(out.bytes), isFalse);
      final decoded = img.decodeJpg(out.bytes)!;
      expect((decoded.width, decoded.height), (600, 600));
    });

    test('scales the longest side down to 2560 px', () async {
      final source = await preparer.load(
        png(3000, 1000),
        purpose: ImagePurpose.cover,
        aspectRatio: 3,
      );
      final out = await preparer.crop(
        source,
        const Rect.fromLTWH(0, 0, 3000, 1000),
      );
      source.dispose();
      expect((out.width, out.height), (2560, 853));
      expect(out.bytes.length, lessThan(ImagePreparer.maxUploadBytes));
    });

    test('keeps transparency as PNG, sends opaque PNGs as JPEG', () async {
      final clear = await preparer.load(
        png(300, 300, transparent: true),
        purpose: ImagePurpose.logo,
        aspectRatio: 1,
      );
      final logo = await preparer.crop(
        clear,
        const Rect.fromLTWH(0, 0, 300, 300),
      );
      clear.dispose();
      expect(logo.format, ImageFormat.png);
      expect(sniffImageFormat(logo.bytes), ImageFormat.png);

      final solid = await preparer.load(
        png(300, 300),
        purpose: ImagePurpose.logo,
        aspectRatio: 1,
      );
      final photo = await preparer.crop(
        solid,
        const Rect.fromLTWH(0, 0, 300, 300),
      );
      solid.dispose();
      expect(photo.format, ImageFormat.jpeg);
    });
  });
}
