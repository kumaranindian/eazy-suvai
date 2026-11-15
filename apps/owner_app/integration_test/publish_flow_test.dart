// End-to-end publishing on the Firebase Emulator Suite (M06) at 1280 px,
// through the real callables, rules and triggers:
//
// empty menu blocked with a reason and a Fix link (AC-021) → content added →
// draft preview (previewMenu, iframe on the web) → publish with the change
// summary (version 1, bar disappears) → a price edit brings the bar back
// (trigger stamps draftUpdatedAt) → availability toggle does not → publish
// "1 item changed" (version 2) → restore version 1 from Version history as
// version 3 with the draft replaced (AC-013) → edit, then discard changes.
//
// Run with: bash tool/integration.sh   (starts the emulators and Chrome)
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:core/core.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:owner_app/app.dart';
import 'package:owner_app/features/publishing/presentation/preview_page.dart';
import 'package:owner_app/features/publishing/presentation/publish_problems.dart';
import 'package:owner_app/router/app_router.dart';

import 'menu_flow_test.dart'
    show createVerifiedOwner, pumpUntil, seedPlatformLabels, waitFor;

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() async {
    TimeService.ensureInitialized();
    await initFirebase(
      AppEnv.parse(envName: 'dev', useEmulators: true),
      optionsFor: (_) => throw StateError('emulators only'),
    );
  });

  testWidgets('preview, publish, change, restore and discard (AC-013, '
      'AC-021, FR-095)', (tester) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(1280, 900);
    addTearDown(tester.view.reset);

    await seedPlatformLabels();
    final rid = await createVerifiedOwner();
    final db = FirebaseFirestore.instance;
    final root = db.doc('restaurants/$rid');
    Future<Map<String, dynamic>> rootData() async =>
        (await root.get(const GetOptions(source: Source.server))).data()!;
    Future<Map<String, dynamic>> itemData(String id) async =>
        (await db
                .doc('restaurants/$rid/items/$id')
                .get(const GetOptions(source: Source.server)))
            .data()!;
    Future<Object?> call(String name, Map<String, Object?> data) async =>
        (await regionalFunctions.httpsCallable(name).call<Object?>(data)).data;

    await tester.pumpWidget(const ProviderScope(child: OwnerApp()));
    final router = ProviderScope.containerOf(
      tester.element(find.byType(OwnerApp)),
    ).read(appRouterProvider);
    await pumpUntil(
      tester,
      () => router.routerDelegate.currentConfiguration.uri.path == '/',
      what: 'dashboard',
    );

    Future<void> tap(Finder f) async {
      FocusManager.instance.primaryFocus?.unfocus();
      await tester.ensureVisible(f.first);
      await tester.pumpAndSettle();
      await tester.tap(f.first);
      await tester.pumpAndSettle();
    }

    bool shown(Finder f) => f.evaluate().isNotEmpty;

    // 1. Never published: the bar says so. Publishing an empty menu is
    //    blocked with the reason and a Fix link (AC-021, BR-003).
    await pumpUntil(
      tester,
      () => shown(find.text('Not published yet')),
      what: 'publish bar',
    );
    await tap(find.byKey(PublishKeys.barPublish));
    await pumpUntil(
      tester,
      () => shown(find.textContaining('Your menu is empty.')),
      what: 'empty-menu problem',
    );
    final confirm = tester.widget<AppPrimaryButton>(
      find.byKey(PublishKeys.confirm),
    );
    expect(confirm.onPressed, isNull);
    await tap(find.byKey(PublishKeys.fix(0)));
    expect(router.routerDelegate.currentConfiguration.uri.path, Routes.menu);

    // 2. Content through the M04 callables.
    final cid =
        ((await call('createCategory', {
                  'restaurantId': rid,
                  'name': 'Tiffin',
                }))!
                as Map)['id']
            as String;
    final idli =
        ((await call('createItem', {
                  'restaurantId': rid,
                  'categoryId': cid,
                  'name': 'Idli',
                  'priceMinor': 6000,
                  'dietaryLabelId': 'vegetarian',
                  'tagIds': ['spicy'],
                }))!
                as Map)['id']
            as String;

    // 3. Draft preview: the renderer's HTML with noindex, shown in frames.
    final previewData =
        (await call('previewMenu', {'restaurantId': rid}))! as Map;
    final html = previewData['html']! as String;
    expect(html, contains('noindex'));
    expect(html, contains('Idli'));
    expect(html, contains('₹60.00'));
    await tap(find.byKey(PublishKeys.barPreview));
    await pumpUntil(
      tester,
      () =>
          shown(find.byType(PreviewPage)) &&
          shown(find.byKey(PublishKeys.previewDesktop)),
      what: 'preview frames',
    );
    expect(find.byKey(PublishKeys.previewPhone), findsOneWidget);
    expect(find.byType(HtmlElementView), findsNWidgets(2));
    expect(tester.takeException(), isNull);

    // 4. Publish from the preview: the summary, then version 1.
    await tap(find.byKey(PublishKeys.previewPublish));
    await pumpUntil(
      tester,
      () => shown(
        find.text(
          '1 category and 1 item go live at your menu link and QR code.',
        ),
      ),
      what: 'first publish summary',
    );
    await tap(find.byKey(PublishKeys.confirm));
    await pumpUntil(
      tester,
      () => shown(find.text('Version 1 is live.')),
      what: 'published snack bar',
    );
    var r = await rootData();
    expect(r['publishedVersion'], 1);
    final v1 =
        (await db
                .doc('restaurants/$rid/versions/1')
                .get(const GetOptions(source: Source.server)))
            .data()!;
    final snapshot = v1['snapshot'] as Map;
    expect((snapshot['items'] as List).single['name'], 'Idli');
    expect(snapshot['currency'], 'INR');
    // Owners can read versions, never the private draft source.
    await expectLater(
      db.doc('restaurants/$rid/versions/1/private/source').get(),
      throwsA(isA<FirebaseException>()),
    );
    router.pop();
    await tester.pumpAndSettle();
    await pumpUntil(
      tester,
      () => !shown(find.byKey(PublishKeys.bar)),
      what: 'bar hidden after publishing',
    );

    // 5. Availability is live: no unpublished change (FR-095, BR-018).
    await db.doc('restaurants/$rid/items/$idli').update({
      'available': false,
      'updatedAt': FieldValue.serverTimestamp(),
    });
    await tester.pump(const Duration(seconds: 3));
    await tester.pumpAndSettle();
    expect(find.byKey(PublishKeys.bar), findsNothing);
    await db.doc('restaurants/$rid/items/$idli').update({
      'available': true,
      'updatedAt': FieldValue.serverTimestamp(),
    });

    // 6. A price edit is a draft change: the bar comes back.
    await db.doc('restaurants/$rid/items/$idli').update({
      'priceMinor': 7000,
      'updatedAt': FieldValue.serverTimestamp(),
    });
    await pumpUntil(
      tester,
      () => shown(find.text('Unpublished changes')),
      what: 'unpublished changes bar',
    );
    await tap(find.byKey(PublishKeys.barPublish));
    await pumpUntil(
      tester,
      () => shown(find.text('1 item changed')),
      what: 'change summary',
    );
    await tap(find.byKey(PublishKeys.confirm));
    await pumpUntil(
      tester,
      () => shown(find.text('Version 2 is live.')),
      what: 'version 2',
    );

    // 7. Restore version 1 (published as 3, draft replaced) (AC-013).
    router.go(Routes.versions);
    await pumpUntil(
      tester,
      () => shown(find.byKey(PublishKeys.restore(1))),
      what: 'version history',
    );
    await tap(find.byKey(PublishKeys.restore(1)));
    await tap(find.byKey(PublishKeys.restoreConfirm));
    await pumpUntil(
      tester,
      () => shown(find.text('Version 1 is live again as version 3.')),
      what: 'restored',
    );
    r = await rootData();
    expect(r['publishedVersion'], 3);
    expect((await itemData(idli))['priceMinor'], 6000);

    // 8. Edit, then discard: the draft returns to the live version.
    await db.doc('restaurants/$rid/items/$idli').update({
      'name': 'Mini idli',
      'updatedAt': FieldValue.serverTimestamp(),
    });
    await pumpUntil(
      tester,
      () => shown(find.byKey(PublishKeys.discard)),
      what: 'discard button',
    );
    await tap(find.byKey(PublishKeys.discard));
    await tap(find.text('Discard changes').last);
    await pumpUntil(
      tester,
      () => shown(find.text('Your draft matches version 3 again.')),
      what: 'discarded',
    );
    expect((await itemData(idli))['name'], 'Idli');
    await waitFor(
      tester,
      rootData,
      (d) => d['publishedVersion'] == 3,
      what: 'no new version on discard',
    );
    await pumpUntil(
      tester,
      () => !shown(find.byKey(PublishKeys.bar)),
      what: 'bar hidden after discard',
    );
  });
}
