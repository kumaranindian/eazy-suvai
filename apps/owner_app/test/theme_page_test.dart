// M05: theme gallery, theme editor and the live preview (FR-055 to FR-060).
import 'package:core/core.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:owner_app/features/home/presentation/dashboard_page.dart';
import 'package:owner_app/features/theme/presentation/contrast_notice.dart';
import 'package:owner_app/features/theme/presentation/menu_theme_preview.dart';
import 'package:owner_app/features/theme/presentation/theme_editor_page.dart';
import 'package:owner_app/features/theme/presentation/theme_gallery_page.dart';
import 'package:owner_app/router/app_router.dart';

import 'fake_menu.dart';
import 'fake_theme.dart';
import 'helpers.dart';

Future<TestApp> _open(
  WidgetTester tester,
  String route, {
  double width = 1280,
  Map<String, dynamic> restaurant = const {},
  FakeMenuRepository? menu,
}) async {
  final app = await pumpOwnerApp(
    tester,
    width: width,
    signedIn: verifiedOwner(),
    restaurant: FakeRestaurantRepository(restaurantData(restaurant)),
    menu: menu,
  );
  await app.go(route);
  return app;
}

/// Lets the 1 s autosave run.
Future<void> _autosave(WidgetTester tester) async {
  await tester.pump(const Duration(milliseconds: 1100));
  await tester.pumpAndSettle();
}

Finder get _canvas => find.byKey(MenuThemePreview.canvasKey);

Color? _canvasColor(WidgetTester tester) =>
    tester.widget<Material>(_canvas.first).color;

Color? _previewTextColor(WidgetTester tester, String text) => tester
    .widget<Text>(
      find.descendant(of: _canvas.first, matching: find.text(text)).first,
    )
    .style
    ?.color;

