import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;
import 'package:owner_app/features/qr/application/qr_image.dart';
import 'package:owner_app/features/qr/domain/qr_link.dart';
import 'package:qr/qr.dart';

/// A square logo: a coloured disc with a letter-like bar, as a PNG.
Uint8List sampleLogo({int size = 512, bool solidBlack = false}) {
  final logo = img.Image(width: size, height: size);
  img.fill(logo, color: img.ColorRgb8(255, 255, 255));
  img.fillCircle(
    logo,
    x: size ~/ 2,
    y: size ~/ 2,
    radius: size ~/ 2 - 4,
    color: solidBlack ? img.ColorRgb8(0, 0, 0) : img.ColorRgb8(168, 85, 10),
  );
  img.fillRect(
    logo,
    x1: size ~/ 4,
    y1: size ~/ 2 - 20,
    x2: size * 3 ~/ 4,
    y2: size ~/ 2 + 20,
    color: img.ColorRgb8(255, 255, 255),
  );
  return Uint8List.fromList(img.encodePng(logo));
}

void main() {
  const url = 'https://menu.eazysuvai.com/q/AB3K7MNP';

  group('QR link', () {
    test('encodes the /q/ URL with the upper-case code, never the slug', () {
      expect(
        qrUrlFor('ab3k7mnp', menuBaseUrl: 'https://menu.eazysuvai.com/'),
        url,
      );
      expect(
        qrUrlFor(
          'AB3K7MNP',
          menuBaseUrl: 'https://eazy-suvai-dev-menu.web.app',
        ),
        'https://eazy-suvai-dev-menu.web.app/q/AB3K7MNP',
      );
      expect(shortUrlText(url), 'menu.eazysuvai.com/q/AB3K7MNP');
      expect(
        whatsAppShareUri('See our menu: $url').toString(),
        'https://wa.me/?text=See%20our%20menu%3A%20https%3A%2F%2Fmenu.eazysuvai.com%2Fq%2FAB3K7MNP',
      );
      expect(fileSlug('Spice Garden & Café!'), 'spice-garden-caf');
      expect(fileSlug('தமிழ்'), 'menu');
    });
  });

  group('renderQrPng', () {
    test('plain code: ≥ 1024 px, 4-module quiet zone, level M, decodes', () {
      final r = renderQrPng(url);
      expect(r.size, greaterThanOrEqualTo(1024));
      expect(r.errorLevel, QrErrorCorrectLevel.M);
      expect(r.logoArea, 0);
      final image = img.decodePng(r.png)!;
      expect(image.width, r.size);
      expect(image.height, r.size);
      // The quiet zone is white all round.
      final quiet = qrQuietModules * r.modulePixels;
      for (var i = 0; i < r.size; i += 7) {
        for (final (x, y) in [
          (i, quiet - 1),
          (quiet - 1, i),
          (i, r.size - quiet),
          (r.size - quiet, i),
        ]) {
          expect(image.getPixel(x, y).r, 255, reason: 'quiet zone at $x,$y');
        }
      }
      // The top-left finder pattern starts right after it.
      expect(image.getPixel(quiet, quiet).r, 0);
      expect(decodeQrImage(r.png), url);
      expect(qrDecodesTo(r.png, url), isTrue);
    });

    test('with a logo: level H, at most 20 % of the area, decodes', () {
      final r = renderQrPng(url, logo: sampleLogo());
      expect(r.errorLevel, QrErrorCorrectLevel.H);
      expect(r.logoArea, lessThanOrEqualTo(qrMaxLogoArea));
      expect(r.logoArea, greaterThan(0.15));
      final image = img.decodePng(r.png)!;
      // The centre shows the logo (orange), not modules.
      final c = image.getPixel(r.size ~/ 2, r.size ~/ 2 - 60);
      expect((c.r, c.g, c.b), (168, 85, 10));
      expect(qrDecodesTo(r.png, url), isTrue);
    });

    test('wide logos keep their aspect ratio inside the pad', () {
      final wide = img.Image(width: 800, height: 200);
      img.fill(wide, color: img.ColorRgb8(20, 120, 60));
      final r = renderQrPng(url, logo: Uint8List.fromList(img.encodePng(wide)));
      expect(qrDecodesTo(r.png, url), isTrue);
    });
  });

  group('buildQrArtifact (FR-053)', () {
    test('offers the logo version only when it decodes', () {
      final a = buildQrArtifact(QrJob(url, sampleLogo()));
      expect(a.withLogo, isTrue);
      expect(a.logoRejected, isFalse);
      expect(decodeQrImage(a.png), url);
    });

    test('falls back to the plain code when the logo version fails', () {
      // An undecodable "logo" file.
      final a = buildQrArtifact(QrJob(url, Uint8List.fromList([1, 2, 3, 4])));
      expect(a.withLogo, isFalse);
      expect(a.logoRejected, isTrue);
      expect(decodeQrImage(a.png), url);
    });

    test('a logo version that does not decode is never returned', () {
      // The first check is the logo version: make it fail, as a logo that
      // hides too much of the code would.
      var calls = 0;
      bool check(Uint8List png, String expected) =>
          ++calls > 1 && qrDecodesTo(png, expected);

      final a = buildQrArtifact(QrJob(url, sampleLogo()), check: check);
      expect(calls, 2);
      expect(a.withLogo, isFalse);
      expect(a.logoRejected, isTrue);
      expect(decodeQrImage(a.png), url);
    });

    test('throws if even the plain code would not decode', () {
      expect(
        () => buildQrArtifact(const QrJob(url, null), check: (_, _) => false),
        throwsStateError,
      );
    });

    test('without a logo, the plain code', () {
      final a = buildQrArtifact(const QrJob(url, null));
      expect(a.withLogo, isFalse);
      expect(a.logoRejected, isFalse);
      expect(a.render.size, greaterThanOrEqualTo(1024));
    });
  });
}
