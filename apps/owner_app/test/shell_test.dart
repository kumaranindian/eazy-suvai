import 'package:core/core.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
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
      expect(find.textContaining('Layout: $layout'), findsOneWidget);
      expect(tester.takeException(), isNull);

      // Navigate to Settings and back to Home.
      await tester.tap(find.text('Settings').last);
      await tester.pumpAndSettle();
      expect(find.textContaining('Layout: $layout'), findsOneWidget);
      expect(find.widgetWithText(AppBar, 'Settings'), findsOneWidget);

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
      (Routes.home, 'Home'),
    ]) {
      await app.go(path);
      expect(find.widgetWithText(AppBar, title), findsOneWidget, reason: path);
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