void main() {
  group('gallery', () {
    for (final width in [360.0, 768.0, 1280.0]) {
      testWidgets('${width.toInt()} px: themes, badges and choosing one', (
        tester,
      ) async {
        final app = await _open(tester, Routes.theme, width: width);
        expect(find.text('Theme'), findsWidgets);
        for (final p in seedPresets) {
          expect(find.byKey(ThemeGalleryPage.cardKey(p.id)), findsOneWidget);
        }
        expect(find.text('Premium'), findsOneWidget);
        expect(find.text('No theme chosen yet'), findsOneWidget);
        // Wide layouts show the preview beside the grid; phones open it.
        expect(_canvas, width < 600 ? findsNothing : findsOneWidget);

        final card = find.byKey(ThemeGalleryPage.cardKey('midnight'));
        await tester.ensureVisible(card);
        await tester.pumpAndSettle();
        await tester.tap(card);
        await tester.pump();
        // The preview follows at once, before anything is saved.
        expect(app.restaurant.updates, isEmpty);
        if (width >= 600) {
          expect(_canvasColor(tester), const Color(0xFF121417));
        }
        await _autosave(tester);
        expect(app.restaurant.updates.last, {
          'themeId': 'midnight',
          'themeSettings': <String, Object>{},
        });
        expect(find.text('Midnight'), findsWidgets);
        expect(tester.takeException(), isNull);
      });
    }

    testWidgets(
      '2 columns on phones and tablets, 4 on desktops (3 themes: one row)',
      (tester) async {
        for (final (width, columns) in [(360.0, 2), (768.0, 2), (1280.0, 3)]) {
          await _open(tester, Routes.theme, width: width);
          final xs = {
            for (final p in seedPresets)
              tester
                  .getTopLeft(find.byKey(ThemeGalleryPage.cardKey(p.id)))
                  .dx
                  .round(),
          };
          // Three themes: all in one row at 4 columns, 2 + 1 at 2 columns.
          expect(xs, hasLength(columns), reason: '$width px');
        }
      },
    );

    testWidgets('phones open a full-screen preview', (tester) async {
      await _open(
        tester,
        Routes.theme,
        width: 360,
        restaurant: {'themeId': 'saffron'},
      );
      await tester.tap(find.byKey(ThemeGalleryPage.previewKey));
      await tester.pumpAndSettle();
      expect(_canvas, findsOneWidget);
      expect(tester.getSize(_canvas).width, 360);
      expect(_canvasColor(tester), const Color(0xFFFFF8EE));
      await tester.tap(find.byKey(const ValueKey('theme.preview.close')));
      await tester.pumpAndSettle();
      expect(_canvas, findsNothing);
    });

    testWidgets('switching away from a customized theme asks first', (
      tester,
    ) async {
      final app = await _open(
        tester,
        Routes.theme,
        restaurant: {
          'themeId': 'saffron',
          'themeSettings': {'primary': '#123456'},
        },
      );
      expect(find.text('Saffron (customized)'), findsOneWidget);
      await app.tap(find.byKey(ThemeGalleryPage.cardKey('minimal')));
      expect(find.text('Switch theme?'), findsOneWidget);
      await app.tap(find.text('Cancel'));
      await _autosave(tester);
      expect(app.restaurant.updates, isEmpty);

      await app.tap(find.byKey(ThemeGalleryPage.cardKey('minimal')));
      await app.tap(find.text('Switch theme'));
      await _autosave(tester);
      expect(app.restaurant.updates.last, {
        'themeId': 'minimal',
        'themeSettings': <String, Object>{},
      });
    });

    testWidgets('empty state when no themes are seeded', (tester) async {
      final app = await pumpOwnerApp(
        tester,
        signedIn: verifiedOwner(),
        themes: FakeThemeRepository(themes: const []),
      );
      await app.go(Routes.theme);
      expect(
        find.text('No themes are available yet. Please try again later.'),
        findsOneWidget,
      );
    });
  });

  group('editor', () {
    for (final width in [360.0, 768.0, 1280.0]) {
      testWidgets('${width.toInt()} px: every control saves to the draft', (
        tester,
      ) async {
        final app = await _open(
          tester,
          Routes.themeEditor,
          width: width,
          restaurant: {'themeId': 'saffron'},
        );
        expect(find.text('Customize theme'), findsOneWidget);
        expect(find.byKey(ContrastNotice.okKey), findsOneWidget);
        // Compact: preview from the app bar; wider: beside the controls.
        expect(_canvas, width < 600 ? findsNothing : findsOneWidget);
        expect(
          find.byKey(ThemeEditorPage.previewKey),
          width < 600 ? findsOneWidget : findsNothing,
        );
        expect(
          find.byKey(ThemeEditorPage.deviceKey),
          width >= 1024 ? findsOneWidget : findsNothing,
        );

        await app.enter(const ValueKey('color.primary.hex'), '#0b6580');
        await app.tap(find.byKey(ThemeEditorPage.layoutKey(MenuLayout.grid)));
        await app.tap(find.byKey(ThemeEditorPage.cardKey(CardLayout.compact)));
        await app.tap(find.byKey(ThemeEditorPage.darkModeKey));
        await app.choose(ThemeEditorPage.fontKey, 'Lora');
        await _autosave(tester);
        expect(app.restaurant.updates.last, {
          'themeSettings': {
            'primary': '#0B6580',
            'font': 'Lora',
            'layout': 'grid',
            'cardLayout': 'compact',
            'mode': 'dark',
          },
        });
        expect(find.text('Saved'), findsOneWidget);

        await app.tap(find.byKey(ThemeEditorPage.resetAllKey));
        await _autosave(tester);
        expect(app.restaurant.updates.last, {
          'themeSettings': <String, Object>{},
        });
        expect(tester.takeException(), isNull);
      });
    }

    testWidgets('a colour change updates the preview at once', (tester) async {
      final app = await _open(
        tester,
        Routes.themeEditor,
        restaurant: {'themeId': 'saffron'},
      );
      expect(_canvasColor(tester), const Color(0xFFFFF8EE));
      final swatch = find.byKey(
        const ValueKey('color.background.swatch.#F2F8FA'),
      );
      await tester.ensureVisible(swatch);
      await tester.pumpAndSettle();
      await tester.tap(swatch);
      await tester.pump();
      // No autosave yet: the preview uses the local edit.
      expect(app.restaurant.updates, isEmpty);
      expect(_canvasColor(tester), const Color(0xFFF2F8FA));
      await _autosave(tester);
      expect(app.restaurant.updates.last, {
        'themeSettings': {'background': '#F2F8FA'},
      });
    });

    testWidgets(
      'low contrast warns and the preview uses the adjusted text (FR-060)',
      (tester) async {
        final app = await _open(
          tester,
          Routes.themeEditor,
          restaurant: {'themeId': 'saffron'},
        );
        expect(
          _previewTextColor(tester, 'Spice Garden'),
          const Color(0xFF2B2B2B),
        );
        // Charcoal background with the theme's charcoal text: 1:1.
        await app.enter(const ValueKey('color.background.hex'), '#2B2B2B');
        expect(find.byKey(ContrastNotice.warningKey), findsOneWidget);
        expect(
          find.textContaining('Your menu will use white text instead.'),
          findsOneWidget,
        );
        expect(_canvasColor(tester), const Color(0xFF2B2B2B));
        expect(_previewTextColor(tester, 'Spice Garden'), Colors.white);

        // Back to the theme colour: the warning goes away.
        await app.tap(find.byKey(const ValueKey('color.background.reset')));
        expect(find.byKey(ContrastNotice.okKey), findsOneWidget);
        expect(
          _previewTextColor(tester, 'Spice Garden'),
          const Color(0xFF2B2B2B),
        );
      },
    );

    testWidgets('an invalid hex code is not applied', (tester) async {
      final app = await _open(
        tester,
        Routes.themeEditor,
        restaurant: {'themeId': 'saffron'},
      );
      await app.enter(const ValueKey('color.primary.hex'), '#12');
      expect(find.text('Enter a colour like #A8550A.'), findsOneWidget);
      await _autosave(tester);
      expect(app.restaurant.updates, isEmpty);
    });

    testWidgets('desktop preview on wide screens', (tester) async {
      final app = await _open(
        tester,
        Routes.themeEditor,
        restaurant: {'themeId': 'saffron'},
      );
      final phone = tester.getSize(_canvas);
      expect(phone.width / phone.height, closeTo(390 / 780, 0.01));
      await app.tap(find.text('Desktop'));
      final desktop = tester.getSize(_canvas);
      expect(desktop.width / desktop.height, closeTo(1280 / 800, 0.01));
    });

    testWidgets('asks to choose a theme first', (tester) async {
      final app = await _open(tester, Routes.themeEditor, width: 360);
      expect(
        find.text('Choose a theme first, then customize it.'),
        findsOneWidget,
      );
      await app.tap(find.text('Choose a theme'));
      expect(app.location, Routes.theme);
    });
  });

  group('preview content', () {
    testWidgets('uses the real menu: active categories, items, sold out', (
      tester,
    ) async {
      await _open(
        tester,
        Routes.themeEditor,
        restaurant: {'themeId': 'saffron'},
        menu: sampleMenu(),
      );
      for (final name in ['Starters', 'Mains', 'Paneer tikka', 'Veg biryani']) {
        expect(
          find.descendant(of: _canvas, matching: find.text(name)),
          findsWidgets,
          reason: name,
        );
      }
      expect(
        find.descendant(of: _canvas, matching: find.text('Sold out')),
        findsOneWidget,
      );
      expect(
        find.descendant(of: _canvas, matching: find.text('₹249.00')),
        findsOneWidget,
      );
      expect(
        find.text('Sample dishes are shown until you add items.'),
        findsNothing,
      );
    });

    testWidgets('shows sample dishes while the menu is empty', (tester) async {
      await _open(
        tester,
        Routes.themeEditor,
        restaurant: {'themeId': 'saffron'},
      );
      expect(
        find.text('Sample dishes are shown until you add items.'),
        findsOneWidget,
      );
      expect(
        find.descendant(of: _canvas, matching: find.text('Masala dosa')),
        findsOneWidget,
      );
    });

    testWidgets('uses the theme font', (tester) async {
      final app = await _open(
        tester,
        Routes.themeEditor,
        restaurant: {'themeId': 'saffron'},
      );
      expect(
        tester
            .widget<Text>(
              find.descendant(of: _canvas, matching: find.text('Spice Garden')),
            )
            .style
            ?.fontFamily,
        'Poppins',
      );
      await app.choose(ThemeEditorPage.fontKey, 'Playfair Display');
      expect(
        tester
            .widget<Text>(
              find.descendant(of: _canvas, matching: find.text('Spice Garden')),
            )
            .style
            ?.fontFamily,
        'Playfair Display',
      );
    });
  });

  group('entry points', () {
    testWidgets('Settings lists the theme with its name', (tester) async {
      final app = await _open(
        tester,
        Routes.settings,
        restaurant: {
          'themeId': 'saffron',
          'themeSettings': {'mode': 'dark'},
        },
      );
      expect(find.text('Saffron (customized)'), findsOneWidget);
      await app.tap(find.byKey(const ValueKey('settings.theme')));
      expect(app.location, Routes.theme);
    });

    testWidgets('the checklist step "Choose a theme" opens the gallery', (
      tester,
    ) async {
      final app = await _open(tester, Routes.home);
      await app.tap(find.byKey(DashboardKeys.step(SetupStep.theme)));
      expect(app.location, Routes.theme);
    });
  });
}
