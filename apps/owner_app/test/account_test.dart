// M12: export the menu and the delete-account flow (FR-105).
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:owner_app/features/account/presentation/account_page.dart';
import 'package:owner_app/features/qr/data/share_actions.dart';
import 'package:owner_app/router/app_router.dart';

import 'helpers.dart';
import 'qr_share_test.dart' show FakeQrShareActions;

Future<(TestApp, FakeAccountRepository, FakeQrShareActions)> openAccount(
  WidgetTester tester, {
  double width = 360,
  String route = Routes.account,
}) async {
  final account = FakeAccountRepository();
  final actions = FakeQrShareActions();
  final app = await pumpOwnerApp(
    tester,
    width: width,
    signedIn: verifiedOwner(),
    account: account,
    overrides: [qrShareActionsProvider.overrideWithValue(actions)],
  );
  await app.go(route);
  return (app, account, actions);
}

Future<void> tapAt(WidgetTester tester, Finder f) async {
  await Scrollable.ensureVisible(tester.element(f), alignment: 0.2);
  await tester.pumpAndSettle();
  await tester.tap(f);
  await tester.pumpAndSettle();
}

void main() {
  for (final width in [360.0, 768.0, 1280.0]) {
    testWidgets('exports the menu as CSV and JSON at ${width.toInt()} px', (
      tester,
    ) async {
      final (app, account, actions) = await openAccount(tester, width: width);
      expect(tester.takeException(), isNull);
      await tapAt(tester, find.byKey(AccountKeys.exportCsv));
      await tapAt(tester, find.byKey(AccountKeys.exportJson));
      expect(account.exports, ['rest_1', 'rest_1']);
      expect(actions.saves.map((s) => (s.$2, s.$3)), [
        ('spice-garden-menu-2026-11-15.csv', 'text/csv'),
        ('spice-garden-menu-2026-11-15.json', 'application/json'),
      ]);
      expect(utf8.decode(actions.saves.last.$1), '{"items":[]}');
      expect(find.textContaining('is ready'), findsOneWidget);
      expect(app.location, Routes.account);
    });
  }

  testWidgets('settings opens the account page', (tester) async {
    final app = await pumpOwnerApp(
      tester,
      width: 1280,
      signedIn: verifiedOwner(),
    );
    await app.go(Routes.settings);
    await tester.tap(find.byKey(const ValueKey('settings.account')));
    await tester.pumpAndSettle();
    expect(app.location, Routes.account);
  });

  for (final width in [360.0, 1280.0]) {
    testWidgets(
      'delete flow: export offer, name, confirm at ${width.toInt()} px',
      (tester) async {
        final (app, account, _) = await openAccount(tester, width: width);
        await tapAt(tester, find.byKey(AccountKeys.delete));
        expect(app.location, Routes.deleteAccount);
        await tapAt(tester, find.byKey(AccountKeys.next));
        // The name must match (case and spaces ignored).
        await tester.enterText(find.byKey(AccountKeys.name), 'Spice');
        await tester.pump();
        final cont = find.widgetWithText(FilledButton, 'Continue');
        expect(tester.widget<FilledButton>(cont.last).onPressed, isNull);
        await tester.enterText(
          find.byKey(AccountKeys.name),
          '  spice   garden ',
        );
        await tester.pump();
        await tapAt(tester, cont.last);
        expect(find.textContaining('deleted after 90 days'), findsWidgets);
        await tapAt(tester, find.byKey(AccountKeys.confirm));
        expect(account.deletions, [('rest_1', '  spice   garden ')]);
        // Signed out afterwards.
        expect(app.location, startsWith(Routes.signIn));
      },
    );
  }
}
