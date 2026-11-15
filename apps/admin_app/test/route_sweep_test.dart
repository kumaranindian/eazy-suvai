// M13: every admin screen at 768 and 1280 px (full) and at 360 px
// (read-only), at 200 % text, right to left, and against Flutter's
// accessibility guidelines. Any layout error fails the test.
import 'package:admin_app/router/app_router.dart';
import 'package:flutter_test/flutter_test.dart';

import 'audit_test.dart' show auditApi;
import 'helpers.dart';

final adminRoutes = <String>[
  Routes.dashboard,
  Routes.restaurants,
  Routes.restaurant('r1'),
  Routes.upgrades,
  Routes.plans,
  Routes.catalog,
  Routes.audit,
  Routes.settings,
];

Future<AdminTestApp> pumpSweep(WidgetTester tester, double width) =>
    pumpAdminApp(
      tester,
      width: width,
      signedIn: adminUser(totp: true),
      secondFactor: 'totp',
      api: auditApi(),
    );

Future<void> visitAll(
  WidgetTester tester,
  AdminTestApp app,
  String label,
) async {
  final failures = <String>[];
  for (final route in adminRoutes) {
    await app.go(route);
    final e = tester.takeException();
    if (e != null) failures.add('$route: $e');
  }
  expect(failures, isEmpty, reason: label);
}

void main() {
  for (final width in [360.0, 768.0, 1280.0]) {
    testWidgets('every admin screen renders at ${width.toInt()} px', (
      tester,
    ) async {
      await visitAll(tester, await pumpSweep(tester, width), '$width');
    });

    testWidgets('every admin screen at 200 % text, ${width.toInt()} px', (
      tester,
    ) async {
      tester.platformDispatcher.textScaleFactorTestValue = 2.0;
      addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
      await visitAll(tester, await pumpSweep(tester, width), '200% $width');
    });
  }

  testWidgets('every admin screen right to left at 1280 px', (tester) async {
    final app = await pumpSweep(tester, 1280);
    final failures = <String>[];
    for (final route in adminRoutes) {
      app.router.go(route);
      await tester.pumpAndSettle();
      if (tester.takeException() case final e?) failures.add('$route: $e');
    }
    expect(failures, isEmpty);
  });

  for (final width in [360.0, 1280.0]) {
    testWidgets('accessibility guidelines at ${width.toInt()} px', (
      tester,
    ) async {
      final handle = tester.ensureSemantics();
      final app = await pumpSweep(tester, width);
      for (final route in adminRoutes) {
        await app.go(route);
        await expectLater(
          tester,
          meetsGuideline(labeledTapTargetGuideline),
          reason: route,
        );
        await expectLater(
          tester,
          meetsGuideline(textContrastGuideline),
          reason: route,
        );
      }
      handle.dispose();
    });
  }
}
