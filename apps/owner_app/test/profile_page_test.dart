// M03: restaurant profile editor (FR-011 to FR-014, AC-002).
import 'package:cloud_firestore/cloud_firestore.dart' show FirebaseException;
import 'package:core/core.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:owner_app/features/restaurant/presentation/menu_header_preview.dart';
import 'package:owner_app/features/restaurant/presentation/profile_form.dart';
import 'package:owner_app/features/restaurant/presentation/save_status.dart';
import 'package:owner_app/router/app_router.dart';

import 'helpers.dart';

const _logo = {
  'path': 'restaurants/rest_1/images/abcdefghij0123456789/original.png',
  'status': 'ready',
  'contentType': 'image/png',
  'width': 512,
  'height': 512,
  'renditions': {
    'w320': 'restaurants/rest_1/images/abcdefghij0123456789/w320.webp',
    'w640': 'restaurants/rest_1/images/abcdefghij0123456789/w640.webp',
    'w1280': 'restaurants/rest_1/images/abcdefghij0123456789/w1280.webp',
  },
};

Future<TestApp> openProfile(
  WidgetTester tester, {
  double width = 1280,
  FakeRestaurantRepository? restaurant,
}) async {
  final app = await pumpOwnerApp(
    tester,
    width: width,
    signedIn: verifiedOwner(),
    restaurant: restaurant,
  );
  await app.go(Routes.profile);
  return app;
}

/// Waits out the 1 s autosave pause.
Future<void> autosave(WidgetTester tester) async {
  await tester.pump(const Duration(seconds: 1));
  await tester.pump();
}

