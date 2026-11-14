// M03: menu link (slug) editor (FR-092, FR-093, BR-002).
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:owner_app/features/restaurant/presentation/menu_link_page.dart';
import 'package:owner_app/router/app_router.dart';

import 'helpers.dart';

Future<TestApp> openMenuLink(WidgetTester tester, {double width = 1280}) async {
  final app = await pumpOwnerApp(
    tester,
    width: width,
    signedIn: verifiedOwner(),
  );
  await app.go(Routes.menuLink);
  return app;
}

Future<void> typeSlug(TestApp app, String slug) async {
  await app.enter(MenuLinkKeys.field, slug);
  await app.tester.pump(MenuLinkPage.checkDelay);
  await app.tester.pump();
}

AppPrimaryButtonState saveButton(WidgetTester tester) => AppPrimaryButtonState(
  tester.widget<FilledButton>(
    find.descendant(
      of: find.byKey(MenuLinkKeys.save),
      matching: find.byType(FilledButton),
    ),
  ),
);

class AppPrimaryButtonState {
  AppPrimaryButtonState(this.button);
  final FilledButton button;
  bool get enabled => button.onPressed != null;
}

void main() {
  for (final width in [360.0, 768.0, 1280.0]) {
    testWidgets('shows and copies the current link at ${width.toInt()} px', (
      tester,
    ) async {
      final copied = <String>[];
      tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
        SystemChannels.platform,
        (call) async {
          if (call.method == 'Clipboard.setData') {
            copied.add((call.arguments as Map)['text'] as String);
          }
          return null;
        },
      );
      addTearDown(
        () => tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
          SystemChannels.platform,
          null,
        ),
      );

      final app = await openMenuLink(tester, width: width);
      expect(find.text(menuUrl('spice-garden')), findsOneWidget);
      expect(
        find.text('Your QR code always works, even if you change this link.'),
        findsOneWidget,
      );
      await app.tap(find.byKey(MenuLinkKeys.copy));
      expect(copied, [menuUrl('spice-garden')]);
      expect(find.text('Link copied'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  }

  testWidgets('format errors are shown at once, without calling the server', (
    tester,
  ) async {
    final app = await openMenuLink(tester);
    await typeSlug(app, 'ab');
    expect(
      find.textContaining('Use 3 to 60 lowercase letters'),
      findsOneWidget,
    );
    await typeSlug(app, 'spice--garden');
    expect(
      find.textContaining('Use 3 to 60 lowercase letters'),
      findsOneWidget,
    );
    expect(app.restaurant.slugChecks, isEmpty);
    expect(saveButton(tester).enabled, isFalse);
  });

  testWidgets('a reserved word is refused with a clear message (FR-092)', (
    tester,
  ) async {
    final app = await openMenuLink(tester);
    await typeSlug(app, 'admin');
    expect(
      find.text('This link is reserved. Choose another one.'),
      findsOneWidget,
    );
    expect(saveButton(tester).enabled, isFalse);
  });

  testWidgets('a taken slug is refused with a clear message (BR-002)', (
    tester,
  ) async {
    final app = await openMenuLink(tester);
    await typeSlug(app, 'other-place');
    expect(app.restaurant.slugChecks, ['other-place']);
    expect(
      find.text(
        'Another restaurant already uses this link. Try adding your area or city.',
      ),
      findsOneWidget,
    );
    expect(saveButton(tester).enabled, isFalse);
  });

  testWidgets(
    'input is lower-cased and limited to letters, digits and hyphens',
    (tester) async {
      final app = await openMenuLink(tester);
      await typeSlug(app, 'Spice Garden_Chennai');
      final field = tester.widget<TextField>(find.byKey(MenuLinkKeys.field));
      expect(field.controller!.text, 'spicegardenchennai');
      expect(app.restaurant.slugChecks, ['spicegardenchennai']);
    },
  );

  testWidgets(
    'an available slug can be saved after confirming; the old link keeps working (FR-093)',
    (tester) async {
      final app = await openMenuLink(tester);
      await typeSlug(app, 'spice-garden-chennai');
      expect(find.text('This link is available.'), findsOneWidget);
      expect(saveButton(tester).enabled, isTrue);

      await app.tap(find.byKey(MenuLinkKeys.save));
      expect(find.text('Change your menu link?'), findsOneWidget);
      expect(
        find.textContaining(
          'The old link ${menuUrl('spice-garden')} keeps working',
        ),
        findsOneWidget,
      );
      await app.tap(find.widgetWithText(FilledButton, 'Change link').last);

      expect(app.restaurant.slugChanges, ['spice-garden-chennai']);
      expect(find.text('Your menu link was changed.'), findsOneWidget);
      expect(find.text(menuUrl('spice-garden-chennai')), findsOneWidget);
    },
  );

  testWidgets('a slug taken between the check and the save is reported', (
    tester,
  ) async {
    final app = await openMenuLink(tester);
    await typeSlug(app, 'hot-name');
    app.restaurant.taken.add('hot-name');
    await app.tap(find.byKey(MenuLinkKeys.save));
    await app.tap(find.widgetWithText(FilledButton, 'Change link').last);
    expect(app.restaurant.slugChanges, isEmpty);
    expect(
      find.text(
        'Another restaurant already uses this link. Try adding your area or city.',
      ),
      findsOneWidget,
    );
  });
}
