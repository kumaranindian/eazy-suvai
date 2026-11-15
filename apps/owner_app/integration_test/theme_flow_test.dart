// End-to-end theme customization on the Firebase Emulator Suite (M05): the
// owner app at 1280 px writes the theme draft through the real security
// rules.
//
// seed themes → choose Saffron in the gallery (themeId, autosave) → editor:
// a charcoal background shows the contrast warning and the preview uses
// white text (FR-060) → dark mode → the draft holds the overrides and
// draftUpdatedAt → the rules refuse a malformed override and a theme that
// does not exist.
//
// Run with: bash tool/integration.sh   (starts the emulators and Chrome)
import 'dart:convert';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:core/core.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:integration_test/integration_test.dart';
import 'package:owner_app/app.dart';
import 'package:owner_app/features/theme/presentation/contrast_notice.dart';
import 'package:owner_app/features/theme/presentation/menu_theme_preview.dart';
import 'package:owner_app/features/theme/presentation/theme_editor_page.dart';
import 'package:owner_app/features/theme/presentation/theme_gallery_page.dart';
import 'package:owner_app/router/app_router.dart';

import 'menu_flow_test.dart' show createVerifiedOwner, pumpUntil, waitFor;

const _firestore =
    'http://localhost:${EmulatorPorts.firestore}/v1/projects/${AppEnv.demoProjectId}/databases/(default)/documents';

/// Seeds two themes as scripts/seed-platform.mjs would (admin REST access).
Future<void> seedThemes() async {
  Map<String, Object> str(String v) => {'stringValue': v};
  Future<void> put(
    String id,
    String name,
    bool premium,
    Map<String, String> t,
  ) => http.patch(
    Uri.parse('$_firestore/themes/$id'),
    headers: {
      'content-type': 'application/json',
      'authorization': 'Bearer owner',
    },
    body: jsonEncode({
      'fields': {
        'name': str(name),
        'premium': {'booleanValue': premium},
        'sort': {'integerValue': premium ? '40' : '10'},
        'retired': {'booleanValue': false},
        'tokens': {
          'mapValue': {
            'fields': {for (final e in t.entries) e.key: str(e.value)},
          },
        },
      },
    }),
  );

  await put('saffron', 'Saffron', false, {
    'primary': '#A8550A',
    'secondary': '#3B7A20',
    'background': '#FFF8EE',
    'surface': '#FFFFFF',
    'text': '#2B2B2B',
    'font': 'Poppins',
    'layout': 'list',
    'cardLayout': 'image-left',
    'mode': 'light',
  });
  await put('midnight', 'Midnight', true, {
    'primary': '#FFB454',
    'secondary': '#8FCB6B',
    'background': '#121417',
    'surface': '#1E2126',
    'text': '#F2EDE8',
    'font': 'Inter',
    'layout': 'grid',
    'cardLayout': 'image-top',
    'mode': 'dark',
  });
}

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() async {
    TimeService.ensureInitialized();
    await initFirebase(
      AppEnv.parse(envName: 'dev', useEmulators: true),
      optionsFor: (_) => throw StateError('emulators only'),
    );
  });

  testWidgets('choose a theme, customize it, contrast fix, rules (AC-012, '
      'BR-012, FR-060)', (tester) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(1280, 900);
    addTearDown(tester.view.reset);

    await seedThemes();
    final rid = await createVerifiedOwner();
    final root = FirebaseFirestore.instance.doc('restaurants/$rid');
    Future<Map<String, dynamic>> rootData() async =>
        (await root.get(const GetOptions(source: Source.server))).data()!;

    // Google Fonts are not fetched in the headless run.
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          menuFontResolverProvider.overrideWithValue(
            const PlainMenuFontResolver(),
          ),
        ],
        child: const OwnerApp(),
      ),
    );
    final router = ProviderScope.containerOf(
      tester.element(find.byType(OwnerApp)),
    ).read(appRouterProvider);
    await pumpUntil(
      tester,
      () => router.routerDelegate.currentConfiguration.uri.path == '/',
      what: 'dashboard',
    );
    router.go(Routes.theme);
    await pumpUntil(
      tester,
      () =>
          find.byKey(ThemeGalleryPage.cardKey('saffron')).evaluate().isNotEmpty,
      what: 'theme gallery',
    );
    expect(find.text('Premium'), findsOneWidget);

    Future<void> tap(Finder f) async {
      FocusManager.instance.primaryFocus?.unfocus();
      await tester.ensureVisible(f.first);
      await tester.pumpAndSettle();
      await tester.tap(f.first);
      await tester.pumpAndSettle();
    }

    // 1. Choose Saffron: themeId through the owner whitelist.
    await tap(find.byKey(ThemeGalleryPage.cardKey('saffron')));
    final chosen = await waitFor(
      tester,
      rootData,
      (d) => d['themeId'] == 'saffron',
      what: 'themeId saved',
    );
    expect(chosen['themeSettings'], <String, Object>{});
    expect(chosen['draftUpdatedAt'], isA<Timestamp>());

    // 2. Editor: a charcoal background with charcoal text.
    await tap(find.byKey(ThemeGalleryPage.customizeKey));
    await pumpUntil(
      tester,
      () => find.byKey(ThemeEditorPage.darkModeKey).evaluate().isNotEmpty,
      what: 'theme editor',
    );
    const hex = ValueKey('color.background.hex');
    await tester.ensureVisible(find.byKey(hex));
    await tester.enterText(find.byKey(hex), '#2b2b2b');
    await tester.pump();
    // On the web the first tap after typing only moves focus.
    FocusManager.instance.primaryFocus?.unfocus();
    await tester.pumpAndSettle();
    expect(find.byKey(ContrastNotice.warningKey), findsOneWidget);
    final name = tester.widget<Text>(
      find.descendant(
        of: find.byKey(MenuThemePreview.canvasKey),
        matching: find.text('Menu Test Kitchen'),
      ),
    );
    expect(name.style?.color, Colors.white);
    await waitFor(
      tester,
      rootData,
      (d) => (d['themeSettings'] as Map?)?['background'] == '#2B2B2B',
      what: 'background override saved',
    );

    // 3. Dark mode.
    final darkSwitch = find.descendant(
      of: find.byKey(ThemeEditorPage.darkModeKey),
      matching: find.byType(Switch),
    );
    bool isDark() => tester.widget<Switch>(darkSwitch).value;
    await tap(darkSwitch);
    if (!isDark()) await tap(darkSwitch);
    await pumpUntil(tester, isDark, what: 'dark mode on');
    final saved = await waitFor(
      tester,
      rootData,
      (d) => (d['themeSettings'] as Map?)?['mode'] == 'dark',
      what: 'mode saved',
    );
    expect(saved['themeSettings'], {'background': '#2B2B2B', 'mode': 'dark'});

    // 4. The rules check what a client sends (BR-011).
    Future<String?> refused(Map<String, Object?> fields) async {
      try {
        await root.update({
          ...fields,
          'draftUpdatedAt': FieldValue.serverTimestamp(),
        });
        return null;
      } on FirebaseException catch (e) {
        return e.code;
      }
    }

    expect(
      await refused({
        'themeSettings': {'primary': 'red'},
      }),
      'permission-denied',
    );
    expect(await refused({'themeId': 'no-such-theme'}), 'permission-denied');
    // M10 (BR-011): a premium theme needs a paid plan; a free one is fine.
    expect(await refused({'themeId': 'midnight'}), 'permission-denied');
    expect(await refused({'themeId': 'saffron'}), isNull);
  });
}
