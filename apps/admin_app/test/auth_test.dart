import 'package:admin_app/router/app_router.dart';
import 'package:admin_app/router/auth_guard.dart';
import 'package:core/core.dart';
import 'package:core/testing.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:qr_flutter/qr_flutter.dart';

import 'helpers.dart';

void main() {
  group('adminRedirect (FR-084)', () {
    const admin = AuthSession(
      uid: 'a1',
      email: 'a@b.co',
      emailVerified: true,
      role: UserRole.platformAdmin,
    );
    const adminTotp = AuthSession(
      uid: 'a1',
      email: 'a@b.co',
      emailVerified: true,
      role: UserRole.platformAdmin,
      secondFactor: 'totp',
    );
    const owner = AuthSession(
      uid: 'u1',
      email: 'a@b.co',
      emailVerified: true,
      role: UserRole.owner,
      restaurantId: 'r1',
    );
    String? at(AuthSession? s, String uri, {bool mfa = true}) =>
        adminRedirect(AsyncData(s), Uri.parse(uri), mfaRequired: mfa);

    test('signed out or not an admin → sign-in', () {
      expect(at(null, '/'), Routes.signIn);
      expect(at(null, '/restaurants'), '/sign-in?from=%2Frestaurants');
      expect(at(null, Routes.signIn), isNull);
      expect(at(owner, '/'), Routes.signIn);
      expect(at(owner, Routes.mfaSetup), Routes.signIn);
    });

    test('admin without TOTP must enrol', () {
      expect(at(admin, '/'), Routes.mfaSetup);
      expect(at(admin, Routes.signIn), Routes.mfaSetup);
      expect(at(admin, Routes.mfaSetup), isNull);
    });

    test('admin with TOTP reaches the dashboard', () {
      expect(at(adminTotp, '/plans'), isNull);
      expect(at(adminTotp, Routes.signIn), Routes.dashboard);
      expect(at(adminTotp, '/sign-in?from=/plans'), '/plans');
      expect(at(adminTotp, Routes.mfaSetup), Routes.dashboard);
    });

    test('on the emulators MFA is relaxed', () {
      expect(at(admin, '/', mfa: false), isNull);
    });

    test('loading goes to splash', () {
      expect(
        adminRedirect(
          const AsyncLoading(),
          Uri.parse('/plans'),
          mfaRequired: true,
        ),
        '/splash?from=%2Fplans',
      );
    });
  });

  testWidgets('first sign-in enrols TOTP, then signs in with the code', (
    tester,
  ) async {
    final semantics = tester.ensureSemantics();
    final app = await pumpAdminApp(tester, users: [adminUser()]);
    expect(app.location, Routes.signIn);

    await app.signIn();
    expect(app.location, Routes.mfaSetup);
    expect(find.text('Set up two-factor sign-in'), findsOneWidget);
    expect(find.byType(QrImageView), findsOneWidget);
    expect(find.text('JBSWY3DPEHPK3PXP'), findsOneWidget);
    expect(
      find.bySemanticsLabel('QR code for your authenticator app'),
      findsOneWidget,
    );

    await app.enter('mfa.code', '000000');
    await app.tap(find.byKey(const ValueKey('mfa.submit')));
    expect(
      find.text(
        'That code is not correct. Enter the current 6-digit code from your authenticator app.',
      ),
      findsOneWidget,
    );

    await app.enter('mfa.code', validCode);
    await app.tap(find.byKey(const ValueKey('mfa.submit')));
    expect(app.auth.current, isNull, reason: 'signed out after enrolment');
    expect(app.location, startsWith(Routes.signIn));
    expect(
      find.text('Two-factor sign-in is on. Sign in again with your code.'),
      findsOneWidget,
    );

    await app.signIn();
    expect(find.text('Enter your code'), findsOneWidget);
    expect(app.auth.current, isNull, reason: 'not signed in before the code');

    await app.enter('admin.code', '12');
    await app.tap(find.byKey(const ValueKey('admin.submit')));
    expect(
      find.text('Enter the 6 digits from your authenticator app.'),
      findsOneWidget,
    );

    await app.enter('admin.code', validCode);
    await app.tap(find.byKey(const ValueKey('admin.submit')));
    expect(app.location, Routes.dashboard);
    expect(find.widgetWithText(AppBar, 'Dashboard'), findsOneWidget);
    semantics.dispose();
  });

  testWidgets('an owner account is refused and signed out', (tester) async {
    final owner = FakeUser(
      uid: 'u1',
      email: 'owner@example.com',
      password: 'Secret123!',
      emailVerified: true,
      claims: {'role': 'owner', 'restaurantId': 'r1'},
    );
    final app = await pumpAdminApp(tester, users: [owner]);
    await app.signIn(email: 'owner@example.com');
    expect(app.auth.current, isNull);
    expect(
      find.text('This account is not a platform administrator.'),
      findsOneWidget,
    );
    expect(app.location, Routes.signIn);
  });

  testWidgets('an admin with an unverified email is told to verify first', (
    tester,
  ) async {
    final app = await pumpAdminApp(tester, users: [adminUser(verified: false)]);
    await app.signIn();
    expect(app.auth.current, isNull);
    expect(app.auth.verificationEmailsSent, ['admin@example.com']);
    expect(
      find.text(
        'Verify your email address before setting up two-factor authentication.',
      ),
      findsOneWidget,
    );
  });

  testWidgets('cancel on the code step returns to email and password', (
    tester,
  ) async {
    final app = await pumpAdminApp(tester, users: [adminUser(totp: true)]);
    await app.signIn();
    await app.tap(find.text('Cancel'));
    expect(find.byKey(const ValueKey('admin.password')), findsOneWidget);
  });

  testWidgets('on the emulators an admin without TOTP reaches the dashboard', (
    tester,
  ) async {
    final app = await pumpAdminApp(
      tester,
      users: [adminUser()],
      mfaRequired: false,
    );
    await app.signIn();
    expect(app.location, Routes.dashboard);
  });

  for (final width in [360.0, 768.0, 1280.0]) {
    testWidgets('sign-in and MFA setup at ${width.toInt()} px', (tester) async {
      final app = await pumpAdminApp(tester, width: width);
      expect(find.text('Sign in'), findsWidgets);
      expect(
        find.byKey(AuthLayout.brandPanelKey),
        width >= 1024 ? findsOneWidget : findsNothing,
      );
      expect(tester.takeException(), isNull);

      app.auth.users['admin@example.com'] = adminUser();
      await app.signIn();
      expect(app.location, Routes.mfaSetup);
      expect(tester.takeException(), isNull);
      expect(
        tester.getSize(find.byType(TextField).first).width,
        lessThanOrEqualTo(AuthLayout.maxFormWidth),
      );
    });
  }
}
