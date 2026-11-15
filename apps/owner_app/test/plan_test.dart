// M10: plan page, banners, over-limit manager and plan gates
// (FR-076 to FR-083, FR-100, FR-101, FR-106).
import 'package:core/core.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:owner_app/features/plan/presentation/hidden_content_page.dart';
import 'package:owner_app/features/plan/presentation/plan_page.dart';
import 'package:owner_app/features/plan/presentation/subscription_banner.dart';
import 'package:owner_app/router/app_router.dart';

import 'fake_menu.dart';
import 'fake_plan.dart';
import 'helpers.dart';

Future<(TestApp, FakePlanRepository)> openPlan(
  WidgetTester tester, {
  double width = 360,
  Map<String, dynamic> extra = const {},
  FakeMenuRepository? menu,
  String route = Routes.plan,
}) async {
  final restaurants = FakeRestaurantRepository(restaurantData(extra));
  final plans = FakePlanRepository(restaurants: restaurants);
  final app = await pumpOwnerApp(
    tester,
    width: width,
    signedIn: verifiedOwner(),
    restaurant: restaurants,
    plans: plans,
    menu: menu,
  );
  await app.go(route);
  return (app, plans);
}

/// 52 items in two categories; the last two hidden after a downgrade.
FakeMenuRepository overLimitMenu() => FakeMenuRepository(
  categories: [
    const MenuCategory(id: 'c1', name: 'Starters', sequence: 1000),
    const MenuCategory(id: 'c2', name: 'Mains', sequence: 2000),
  ],
  items: [
    for (var i = 0; i < 52; i++)
      MenuItem(
        id: 'i$i',
        categoryId: i < 26 ? 'c1' : 'c2',
        name: 'Dish $i',
        priceMinor: 1000,
        dietaryLabelId: 'vegetarian',
        sequence: (i + 1) * 1000,
        hiddenOverLimit: i >= 50,
      ),
  ],
);

/// Scrolls [finder] to the upper part of the view (clear of the bottom
/// navigation bar) and taps it.
Future<void> tapIt(WidgetTester tester, Finder finder) async {
  await Scrollable.ensureVisible(tester.element(finder), alignment: 0.2);
  await tester.pumpAndSettle();
  await tester.tap(finder);
  await tester.pumpAndSettle();
}

