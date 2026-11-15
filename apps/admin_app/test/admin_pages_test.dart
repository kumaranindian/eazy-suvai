// M11: dashboard, restaurants, detail, editors and settings in the admin app.
import 'package:admin_app/features/catalog/catalog_pages.dart';
import 'package:admin_app/features/dashboard/dashboard_page.dart';
import 'package:admin_app/features/restaurants/restaurant_detail_page.dart';
import 'package:admin_app/features/restaurants/restaurants_page.dart';
import 'package:admin_app/features/settings/settings_page.dart';
import 'package:admin_app/features/subscriptions/presentation/change_plan_dialog.dart';
import 'package:admin_app/router/app_router.dart';
import 'package:admin_app/widgets/admin_widgets.dart';
import 'package:admin_app/widgets/read_only.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'fake_admin_api.dart';
import 'helpers.dart';

Map<String, Object?> rowOf(
  String id,
  String name, {
  String status = 'active',
}) => {
  'id': id,
  'name': name,
  'slug': 'slug-$id',
  'ownerEmail': '$id@example.com',
  'ownerMobile': '+919800000000',
  'country': 'IN',
  'status': status,
  'planId': 'free',
  'subscriptionStatus': 'free',
  'items': 12,
  'createdAt': '2026-11-10T10:00:00.000Z',
};

FakeAdminApi api() => FakeAdminApi({
  'adminDashboard': (_) => {
    'stats': {
      'restaurants': 12,
      'restaurantsByStatus': {
        'active': 9,
        'suspended': 2,
        'deactivated': 1,
        'deleted': 0,
      },
      'subscriptionsByStatus': {'free': 8, 'active': 3, 'grace': 1},
      'subscriptionsExpired': 2,
      'totalItems': 340,
      'menuViews': 15230,
      'qrVisits': 9000,
      'activated': 8,
      'publishedMenus': 7,
      'qrDownloads': 21,
      'conversions': 3,
      'renewals': 1,
      'medianMinutesToFirstPublish': 18,
      'monthly': [
        {'month': '2026-11', 'views': 1200, 'qrVisits': 800},
      ],
    },
    'pendingUpgrades': 4,
    'recentSignups': [rowOf('r1', 'Spice Garden')],
  },
  'adminSearchRestaurants': (d) => d['cursor'] == null
      ? {
          'rows': [
            rowOf('r1', 'Spice Garden'),
            rowOf('r2', 'Dosa Corner', status: 'suspended'),
          ],
          'nextCursor': 'r2',
        }
      : {
          'rows': [rowOf('r3', 'Biryani House')],
          'nextCursor': null,
        },
  'adminGetRestaurant': (_) => {
    'restaurant': {
      ...rowOf('r1', 'Spice Garden'),
      'ownerName': 'Priya',
      'categories': 3,
      'publishedVersion': 4,
      'publishedAt': '2026-11-14T10:00:00.000Z',
      'currency': 'INR',
      'timezone': 'Asia/Kolkata',
      'qrCode': 'AB3K7MNP',
    },
    'subscription': {
      'status': 'active',
      'planId': 'pro',
      'billing': 'annual',
      'startAt': '2026-01-01T00:00:00.000Z',
      'expiresAt': '2027-01-01T00:00:00.000Z',
    },
    'payments': [
      {
        'id': 'p1',
        'amountMinor': 999900,
        'currency': 'INR',
        'method': 'bank-transfer',
        'reference': 'NEFT-1',
        'planId': 'pro',
        'paidAt': '2026-01-01T00:00:00.000Z',
        'periodStart': '2026-01-01T00:00:00.000Z',
        'periodEnd': '2027-01-01T00:00:00.000Z',
      },
    ],
    'history': [
      {
        'action': 'activate',
        'fromPlanId': 'free',
        'toPlanId': 'pro',
        'toStatus': 'active',
        'at': '2026-01-01T00:00:00.000Z',
      },
    ],
    'activity': [
      {
        'action': 'menu.publish',
        'actorRole': 'owner',
        'at': '2026-11-14T10:00:00.000Z',
      },
    ],
    'signIns': {'lastSignInAt': 'Sun, 15 Nov 2026 09:00:00 GMT'},
  },
  'adminListCatalog': (d) => switch (d['kind']) {
    'plans' => {
      'entries': [
        {
          'id': 'free',
          'name': 'Free',
          'isFree': true,
          'active': true,
          'sort': 0,
          'billing': <String>[],
          'prices': <String, Object>{},
          'limits': {
            'maxItems': 50,
            'maxCategories': 10,
            'maxBranches': 1,
            'premiumThemes': false,
            'defaultThemeId': 'saffron',
            'analyticsDays': 7,
            'qrLogo': false,
            'removeBranding': false,
          },
        },
        {
          'id': 'pro',
          'name': 'Pro',
          'isFree': false,
          'active': true,
          'sort': 1,
          'billing': ['monthly', 'annual'],
          'prices': <String, Object>{},
          'limits': {
            'maxItems': 500,
            'maxCategories': 10000,
            'maxBranches': 1,
            'premiumThemes': true,
            'defaultThemeId': 'saffron',
            'analyticsDays': 365,
            'qrLogo': true,
            'removeBranding': true,
          },
        },
      ],
    },
    'labels' => {
      'entries': [
        {
          'id': 'vegetarian',
          'name': 'Vegetarian',
          'icon': 'veg',
          'color': '#0F7B0F',
          'sort': 10,
          'retired': false,
        },
      ],
    },
    'tags' => {'entries': <Object>[]},
    'themes' => {
      'entries': [
        {
          'id': 'saffron',
          'name': 'Saffron',
          'premium': false,
          'sort': 10,
          'tokens': {
            'primary': '#A8550A',
            'secondary': '#3B7A20',
            'background': '#FFF8EE',
            'surface': '#FFFFFF',
            'text': '#2B2B2B',
            'font': 'Poppins',
            'layout': 'list',
            'cardLayout': 'image-left',
            'mode': 'light',
          },
        },
      ],
    },
    _ => {
      'config': {
        'graceDays': 14,
        'reservedSlugs': ['admin', 'api'],
        'fonts': ['Poppins'],
        'currencies': {'INR': 2},
        'supportEmail': 'help@eazysuvai.com',
        'announcement': null,
      },
    },
  },
  'adminListAdmins': (_) => {
    'admins': [
      {'uid': 'a1', 'email': 'admin@example.com'},
    ],
  },
});

