import 'dart:convert';
import 'dart:typed_data';
import 'dart:ui';

import 'package:cloud_firestore/cloud_firestore.dart' show Timestamp;
import 'package:core/core.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;

// Real WebP files made with sharp, 300 × 200 px (see M02 completion notes).
final _webpLossy = base64Decode(
  'UklGRtwAAABXRUJQVlA4INAAAAAwEQCdASosAcgAPtFosVMoJiSioCgBABoJaW7hdrEQnAAAE9gHvtk5D32ydM9Sitj30P3gN38HAEA99snIe+2TkPfbJyHwH6Xa8XJyHvtk5D32ych77ZOQ99snIe+2TnERcnIe+2TkPfbJyHvtk5D32ych77ZOQ+A/S7Xi5OQ9+AxteLk5D32ych77ZOQ99smIAAD+/z5Vf+6ABT9n//9CT/4mz/ibPg3oNMeyxIeyxIeyxIeywiA+kA4vMJxnZyxpZQgGcVAAQEsO4yRhAAAA',
);
final _webpLossless = base64Decode(
  'UklGRiQAAABXRUJQVlA4TBcAAAAvK8ExAAfQ/4j+BwAU6f9/iuh/6v/XAAA=',
);
final _webpExtended = base64Decode(
  'UklGRgQBAABXRUJQVlA4WAoAAAAQAAAAKwEAxwAAQUxQSBIAAAABB1DAiAgAKNL//xTR/9T/rwFWUDggzAAAANAQAJ0BKiwByAA+0WixUygmJKKgKAEAGglpbuF2sQ0ACewD32ych77ZOR/zyitkXXbU4YJS819rxcnIe+2TkPfbJyH0L6Xa8XJyHvtk5D32ych77ZOQ99snIe+2UDLxcnIe+2TkPfbJyHvtk5D32ych77ZOQ+hfS7Xi5OQ+BGRaVAsl2vFych77ZOQ99scAAP7/cD3//+hJ//xNn/9Js+EV+9y0UEvZ0GaeeGaeeGaeeGaZ3GFRICEh2CAGQz8BATw61hAM8qjGqCAAAA==',
);

Uint8List _png(int w, int h) => img.encodePng(img.Image(width: w, height: h));
Uint8List _jpeg(int w, int h) => img.encodeJpg(img.Image(width: w, height: h));

