// M09: analytics summary and the owner screen (FR-071 to FR-075, AC-015).
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:owner_app/features/analytics/domain/analytics.dart';
import 'package:owner_app/features/analytics/presentation/analytics_page.dart';
import 'package:owner_app/router/app_router.dart';

import 'fake_analytics.dart';
import 'fake_menu.dart';
import 'helpers.dart';

const today = '2026-11-15';

List<AnalyticsDay> sampleDays() => [
  const AnalyticsDay(
    date: '2026-11-15',
    views: 12,
    qrVisits: 9,
    categoryTaps: {'c1': 5, 'c2': 2},
    itemOpens: {'i1': 4, 'gone': 1},
  ),
  const AnalyticsDay(
    date: '2026-11-13',
    views: 8,
    qrVisits: 3,
    itemOpens: {'i2': 6},
  ),
  // Outside 7 days, inside 30.
  const AnalyticsDay(
    date: '2026-10-25',
    views: 30,
    qrVisits: 10,
    categoryTaps: {'c2': 9},
  ),
];

void main() {
  group('summarize', () {
    test('ranges end today in the restaurant zone', () {
      final r7 = presetRange(AnalyticsRangeKind.last7, today);
      expect((r7.start, r7.end, r7.days), ('2026-11-09', today, 7));
      final r30 = presetRange(AnalyticsRangeKind.last30, today);
      expect((r30.start, r30.days), ('2026-10-17', 30));
      expect(earliestAllowed(today, 7), '2026-11-09');
      expect(rangeAllowed(r30, today, 7), isFalse);
      expect(rangeAllowed(r30, today, 365), isTrue);
      expect(dayKeys('2026-02-27', '2026-03-01'), [
        '2026-02-27',
        '2026-02-28',
        '2026-03-01',
      ]);
    });

    test('totals, a gap-free series, top lists and months', () {
      final s = summarize(
        presetRange(AnalyticsRangeKind.last30, today),
        sampleDays(),
      );
      expect(
        (s.views, s.qrVisits, s.categoryTaps, s.itemOpens),
        (50, 22, 16, 11),
      );
      expect(s.qrShare, closeTo(0.44, 1e-9));
      expect(s.series, hasLength(30));
      expect(s.series.last.views, 12);
      expect(s.series.where((p) => p.views == 0), hasLength(27));
      expect(s.topCategories.map((r) => (r.id, r.count)), [
        ('c2', 11),
        ('c1', 5),
      ]);
      expect(s.topItems.first.id, 'i2');
      expect(s.months.map((m) => (m.month, m.views)), [
        ('2026-10', 30),
        ('2026-11', 20),
      ]);
      final s7 = summarize(
        presetRange(AnalyticsRangeKind.last7, today),
        sampleDays(),
      );
      expect(s7.views, 20);
      expect(s7.months, hasLength(1));
      expect(
        summarize(
          presetRange(AnalyticsRangeKind.last7, today),
          const [],
        ).isEmpty,
        isTrue,
      );
    });

    test('reads Firestore maps defensively', () {
      final d = AnalyticsDay.fromMap('2026-11-15', {
        'views': 3,
        'qrVisits': 1.0,
        'categoryTaps': {'c1': 2, 'bad': 'x'},
        'itemOpens': null,
      });
      expect((d.views, d.qrVisits), (3, 1));
      expect(d.categoryTaps, {'c1': 2, 'bad': 0});
      expect(d.itemOpens, isEmpty);
    });
  });

  for (final width in [360.0, 768.0, 1280.0]) {
    testWidgets(
      'shows views, QR visits and item interest at ${width.toInt()} px',
      (tester) async {
        final repo = FakeAnalyticsRepository(sampleDays());
        final app = await pumpOwnerApp(
          tester,
          width: width,
          signedIn: verifiedOwner(),
          restaurant: FakeRestaurantRepository(
            restaurantData({'publishedVersion': 1}),
          ),
          menu: sampleMenu(),
          analytics: repo,
        );
        await app.go(Routes.analytics);
        expect(tester.takeException(), isNull);
        expect(repo.ranges.last, ('2026-11-09', today));
        expect(find.text('Nov 9, 2026 – Nov 15, 2026'), findsOneWidget);
        Finder tile(String name, String value) => find.descendant(
          of: find.byKey(AnalyticsKeys.tile(name)),
          matching: find.text(value),
        );
        expect(tile('views', '20'), findsOneWidget);
        expect(tile('qr', '12'), findsOneWidget);
        expect(tile('qrShare', '60%'), findsOneWidget);
        expect(tile('items', '11'), findsOneWidget);
        expect(find.byKey(AnalyticsKeys.chart), findsOneWidget);
        await tester.ensureVisible(find.byKey(AnalyticsKeys.topItems));
        expect(find.text('Removed from the menu'), findsOneWidget);
        expect(find.text('6 opens'), findsOneWidget);
        expect(find.byKey(AnalyticsKeys.notPublished), findsNothing);
        // Layout: four tiles in a row from 600 px; top lists side by side ≥ 1024.
        final views = tester.getRect(find.byKey(AnalyticsKeys.tile('views')));
        final items = tester.getRect(find.byKey(AnalyticsKeys.tile('items')));
        expect(items.top == views.top, width >= 600);
        final cats = tester.getRect(find.byKey(AnalyticsKeys.topCategories));
        final top = tester.getRect(find.byKey(AnalyticsKeys.topItems));
        expect(cats.top == top.top, width >= 1024);
      },
    );
  }

  testWidgets('Free plans see an upgrade prompt for 30 days (FR-074)', (
    tester,
  ) async {
    final repo = FakeAnalyticsRepository(sampleDays());
    final app = await pumpOwnerApp(
      tester,
      signedIn: verifiedOwner(),
      restaurant: FakeRestaurantRepository(
        restaurantData({'publishedVersion': 1}),
      ),
      analytics: repo,
    );
    await app.go(Routes.analytics);
    expect(find.text('30 days (Pro)'), findsOneWidget);
    await tester.tap(find.byKey(AnalyticsKeys.range30));
    await tester.pumpAndSettle();
    expect(find.byKey(AnalyticsKeys.upgrade), findsOneWidget);
    expect(repo.ranges.map((r) => r.$1).toSet(), {'2026-11-09'});
    await tester.tap(find.text('See plans'));
    await tester.pumpAndSettle();
    expect(app.location, Routes.plan);
  });

  testWidgets('Pro plans get 30 days with monthly totals', (tester) async {
    final repo = FakeAnalyticsRepository(sampleDays());
    final app = await pumpOwnerApp(
      tester,
      width: 1280,
      signedIn: verifiedOwner(),
      restaurant: FakeRestaurantRepository(
        restaurantData({'publishedVersion': 1, 'planId': 'pro'}),
      ),
      analytics: repo,
    );
    await app.go(Routes.analytics);
    await tester.tap(find.byKey(AnalyticsKeys.range30));
    await tester.pumpAndSettle();
    expect(find.byKey(AnalyticsKeys.upgrade), findsNothing);
    expect(repo.ranges.last, ('2026-10-17', today));
    expect(
      find.descendant(
        of: find.byKey(AnalyticsKeys.tile('views')),
        matching: find.text('50'),
      ),
      findsOneWidget,
    );
    await tester.ensureVisible(find.byKey(AnalyticsKeys.months));
    expect(find.text('October 2026'), findsOneWidget);
    expect(find.text('30 views · 10 QR visits'), findsOneWidget);
  });

  testWidgets('custom range is limited to the plan history', (tester) async {
    final repo = FakeAnalyticsRepository(sampleDays());
    final app = await pumpOwnerApp(
      tester,
      width: 1280,
      signedIn: verifiedOwner(),
      restaurant: FakeRestaurantRepository(
        restaurantData({'publishedVersion': 1}),
      ),
      analytics: repo,
    );
    await app.go(Routes.analytics);
    await tester.tap(find.byKey(AnalyticsKeys.rangeCustom));
    await tester.pumpAndSettle();
    final picker = tester.widget<DateRangePickerDialog>(
      find.byType(DateRangePickerDialog),
    );
    expect(keyOfDate(picker.firstDate), '2026-11-09');
    expect(keyOfDate(picker.lastDate), today);
    Navigator.of(tester.element(find.byType(DateRangePickerDialog))).pop();
    await tester.pumpAndSettle();
    expect(find.byType(DateRangePickerDialog), findsNothing);
  });

  testWidgets('empty state and the not-published note', (tester) async {
    final app = await pumpOwnerApp(
      tester,
      signedIn: verifiedOwner(),
      analytics: FakeAnalyticsRepository(),
    );
    await app.go(Routes.analytics);
    expect(find.byKey(AnalyticsKeys.empty), findsOneWidget);
    expect(find.text('No visits in this period'), findsOneWidget);
    expect(find.byKey(AnalyticsKeys.notPublished), findsOneWidget);
    await tester.tap(find.text('QR & share').last);
    await tester.pumpAndSettle();
    expect(app.location, Routes.share);
  });
}
