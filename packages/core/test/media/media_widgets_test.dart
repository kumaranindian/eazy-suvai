import 'package:core/core.dart';
import 'package:core/testing.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;

import '../test_app.dart';

const rid = 'rest_1';
const widths = [360.0, 768.0, 1280.0];

Uint8List pngBytes(int w, int h) => img.encodePng(
  img.Image(width: w, height: h)..clear(img.ColorRgb8(30, 140, 60)),
);

ImageObject ready(String path) {
  final folder = path.substring(0, path.lastIndexOf('/'));
  return ImageObject(
    path: path,
    status: ImageStatus.ready,
    contentType: 'image/jpeg',
    width: 800,
    height: 800,
    renditions: ImageRenditions(
      w320: '$folder/w320.webp',
      w640: '$folder/w640.webp',
      w1280: '$folder/w1280.webp',
    ),
  );
}

const existing = 'restaurants/rest_1/images/existing00000000000/original.jpg';

/// Test harness: the field follows [doc] the way a screen follows a
/// Firestore stream.
class Harness {
  Harness({ImageObject? initial}) : doc = ValueNotifier(initial);

  final ValueNotifier<ImageObject?> doc;
  final picker = FakeImageFilePicker();
  final uploader = FakeImageUploader();
  final resolver = FakeStorageImageResolver();
  final uploaded = <ImageObject>[];
  var removed = 0;

  Widget build({
    ImagePurpose purpose = ImagePurpose.logo,
    bool removable = true,
    bool dense = false,
  }) => ProviderScope(
    overrides: [
      imageFilePickerProvider.overrideWithValue(picker),
      imageUploaderProvider.overrideWithValue(uploader),
      storageImageResolverProvider.overrideWithValue(resolver),
    ],
    child: testApp(
      Scaffold(
        body: SingleChildScrollView(
          padding: const EdgeInsetsDirectional.all(16),
          child: ValueListenableBuilder<ImageObject?>(
            valueListenable: doc,
            builder: (context, value, _) => ImagePickerField(
              purpose: purpose,
              restaurantId: rid,
              targetPath: purpose == ImagePurpose.item
                  ? 'restaurants/$rid/items/i1'
                  : 'restaurants/$rid',
              label: 'Logo',
              value: value,
              dense: dense,
              onUploaded: uploaded.add,
              onRemove: removable ? () => removed++ : null,
            ),
          ),
        ),
      ),
    ),
  );
}

/// Pumps, letting real async work (image decoding, isolates) run, until
/// [finder] matches.
Future<void> pumpUntilFound(WidgetTester tester, Finder finder) async {
  for (var i = 0; i < 100; i++) {
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 20)),
    );
    await tester.pump();
    if (finder.evaluate().isNotEmpty) return;
  }
  fail('Timed out waiting for $finder');
}

