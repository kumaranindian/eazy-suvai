// M03: dashboard home with the setup checklist.
import 'package:core/core.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:owner_app/features/home/presentation/dashboard_page.dart';
import 'package:owner_app/features/restaurant/presentation/menu_link_page.dart';
import 'package:owner_app/router/app_router.dart';

import 'helpers.dart';

double _x(WidgetTester tester, Key key) =>
    tester.getTopLeft(find.byKey(key)).dx;

void main() {
  for (final (width, columns) in [(360.0, 1), (768.0, 2), (1280.0, 3)]) {
    testWidgets('${width.toInt()} px: $columns column(s) of cards', (
      tester,
    ) async {
      await pumpOwnerApp(tester, width: width, signedIn: verifiedOwner());
      final xs = {
        for (final k in [
          DashboardKeys.checklist,
          DashboardKeys.status,
          DashboardKeys.qr,
        ])
          _x(tester, k).round(),
      };
      expect(xs, hasLength(columns));
      expect(tester.takeException(), isNull);
    });
  }

  testWidgets('checklist reflects the restaurant and links to the next step', (
    tester,
  ) async {
    final app = await pumpOwnerApp(
      tester,
      width: 1280,
      signedIn: verifiedOwner(),
    );
    expect(find.text('0 of 6 done'), findsOneWidget);
    expect(
      find.text(
        'Add a description, a phone number or email, and your address.',
      ),
      findsOneWidget,
    );

    app.restaurant.emit({
      'description': 'Dosas',
      'contact': {'city': 'Chennai', 'phone': '+914423456789'},
      'counts': {'categories': 2, 'items': 0},
    });
    await tester.pumpAndSettle();
    expect(find.text('2 of 6 done'), findsOneWidget);
    expect(
      find.descendant(
        of: find.byKey(DashboardKeys.step(SetupStep.profile)),
        matching: find.byIcon(Icons.check_circle),
      ),
      findsOneWidget,
    );
    // Next step: the logo.
    expect(find.text('A square logo, at least 256 × 256 px.'), findsOneWidget);
    await app.tap(find.byKey(DashboardKeys.step(SetupStep.logo)));
    expect(app.location, Routes.profile);
  });

  testWidgets('menu status: draft, then live with a prices warning', (
    tester,
  ) async {
    final app = await pumpOwnerApp(
      tester,
      width: 768,
      signedIn: verifiedOwner(),
    );
    expect(find.text('Draft'), findsOneWidget);
    expect(find.text('Categories: 0 · Dishes: 0'), findsOneWidget);

    app.restaurant.emit({
      'publishedVersion': 4,
      'pricesNeedReview': true,
      'counts': {'categories': 3, 'items': 12},
    });
    await tester.pumpAndSettle();
    expect(find.text('Live · version 4'), findsOneWidget);
    expect(find.text('Categories: 3 · Dishes: 12'), findsOneWidget);
    expect(
      find.textContaining('You changed the currency after publishing.'),
      findsOneWidget,
    );
  });

  testWidgets('QR shortcut shows the link and code, and opens QR & share', (
    tester,
  ) async {
    final app = await pumpOwnerApp(
      tester,
      width: 360,
      signedIn: verifiedOwner(),
    );
    await tester.ensureVisible(find.byKey(DashboardKeys.qr));
    expect(find.text(menuUrl('spice-garden')), findsOneWidget);
    expect(find.text('QR code: ABCDEFGH'), findsOneWidget);
    await app.tap(
      find.descendant(
        of: find.byKey(DashboardKeys.qr),
        matching: find.text('QR & share'),
      ),
    );
    expect(app.location, Routes.share);
  });
}
