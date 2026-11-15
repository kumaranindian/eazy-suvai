// M13: every owner screen at 360, 768 and 1280 px, at 200 % text, in a
// right-to-left layout, and against Flutter's accessibility guidelines
// (tap targets, labels, text contrast). An overflow or any other layout
// error fails the test.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:owner_app/app.dart';
import 'package:owner_app/router/app_router.dart';

import 'fake_analytics.dart';
import 'fake_menu.dart';
import 'fake_plan.dart';
import 'helpers.dart';
import 'analytics_test.dart' show sampleDays;

/// Every route a signed-in owner can open (account screens redirect).
final ownerRoutes = <String>[
  Routes.home,
  Routes.menu,
  Routes.menuCategory('c1'),
  Routes.menuItem('i1'),
  Routes.menuNewItem('c1'),
  Routes.menuDeleted,
  Routes.share,
  Routes.analytics,
  Routes.settings,
  Routes.profile,
  Routes.hours,
  Routes.regional,
  Routes.menuLink,
  Routes.theme,
  Routes.themeEditor,
  Routes.plan,
  Routes.planHidden,
  Routes.account,
  Routes.deleteAccount,
  Routes.preview,
  Routes.versions,
];

Future<TestApp> pumpFull(
  WidgetTester tester, {
  required double width,
  TextDirection? direction,
}) => pumpOwnerApp(
  tester,
  width: width,
  signedIn: verifiedOwner(),
  restaurant: FakeRestaurantRepository(
    restaurantData({
      ...proData(),
      'publishedVersion': 1,
      'counts': {'categories': 2, 'items': 3},
      'description':
          'South Indian classics, biryani and filter coffee since 1998.',
    }),
  ),
  menu: sampleMenu(),
  analytics: FakeAnalyticsRepository(sampleDays()),
  overrides: [
    if (direction != null)
      textDirectionOverrideProvider.overrideWithValue(direction),
  ],
);

Future<void> visitAll(WidgetTester tester, TestApp app, String label) async {
  final failures = <String>[];
  for (final route in ownerRoutes) {
    await app.go(route);
    final e = tester.takeException();
    if (e != null) failures.add('$route: $e');
  }
  expect(failures, isEmpty, reason: label);
}

void main() {
  for (final width in [360.0, 768.0, 1280.0]) {
    testWidgets('every owner screen renders at ${width.toInt()} px', (
      tester,
    ) async {
      final app = await pumpFull(tester, width: width);
      await visitAll(tester, app, '${width.toInt()} px');
    });

    testWidgets('every owner screen at 200 % text, ${width.toInt()} px', (
      tester,
    ) async {
      tester.platformDispatcher.textScaleFactorTestValue = 2.0;
      addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
      final app = await pumpFull(tester, width: width);
      await visitAll(tester, app, '200% ${width.toInt()} px');
    });

    testWidgets('every owner screen right to left, ${width.toInt()} px', (
      tester,
    ) async {
      final app = await pumpFull(
        tester,
        width: width,
        direction: TextDirection.rtl,
      );
      await visitAll(tester, app, 'RTL ${width.toInt()} px');
      expect(
        Directionality.of(tester.element(find.byType(Scaffold).first)),
        TextDirection.rtl,
      );
    });
  }

  for (final width in [360.0, 1280.0]) {
    testWidgets(
      'accessibility guidelines on every owner screen at ${width.toInt()} px',
      (tester) async {
        final handle = tester.ensureSemantics();
        final app = await pumpFull(tester, width: width);
        for (final route in ownerRoutes) {
          await app.go(route);
          await expectLater(
            tester,
            meetsGuideline(labeledTapTargetGuideline),
            reason: route,
          );
          await expectLater(
            tester,
            meetsGuideline(androidTapTargetGuideline),
            reason: route,
          );
          await expectLater(
            tester,
            meetsGuideline(textContrastGuideline),
            reason: route,
          );
        }
        handle.dispose();
      },
    );
  }
}
