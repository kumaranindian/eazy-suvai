// M08: QR code and sharing (FR-047 to FR-054, FR-067 to FR-070).
import 'dart:typed_data';

import 'package:core/core.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:owner_app/features/restaurant/data/restaurant_repository.dart';
import 'package:image/image.dart' as img;
import 'package:owner_app/features/qr/application/qr_image.dart';
import 'package:owner_app/features/qr/data/logo_loader.dart';
import 'package:owner_app/features/qr/data/share_actions.dart';
import 'package:owner_app/features/qr/presentation/qr_pdf_preview.dart';
import 'package:owner_app/features/qr/domain/qr_link.dart';
import 'package:owner_app/features/qr/presentation/qr_share_page.dart';
import 'package:owner_app/features/restaurant/presentation/menu_link_page.dart'
    show menuUrl;
import 'package:owner_app/router/app_router.dart';

import 'fake_plan.dart';
import 'helpers.dart';
import 'qr_image_test.dart' show sampleLogo;

final qrUrl = qrUrlFor('ABCDEFGH');
final slugUrl = menuUrl('spice-garden');

class FakeQrShareActions implements QrShareActions {
  final copies = <String>[];
  final whatsApp = <String>[];
  final shares = <(String, String)>[];
  final saves = <(Uint8List, String, String)>[];
  bool whatsAppOpens = true;
  ShareOutcome shareOutcome = ShareOutcome.done;
  @override
  bool savesByDownload = true;

  @override
  Future<void> copy(String text) async => copies.add(text);

  @override
  Future<bool> openWhatsApp(String message) async {
    whatsApp.add(message);
    return whatsAppOpens;
  }

  @override
  Future<ShareOutcome> shareText(String text, {required String subject}) async {
    shares.add((text, subject));
    return shareOutcome;
  }

  @override
  Future<ShareOutcome> saveFile(
    Uint8List bytes, {
    required String fileName,
    required String mimeType,
  }) async {
    saves.add((bytes, fileName, mimeType));
    return ShareOutcome.done;
  }
}

class FakeLogoLoader implements QrLogoLoader {
  FakeLogoLoader({this.fail = false});
  final bool fail;
  int loads = 0;

  @override
  Future<Uint8List?> load(ImageObject? logo) async {
    loads++;
    if (fail) throw Exception('storage unavailable');
    return sampleLogo();
  }
}

Map<String, dynamic> readyLogo() => {
  'path': 'restaurants/rest_1/images/logo1/original.png',
  'status': 'ready',
  'contentType': 'image/png',
  'width': 512,
  'height': 512,
  'renditions': {
    'w320': 'restaurants/rest_1/images/logo1/w320.webp',
    'w640': 'restaurants/rest_1/images/logo1/w640.webp',
    'w1280': 'restaurants/rest_1/images/logo1/w1280.webp',
  },
};

class QrHarness {
  QrHarness(this.app, this.actions, this.logos);
  final TestApp app;
  final FakeQrShareActions actions;
  final FakeLogoLoader logos;
  WidgetTester get tester => app.tester;
}

/// The QR screen of a published restaurant; the QR is rendered in the test
/// zone (no isolate) and the PDF viewer is a stand-in.
Future<QrHarness> openQr(
  WidgetTester tester, {
  double width = 360,
  Map<String, dynamic> extra = const {'publishedVersion': 1},
  FakeLogoLoader? logos,
  QrCheck check = qrDecodesTo,
}) async {
  final actions = FakeQrShareActions();
  final loader = logos ?? FakeLogoLoader();
  final app = await pumpOwnerApp(
    tester,
    width: width,
    signedIn: verifiedOwner(),
    restaurant: FakeRestaurantRepository(restaurantData(extra)),
    qrBuilder: (job) async => buildQrArtifact(job, check: check),
    overrides: [
      qrShareActionsProvider.overrideWithValue(actions),
      qrLogoLoaderProvider.overrideWithValue(loader),
    ],
  );
  await app.go(Routes.share);
  await settle(tester);
  return QrHarness(app, actions, loader);
}

/// Lets the real PNG/PDF work (outside the fake clock) finish.
Future<void> settle(WidgetTester tester) async {
  for (var i = 0; i < 5; i++) {
    await tester.runAsync(() => Future<void>.delayed(Duration.zero));
    await tester.pumpAndSettle();
  }
}

Uint8List shownPng(WidgetTester tester) =>
    (tester.widget<Image>(find.byKey(QrKeys.image)).image as MemoryImage).bytes;

/// Scrolls [key] to the upper part of the view (clear of the bottom
/// navigation bar), taps it and lets the work finish.
Future<void> tapKey(WidgetTester tester, Key key) async {
  final target = find.byKey(key);
  await Scrollable.ensureVisible(tester.element(target), alignment: 0.2);
  await tester.pumpAndSettle();
  await tester.tap(target);
  await settle(tester);
}

