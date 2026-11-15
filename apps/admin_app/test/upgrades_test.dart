// M10: admin upgrade-request queue and the record-payment form
// (FR-106, §5.5, AC-030).
import 'package:admin_app/features/subscriptions/presentation/upgrade_requests_page.dart';
import 'package:admin_app/router/app_router.dart';
import 'package:admin_app/widgets/read_only.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'fake_admin_api.dart';
import 'helpers.dart';

FakeAdminApi upgradesApi() {
  var pending = true;
  return FakeAdminApi({
    'adminListUpgradeRequests': (d) => {
      'requests': d['status'] == 'pending' && pending
          ? [
              {
                'id': 'req1',
                'restaurantId': 'rest_1',
                'restaurantName': 'Spice Garden',
                'ownerEmail': 'owner@example.com',
                'ownerMobile': '+919876543210',
                'currency': 'INR',
                'currentPlanId': 'free',
                'requestedPlanId': 'pro',
                'billing': 'annual',
                'status': 'pending',
                'createdAt': '2026-11-14T10:00:00.000Z',
              },
            ]
          : <Object>[],
    },
    'recordPaymentAndActivate': (d) {
      pending = false;
      return {'paymentId': 'pay1', 'restored': 0};
    },
    'closeUpgradeRequest': (d) {
      pending = false;
      return {'ok': true};
    },
  });
}

Future<AdminTestApp> openUpgrades(
  WidgetTester tester,
  FakeAdminApi api, {
  double width = 1280,
}) async {
  final app = await pumpAdminApp(
    tester,
    width: width,
    signedIn: adminUser(totp: true),
    secondFactor: 'totp',
    api: api,
  );
  await app.go(Routes.upgrades);
  return app;
}

void main() {
  for (final width in [768.0, 1280.0]) {
    testWidgets('lists pending requests in a table at ${width.toInt()} px', (
      tester,
    ) async {
      await openUpgrades(tester, upgradesApi(), width: width);
      expect(tester.takeException(), isNull);
      expect(find.byKey(UpgradeKeys.table), findsOneWidget);
      expect(find.text('Spice Garden'), findsOneWidget);
      expect(find.text('free → pro'), findsOneWidget);
      expect(find.byKey(UpgradeKeys.record('req1')), findsOneWidget);
      expect(find.byKey(ReadOnlyNotice.noticeKey), findsNothing);
    });
  }

  testWidgets('is read-only below 600 px', (tester) async {
    await openUpgrades(tester, upgradesApi(), width: 360);
    expect(find.byKey(ReadOnlyNotice.noticeKey), findsOneWidget);
    expect(find.text('Spice Garden'), findsOneWidget);
    expect(find.byKey(UpgradeKeys.record('req1')), findsNothing);
  });

  testWidgets('records an offline payment with dates by billing', (
    tester,
  ) async {
    final api = upgradesApi();
    final app = await openUpgrades(tester, api);
    await app.tap(find.byKey(UpgradeKeys.record('req1')));
    expect(find.text('Record payment – Spice Garden'), findsOneWidget);
    // Amount and reference are required.
    await app.tap(find.byKey(UpgradeKeys.submit));
    expect(find.text('Enter the amount received.'), findsOneWidget);
    expect(api.callsTo('recordPaymentAndActivate'), isEmpty);
    await tester.enterText(find.byKey(UpgradeKeys.amount), '9999');
    await tester.enterText(find.byKey(UpgradeKeys.reference), 'NEFT-123');
    await app.tap(find.byKey(UpgradeKeys.submit));
    final call = api.callsTo('recordPaymentAndActivate').single;
    expect(call['restaurantId'], 'rest_1');
    expect(call['planId'], 'pro');
    expect(call['billing'], 'annual');
    expect(call['amountMinor'], 999900);
    expect(call['currency'], 'INR');
    expect(call['method'], 'bank-transfer');
    expect(call['reference'], 'NEFT-123');
    expect(call['requestId'], 'req1');
    final start = DateTime.parse('${call['startAt']}');
    final end = DateTime.parse('${call['endAt']}');
    expect(end.year - start.year, 1);
    expect(find.textContaining('Payment recorded'), findsOneWidget);
    expect(find.byKey(UpgradeKeys.empty), findsOneWidget);
  });

  testWidgets('declines a request with a reason', (tester) async {
    final api = upgradesApi();
    final app = await openUpgrades(tester, api);
    await app.tap(find.byKey(UpgradeKeys.decline('req1')));
    final submit = tester.widget<FilledButton>(
      find.byKey(UpgradeKeys.declineSubmit),
    );
    expect(submit.onPressed, isNull);
    await tester.enterText(
      find.byKey(UpgradeKeys.reason),
      'Owner asked to wait',
    );
    await tester.pump();
    await app.tap(find.byKey(UpgradeKeys.declineSubmit));
    expect(api.callsTo('closeUpgradeRequest').single, {
      'requestId': 'req1',
      'reason': 'Owner asked to wait',
    });
    expect(find.text('Request declined.'), findsOneWidget);
  });
}
