// M13: FRD §13 success metrics on the admin dashboard.
import 'package:admin_app/features/dashboard/dashboard_page.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'admin_pages_test.dart' as pages;

String rowText(WidgetTester tester, String key) => tester
    .widgetList<Text>(
      find.descendant(
        of: find.byKey(DashboardKeys.metric(key)),
        matching: find.byType(Text),
      ),
    )
    .map((t) => t.data)
    .join(' | ');

void main() {
  for (final width in [360.0, 1280.0]) {
    testWidgets('success metrics with rates at ${width.toInt()} px', (
      tester,
    ) async {
      await pages.open(tester, pages.api(), '/', width: width);
      await tester.scrollUntilVisible(
        find.byKey(DashboardKeys.metric('support')),
        200,
        scrollable: find.byType(Scrollable).first,
      );
      // 12 registered, 8 activated.
      expect(rowText(tester, 'activated'), contains('8 (66.7%)'));
      expect(rowText(tester, 'published'), contains('7'));
      expect(rowText(tester, 'qrDownloads'), contains('21'));
      expect(rowText(tester, 'median'), contains('18 minutes'));
      expect(rowText(tester, 'monthViews'), contains('2026-11'));
      expect(rowText(tester, 'monthViews'), contains('1,200 views · 800 QR visits'));
      expect(rowText(tester, 'conversion'), contains('3 (25%)'));
      // 1 renewal, 2 expired: 33.3 %.
      expect(rowText(tester, 'renewal'), contains('1 (33.3%)'));
      // 1 deactivated, 0 deleted of 12.
      expect(rowText(tester, 'churn'), contains('8.3%'));
      // 340 items / 12 restaurants.
      expect(rowText(tester, 'avgItems'), contains('28.3'));
      expect(rowText(tester, 'support'), contains('support inbox'));
      expect(tester.takeException(), isNull);
    });
  }
}
