import 'package:core/core.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:admin_app/app.dart';
import 'package:admin_app/router/app_router.dart';

Future<void> pumpApp(WidgetTester tester, double width) async {
  tester.view.devicePixelRatio = 1;
  tester.view.physicalSize = Size(width, 900);
  addTearDown(tester.view.reset);
  await tester.pumpWidget(const ProviderScope(child: AdminApp()));
  await tester.pumpAndSettle();
}

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
    router.go(Routes.signIn);
    await tester.pumpAndSettle();
    expect(find.widgetWithText(AppBar, 'Sign in'), findsOneWidget);
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
