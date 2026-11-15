// M13: terms and privacy links on sign-up and on the Account page.
import 'package:flutter_test/flutter_test.dart';
import 'package:owner_app/features/auth/presentation/legal_links.dart';
import 'package:owner_app/router/app_router.dart';

import 'helpers.dart';

void main() {
  for (final width in [360.0, 1280.0]) {
    testWidgets('sign-up links the terms and privacy at ${width.toInt()} px', (
      tester,
    ) async {
      final opened = <Uri>[];
      final app = await pumpOwnerApp(
        tester,
        width: width,
        overrides: [
          legalLinkOpenerProvider.overrideWithValue((u) async => opened.add(u)),
        ],
      );
      await app.go(Routes.signUp);
      expect(
        find.text('By creating an account, you agree to the'),
        findsOneWidget,
      );
      await tester.ensureVisible(find.byKey(LegalKeys.terms));
      await tester.tap(find.byKey(LegalKeys.terms));
      await tester.ensureVisible(find.byKey(LegalKeys.privacy));
      await tester.tap(find.byKey(LegalKeys.privacy));
      expect(opened.map((u) => u.path), ['/terms', '/privacy']);
      expect(tester.takeException(), isNull);
    });
  }

  testWidgets('the Account page links both pages', (tester) async {
    final opened = <Uri>[];
    final app = await pumpOwnerApp(
      tester,
      signedIn: verifiedOwner(),
      overrides: [
        legalLinkOpenerProvider.overrideWithValue((u) async => opened.add(u)),
      ],
    );
    await app.go(Routes.account);
    await tester.ensureVisible(find.byKey(LegalKeys.privacy));
    await tester.tap(find.byKey(LegalKeys.privacy));
    expect(opened.single.path, '/privacy');
  });
}