void main() {
  group('layout', () {
    testWidgets('360 px: expandable sections and a sticky save bar', (
      tester,
    ) async {
      final app = await openProfile(tester, width: 360);
      expect(find.byType(ExpansionTile), findsNWidgets(7));
      expect(find.byType(SaveBar), findsOneWidget);
      expect(find.text('Changes save automatically'), findsOneWidget);
      // The first section is open.
      expect(find.byKey(ProfileKeys.name), findsOneWidget);

      // "Save now" saves at once, without waiting for the pause.
      await app.enter(ProfileKeys.description, 'Filter coffee and dosas');
      await tester.tap(find.byKey(SaveBar.saveNowKey));
      await tester.pump();
      expect(app.restaurant.updates.single, {
        'description': 'Filter coffee and dosas',
      });
      await tester.pump(const Duration(seconds: 2));
      expect(tester.takeException(), isNull);
    });

    testWidgets('768 px: two columns of sections, no save bar', (tester) async {
      await openProfile(tester, width: 768);
      expect(find.byType(ExpansionTile), findsNothing);
      expect(find.byType(SaveBar), findsNothing);
      final xs = tester
          .widgetList<FormSection>(find.byType(FormSection))
          .map((w) => tester.getTopLeft(find.byWidget(w)).dx.round())
          .toSet();
      expect(xs, hasLength(2));
      expect(find.byType(SaveStatusIndicator), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets(
      '1280 px: form up to 720 px with the live preview on the right',
      (tester) async {
        await openProfile(tester, width: 1280);
        final preview = tester.getRect(find.byType(MenuHeaderPreview));
        final form = tester.getRect(find.byType(FormSection).first);
        expect(form.width, lessThanOrEqualTo(720));
        expect(preview.left, greaterThan(form.right));
        expect(tester.takeException(), isNull);
      },
    );
  });

  testWidgets('a change autosaves to the draft after 1 s (FR-012)', (
    tester,
  ) async {
    final app = await openProfile(tester);
    await app.enter(ProfileKeys.description, 'Dosas since 1998');
    await tester.pump(const Duration(milliseconds: 900));
    expect(app.restaurant.updates, isEmpty);
    expect(find.text('Saving…'), findsOneWidget);

    await app.enter(ProfileKeys.name, 'Spice Garden Café');
    await tester.pump(const Duration(milliseconds: 900));
    expect(
      app.restaurant.updates,
      isEmpty,
      reason: 'typing restarts the pause',
    );

    await autosave(tester);
    expect(app.restaurant.updates.single, {
      'description': 'Dosas since 1998',
      'name': 'Spice Garden Café',
    });
    expect(find.text('Saved'), findsOneWidget);
    // The preview follows the form.
    expect(
      find.descendant(
        of: find.byType(MenuHeaderPreview),
        matching: find.text('Spice Garden Café'),
      ),
      findsOneWidget,
    );
  });

  testWidgets('every FR-011 field is saved in its stored form (AC-002)', (
    tester,
  ) async {
    final app = await openProfile(tester);
    await app.choose(ProfileKeys.businessType, 'Café');
    await app.enter(ProfileKeys.phone, '044 2345 6789');
    await app.enter(ProfileKeys.email, 'hello@spicegarden.in');
    await app.enter(ProfileKeys.website, 'spicegarden.in');
    await app.enter(ProfileKeys.address, '12 Anna Salai, T. Nagar');
    await app.enter(ProfileKeys.postalCode, '600017');
    await app.enter(
      ProfileKeys.social(SocialNetwork.instagram),
      '@spicegarden',
    );
    await app.enter(
      ProfileKeys.social(SocialNetwork.facebook),
      'facebook.com/spicegarden',
    );
    await app.enter(ProfileKeys.social(SocialNetwork.x), '@spicegarden');
    await app.enter(ProfileKeys.social(SocialNetwork.youtube), '@spicegarden');
    await app.enter(
      ProfileKeys.social(SocialNetwork.googleMaps),
      'https://maps.app.goo.gl/abc123',
    );
    await autosave(tester);

    // The dropdown animation outlasts the 1 s pause, so the business type
    // may be saved on its own; compare everything written.
    final written = {for (final u in app.restaurant.updates) ...u};
    expect(written, {
      'businessType': 'cafe',
      'contact': {
        'phone': '+914423456789',
        'email': 'hello@spicegarden.in',
        'address': '12 Anna Salai, T. Nagar',
        'city': 'Chennai',
        'postalCode': '600017',
        'website': 'https://spicegarden.in',
        'social': {
          'instagram': 'https://instagram.com/spicegarden',
          'facebook': 'https://facebook.com/spicegarden',
          'x': 'https://x.com/spicegarden',
          'youtube': 'https://youtube.com/@spicegarden',
          'googleMaps': 'https://maps.app.goo.gl/abc123',
        },
      },
    });
    expect(
      find.text('PIN code'),
      findsOneWidget,
      reason: 'India calls it a PIN code',
    );
  });

  group('validation', () {
    final cases = <(String, Key, String, String)>[
      ('an empty name', ProfileKeys.name, '', 'This field is required.'),
      (
        'an invalid phone for India',
        ProfileKeys.phone,
        '12345',
        "Enter a valid phone number for your restaurant's country.",
      ),
      (
        'a bad email',
        ProfileKeys.email,
        'hello@',
        'Enter a valid email address, like name@example.com.',
      ),
      (
        'an http website',
        ProfileKeys.website,
        'http://spicegarden.in',
        'Use a secure address that starts with https://.',
      ),
      (
        'a bad PIN code',
        ProfileKeys.postalCode,
        '60001',
        'Enter a valid PIN code.',
      ),
      (
        'a link to another site as Instagram',
        ProfileKeys.social(SocialNetwork.instagram),
        'https://example.com/spice',
        'Enter a link to your Instagram page.',
      ),
    ];

    for (final (what, key, value, message) in cases) {
      testWidgets('refuses $what and saves nothing', (tester) async {
        final app = await openProfile(tester);
        await app.enter(key, value);
        expect(find.text(message), findsOneWidget);
        await autosave(tester);
        expect(app.restaurant.updates, isEmpty);
        expect(find.text('Fix the highlighted fields to save'), findsOneWidget);
      });
    }

    testWidgets('fixing the field saves it', (tester) async {
      final app = await openProfile(tester);
      await app.enter(ProfileKeys.website, 'http://spicegarden.in');
      await autosave(tester);
      expect(app.restaurant.updates, isEmpty);
      await app.enter(ProfileKeys.website, 'https://spicegarden.in');
      await autosave(tester);
      expect(app.restaurant.updates.single['contact'], {
        'city': 'Chennai',
        'website': 'https://spicegarden.in',
      });
      expect(find.text('Saved'), findsOneWidget);
    });

    testWidgets(
      'UAE has no postal code; phone checked for the UAE (FRD §6.1)',
      (tester) async {
        final app = await openProfile(
          tester,
          restaurant: FakeRestaurantRepository(
            restaurantData({
              'country': 'AE',
              'currency': 'AED',
              'timezone': 'Asia/Dubai',
            }),
          ),
        );
        expect(find.byKey(ProfileKeys.postalCode), findsNothing);
        expect(find.text('+971 '), findsOneWidget);
        await app.enter(ProfileKeys.phone, '98765 43210');
        expect(
          find.text(
            "Enter a valid phone number for your restaurant's country.",
          ),
          findsOneWidget,
        );
        await app.enter(ProfileKeys.phone, '50 123 4567');
        await autosave(tester);
        expect(app.restaurant.updates.single['contact'], {
          'city': 'Chennai',
          'phone': '+971501234567',
        });
      },
    );
  });

  testWidgets(
    'visibility toggles are saved and the preview hides the field (FR-013, FR-014)',
    (tester) async {
      final app = await openProfile(
        tester,
        restaurant: FakeRestaurantRepository(
          restaurantData({
            'contact': {
              'city': 'Chennai',
              'email': 'hello@spicegarden.in',
              'phone': '+914423456789',
            },
          }),
        ),
      );
      final preview = find.byType(MenuHeaderPreview);
      expect(
        find.descendant(
          of: preview,
          matching: find.text('hello@spicegarden.in'),
        ),
        findsOneWidget,
      );

      await app.tap(find.byKey(ProfileKeys.visibility(VisibleField.email)));
      await autosave(tester);
      expect(app.restaurant.updates.single, {
        'visibility': {
          'phone': true,
          'email': false,
          'address': true,
          'hours': true,
          'social': true,
        },
      });
      expect(
        find.descendant(
          of: preview,
          matching: find.text('hello@spicegarden.in'),
        ),
        findsNothing,
      );
      expect(find.text('Hidden from customers: Email'), findsOneWidget);
    },
  );

  testWidgets('removing the logo sets the field to null (M02 contract)', (
    tester,
  ) async {
    final app = await openProfile(
      tester,
      restaurant: FakeRestaurantRepository(restaurantData({'logo': _logo})),
    );
    expect(find.byType(ImagePickerField), findsNWidgets(2));
    await app.tap(find.text('Remove'));
    await tester.tap(find.widgetWithText(FilledButton, 'Remove'));
    await tester.pumpAndSettle();
    expect(app.restaurant.updates.single, {'logo': null});
  });

  testWidgets('a failed save keeps the changes and can be retried', (
    tester,
  ) async {
    final app = await openProfile(tester);
    app.restaurant.nextError = FirebaseException(
      plugin: 'cloud_firestore',
      code: 'unavailable',
    );
    await app.enter(ProfileKeys.description, 'Hello');
    await autosave(tester);
    expect(app.restaurant.updates, isEmpty);
    expect(find.text("Couldn't save your changes"), findsOneWidget);

    await tester.tap(find.byKey(SaveStatusIndicator.retryKey));
    await tester.pump();
    expect(app.restaurant.updates.single, {'description': 'Hello'});
    expect(find.text('Saved'), findsOneWidget);
  });
}
