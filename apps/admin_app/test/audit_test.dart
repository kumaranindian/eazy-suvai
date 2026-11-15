// M12: the audit log viewer (FR-090, BR-014).
import 'package:admin_app/features/audit/audit_log_page.dart';
import 'package:admin_app/features/restaurants/restaurant_detail_page.dart';
import 'package:admin_app/router/app_router.dart';
import 'package:admin_app/widgets/read_only.dart';
import 'package:flutter_test/flutter_test.dart';

import 'admin_pages_test.dart' as pages;
import 'fake_admin_api.dart';
import 'helpers.dart';

FakeAdminApi auditApi() {
  final base = pages.api();
  base.handlers['adminListAuditLogs'] = (d) => {
    'entries': d['cursor'] == null
        ? [
            {
              'id': 'a2',
              'at': '2026-11-14T10:00:00.000Z',
              'actorUid': 'admin1',
              'actorRole': 'platformAdmin',
              'action': 'restaurant.suspend',
              'restaurantId': 'r1',
              'target': 'restaurants/r1',
              'reason': 'Unpaid invoice',
              'details': {'from': 'active', 'to': 'suspended'},
              'anonymized': false,
            },
            {
              'id': 'a1',
              'at': '2026-11-12T10:00:00.000Z',
              'actorUid': 'anon:1234',
              'actorRole': 'owner',
              'action': 'menu.publish',
              'restaurantId': 'r1',
              'target': 'x',
              'reason': null,
              'details': {'version': 3},
              'anonymized': true,
            },
          ]
        : <Object>[],
    'nextCursor': d['cursor'] == null ? 'a1' : null,
  };
  return base;
}

Future<AdminTestApp> openAudit(
  WidgetTester tester,
  FakeAdminApi api, {
  double width = 1280,
  String route = Routes.audit,
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
  for (final width in [768.0, 1280.0]) {
    testWidgets(
      'filters and shows entries with a detail view at ${width.toInt()} px',
      (tester) async {
        final api = auditApi();
        final app = await openAudit(tester, api, width: width);
        expect(tester.takeException(), isNull);
        expect(find.byKey(AuditKeys.table), findsOneWidget);
        expect(find.text('restaurant.suspend'), findsOneWidget);
        await tester.enterText(find.byKey(AuditKeys.actor), 'admin1');
        await tester.enterText(
          find.byKey(AuditKeys.action),
          'restaurant.suspend',
        );
        await app.tap(find.byKey(AuditKeys.apply));
        expect(api.callsTo('adminListAuditLogs').last, {
          'actorUid': 'admin1',
          'action': 'restaurant.suspend',
          'pageSize': 50,
        });
        await app.tap(
          find.descendant(
            of: find.byKey(AuditKeys.table),
            matching: find.text('restaurant.suspend'),
          ),
        );
        expect(find.byKey(AuditKeys.detail), findsOneWidget);
        expect(find.textContaining('"to": "suspended"'), findsOneWidget);
      },
    );
  }

  testWidgets('read-only cards at 360 px, next page', (tester) async {
    final api = auditApi();
    final app = await openAudit(tester, api, width: 360);
    expect(find.byKey(ReadOnlyNotice.noticeKey), findsOneWidget);
    expect(find.byKey(AuditKeys.row('a1')), findsOneWidget);
    await app.tap(find.byKey(AuditKeys.next));
    expect(api.callsTo('adminListAuditLogs').last['cursor'], 'a1');
  });

  testWidgets('the restaurant activity card links to its audit entries', (
    tester,
  ) async {
    final api = auditApi();
    final app = await openAudit(tester, api, route: Routes.restaurant('r1'));
    await app.tap(find.byKey(DetailKeys.auditLink));
    expect(app.location, '${Routes.audit}?restaurant=r1');
    expect(api.callsTo('adminListAuditLogs').last['restaurantId'], 'r1');
  });
}