Future<AdminTestApp> open(
  WidgetTester tester,
  FakeAdminApi api,
  String route, {
  double width = 1280,
}) async {
  final app = await pumpAdminApp(
    tester,
    width: width,
    signedIn: adminUser(totp: true),
    secondFactor: 'totp',
    api: api,
  );
  await app.go(route);
  return app;
}

void main() {
  testWidgets('dashboard shows the FR-085 counts and recent sign-ups', (
    tester,
  ) async {
    final a = api();
    final app = await open(tester, a, Routes.dashboard);
    Finder tile(String k, String v) => find.descendant(
      of: find.byKey(DashboardKeys.tile(k)),
      matching: find.text(v),
    );
    expect(tile('total', '12'), findsOneWidget);
    expect(tile('suspended', '2'), findsOneWidget);
    expect(tile('paid', '3'), findsOneWidget);
    expect(tile('grace', '1'), findsOneWidget);
    expect(tile('expired', '2'), findsOneWidget);
    expect(tile('pending', '4'), findsOneWidget);
    expect(tile('views', '15,230'), findsOneWidget);
    expect(find.text('Spice Garden'), findsOneWidget);
    await app.tap(find.byKey(DashboardKeys.tile('pending')));
    expect(app.location, Routes.upgrades);
  });

  for (final width in [768.0, 1280.0]) {
    testWidgets(
      'restaurant table: search, filter and pages at ${width.toInt()} px',
      (tester) async {
        final a = api();
        final app = await open(tester, a, Routes.restaurants, width: width);
        expect(tester.takeException(), isNull);
        expect(find.byKey(RestaurantsKeys.table), findsOneWidget);
        expect(find.text('Spice Garden'), findsOneWidget);
        expect(find.text('Dosa Corner'), findsOneWidget);
        await tester.enterText(
          find.byKey(RestaurantsKeys.search),
          'spice@example.com',
        );
        await tester.testTextInput.receiveAction(TextInputAction.search);
        await tester.pumpAndSettle();
        expect(
          a.callsTo('adminSearchRestaurants').last['query'],
          'spice@example.com',
        );
        await app.tap(find.byKey(RestaurantsKeys.status));
        await app.tap(find.text('Suspended').last);
        expect(a.callsTo('adminSearchRestaurants').last, {
          'query': 'spice@example.com',
          'status': 'suspended',
          'pageSize': 25,
        });
        await app.tap(find.byKey(RestaurantsKeys.next));
        expect(a.callsTo('adminSearchRestaurants').last['cursor'], 'r2');
        expect(find.text('Biryani House'), findsOneWidget);
        expect(find.text('Page 2'), findsOneWidget);
        await app.tap(find.byKey(RestaurantsKeys.previous));
        expect(find.text('Page 1'), findsOneWidget);
        await app.tap(find.text('Spice Garden'));
        expect(app.location, Routes.restaurant('r1'));
      },
    );
  }

  testWidgets('restaurants are read-only cards at 360 px', (tester) async {
    await open(tester, api(), Routes.restaurants, width: 360);
    expect(find.byKey(ReadOnlyNotice.noticeKey), findsOneWidget);
    expect(find.byKey(RestaurantsKeys.table), findsNothing);
    expect(find.byKey(RestaurantsKeys.row('r1')), findsOneWidget);
  });

  for (final width in [768.0, 1280.0]) {
    testWidgets(
      'detail: profile, subscription, payments, activity and a suspension at ${width.toInt()} px',
      (tester) async {
        final a = api();
        final app = await open(
          tester,
          a,
          Routes.restaurant('r1'),
          width: width,
        );
        expect(tester.takeException(), isNull);
        expect(find.text('Priya'), findsOneWidget);
        expect(find.textContaining('NEFT-1'), findsOneWidget);
        expect(find.text('menu.publish'), findsOneWidget);
        expect(find.textContaining('activate: free → pro'), findsOneWidget);
        // Suspend needs a reason (FR-088).
        await app.tap(find.byKey(DetailKeys.statusAction('suspended')));
        final confirm = tester.widget<FilledButton>(
          find.byKey(ReasonKeys.confirm),
        );
        expect(confirm.onPressed, isNull);
        await tester.enterText(find.byKey(ReasonKeys.field), 'Unpaid invoice');
        await tester.pump();
        await app.tap(find.byKey(ReasonKeys.confirm));
        expect(a.callsTo('setRestaurantStatus').single, {
          'restaurantId': 'r1',
          'status': 'suspended',
          'reason': 'Unpaid invoice',
        });
        expect(find.text('Status changed and logged.'), findsOneWidget);
        // Downgrade with a reason (FR-081).
        await app.tap(find.byKey(DetailKeys.downgrade));
        await tester.enterText(
          find.byKey(ReasonKeys.field),
          'Refund requested',
        );
        await tester.pump();
        await app.tap(find.byKey(ReasonKeys.confirm));
        expect(a.callsTo('changeSubscription').single, {
          'action': 'downgrade',
          'restaurantId': 'r1',
          'reason': 'Refund requested',
        });
      },
    );
  }

  for (final width in [768.0, 1280.0]) {
    testWidgets(
      'change plan: promote a Free restaurant to Pro with dates and a reason, no payment, at ${width.toInt()} px',
      (tester) async {
        final a = api();
        final detail = a.handlers['adminGetRestaurant']!;
        a.handlers['adminGetRestaurant'] = (d) => {
          ...detail(d)! as Map<String, Object?>,
          'subscription': {'status': 'free', 'planId': 'free'},
        };
        final app = await open(
          tester,
          a,
          Routes.restaurant('r1'),
          width: width,
        );
        await app.tap(find.byKey(DetailKeys.changePlan));
        expect(tester.takeException(), isNull);
        expect(find.text('Current plan: Free'), findsOneWidget);
        // Only the other active plans are offered.
        expect(find.byKey(ChangePlanKeys.plan('free')), findsNothing);
        FilledButton submit() =>
            tester.widget<FilledButton>(find.byKey(ChangePlanKeys.submit));
        expect(submit().onPressed, isNull);
        await app.tap(find.byKey(ChangePlanKeys.plan('pro')));
        expect(find.textContaining('No payment is recorded'), findsOneWidget);
        expect(find.byKey(ChangePlanKeys.startAt), findsOneWidget);
        expect(find.byKey(ChangePlanKeys.endAt), findsOneWidget);
        // A reason is required (FR-081).
        expect(submit().onPressed, isNull);
        await tester.enterText(find.byKey(ChangePlanKeys.reason), 'Trial');
        await tester.pump();
        await app.tap(find.byKey(ChangePlanKeys.submit));
        String iso(DateTime d) =>
            '${d.year.toString().padLeft(4, '0')}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';
        final now = DateTime.now();
        expect(a.callsTo('changeSubscription').single, {
          'action': 'modify',
          'restaurantId': 'r1',
          'planId': 'pro',
          'startAt': iso(DateTime.utc(now.year, now.month, now.day)),
          'expiresAt': iso(DateTime.utc(now.year, now.month + 1, now.day)),
          'reason': 'Trial',
        });
        expect(find.byKey(ChangePlanKeys.submit), findsNothing);
        expect(find.text('Subscription changed and logged.'), findsOneWidget);
      },
    );
  }

  testWidgets(
    'change plan: Pro to Free needs no dates and warns about hidden content',
    (tester) async {
      final a = api();
      final app = await open(tester, a, Routes.restaurant('r1'), width: 1280);
      await app.tap(find.byKey(DetailKeys.changePlan));
      expect(find.text('Current plan: Pro'), findsOneWidget);
      expect(find.byKey(ChangePlanKeys.plan('pro')), findsNothing);
      await app.tap(find.byKey(ChangePlanKeys.plan('free')));
      expect(
        find.textContaining('hidden and the menu is republished'),
        findsOneWidget,
      );
      expect(find.byKey(ChangePlanKeys.endAt), findsNothing);
      await tester.enterText(find.byKey(ChangePlanKeys.reason), 'Comp ended');
      await tester.pump();
      await app.tap(find.byKey(ChangePlanKeys.submit));
      expect(a.callsTo('changeSubscription').single, {
        'action': 'modify',
        'restaurantId': 'r1',
        'planId': 'free',
        'reason': 'Comp ended',
      });
    },
  );

  testWidgets(
    'change plan: a refused change keeps the dialog open with the message',
    (tester) async {
      final a = api()
        ..errors['changeSubscription'] = FirebaseFunctionsException(
          code: 'invalid-argument',
          message: 'A paid plan needs a future expiry.',
          details: {'code': 'invalid-input'},
        );
      final app = await open(tester, a, Routes.restaurant('r1'), width: 1280);
      await app.tap(find.byKey(DetailKeys.changePlan));
      await app.tap(find.byKey(ChangePlanKeys.plan('free')));
      await tester.enterText(find.byKey(ChangePlanKeys.reason), 'Correction');
      await tester.pump();
      await app.tap(find.byKey(ChangePlanKeys.submit));
      expect(find.byKey(ChangePlanKeys.submit), findsOneWidget);
      expect(
        find.text('Some details are not valid. Check them and try again.'),
        findsOneWidget,
      );
    },
  );

  testWidgets('detail is read-only at 360 px', (tester) async {
    await open(tester, api(), Routes.restaurant('r1'), width: 360);
    expect(find.byKey(ReadOnlyNotice.noticeKey), findsOneWidget);
    expect(find.byKey(DetailKeys.statusAction('suspended')), findsNothing);
    expect(find.byKey(DetailKeys.recordPayment), findsNothing);
    expect(find.byKey(DetailKeys.changePlan), findsNothing);
    expect(find.text('Priya'), findsOneWidget);
  });

  testWidgets('plans editor saves limits and applies them to subscribers', (
    tester,
  ) async {
    final a = api();
    final app = await open(tester, a, Routes.plans);
    await app.tap(find.byKey(CatalogKeys.edit('plan', 'pro')));
    await tester.enterText(find.byKey(CatalogKeys.field('maxItems')), '600');
    await tester.enterText(
      find.byKey(CatalogKeys.field('prices')),
      'INR 49900 499900',
    );
    await app.tap(find.byKey(CatalogKeys.apply));
    await app.tap(find.byKey(CatalogKeys.save));
    final call = a.callsTo('upsertPlan').single;
    expect(call['id'], 'pro');
    expect((call['limits']! as Map)['maxItems'], 600);
    expect(call['prices'], {
      'INR': {'monthly': 49900, 'annual': 499900},
    });
    expect(call['applyToSubscribers'], isTrue);
  });

  testWidgets('labels: add and retire (FR-104); themes listed', (tester) async {
    final a = api();
    final app = await open(tester, a, Routes.catalog);
    expect(find.text('Vegetarian'), findsOneWidget);
    await app.tap(find.byKey(CatalogKeys.edit('labels', 'vegetarian')));
    await app.tap(find.byKey(CatalogKeys.retired));
    await app.tap(find.byKey(CatalogKeys.save));
    expect(a.callsTo('upsertLabel').single, {
      'kind': 'label',
      'id': 'vegetarian',
      'name': 'Vegetarian',
      'icon': 'veg',
      'color': '#0F7B0F',
      'sort': 10,
      'retired': true,
    });
    await app.tap(find.text('Themes'));
    expect(find.text('Saffron'), findsOneWidget);
  });

  testWidgets('settings: platform config, announcement and admins', (
    tester,
  ) async {
    final a = api();
    final app = await open(tester, a, Routes.settings);
    await tester.enterText(find.byKey(SettingsKeys.graceDays), '7');
    await app.tap(find.byKey(SettingsKeys.saveConfig));
    expect(a.callsTo('updatePlatformConfig').single, {
      'reservedSlugs': ['admin', 'api'],
      'graceDays': 7,
      'fonts': ['Poppins'],
      'currencies': {'INR': 2},
      'supportEmail': 'help@eazysuvai.com',
    });
    await tester.enterText(
      find.byKey(SettingsKeys.announcementText),
      'Maintenance on Sunday',
    );
    await app.tap(find.byKey(SettingsKeys.announcementActive));
    await app.tap(find.byKey(SettingsKeys.saveAnnouncement));
    expect(a.callsTo('setAnnouncement').single, {
      'text': 'Maintenance on Sunday',
      'level': 'info',
      'active': true,
    });
    await tester.enterText(
      find.byKey(SettingsKeys.adminEmail),
      'staff@example.com',
    );
    await app.tap(find.byKey(SettingsKeys.grant));
    await tester.enterText(find.byKey(ReasonKeys.field), 'New hire');
    await tester.pump();
    await app.tap(find.byKey(ReasonKeys.confirm));
    expect(a.callsTo('setAdminRole').single, {
      'email': 'staff@example.com',
      'grant': true,
      'reason': 'New hire',
    });
  });
}
