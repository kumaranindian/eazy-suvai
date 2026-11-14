// M03: currency and time zone (FR-011, FR-103, FRD §6.2–6.4).
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:owner_app/features/restaurant/presentation/regional_page.dart';
import 'package:owner_app/router/app_router.dart';

import 'helpers.dart';

Future<TestApp> openRegional(
  WidgetTester tester, {
  double width = 1280,
  Map<String, dynamic> extra = const {},
}) async {
  final app = await pumpOwnerApp(
    tester,
    width: width,
    signedIn: verifiedOwner(),
    restaurant: FakeRestaurantRepository(restaurantData(extra)),
  );
  await app.go(Routes.regional);
  return app;
}

Finder get _currency => find.byWidgetPredicate(
  (w) =>
      w.key is ValueKey<String> &&
      (w.key! as ValueKey<String>).value.startsWith(
        RegionalKeys.currency.value,
      ),
);

Future<void> pickCurrency(TestApp app, String label) async {
  await app.tap(_currency);
  await app.tester.tap(find.text(label).last);
  await app.tester.pumpAndSettle();
}

void main() {
  testWidgets('before any publish or items, the currency changes at once', (
    tester,
  ) async {
    final app = await openRegional(tester);
    expect(find.text('India'), findsOneWidget, reason: 'country is read-only');
    expect(
      find.text('Set when you signed up. Contact support to change it.'),
      findsOneWidget,
    );
    await pickCurrency(app, 'UAE dirham (AED)');
    expect(find.byType(AlertDialog), findsNothing);
    expect(app.restaurant.updates.single, {'currency': 'AED'});
  });

  testWidgets('after the first publish the FR-103 warning must be confirmed', (
    tester,
  ) async {
    final app = await openRegional(
      tester,
      extra: {
        'publishedVersion': 2,
        'counts': {'categories': 1, 'items': 4},
      },
    );
    await pickCurrency(app, 'Kuwaiti dinar (KWD)');
    expect(find.text('Switch to KWD?'), findsOneWidget);
    expect(
      find.textContaining(
        'Prices are not converted. A price of 100 INR becomes 100 KWD.',
      ),
      findsOneWidget,
    );
    expect(
      find.textContaining('review every price before the next publish'),
      findsOneWidget,
    );

    // Cancel: nothing changes and the dropdown shows INR again.
    await app.tap(find.text('Cancel'));
    expect(app.restaurant.updates, isEmpty);
    expect(find.text('Indian rupee (INR)'), findsOneWidget);

    await pickCurrency(app, 'Kuwaiti dinar (KWD)');
    await app.tap(find.text('Change currency'));
    expect(app.restaurant.updates.single, {'currency': 'KWD'});
  });

  testWidgets('a draft with priced items gets a lighter warning', (
    tester,
  ) async {
    final app = await openRegional(
      tester,
      extra: {
        'counts': {'categories': 1, 'items': 3},
      },
    );
    await pickCurrency(app, 'US dollar (USD)');
    expect(
      find.textContaining('Check your item prices after the change.'),
      findsOneWidget,
    );
    await app.tap(find.text('Change currency'));
    expect(app.restaurant.updates.single, {'currency': 'USD'});
  });

  testWidgets('pricesNeedReview shows a banner (set by onRestaurantUpdated)', (
    tester,
  ) async {
    await openRegional(
      tester,
      extra: {'publishedVersion': 1, 'pricesNeedReview': true},
    );
    expect(find.byKey(RegionalKeys.pricesBanner), findsOneWidget);
  });

  for (final width in [360.0, 768.0, 1280.0]) {
    testWidgets('time zone picker with search at ${width.toInt()} px', (
      tester,
    ) async {
      final app = await openRegional(
        tester,
        width: width,
        extra: {
          'country': 'US',
          'currency': 'USD',
          'timezone': 'America/New_York',
        },
      );
      expect(find.text('America/New_York'), findsOneWidget);
      await app.tap(find.byKey(RegionalKeys.timezone));
      expect(find.text('Suggested for your country'), findsOneWidget);
      expect(
        find.text('America/Chicago'),
        findsOneWidget,
        reason: 'US zones are suggested first',
      );

      await tester.enterText(
        find.byKey(RegionalKeys.timezoneSearch),
        'los ang',
      );
      await tester.pumpAndSettle();
      expect(find.text('America/Chicago'), findsNothing);
      await app.tap(find.text('America/Los_Angeles'));
      expect(app.restaurant.updates.single, {
        'timezone': 'America/Los_Angeles',
      });
      expect(tester.takeException(), isNull);
    });
  }

  test('utcOffsetLabel', () {
    expect(
      utcOffsetLabel('Asia/Kolkata', now: DateTime.utc(2026, 1, 1)),
      'UTC+05:30',
    );
    expect(
      utcOffsetLabel('America/New_York', now: DateTime.utc(2026, 1, 1)),
      'UTC−05:00',
    );
    expect(utcOffsetLabel('Not/AZone'), '');
  });
}
