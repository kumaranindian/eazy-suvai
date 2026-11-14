import 'package:core/core.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:owner_app/features/home/presentation/dashboard_page.dart';
import 'package:owner_app/features/menu/presentation/menu_actions.dart';
import 'package:owner_app/features/shell/presentation/owner_shell.dart';
import 'package:owner_app/router/app_router.dart';

import 'helpers.dart';

void main() {
  const cases = [
    (360.0, ResponsiveScaffold.bottomBarKey, 'compact'),
    (768.0, ResponsiveScaffold.railKey, 'medium'),
    (1280.0, ResponsiveScaffold.sideMenuKey, 'expanded'),
  ];

  for (final (width, navKey, layout) in cases) {
    testWidgets('owner shell at ${width.toInt()} px', (tester) async {
      await pumpOwnerApp(tester, width: width, signedIn: verifiedOwner());

      expect(find.byKey(navKey), findsOneWidget);
      // M03: Home is the dashboard.
      expect(find.byKey(DashboardKeys.checklist), findsOneWidget);
      expect(tester.takeException(), isNull);

      // M04: the menu manager, one, two or three panes by width.
      await tester.tap(find.text('Menu').last);
      await tester.pumpAndSettle();
      expect(find.byKey(MenuKeys.categoryPane), findsOneWidget);
      expect(
        find.byKey(MenuKeys.itemPane),
        layout == 'compact' ? findsNothing : findsOneWidget,
      );
      expect(
        find.byKey(MenuKeys.editorPane),
        layout == 'expanded' ? findsOneWidget : findsNothing,
      );
      expect(tester.takeException(), isNull);

      // Settings lists the M03 pages.
      await tester.tap(find.text('Settings').last);
      await tester.pumpAndSettle();
      expect(find.widgetWithText(AppBar, 'Settings'), findsOneWidget);
      expect(find.text('Restaurant profile'), findsOneWidget);
      expect(find.text('Menu link'), findsOneWidget);

      await tester.tap(find.text('Home').last);
      await tester.pumpAndSettle();
      expect(find.widgetWithText(AppBar, 'Home'), findsOneWidget);
    });
  }

  testWidgets('every shell route renders', (tester) async {
    final app = await pumpOwnerApp(
      tester,
      width: 1280,
      signedIn: verifiedOwner(),
    );
    for (final (path, title) in const [
      (Routes.menu, 'Menu'),
      (Routes.share, 'QR & share'),
      (Routes.settings, 'Settings'),
      (Routes.profile, 'Restaurant profile'),
      (Routes.hours, 'Opening hours'),
      (Routes.regional, 'Currency and time zone'),
      (Routes.menuLink, 'Menu link'),
      (Routes.menuDeleted, 'Recently deleted'),
      (Routes.plan, 'Plans'),
      (Routes.home, 'Home'),
    ]) {
      await app.go(path);
      expect(find.widgetWithText(AppBar, title), findsOneWidget, reason: path);
      // Detail pages bring their own app bar instead of the shell's.
      expect(find.byType(AppBar), findsOneWidget, reason: path);
    }
    // A signed-in owner who opens /sign-in is sent home.
    await app.go(Routes.signIn);
    expect(app.location, Routes.home);
  });

  testWidgets('unknown route shows not found', (tester) async {
    final app = await pumpOwnerApp(tester, signedIn: verifiedOwner());
    await app.go('/does-not-exist');
    expect(find.text('Page not found'), findsOneWidget);
    await tester.tap(find.text('Go to home'));
    await tester.pumpAndSettle();
    expect(find.widgetWithText(AppBar, 'Home'), findsOneWidget);
  });

  testWidgets('sign out returns to sign-in (FR-005)', (tester) async {
    final app = await pumpOwnerApp(tester, signedIn: verifiedOwner());
    expect(find.byTooltip('Sign out'), findsOneWidget);
    await tester.tap(find.byKey(OwnerShell.signOutKey));
    await tester.pumpAndSettle();
    expect(app.auth.current, isNull);
    expect(app.location, Routes.signIn);
  });
}
