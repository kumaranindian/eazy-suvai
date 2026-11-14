import 'package:core/core.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:admin_app/app.dart';
import 'package:admin_app/router/app_router.dart';

import 'package:admin_app/features/shell/presentation/admin_shell.dart';

import 'helpers.dart';

Future<void> pumpApp(WidgetTester tester, double width) => pumpAdminApp(
  tester,
  width: width,
  signedIn: adminUser(totp: true),
  secondFactor: 'totp',
);

void main() {
  const cases = [
    (360.0, ResponsiveScaffold.bottomBarKey, 'compact'),
    (768.0, ResponsiveScaffold.railKey, 'medium'),
    (1280.0, ResponsiveScaffold.sideMenuKey, 'expanded'),
  ];

  for (final (width, navKey, layout) in cases) {
    testWidgets('admin shell at ${width.toInt()} px', (tester) async {
      await pumpApp(tester, width);

      expect(find.byKey(navKey), findsOneWidget);
      expect(find.textContaining('Layout: $layout'), findsOneWidget);
      expect(tester.takeException(), isNull);

      // Navigate to Settings and back to Home.
      await tester.tap(find.text('Settings').last);
      await tester.pumpAndSettle();
      expect(find.textContaining('Layout: $layout'), findsOneWidget);
      expect(find.widgetWithText(AppBar, 'Settings'), findsOneWidget);

      await tester.tap(find.text('Dashboard').last);
      await tester.pumpAndSettle();
      expect(find.widgetWithText(AppBar, 'Dashboard'), findsOneWidget);
    });
  }

  testWidgets('every shell route renders', (tester) async {
    await pumpApp(tester, 1280);
    final container = ProviderScope.containerOf(
      tester.element(find.byType(AdminApp)),
    );
    final router = container.read(appRouterProvider);
    for (final (path, title) in const [
      (Routes.restaurants, 'Restaurants'),
      (Routes.plans, 'Plans'),
      (Routes.settings, 'Settings'),
      (Routes.dashboard, 'Dashboard'),
    ]) {
      router.go(path);
      await tester.pumpAndSettle();
      expect(find.widgetWithText(AppBar, title), findsOneWidget, reason: path);
    }
    // A signed-in admin who opens /sign-in is sent to the dashboard.
    router.go(Routes.signIn);
    await tester.pumpAndSettle();
    expect(find.widgetWithText(AppBar, 'Dashboard'), findsOneWidget);
  });

  testWidgets('sign out returns to sign-in', (tester) async {
    await pumpApp(tester, 768);
    await tester.tap(find.byKey(AdminShell.signOutKey));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('admin.email')), findsOneWidget);
  });

  testWidgets('unknown route shows not found', (tester) async {
    await pumpApp(tester, 360);
    final container = ProviderScope.containerOf(
      tester.element(find.byType(AdminApp)),
    );
    container.read(appRouterProvider).go('/does-not-exist');
    await tester.pumpAndSettle();
    expect(find.text('Page not found'), findsOneWidget);
    await tester.tap(find.text('Go to dashboard'));
    await tester.pumpAndSettle();
    expect(find.widgetWithText(AppBar, 'Dashboard'), findsOneWidget);
  });
}