void main() {
  for (final width in widths) {
    final w = width.toInt();
    final expectedHeight = width < 600 ? 96.0 : 160.0;

    testWidgets('empty field at $w px: add button, hint, no remove', (
      tester,
    ) async {
      await setSurfaceWidth(tester, width);
      final h = Harness();
      await tester.pumpWidget(h.build());

      expect(find.text('Logo'), findsOneWidget);
      expect(find.text('Add image'), findsOneWidget);
      expect(find.text('Remove'), findsNothing);
      expect(find.textContaining('at least 256 × 256 px'), findsOneWidget);
      expect(
        tester.getSize(find.byType(ResponsiveImage)).height,
        expectedHeight,
      );
      expect(find.bySemanticsLabel('No image'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('ready field at $w px: preview, replace and remove', (
      tester,
    ) async {
      await setSurfaceWidth(tester, width);
      final h = Harness(initial: ready(existing));
      await tester.pumpWidget(h.build());
      await tester.pumpAndSettle();

      expect(find.text('Replace'), findsOneWidget);
      expect(find.text('Remove'), findsOneWidget);
      expect(tester.widget<Image>(find.byType(Image)).semanticLabel, 'Logo');
      // 96 or 160 logical px at DPR 1 → the 320 px rendition.
      expect(h.resolver.resolved.single, endsWith('/w320.webp'));
      expect(tester.takeException(), isNull);
    });

    testWidgets('cover field at $w px fits the width at 3:1', (tester) async {
      await setSurfaceWidth(tester, width);
      final h = Harness();
      await tester.pumpWidget(h.build(purpose: ImagePurpose.cover));
      final size = tester.getSize(find.byType(ResponsiveImage));
      expect(size.width / size.height, closeTo(3, 0.01));
      expect(size.width, lessThanOrEqualTo(width - 32));
      expect(tester.takeException(), isNull);
    });

    testWidgets('pick, crop, upload, process at $w px (FR-031)', (
      tester,
    ) async {
      await setSurfaceWidth(tester, width);
      final h = Harness(initial: ready(existing));
      h.picker.next = PickedImageFile(
        bytes: pngBytes(900, 600),
        name: 'dosa.png',
      );
      await tester.pumpWidget(h.build());
      await tester.pumpAndSettle();

      await tester.tap(find.text('Replace'));
      await pumpUntilFound(tester, find.byType(ImageCropDialog));
      await tester.pumpAndSettle();

      // Full screen on compact, a dialog of at most 640 px elsewhere.
      final dialogMaterial = find
          .descendant(of: find.byType(Dialog), matching: find.byType(Material))
          .first;
      final dialogWidth = tester.getSize(dialogMaterial).width;
      if (width < 600) {
        expect(dialogWidth, width);
      } else {
        expect(dialogWidth, lessThanOrEqualTo(ImageCropDialog.dialogWidth));
      }
      expect(find.text('Crop image'), findsOneWidget);
      expect(tester.takeException(), isNull);

      await tester.tap(find.text('Use image'));
      await pumpUntilFound(tester, find.textContaining('Uploading'));

      final upload = h.uploader.last;
      expect(upload.request.metadata, {
        'purpose': 'logo',
        'targetPath': 'restaurants/$rid',
        'field': 'logo',
      });
      expect(upload.request.format, ImageFormat.jpeg);
      final decoded = img.decodeJpg(upload.request.bytes)!;
      expect((decoded.width, decoded.height), (600, 600));

      upload.emit(0.5);
      await tester.pump();
      expect(find.text('Uploading… 50%'), findsOneWidget);
      expect(find.text('Cancel upload'), findsOneWidget);

      upload.complete();
      await tester.pump();
      await tester.pump();
      expect(find.text('Processing image…'), findsOneWidget);
      expect(h.uploaded.single, ImageObject.processing(upload.path));

      // The function claims the field, then finishes it.
      h.doc.value = ImageObject.processing(upload.path);
      await tester.pump();
      expect(find.text('Processing image…'), findsOneWidget);

      h.doc.value = ready(upload.path);
      await tester.pumpAndSettle();
      expect(find.text('Processing image…'), findsNothing);
      expect(find.text('Replace'), findsOneWidget);
      expect(
        h.resolver.resolved.last,
        startsWith(upload.path.substring(0, upload.path.lastIndexOf('/'))),
      );
      expect(tester.takeException(), isNull);
    });
  }

  group('rejections (AC-005, FR-102)', () {
    Future<void> pickAndExpect(
      WidgetTester tester,
      Uint8List bytes,
      String message, {
      ImagePurpose purpose = ImagePurpose.logo,
    }) async {
      final h = Harness();
      h.picker.next = PickedImageFile(bytes: bytes, name: 'file.jpg');
      await tester.pumpWidget(h.build(purpose: purpose));
      await tester.tap(find.text('Add image'));
      await pumpUntilFound(tester, find.textContaining(message));
      expect(h.uploader.uploads, isEmpty);
      expect(find.byType(ImageCropDialog), findsNothing);
      expect(find.text('Add image'), findsOneWidget, reason: 'can retry');
    }

    testWidgets('a 6 MB file is refused', (tester) async {
      final big = Uint8List(6 * 1024 * 1024)..setAll(0, [0xFF, 0xD8, 0xFF]);
      await pickAndExpect(tester, big, 'larger than 5 MB');
    });

    testWidgets('a renamed PDF is refused', (tester) async {
      final pdf = Uint8List.fromList('%PDF-1.7\n1 0 obj'.codeUnits);
      await pickAndExpect(tester, pdf, 'Choose a JPEG, PNG or WebP image');
    });

    testWidgets('a small item photo is refused with the minimum', (
      tester,
    ) async {
      await pickAndExpect(
        tester,
        pngBytes(300, 300),
        'at least 400 × 400 px',
        purpose: ImagePurpose.item,
      );
    });

    testWidgets('a server rejection shows its reason', (tester) async {
      final h = Harness(
        initial: const ImageObject(
          path: existing,
          status: ImageStatus.rejected,
          reason: ImageRejectReason.unsupportedType,
        ),
      );
      await tester.pumpWidget(h.build());
      expect(
        find.textContaining("This file type isn't supported"),
        findsOneWidget,
      );
      expect(find.bySemanticsLabel('Image not accepted'), findsOneWidget);
    });

    testWidgets('the picker failing is logged and shows no permission hint', (
      tester,
    ) async {
      final logged = <String>[];
      MediaErrorLog.sink = (e, _, c) => logged.add('$c: $e');
      addTearDown(() => MediaErrorLog.sink = null);
      final h = Harness()
        ..picker.error = const ImagePickException(cause: 'MissingPlugin');
      await tester.pumpWidget(h.build());
      await tester.tap(find.text('Add image'));
      await tester.pump();
      expect(
        find.textContaining("couldn't open the image picker"),
        findsOneWidget,
      );
      expect(find.textContaining('access your photos'), findsNothing);
      expect(find.text('Open settings'), findsNothing);
      expect(logged.single, contains('opening the picker for logo'));
      expect(logged.single, contains('MissingPlugin'));
    });

    testWidgets('a refused photo permission says so', (tester) async {
      final h = Harness()
        ..picker.error = const ImagePickException(accessDenied: true);
      await tester.pumpWidget(h.build());
      await tester.tap(find.text('Add image'));
      await tester.pump();
      expect(find.textContaining('access your photos'), findsOneWidget);
    });

    testWidgets('on iOS a refused permission offers the settings', (
      tester,
    ) async {
      debugDefaultTargetPlatformOverride = TargetPlatform.iOS;
      final h = Harness()
        ..picker.error = const ImagePickException(accessDenied: true);
      await tester.pumpWidget(h.build());
      await tester.tap(find.text('Add image'));
      await tester.pump();
      expect(find.text('Open settings'), findsOneWidget);
      debugDefaultTargetPlatformOverride = null;
    });

    test('iOS permission codes count as a refusal', () {
      bool denied(String code) =>
          DeviceImageFilePicker.isAccessDenied(PlatformException(code: code));
      expect(denied('photo_access_denied'), isTrue);
      expect(denied('photo_access_restricted'), isTrue);
      expect(denied('invalid_image'), isFalse);
    });
  });

  group('upload control', () {
    Future<Harness> startUpload(WidgetTester tester) async {
      final h = Harness();
      h.picker.next = PickedImageFile(bytes: pngBytes(400, 400), name: 'a.png');
      await tester.pumpWidget(h.build());
      await tester.tap(find.text('Add image'));
      await pumpUntilFound(tester, find.byType(ImageCropDialog));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Use image'));
      await pumpUntilFound(tester, find.text('Cancel upload'));
      return h;
    }

    testWidgets('cancel stops the upload without an error', (tester) async {
      final h = await startUpload(tester);
      await tester.tap(find.text('Cancel upload'));
      await tester.pump();
      await tester.pump();
      expect(h.uploader.last.canceled, isTrue);
      expect(find.text('Add image'), findsOneWidget);
      expect(find.byIcon(Icons.error_outline), findsNothing);
      expect(h.uploaded, isEmpty);
    });

    testWidgets('a failed upload shows a retry message', (tester) async {
      final h = await startUpload(tester);
      h.uploader.last.fail();
      await tester.pump();
      await tester.pump();
      expect(find.textContaining('Upload failed'), findsOneWidget);
      expect(find.text('Add image'), findsOneWidget);
      // Retry sends the same cropped image again.
      final first = h.uploader.last.request.bytes;
      await tester.tap(find.text('Retry'));
      await tester.pump();
      expect(h.uploader.uploads, hasLength(2));
      expect(h.uploader.last.request.bytes, same(first));
      expect(find.text('Cancel upload'), findsOneWidget);
      expect(find.textContaining('Upload failed'), findsNothing);
      h.uploader.last.complete();
      await tester.pump();
      await tester.pump();
      expect(find.text('Retry'), findsNothing);
    });

    testWidgets('cancelling the crop uploads nothing', (tester) async {
      final h = Harness();
      h.picker.next = PickedImageFile(bytes: pngBytes(400, 400), name: 'a.png');
      await tester.pumpWidget(h.build());
      await tester.tap(find.text('Add image'));
      await pumpUntilFound(tester, find.byType(ImageCropDialog));
      await tester.pumpAndSettle();
      // The default 800 px test window shows the dialog, not full screen.
      await tester.tap(find.text('Cancel'));
      await tester.pumpAndSettle();
      expect(find.byType(ImageCropDialog), findsNothing);
      expect(h.uploader.uploads, isEmpty);
    });

    testWidgets('a user who cancels the picker sees no change', (tester) async {
      final h = Harness();
      await tester.pumpWidget(h.build());
      await tester.tap(find.text('Add image'));
      await tester.pump();
      expect(h.picker.calls, 1);
      expect(find.byType(ImageCropDialog), findsNothing);
      expect(find.byIcon(Icons.error_outline), findsNothing);
    });
  });

  testWidgets('remove asks first, then calls onRemove', (tester) async {
    final h = Harness(initial: ready(existing));
    await tester.pumpWidget(h.build());
    await tester.pumpAndSettle();

    await tester.tap(find.text('Remove'));
    await tester.pumpAndSettle();
    expect(find.text('Remove this image?'), findsOneWidget);
    await tester.tap(find.text('Cancel'));
    await tester.pumpAndSettle();
    expect(h.removed, 0);

    await tester.tap(find.text('Remove'));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(FilledButton, 'Remove'));
    await tester.pumpAndSettle();
    expect(h.removed, 1);
  });

  testWidgets('no remove button without onRemove; dense uses 96 px', (
    tester,
  ) async {
    await setSurfaceWidth(tester, 1280);
    final h = Harness(initial: ready(existing));
    await tester.pumpWidget(h.build(removable: false, dense: true));
    await tester.pumpAndSettle();
    expect(find.text('Remove'), findsNothing);
    expect(tester.getSize(find.byType(ResponsiveImage)).height, 96);
  });

  group('ResponsiveImage', () {
    Future<FakeStorageImageResolver> show(
      WidgetTester tester,
      ImageObject? image, {
      double size = 200,
      double dpr = 1,
    }) async {
      tester.view.devicePixelRatio = dpr;
      tester.view.physicalSize = Size(1280 * dpr, 900 * dpr);
      addTearDown(tester.view.reset);
      final resolver = FakeStorageImageResolver();
      await tester.pumpWidget(
        ProviderScope(
          overrides: [storageImageResolverProvider.overrideWithValue(resolver)],
          child: testApp(
            Scaffold(
              body: Center(
                child: SizedBox.square(
                  dimension: size,
                  child: ResponsiveImage(image: image, semanticLabel: 'Dosa'),
                ),
              ),
            ),
          ),
        ),
      );
      // Not pumpAndSettle: the processing spinner never settles.
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));
      return resolver;
    }

    testWidgets('chooses the rendition for the physical width', (tester) async {
      expect((await show(tester, ready(existing), size: 96)).resolved, [
        endsWith('w320.webp'),
      ]);
      expect(
        (await show(tester, ready(existing), size: 300, dpr: 2)).resolved,
        [endsWith('w640.webp')],
      );
      expect(
        (await show(tester, ready(existing), size: 400, dpr: 3)).resolved,
        [endsWith('w1280.webp')],
      );
      expect(find.bySemanticsLabel('Dosa'), findsOneWidget);
    });

    testWidgets('shows placeholders without loading anything', (tester) async {
      var r = await show(tester, null);
      expect(find.byIcon(Icons.image_outlined), findsOneWidget);
      expect(r.resolved, isEmpty);

      r = await show(tester, const ImageObject.processing(existing));
      expect(find.byType(CircularProgressIndicator), findsOneWidget);
      expect(find.bySemanticsLabel('Processing image…'), findsOneWidget);
      expect(r.resolved, isEmpty);

      r = await show(
        tester,
        const ImageObject(
          path: existing,
          status: ImageStatus.rejected,
          reason: ImageRejectReason.tooSmall,
        ),
      );
      expect(find.byIcon(Icons.broken_image_outlined), findsOneWidget);
      expect(r.resolved, isEmpty);
    });
  });
}
