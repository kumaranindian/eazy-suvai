// M11: the admin's announcement and the suspended / deactivated notice
// (FR-099: "blocked; login shows a notice and support contact").
import 'package:flutter_test/flutter_test.dart';
import 'package:owner_app/features/account/data/account_notices.dart';
import 'package:owner_app/features/account/presentation/account_notices_view.dart';
import 'package:owner_app/router/app_router.dart';

import 'helpers.dart';

void main() {
  for (final width in [360.0, 768.0, 1280.0]) {
    testWidgets(
      'shows the announcement on the dashboard at ${width.toInt()} px',
      (tester) async {
        await pumpOwnerApp(
          tester,
          width: width,
          signedIn: verifiedOwner(),
          notice: const PlatformNotice(
            text: 'Maintenance on Sunday 2 am',
            warning: true,
          ),
        );
        expect(tester.takeException(), isNull);
        expect(find.byKey(AccountNoticeKeys.announcement), findsOneWidget);
        expect(find.text('Maintenance on Sunday 2 am'), findsOneWidget);
      },
    );
  }

  test('an announcement past its end date is hidden', () {
    final n = PlatformNotice.fromMap({
      'announcement': {
        'text': 'Old news',
        'active': true,
        'until': '2026-11-01T00:00:00Z',
      },
    });
    expect(n.visibleAt(DateTime.utc(2026, 11, 15)), isFalse);
    expect(
      PlatformNotice.fromMap({
        'announcement': {'text': 'x', 'active': false},
      }).text,
      isNull,
    );
    expect(PlatformNotice.fromMap(null).text, isNull);
  });

  for (final (status, title) in [
    ('suspended', 'Your account is suspended'),
    ('deactivated', 'Your account is deactivated'),
  ]) {
    testWidgets('a $status owner sees only the notice and support contact', (
      tester,
    ) async {
      final app = await pumpOwnerApp(
        tester,
        signedIn: verifiedOwner(),
        accountStatus: status,
        notice: const PlatformNotice(supportEmail: 'help@eazysuvai.com'),
      );
      expect(find.byKey(AccountNoticeKeys.blocked), findsOneWidget);
      expect(find.text(title), findsOneWidget);
      expect(find.textContaining('help@eazysuvai.com'), findsOneWidget);
      await app.go(Routes.menu);
      expect(find.byKey(AccountNoticeKeys.blocked), findsOneWidget);
      await tester.tap(find.byKey(AccountNoticeKeys.signOut));
      await tester.pumpAndSettle();
      expect(app.location, startsWith(Routes.signIn));
    });
  }
}