void main() {
  group('sniffImageFormat', () {
    test('detects JPEG, PNG and WebP by content', () {
      expect(sniffImageFormat(_jpeg(4, 4)), ImageFormat.jpeg);
      expect(sniffImageFormat(_png(4, 4)), ImageFormat.png);
      expect(sniffImageFormat(_webpLossy), ImageFormat.webp);
      expect(sniffImageFormat(_webpLossless), ImageFormat.webp);
    });

    test('rejects a renamed PDF, GIF, text and short input (AC-005)', () {
      expect(sniffImageFormat(utf8.encode('%PDF-1.7\n1 0 obj')), isNull);
      expect(sniffImageFormat(utf8.encode('GIF89a......')), isNull);
      expect(
        sniffImageFormat(utf8.encode('RIFF\x00\x00\x00\x00WAVEfmt ')),
        isNull,
      );
      expect(sniffImageFormat(Uint8List(0)), isNull);
      expect(sniffImageFormat(Uint8List.fromList([0xFF, 0xD8])), isNull);
    });
  });

  group('readImageHeaderSize', () {
    test('reads PNG, JPEG and all three WebP variants', () {
      expect(readImageHeaderSize(_png(640, 480), ImageFormat.png), (
        width: 640,
        height: 480,
      ));
      expect(readImageHeaderSize(_jpeg(333, 222), ImageFormat.jpeg), (
        width: 333,
        height: 222,
      ));
      for (final webp in [_webpLossy, _webpLossless, _webpExtended]) {
        expect(readImageHeaderSize(webp, ImageFormat.webp), (
          width: 300,
          height: 200,
        ));
      }
    });

    test('returns null for a truncated header', () {
      expect(
        readImageHeaderSize(_png(10, 10).sublist(0, 12), ImageFormat.png),
        isNull,
      );
      expect(
        readImageHeaderSize(_jpeg(10, 10).sublist(0, 8), ImageFormat.jpeg),
        isNull,
      );
    });
  });

  group('ImagePurpose', () {
    test('matches FR-102 minimums and the server field names', () {
      expect(ImagePurpose.logo.minSize, const Size(256, 256));
      expect(ImagePurpose.cover.minSize, const Size(1200, 400));
      expect(ImagePurpose.item.minSize, const Size(400, 400));
      expect(ImagePurpose.category.minSize, const Size(400, 400));
      expect(ImagePurpose.values.map((p) => p.field), [
        'logo',
        'cover',
        'image',
        'image',
      ]);
      expect(ImagePurpose.cover.defaultAspectRatio, 3);
    });
  });

  group('ImageObject.fromMap', () {
    const renditions = {
      'w320': 'r/a/w320.webp',
      'w640': 'r/a/w640.webp',
      'w1280': 'r/a/w1280.webp',
    };

    test('reads a ready image', () {
      final at = DateTime.utc(2026, 11, 14, 10);
      final image = ImageObject.fromMap({
        'path': 'r/a/original.jpg',
        'status': 'ready',
        'contentType': 'image/jpeg',
        'width': 800,
        'height': 600,
        'renditions': renditions,
        'uploadedAt': Timestamp.fromDate(at),
      })!;
      expect(image.isReady, isTrue);
      expect(image.width, 800);
      expect(image.renditions!.w640, 'r/a/w640.webp');
      expect(image.uploadedAt, at);
      expect(image.reason, isNull);
    });

    test('reads processing and rejected images', () {
      expect(
        ImageObject.fromMap({'path': 'p', 'status': 'processing'}),
        const ImageObject.processing('p'),
      );
      final rejected = ImageObject.fromMap({
        'path': 'p',
        'status': 'rejected',
        'reason': 'too-small',
      })!;
      expect(rejected.isRejected, isTrue);
      expect(rejected.reason, ImageRejectReason.tooSmall);
      // Unknown codes fall back to a generic failure.
      expect(
        ImageObject.fromMap({
          'path': 'p',
          'status': 'rejected',
          'reason': 'new-code',
        })!.reason,
        ImageRejectReason.processingFailed,
      );
    });

    test('returns null for null or malformed values', () {
      expect(ImageObject.fromMap(null), isNull);
      expect(ImageObject.fromMap('x'), isNull);
      expect(ImageObject.fromMap({'path': 'p'}), isNull);
      expect(ImageObject.fromMap({'status': 'ready'}), isNull);
      expect(ImageObject.fromMap({'path': 'p', 'status': 'unknown'}), isNull);
      // Ready without renditions is not displayable.
      expect(
        ImageObject.fromMap({'path': 'p', 'status': 'ready'})!.isReady,
        isFalse,
      );
    });
  });

  test('ImageRenditions.pathFor picks the smallest that covers the width', () {
    const r = ImageRenditions(w320: 'a', w640: 'b', w1280: 'c');
    expect(r.pathFor(96), 'a');
    expect(r.pathFor(320), 'a');
    expect(r.pathFor(321), 'b');
    expect(r.pathFor(640), 'b');
    expect(r.pathFor(1000), 'c');
    expect(r.pathFor(4000), 'c');
  });

  test('every reject reason has a message; wire codes match the server', () {
    final l10n = lookupCoreLocalizations(const Locale('en'));
    for (final reason in ImageRejectReason.values) {
      expect(l10n.imageRejectMessage(reason, ImagePurpose.cover), isNotEmpty);
    }
    expect(
      l10n.imageRejectMessage(ImageRejectReason.tooSmall, ImagePurpose.cover),
      contains('1200 × 400'),
    );
    expect(ImageRejectReason.values.map((r) => r.wire).take(5), [
      'unsupported-type',
      'too-large',
      'too-small',
      'invalid-image',
      'processing-failed',
    ]);
  });

  group('newImagePath', () {
    test('follows restaurants/{rid}/images/{id}/original.{ext}', () {
      final path = newImagePath('rest_1', ImageFormat.webp);
      expect(
        path,
        matches(
          RegExp(r'^restaurants/rest_1/images/[A-Za-z0-9]{20}/original\.webp$'),
        ),
      );
      expect(newImagePath('r', ImageFormat.jpeg), endsWith('/original.jpg'));
      expect(newImageId(), isNot(newImageId()));
    });

    test('request metadata names the purpose, target and field', () {
      final r = ImageUploadRequest(
        restaurantId: 'rest_1',
        purpose: ImagePurpose.item,
        targetPath: 'restaurants/rest_1/items/i1',
        bytes: Uint8List(1),
        format: ImageFormat.jpeg,
      );
      expect(r.metadata, {
        'purpose': 'item',
        'targetPath': 'restaurants/rest_1/items/i1',
        'field': 'image',
      });
    });
  });
}
