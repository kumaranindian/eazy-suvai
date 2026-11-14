import 'package:core/core.dart';
import 'package:core/testing.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:owner_app/router/app_router.dart';

import 'helpers.dart';

const _k = ValueKey.new;

Future<void> fillSignUp(
  TestApp app, {
  String email = 'Priya@Example.com',
  String password = 'Secret123!',
  String mobile = '98765 43210',
}) async {
  await app.enter(_k('signUp.restaurantName'), 'Spice Garden');
  await app.choose(_k('signUp.businessType'), 'Restaurant');
  await app.enter(_k('signUp.city'), 'Chennai');
  await app.enter(_k('signUp.ownerName'), 'Priya Raman');
  await app.enterLabelled('Mobile number', mobile);
  await app.enter(_k('signUp.email'), email);
  await app.enter(_k('signUp.password'), password);
}

void main() {
  group('sign-up (FR-001, FR-002, FR-003)', () {
    testWidgets('shows validation errors for empty and invalid fields', (
      tester,
    ) async {
      final app = await pumpOwnerApp(tester);
      await app.go(Routes.signUp);

      await app.tap(find.byKey(_k('signUp.submit')));
      expect(find.text('This field is required.'), findsWidgets);
      expect(app.registration.calls, isEmpty);

      await app.enter(_k('signUp.email'), 'not-an-email');
      expect(
        find.text('Enter a valid email address, like name@example.com.'),
        findsOneWidget,
      );
      await app.enter(_k('signUp.password'), 'short');
      expect(find.text('Use at least 8 characters.'), findsOneWidget);

      // An Indian mobile is valid for India...
      await app.enterLabelled('Mobile number', '98765 43210');
      expect(
        find.text('Enter a valid mobile number for the selected country.'),
        findsNothing,
      );
      // ...but not after switching the country to the UAE.
      await app.choose(_k('signUp.country'), 'United Arab Emirates');
      expect(find.text('+971 '), findsOneWidget);
      expect(
        find.text('Enter a valid mobile number for the selected country.'),
        findsOneWidget,
      );
      await app.dispose();
    });

    testWidgets(
      'creates the account, restaurant, sends the email and signs out',
      (tester) async {
        final app = await pumpOwnerApp(tester);
        await app.go(Routes.signUp);
        await fillSignUp(app);
        await app.tap(find.byKey(_k('signUp.submit')));

        expect(app.auth.users.keys, ['priya@example.com']);
        final details = app.registration.calls.single!;
        expect(details.toJson(), {
          'restaurantName': 'Spice Garden',
          'ownerName': 'Priya Raman',
          'mobile': '+919876543210',
          'country': 'IN',
          'businessType': 'restaurant',
          'city': 'Chennai',
        });
        expect(app.auth.verificationEmailsSent, ['priya@example.com']);
        expect(app.auth.current, isNull, reason: 'signed out (FR-091)');

        expect(app.location, startsWith(Routes.verifyEmail));
        expect(find.text('Check your email'), findsOneWidget);
        expect(find.textContaining('priya@example.com'), findsOneWidget);
        expect(find.text('Resend in 60s'), findsOneWidget);
        await tester.pump(const Duration(seconds: 61));
        expect(find.text('Resend email'), findsOneWidget);
        await app.dispose();
      },
    );

    testWidgets(
      'an email that already has an account shows a clear error (FR-004)',
      (tester) async {
        final app = await pumpOwnerApp(
          tester,
          users: [verifiedOwner(email: 'priya@example.com')],
        );
        await app.go(Routes.signUp);
        await fillSignUp(app);
        await app.tap(find.byKey(_k('signUp.submit')));
        expect(
          find.text(
            'An account with this email already exists. Sign in instead, or reset your password.',
          ),
          findsOneWidget,
        );
        expect(app.registration.calls, isEmpty);
        expect(app.location, Routes.signUp);
      },
    );

    testWidgets(
      'retry after a failed callable does not create a second account',
      (tester) async {
        final app = await pumpOwnerApp(tester);
        await app.go(Routes.signUp);
        await fillSignUp(app);
        app.registration.nextError = FirebaseAuthException(
          code: 'network-request-failed',
        );
        await app.tap(find.byKey(_k('signUp.submit')));
        expect(
          find.text(
            'You seem to be offline. Check your connection and try again.',
          ),
          findsOneWidget,
        );
        expect(app.location, Routes.signUp, reason: 'unverified may stay here');

        await app.tap(find.byKey(_k('signUp.submit')));
        expect(app.auth.users, hasLength(1));
        expect(app.registration.calls, hasLength(2));
        expect(app.location, startsWith(Routes.verifyEmail));
        await app.dispose();
      },
    );
  });

  group('sign-in (FR-005, FR-091)', () {
    testWidgets('a verified owner reaches the dashboard and the from target', (
      tester,
    ) async {
      final app = await pumpOwnerApp(tester, users: [verifiedOwner()]);
      await app.go(Routes.menu);
      expect(app.location, '/sign-in?from=%2Fmenu');

      await app.enter(_k('signIn.email'), 'owner@example.com');
      await app.enter(_k('signIn.password'), 'Secret123!');
      await app.tap(find.byKey(_k('signIn.submit')));
      expect(app.location, Routes.menu);
      expect(find.widgetWithText(AppBar, 'Menu'), findsOneWidget);
    });

    testWidgets(
      'wrong password shows a message that does not reveal which part',
      (tester) async {
        final app = await pumpOwnerApp(tester, users: [verifiedOwner()]);
        await app.enter(_k('signIn.email'), 'owner@example.com');
        await app.enter(_k('signIn.password'), 'wrong-password');
        await app.tap(find.byKey(_k('signIn.submit')));
        expect(
          find.text(
            "That email and password don't match. Check them and try again.",
          ),
          findsOneWidget,
        );
        expect(app.location, Routes.signIn);
      },
    );

    testWidgets('too many attempts is explained', (tester) async {
      final app = await pumpOwnerApp(tester, users: [verifiedOwner()]);
      app.auth.nextError = FirebaseAuthException(code: 'too-many-requests');
      await app.enter(_k('signIn.email'), 'owner@example.com');
      await app.enter(_k('signIn.password'), 'Secret123!');
      await app.tap(find.byKey(_k('signIn.submit')));
      expect(
        find.text('Too many attempts. Wait a few minutes and try again.'),
        findsOneWidget,
      );
    });

    testWidgets('an unverified owner is signed out and offered a resend', (
      tester,
    ) async {
      final user = verifiedOwner()..emailVerified = false;
      final app = await pumpOwnerApp(tester, users: [user]);
      await app.enter(_k('signIn.email'), 'owner@example.com');
      await app.enter(_k('signIn.password'), 'Secret123!');
      await app.tap(find.byKey(_k('signIn.submit')));

      expect(app.auth.current, isNull);
      expect(app.location, startsWith(Routes.verifyEmail));
      expect(
        find.text(
          "Verify your email address before you sign in. Didn't get the email? Send it again.",
        ),
        findsOneWidget,
      );

      await app.tap(find.byKey(_k('verify.resend')));
      expect(app.auth.verificationEmailsSent, ['owner@example.com']);
      expect(app.auth.current, isNull);
      expect(find.text('We sent a new verification link.'), findsOneWidget);
      expect(find.text('Resend in 60s'), findsOneWidget);

      // Verified meanwhile: resend signs in and the router opens the dashboard.
      await tester.pump(const Duration(seconds: 61));
      user.emailVerified = true;
      await app.tap(find.byKey(_k('verify.resend')));
      expect(app.location, Routes.home);
      await app.dispose();
    });

    testWidgets('after a reload the verify page asks to sign in again', (
      tester,
    ) async {
      final app = await pumpOwnerApp(tester);
      await app.go('${Routes.verifyEmail}?email=a@b.co');
      expect(find.byKey(_k('verify.resend')), findsNothing);
      expect(find.text('To get a new link, sign in again.'), findsOneWidget);
      await app.tap(find.byKey(_k('verify.back')));
      expect(app.location, Routes.signIn);
    });

    testWidgets('an admin account is refused in the owner app', (tester) async {
      final admin = FakeUser(
        uid: 'a1',
        email: 'admin@example.com',
        password: 'Secret123!',
        emailVerified: true,
        claims: {'role': 'platformAdmin'},
      );
      final app = await pumpOwnerApp(tester, users: [admin]);
      await app.enter(_k('signIn.email'), 'admin@example.com');
      await app.enter(_k('signIn.password'), 'Secret123!');
      await app.tap(find.byKey(_k('signIn.submit')));
      expect(app.auth.current, isNull);
      expect(
        find.text(
          'This is an administrator account. Use the admin app to sign in.',
        ),
        findsOneWidget,
      );
    });
  });

  group('finishing setup', () {
    testWidgets('without a restaurant, asks for the details and creates it', (
      tester,
    ) async {
      final user = verifiedOwner()..claims = {};
      final app = await pumpOwnerApp(tester, signedIn: user);
      expect(app.location, Routes.signUp);
      expect(find.text('Finish setting up'), findsOneWidget);
      expect(find.byKey(_k('signUp.email')), findsNothing);
      expect(find.byKey(_k('signUp.password')), findsNothing);

      await app.enter(_k('signUp.restaurantName'), 'Spice Garden');
      await app.choose(_k('signUp.businessType'), 'Café');
      await app.enter(_k('signUp.ownerName'), 'Priya');
      await app.enterLabelled('Mobile number', '9876543210');
      await app.tap(find.byKey(_k('signUp.submit')));

      expect(app.registration.calls.last!.businessType, BusinessType.cafe);
      expect(app.location, Routes.home);
    });

    testWidgets('a verified user whose claims were lost is resumed', (
      tester,
    ) async {
      final app = await pumpOwnerApp(tester, signedIn: verifiedOwner());
      // Claims vanish from the token (e.g. a failed claim update) but the
      // restaurant exists: the callable re-applies them.
      final user = app.auth.current!;
      final rid = user.claims['restaurantId'];
      user.claims = {'restaurantId': rid};
      app.auth.emit();
      await tester.pumpAndSettle();
      expect(app.location, Routes.home);
      expect(app.registration.calls, [null]);
    });
  });

  testWidgets(
    'forgot password sends a link and does not reveal accounts (FR-006)',
    (tester) async {
      final app = await pumpOwnerApp(tester);
      await app.enter(_k('signIn.email'), 'someone@example.com');
      await app.tap(find.text('Forgot password?'));
      expect(app.location, startsWith(Routes.forgotPassword));
      await app.tap(find.byKey(_k('forgot.submit')));
      expect(app.auth.passwordResetsSent, ['someone@example.com']);
      expect(
        find.text(
          "If an account exists for someone@example.com, we've sent a reset link. It works once and expires in 1 hour.",
        ),
        findsOneWidget,
      );
    },
  );

  group('screens at 360, 768 and 1280 px', () {
    final pages = {
      Routes.signIn: 'Sign in',
      Routes.signUp: 'Create your account',
      '${Routes.verifyEmail}?email=a@b.co&reason=sent': 'Check your email',
      Routes.forgotPassword: 'Reset your password',
    };
    for (final width in [360.0, 768.0, 1280.0]) {
      testWidgets('auth pages at ${width.toInt()} px', (tester) async {
        final app = await pumpOwnerApp(tester, width: width);
        for (final MapEntry(key: path, value: title) in pages.entries) {
          await app.go(path);
          expect(find.text(title), findsWidgets, reason: path);
          expect(tester.takeException(), isNull, reason: path);
          final brand = find.byKey(AuthLayout.brandPanelKey);
          final wide =
              width >= 1024 && (path == Routes.signIn || path == Routes.signUp);
          expect(brand, wide ? findsOneWidget : findsNothing, reason: path);
          // Form never wider than 480 px.
          final field = find.byType(TextField);
          if (field.evaluate().isNotEmpty) {
            expect(
              tester.getSize(field.first).width,
              lessThanOrEqualTo(AuthLayout.maxFormWidth),
            );
          }
          // Touch targets.
          for (final b in find.byType(FilledButton).evaluate()) {
            expect(
              tester.getSize(find.byWidget(b.widget)).height,
              greaterThanOrEqualTo(48),
            );
          }
        }
        await app.dispose();
      });
    }
  });
}
