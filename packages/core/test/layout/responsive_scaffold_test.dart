import 'package:core/core.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../test_app.dart';

void main() {
  test('Breakpoint.fromWidth boundaries', () {
    expect(Breakpoint.fromWidth(360), Breakpoint.compact);
    expect(Breakpoint.fromWidth(599), Breakpoint.compact);
    expect(Breakpoint.fromWidth(599.9), Breakpoint.compact);
    expect(Breakpoint.fromWidth(600), Breakpoint.medium);
    expect(Breakpoint.fromWidth(1023), Breakpoint.medium);
    expect(Breakpoint.fromWidth(1024), Breakpoint.expanded);
    expect(Breakpoint.fromWidth(1280), Breakpoint.expanded);
  });

  Widget shell({
    ValueChanged<int>? onSelected,
    int selected = 0,
    bool showAppBar = true,
    Widget? banner,
  }) => testApp(
    ResponsiveScaffold(
      title: 'Title',
      showAppBar: showAppBar,
      banner: banner,
      selectedIndex: selected,
      onDestinationSelected: onSelected ?? (_) {},
      destinations: const [
        AppDestination(icon: Icons.home_outlined, label: 'Home'),
        AppDestination(icon: Icons.menu_book_outlined, label: 'Menu'),
        AppDestination(icon: Icons.settings_outlined, label: 'Settings'),
      ],
      body: const Text('Body'),
    ),
  );

  Future<void> pumpAt(WidgetTester tester, double width, Widget w) async {
    await setSurfaceWidth(tester, width);
    await tester.pumpWidget(w);
  }

  void expectNav(Key visible) {
    for (final key in const [
      ResponsiveScaffold.bottomBarKey,
      ResponsiveScaffold.railKey,
      ResponsiveScaffold.sideMenuKey,
    ]) {
      expect(find.byKey(key), key == visible ? findsOneWidget : findsNothing);
    }
    expect(find.text('Body'), findsOneWidget);
  }

  const cases = [
    (360.0, ResponsiveScaffold.bottomBarKey),
    (599.0, ResponsiveScaffold.bottomBarKey),
    (600.0, ResponsiveScaffold.railKey),
    (768.0, ResponsiveScaffold.railKey),
    (1023.0, ResponsiveScaffold.railKey),
    (1024.0, ResponsiveScaffold.sideMenuKey),
    (1280.0, ResponsiveScaffold.sideMenuKey),
  ];
  for (final (width, key) in cases) {
    testWidgets('at ${width.toInt()} px shows $key', (tester) async {
      await pumpAt(tester, width, shell());
      expectNav(key);
      expect(tester.takeException(), isNull);
    });
  }

  for (final width in [360.0, 768.0, 1280.0]) {
    testWidgets('selecting a destination at ${width.toInt()} px', (
      tester,
    ) async {
      int? tapped;
      await pumpAt(tester, width, shell(onSelected: (i) => tapped = i));
      await tester.tap(find.text('Settings'));
      expect(tapped, 2);
    });
  }

  testWidgets('side menu is 240 px and content is capped at 1200 px', (
    tester,
  ) async {
    await pumpAt(tester, 1800, shell());
    expect(
      tester.getSize(find.byKey(ResponsiveScaffold.sideMenuKey)).width,
      240,
    );
    final body = find.ancestor(
      of: find.text('Body'),
      matching: find.byType(ConstrainedBox),
    );
    expect(tester.getSize(body.first).width, lessThanOrEqualTo(1200));
  });

  for (final width in [360.0, 768.0, 1280.0]) {
    testWidgets('showAppBar: false hides the app bar at ${width.toInt()} px', (
      tester,
    ) async {
      await pumpAt(tester, width, shell(showAppBar: false));
      expect(find.byType(AppBar), findsNothing);
      expect(find.text('Body'), findsOneWidget);
      await pumpAt(tester, width, shell());
      expect(find.widgetWithText(AppBar, 'Title'), findsOneWidget);
    });
  }

  testWidgets('desktop portal header: brand segment over the side menu', (
    tester,
  ) async {
    await setSurfaceWidth(tester, 1280);
    await tester.pumpWidget(
      testApp(
        ResponsiveScaffold(
          title: 'Title',
          selectedIndex: 0,
          onDestinationSelected: (_) {},
          sideMenuHeader: const Text('Brand'),
          destinations: const [
            AppDestination(icon: Icons.home_outlined, label: 'Home'),
            AppDestination(icon: Icons.settings_outlined, label: 'Settings'),
          ],
          body: const Text('Body'),
        ),
      ),
    );
    final header = tester.getRect(find.byKey(ResponsiveScaffold.headerKey));
    final brand = tester.getRect(find.byKey(ResponsiveScaffold.headerBrandKey));
    final menu = tester.getRect(find.byKey(ResponsiveScaffold.sideMenuKey));
    final appBar = tester.getRect(find.byType(AppBar));
    expect(header.width, 1280);
    expect(header.height, ResponsiveScaffold.headerHeight);
    // The brand segment lines up with the side menu, directly above it.
    expect(brand.left, menu.left);
    expect(brand.width, menu.width);
    expect(brand.bottom, lessThanOrEqualTo(menu.top));
    expect(
      find.descendant(
        of: find.byKey(ResponsiveScaffold.headerBrandKey),
        matching: find.text('Brand'),
      ),
      findsOneWidget,
    );
    // The page header sits next to it, over the content.
    expect(appBar.left, greaterThan(brand.right));
    expect(appBar.top, header.top);
    // One colour across the whole header.
    final brandColor = tester
        .widget<Material>(find.byKey(ResponsiveScaffold.headerBrandKey))
        .color;
    expect(
      tester.widget<AppBar>(find.byType(AppBar)).backgroundColor,
      brandColor,
    );
    expect(find.widgetWithText(AppBar, 'Title'), findsOneWidget);
  });

  testWidgets('desktop header stays when the page brings its own app bar', (
    tester,
  ) async {
    await pumpAt(tester, 1280, shell(showAppBar: false));
    expect(find.byKey(ResponsiveScaffold.headerKey), findsOneWidget);
    expect(find.byKey(ResponsiveScaffold.headerBrandKey), findsOneWidget);
  });

  testWidgets('works right-to-left', (tester) async {
    await setSurfaceWidth(tester, 1280);
    await tester.pumpWidget(
      testApp(
        const Directionality(
          textDirection: TextDirection.rtl,
          child: _RtlShell(),
        ),
      ),
    );
    final menu = tester.getRect(find.byKey(ResponsiveScaffold.sideMenuKey));
    expect(
      menu.right,
      1280,
      reason: 'side menu sits on the start (right) side',
    );
  });

  for (final width in const [360.0, 768.0, 1280.0]) {
    testWidgets('banner at ${width.toInt()} px (M06 publish bar)', (
      tester,
    ) async {
      await pumpAt(
        tester,
        width,
        shell(banner: const SizedBox(height: 56, child: Text('Banner'))),
      );
      final banner = tester.getRect(find.byKey(ResponsiveScaffold.bannerKey));
      final body = tester.getRect(find.text('Body'));
      if (width < 600) {
        final nav = tester.getRect(find.byKey(ResponsiveScaffold.bottomBarKey));
        expect(banner.bottom, nav.top, reason: 'just above the navigation bar');
        expect(banner.width, width);
      } else {
        expect(
          banner.bottom,
          lessThanOrEqualTo(body.top),
          reason: 'top of the content',
        );
        expect(banner.left, greaterThan(0), reason: 'beside the navigation');
      }
    });
  }

  testWidgets('no banner, no banner slot', (tester) async {
    await pumpAt(tester, 360, shell());
    expect(find.byKey(ResponsiveScaffold.bannerKey), findsNothing);
  });
}

class _RtlShell extends StatelessWidget {
  const _RtlShell();

  @override
  Widget build(BuildContext context) => ResponsiveScaffold(
    title: 'Title',
    selectedIndex: 0,
    onDestinationSelected: (_) {},
    destinations: const [
      AppDestination(icon: Icons.home_outlined, label: 'Home'),
      AppDestination(icon: Icons.settings_outlined, label: 'Settings'),
    ],
    body: const Text('Body'),
  );
}