void main() {
  for (final width in [360.0, 768.0, 1280.0]) {
    testWidgets(
      'Free plan: usage, comparison and request at ${width.toInt()} px',
      (tester) async {
        final (_, plans) = await openPlan(
          tester,
          width: width,
          extra: {
            'counts': {'categories': 3, 'items': 42},
          },
        );
        expect(tester.takeException(), isNull);
        expect(find.text('Free · never expires'), findsOneWidget);
        expect(find.text('Items: 42 of 50'), findsOneWidget);
        expect(find.text('Categories: 3 of 10'), findsOneWidget);
        expect(find.byKey(PlanKeys.planCard('free')), findsOneWidget);
        expect(find.byKey(PlanKeys.planCard('pro')), findsOneWidget);
        expect(find.text('Up to 500 items'), findsOneWidget);
        expect(find.text('Unlimited categories'), findsOneWidget);
        expect(find.text('365 days of analytics history'), findsOneWidget);
        // Comparison beside the current plan only on wide screens.
        final current = tester.getRect(find.byKey(PlanKeys.current));
        final compare = tester.getRect(find.byKey(PlanKeys.compare));
        expect(compare.left > current.right, width >= 1024);

        await tapIt(tester, find.byKey(PlanKeys.request('pro')));
        await tester.tap(find.byKey(PlanKeys.billingMonthly));
        await tester.pumpAndSettle();
        await tester.tap(find.byKey(PlanKeys.send));
        await tester.pumpAndSettle();
        expect(plans.requests, [('pro', 'monthly')]);
        expect(find.byKey(PlanKeys.pending), findsOneWidget);
        // One open request at a time (FR-106).
        final button = tester.widget<FilledButton>(
          find.descendant(
            of: find.byKey(PlanKeys.request('pro')),
            matching: find.byWidgetPredicate((w) => w is FilledButton),
          ),
        );
        expect(button.onPressed, isNull);
      },
    );
  }

  testWidgets('Pro shows the expiry and a reminder 14 days before (FR-100)', (
    tester,
  ) async {
    await openPlan(
      tester,
      width: 1280,
      extra: proData(expiresAt: DateTime.utc(2026, 11, 22)),
    );
    expect(find.text('Pro · paid until Nov 22, 2026'), findsOneWidget);
    expect(find.byKey(SubscriptionBannerKeys.expiring), findsOneWidget);
    expect(find.textContaining('Pro ends in 7 days'), findsOneWidget);
    expect(find.byKey(PlanKeys.request('pro')), findsNothing);
    expect(find.byKey(PlanKeys.switchToFree), findsOneWidget);
  });

  testWidgets('grace shows a renewal banner on the dashboard (FR-100)', (
    tester,
  ) async {
    await openPlan(
      tester,
      route: Routes.home,
      extra: proData(
        expiresAt: DateTime.utc(2026, 11, 10),
        graceEndsAt: DateTime.utc(2026, 11, 24),
      ),
    );
    expect(find.byKey(SubscriptionBannerKeys.grace), findsOneWidget);
    expect(find.textContaining('Renew before Nov 24, 2026'), findsOneWidget);
    await tester.tap(find.text('Renew'));
    await tester.pumpAndSettle();
    expect(find.textContaining('expired on Nov 10, 2026'), findsOneWidget);
  });

  testWidgets('after a downgrade: banner, then swap hidden items (FR-101)', (
    tester,
  ) async {
    final (app, plans) = await openPlan(
      tester,
      route: Routes.home,
      menu: overLimitMenu(),
      extra: {
        'counts': {'categories': 2, 'items': 52},
        'planNotice': {
          'kind': 'limitsApplied',
          'hiddenItems': 2,
          'hiddenCategories': 0,
        },
      },
    );
    expect(find.byKey(SubscriptionBannerKeys.overLimit), findsOneWidget);
    await tester.tap(find.text('Manage'));
    await tester.pumpAndSettle();
    expect(app.location, Routes.planHidden);
    expect(find.text('Visible (50 of 50)'), findsOneWidget);
    // Showing a hidden item without hiding another is over the limit.
    await tester.scrollUntilVisible(find.byKey(HiddenKeys.toggle('i51')), 300);
    await tapIt(tester, find.byKey(HiddenKeys.toggle('i51')));
    expect(find.byKey(HiddenKeys.over), findsOneWidget);
    await tester.scrollUntilVisible(find.byKey(HiddenKeys.toggle('i0')), -300);
    await tapIt(tester, find.byKey(HiddenKeys.toggle('i0')));
    expect(find.byKey(HiddenKeys.over), findsNothing);
    await tester.scrollUntilVisible(find.byKey(HiddenKeys.save), 600);
    await tapIt(tester, find.byKey(HiddenKeys.save));
    expect(plans.hides.single, {
      'hideItemIds': ['i0'],
      'showItemIds': ['i51'],
      'hideCategoryIds': <String>[],
      'showCategoryIds': <String>[],
      'downgrade': false,
    });
    expect(app.location, Routes.plan);
  });

  testWidgets('the over-limit manager shows two lists on desktop', (
    tester,
  ) async {
    await openPlan(
      tester,
      width: 1280,
      route: Routes.planHidden,
      menu: overLimitMenu(),
      extra: {
        'counts': {'categories': 2, 'items': 52},
      },
    );
    expect(find.byKey(HiddenKeys.visibleList), findsOneWidget);
    expect(find.byKey(HiddenKeys.hiddenList), findsOneWidget);
    expect(find.text('Hidden (2)'), findsOneWidget);
    expect(
      find.descendant(
        of: find.byKey(HiddenKeys.hiddenList),
        matching: find.text('Dish 51'),
      ),
      findsOneWidget,
    );
  });

  testWidgets('Pro owners can switch to Free choosing what to hide', (
    tester,
  ) async {
    final (app, plans) = await openPlan(
      tester,
      width: 768,
      menu: overLimitMenu(),
      extra: proData(
        extra: {
          'counts': {'categories': 2, 'items': 52},
        },
      ),
    );
    await tester.tap(find.byKey(PlanKeys.switchToFree));
    await tester.pumpAndSettle();
    expect(find.textContaining('Free shows up to 50 items'), findsOneWidget);
    await tester.scrollUntilVisible(find.byKey(HiddenKeys.save), 600);
    await tapIt(tester, find.byKey(HiddenKeys.save));
    expect(find.text('Switch to Free?'), findsOneWidget);
    await tester.tap(find.text('Switch to Free now').last);
    await tester.pumpAndSettle();
    expect(plans.hides.single['downgrade'], isTrue);
    expect(app.location, Routes.plan);
    expect(find.text('Free · never expires'), findsOneWidget);
  });

  testWidgets('premium themes are locked on Free (BR-011)', (tester) async {
    final app = await pumpOwnerApp(
      tester,
      width: 1280,
      signedIn: verifiedOwner(),
    );
    await app.go(Routes.theme);
    await tester.tap(find.text('Midnight'));
    await tester.pumpAndSettle();
    expect(find.text('Premium theme'), findsOneWidget);
    await tester.tap(find.text('See plans'));
    await tester.pumpAndSettle();
    expect(app.location, Routes.plan);
    expect(
      app.restaurant.updates.where((u) => u.containsKey('themeId')),
      isEmpty,
    );
  });
}