void main() {
  for (final width in [360.0, 768.0, 1280.0]) {
    testWidgets('shows a decodable /q/ code at ${width.toInt()} px', (
      tester,
    ) async {
      final h = await openQr(tester, width: width);
      expect(tester.takeException(), isNull);
      final png = shownPng(tester);
      expect(decodeQrImage(png), qrUrl);
      expect(img.decodePng(png)!.width, greaterThanOrEqualTo(1024));
      expect(find.textContaining(shortUrlText(qrUrl)), findsOneWidget);
      expect(find.text(slugUrl), findsOneWidget);
      expect(find.byKey(QrKeys.notPublished), findsNothing);
      // Phone and tablet (content < 680 px beside the rail): one column.
      // Desktop: preview left (360 px), options right.
      if (width < 1024) {
        expect(find.byKey(QrKeys.previewPane), findsNothing);
        expect(
          tester.getTopLeft(find.byKey(QrKeys.downloadPng)).dy,
          greaterThan(tester.getBottomLeft(find.byKey(QrKeys.image)).dy),
        );
      } else {
        expect(tester.getSize(find.byKey(QrKeys.previewPane)).width, 360);
        expect(
          tester.getTopLeft(find.byKey(QrKeys.optionsPane)).dx,
          greaterThanOrEqualTo(
            tester.getTopRight(find.byKey(QrKeys.previewPane)).dx,
          ),
        );
      }
      // Buttons are at least 48 px tall.
      expect(
        tester.getSize(find.byKey(QrKeys.downloadPng)).height,
        greaterThanOrEqualTo(48),
      );
      expect(h.actions.saves, isEmpty);
    });
  }

  testWidgets('says scans show "coming soon" before the first publish', (
    tester,
  ) async {
    await openQr(tester, extra: const {'publishedVersion': null});
    expect(find.byKey(QrKeys.notPublished), findsOneWidget);
    expect(decodeQrImage(shownPng(tester)), qrUrl);
  });

  testWidgets('downloads a PNG of at least 1024 px that decodes to /q/', (
    tester,
  ) async {
    final h = await openQr(tester);
    await tapKey(tester, QrKeys.downloadPng);
    expect(h.actions.saves, hasLength(1));
    final (bytes, name, mime) = h.actions.saves.single;
    expect(name, 'spice-garden-qr.png');
    expect(mime, 'image/png');
    expect(img.decodePng(bytes)!.width, greaterThanOrEqualTo(1024));
    expect(decodeQrImage(bytes), qrUrl);
    expect(find.text('Downloading spice-garden-qr.png'), findsOneWidget);
    // FRD §13 (M13): the download is counted.
    final repo =
        ProviderScope.containerOf(
              tester.element(find.byType(Scaffold).first),
            ).read(restaurantRepositoryProvider)
            as FakeRestaurantRepository;
    expect(repo.qrDownloads, 1);
  });

  group('logo (FR-053)', () {
    testWidgets('is off and disabled without a logo', (tester) async {
      await openQr(tester, extra: {...proData(), 'publishedVersion': 1});
      final tile = tester.widget<SwitchListTile>(find.byKey(QrKeys.logoSwitch));
      expect(tile.onChanged, isNull);
      expect(
        find.text('Upload a logo in your profile to add it to the code.'),
        findsOneWidget,
      );
    });

    testWidgets('is a Pro feature (M10)', (tester) async {
      await openQr(tester, extra: {'publishedVersion': 1, 'logo': readyLogo()});
      final tile = tester.widget<SwitchListTile>(find.byKey(QrKeys.logoSwitch));
      expect(tile.onChanged, isNull);
      expect(find.textContaining('part of Pro'), findsOneWidget);
    });

    testWidgets('adds the logo, level H, and the PNG still decodes', (
      tester,
    ) async {
      final h = await openQr(
        tester,
        extra: {...proData(), 'publishedVersion': 1, 'logo': readyLogo()},
      );
      final plain = shownPng(tester);
      await tapKey(tester, QrKeys.logoSwitch);
      expect(h.logos.loads, greaterThanOrEqualTo(1));
      final withLogo = shownPng(tester);
      expect(withLogo, isNot(equals(plain)));
      expect(decodeQrImage(withLogo), qrUrl);
      expect(find.textContaining('with your logo'), findsOneWidget);
      expect(find.byKey(QrKeys.logoMessage), findsNothing);
      await tapKey(tester, QrKeys.downloadPng);
      expect(decodeQrImage(h.actions.saves.single.$1), qrUrl);
    });

    testWidgets('falls back to the plain code and says so when it fails', (
      tester,
    ) async {
      // Checks: 1 = the plain code on open, 2 = the logo version after the
      // switch (fail it, as a logo hiding too much of the code would),
      // 3 = the plain fallback.
      var calls = 0;
      final h = await openQr(
        tester,
        extra: {...proData(), 'publishedVersion': 1, 'logo': readyLogo()},
        check: (png, url) => ++calls != 2 && qrDecodesTo(png, url),
      );
      await tapKey(tester, QrKeys.logoSwitch);
      expect(calls, 3);
      expect(find.byKey(QrKeys.logoMessage), findsOneWidget);
      expect(find.textContaining("didn't scan reliably"), findsOneWidget);
      expect(find.textContaining('with your logo'), findsNothing);
      await tapKey(tester, QrKeys.downloadPng);
      expect(decodeQrImage(h.actions.saves.single.$1), qrUrl);
    });

    testWidgets('falls back when the logo cannot be loaded', (tester) async {
      await openQr(
        tester,
        extra: {...proData(), 'publishedVersion': 1, 'logo': readyLogo()},
        logos: FakeLogoLoader(fail: true),
      );
      await tapKey(tester, QrKeys.logoSwitch);
      expect(find.textContaining("couldn't load your logo"), findsOneWidget);
      expect(decodeQrImage(shownPng(tester)), qrUrl);
    });
  });

  group('PDF templates (FR-050, FR-054)', () {
    testWidgets('downloads the A4 poster and the A6 table card', (
      tester,
    ) async {
      final h = await openQr(tester, width: 1280);
      await tapKey(tester, QrKeys.downloadPdf);
      await tester.tap(find.text('A6 table card'));
      await settle(tester);
      await tapKey(tester, QrKeys.downloadPdf);
      expect(h.actions.saves.map((s) => s.$2), [
        'spice-garden-poster-a4.pdf',
        'spice-garden-table-card-a6.pdf',
      ]);
      for (final (bytes, _, mime) in h.actions.saves) {
        expect(mime, 'application/pdf');
        expect(String.fromCharCodes(bytes.sublist(0, 5)), '%PDF-');
      }
    });

    for (final width in [360.0, 1280.0]) {
      testWidgets('previews the template at ${width.toInt()} px', (
        tester,
      ) async {
        final h = await openQr(tester, width: width);
        await tapKey(tester, QrKeys.previewPdf);
        expect(find.byKey(QrPdfPreviewKeys.view), findsOneWidget);
        expect(find.textContaining('PDF '), findsOneWidget);
        expect(find.text('A4 poster preview'), findsOneWidget);
        // A dialog on wide screens, a full page on phones.
        expect(
          find.byType(Dialog),
          width < 600 ? findsNothing : findsOneWidget,
        );
        await tester.tap(find.byKey(QrPdfPreviewKeys.download));
        await settle(tester);
        expect(h.actions.saves.single.$2, 'spice-garden-poster-a4.pdf');
        await tester.tap(find.byKey(QrPdfPreviewKeys.close));
        await settle(tester);
        expect(find.byKey(QrPdfPreviewKeys.view), findsNothing);
      });
    }
  });

  group('sharing (FR-067 to FR-069)', () {
    testWidgets('copies the menu link', (tester) async {
      final h = await openQr(tester);
      await tapKey(tester, QrKeys.copy);
      expect(h.actions.copies, [slugUrl]);
      expect(find.text('Link copied'), findsOneWidget);
    });

    testWidgets('opens WhatsApp with a prefilled message', (tester) async {
      final h = await openQr(tester);
      await tapKey(tester, QrKeys.whatsApp);
      expect(h.actions.whatsApp, [
        'Take a look at the menu of Spice Garden: $slugUrl',
      ]);
      expect(h.actions.copies, isEmpty);
    });

    testWidgets('copies the link when WhatsApp does not open', (tester) async {
      final h = await openQr(tester);
      h.actions.whatsAppOpens = false;
      await tapKey(tester, QrKeys.whatsApp);
      expect(h.actions.copies, [slugUrl]);
      expect(find.textContaining("Couldn't open WhatsApp"), findsOneWidget);
    });

    testWidgets('opens the share sheet, or copies without Web Share', (
      tester,
    ) async {
      final h = await openQr(tester);
      await tapKey(tester, QrKeys.share);
      expect(h.actions.shares, [
        (
          'Take a look at the menu of Spice Garden: $slugUrl',
          'Spice Garden – Menu',
        ),
      ]);
      expect(h.actions.copies, isEmpty);
      h.actions.shareOutcome = ShareOutcome.unsupported;
      await tapKey(tester, QrKeys.share);
      expect(h.actions.copies, [slugUrl]);
      expect(find.textContaining('no share menu'), findsOneWidget);
    });
  });

  testWidgets('the dashboard QR card opens this screen', (tester) async {
    final app = await pumpOwnerApp(
      tester,
      width: 1280,
      signedIn: verifiedOwner(),
    );
    final preview = find.byKey(const ValueKey('dashboard.qrPreview'));
    await tester.ensureVisible(preview);
    await tester.tap(preview);
    await settle(tester);
    expect(app.location, Routes.share);
    expect(find.byKey(QrKeys.image), findsOneWidget);
  });
}
