// M03: first-run setup wizard (FRD §5.1 steps 4–5).
import 'package:core/core.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:owner_app/features/home/presentation/dashboard_page.dart';
import 'package:owner_app/features/restaurant/presentation/menu_header_preview.dart';
import 'package:owner_app/features/restaurant/presentation/profile_form.dart';
import 'package:owner_app/features/setup/presentation/setup_wizard_page.dart';
import 'package:owner_app/router/app_router.dart';

import 'helpers.dart';

/// A restaurant fresh from sign-up: setup never finished.
FakeRestaurantRepository newRestaurant() =>
    FakeRestaurantRepository(restaurantData({'setupCompletedAt': null}));

void main() {
  testWidgets('a new owner lands in the wizard; finishing opens the menu', (
    tester,
  ) async {
    final app = await pumpOwnerApp(
      tester,
      width: 360,
      signedIn: verifiedOwner(),
      restaurant: newRestaurant(),
    );
    expect(app.location, Routes.setup);
    expect(find.text('Set up your restaurant'), findsOneWidget);
    expect(find.text('Step 1 of 3'), findsOneWidget);
    // Sign-up details are filled in already.
    expect(find.widgetWithText(TextFormField, 'Spice Garden'), findsOneWidget);
    expect(find.widgetWithText(TextFormField, 'Chennai'), findsOneWidget);

    await app.enter(ProfileKeys.description, 'Dosas and filter coffee.');
    await app.enter(ProfileKeys.phone, '98765 43210');
    await app.tap(find.byKey(WizardKeys.next));
    expect(app.restaurant.updates.single, {
      'description': 'Dosas and filter coffee.',
      'contact': {'phone': '+919876543210', 'city': 'Chennai'},
    }, reason: 'Next saves at once');
    expect(find.text('Step 2 of 3'), findsOneWidget);
    expect(find.byType(ImagePickerField), findsNWidgets(2));

    // The logo step is optional.
    await app.tap(find.byKey(WizardKeys.next));
    expect(find.text('Step 3 of 3'), findsOneWidget);
    expect(find.text('Build your menu'), findsWidgets);

    await app.tap(find.byKey(WizardKeys.toMenu));
    expect(app.restaurant.setupCompletions, 1);
    expect(app.location, Routes.menu);
    expect(tester.takeException(), isNull);
  });

  testWidgets('the name is required before moving on', (tester) async {
    final app = await pumpOwnerApp(
      tester,
      width: 768,
      signedIn: verifiedOwner(),
      restaurant: newRestaurant(),
    );
    await app.enter(ProfileKeys.name, '');
    await app.tap(find.byKey(WizardKeys.next));
    expect(find.text('This field is required.'), findsOneWidget);
    expect(find.text('Step 1 of 3'), findsOneWidget);
    expect(app.restaurant.updates, isEmpty);
  });

  testWidgets('Back returns to the previous step', (tester) async {
    final app = await pumpOwnerApp(
      tester,
      width: 768,
      signedIn: verifiedOwner(),
      restaurant: newRestaurant(),
    );
    await app.tap(find.byKey(WizardKeys.next));
    expect(find.text('Step 2 of 3'), findsOneWidget);
    await app.tap(find.byKey(WizardKeys.back));
    expect(find.text('Step 1 of 3'), findsOneWidget);
  });

  testWidgets(
    'skipping marks setup done and goes to the dashboard, which does not reopen it',
    (tester) async {
      final app = await pumpOwnerApp(
        tester,
        width: 1280,
        signedIn: verifiedOwner(),
        restaurant: newRestaurant(),
      );
      await app.tap(find.byKey(WizardKeys.skip));
      expect(app.restaurant.setupCompletions, 1);
      expect(app.location, Routes.home);
      expect(find.byKey(DashboardKeys.checklist), findsOneWidget);
    },
  );

  testWidgets('the dashboard opens the wizard only once per session', (
    tester,
  ) async {
    final app = await pumpOwnerApp(
      tester,
      width: 1280,
      signedIn: verifiedOwner(),
      restaurant: newRestaurant(),
    );
    expect(app.location, Routes.setup);
    // Leave without finishing (for example through the address bar).
    await app.go(Routes.home);
    expect(app.location, Routes.home);
    expect(find.byKey(DashboardKeys.checklist), findsOneWidget);
  });

  group('layouts', () {
    testWidgets('360 px: progress bar, buttons in a bottom bar', (
      tester,
    ) async {
      await pumpOwnerApp(
        tester,
        width: 360,
        signedIn: verifiedOwner(),
        restaurant: newRestaurant(),
      );
      expect(find.byKey(WizardKeys.progress), findsOneWidget);
      expect(find.byKey(WizardKeys.stepper), findsNothing);
      expect(find.byType(MenuHeaderPreview), findsNothing);
      expect(
        tester.getTopLeft(find.byKey(WizardKeys.next)).dy,
        greaterThan(800),
        reason: 'bottom bar',
      );
      expect(tester.takeException(), isNull);
    });

    testWidgets('768 px: progress bar in a wider card', (tester) async {
      await pumpOwnerApp(
        tester,
        width: 768,
        signedIn: verifiedOwner(),
        restaurant: newRestaurant(),
      );
      expect(find.byKey(WizardKeys.progress), findsOneWidget);
      final card = tester.getRect(find.byType(Card).first);
      expect(card.width, lessThanOrEqualTo(640));
      expect(card.width, greaterThan(500));
      expect(tester.takeException(), isNull);
    });

    testWidgets(
      '1280 px: stepper on the left, live header preview on the right',
      (tester) async {
        final app = await pumpOwnerApp(
          tester,
          width: 1280,
          signedIn: verifiedOwner(),
          restaurant: newRestaurant(),
        );
        expect(find.byKey(WizardKeys.progress), findsNothing);
        final stepper = tester.getRect(find.byKey(WizardKeys.stepper));
        final preview = tester.getRect(find.byType(MenuHeaderPreview));
        expect(stepper.left, 0);
        expect(preview.left, greaterThan(1280 / 2));
        // The preview follows the form before anything is saved.
        await app.enter(ProfileKeys.name, 'Annapoorna');
        expect(
          find.descendant(
            of: find.byType(MenuHeaderPreview),
            matching: find.text('Annapoorna'),
          ),
          findsOneWidget,
        );
        await tester.pump(const Duration(seconds: 2));
        expect(tester.takeException(), isNull);
      },
    );
  });
}
