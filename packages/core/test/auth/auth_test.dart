import 'package:cloud_functions/cloud_functions.dart';
import 'package:core/core.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../test_app.dart';

void main() {
  final l10n = lookupCoreLocalizations(const Locale('en'));

  group('AuthSession.fromClaims', () {
    test('reads owner claims', () {
      final s = AuthSession.fromClaims('u1', {
        'email': 'a@b.co',
        'email_verified': true,
        'role': 'owner',
        'restaurantId': 'r1',
      });
      expect(s.isOwner, isTrue);
      expect(s.emailVerified, isTrue);
      expect(s.email, 'a@b.co');
    });

    test('unverified, no claims', () {
      final s = AuthSession.fromClaims('u1', {'email_verified': false});
      expect(s.isOwner, isFalse);
      expect(s.emailVerified, isFalse);
      expect(s.role, isNull);
    });

    test('owner role without restaurant is not an owner yet', () {
      final s = AuthSession.fromClaims('u1', {
        'role': 'owner',
        'restaurantId': '',
      });
      expect(s.isOwner, isFalse);
    });

    test('admin second factor from the firebase claim', () {
      final s = AuthSession.fromClaims('a1', {
        'role': 'platformAdmin',
        'firebase': {'sign_in_second_factor': 'totp'},
      });
      expect(s.isAdmin, isTrue);
      expect(s.signedInWithTotp, isTrue);
      expect(AuthSession.fromClaims('a1', {'role': 'hacker'}).role, isNull);
    });
  });

  group('error messages', () {
    test('Firebase auth codes map to localized messages', () {
      final cases = {
        'invalid-credential': l10n.authErrorInvalidCredential,
        'wrong-password': l10n.authErrorInvalidCredential,
        'user-not-found': l10n.authErrorInvalidCredential,
        'email-already-in-use': l10n.authErrorEmailAlreadyInUse,
        'weak-password': l10n.authErrorWeakPassword,
        'password-does-not-meet-requirements': l10n.authErrorWeakPassword,
        'too-many-requests': l10n.authErrorTooManyRequests,
        'network-request-failed': l10n.errorNetwork,
        'expired-action-code': l10n.authErrorExpiredActionCode,
        'invalid-verification-code': l10n.authErrorInvalidMfaCode,
        'unverified-email': l10n.authErrorUnverifiedEmail,
        'user-disabled': l10n.authErrorUserDisabled,
        'something-new': l10n.errorUnknown,
      };
      cases.forEach((code, message) {
        expect(
          l10n.messageForError(FirebaseAuthException(code: code)),
          message,
          reason: code,
        );
      });
    });

    test('every AuthErrorCode has a message', () {
      for (final c in AuthErrorCode.values) {
        expect(l10n.authMessageFor(c), isNotEmpty);
      }
    });

    test('callable errors use details.code', () {
      final e = FirebaseFunctionsException(
        message: 'x',
        code: 'failed-precondition',
        details: {'code': 'registration-incomplete'},
      );
      expect(l10n.messageForError(e), l10n.errorRegistrationIncomplete);
      expect(
        l10n.messageForError(
          FirebaseFunctionsException(message: 'x', code: 'unavailable'),
        ),
        l10n.errorNetwork,
      );
      expect(
        l10n.messageForError(const AuthFailure(AuthErrorCode.emailNotVerified)),
        l10n.errorEmailNotVerified,
      );
      expect(l10n.messageForError(StateError('x')), l10n.errorUnknown);
    });
  });

  test('safeFromParam allows only internal paths', () {
    expect(safeFromParam('/menu'), '/menu');
    expect(safeFromParam('https://evil.com'), isNull);
    expect(safeFromParam('//evil.com'), isNull);
    expect(safeFromParam(r'/\evil.com'), isNull);
    expect(safeFromParam(null), isNull);
  });

  group('AuthLayout', () {
    Widget layout({bool card = false}) => AuthLayout(
      logo: (context, h) =>
          SizedBox(height: h, width: h, child: const Placeholder()),
      tagline: 'Taste meets technology',
      title: 'Sign in',
      card: card,
      child: const TextField(),
    );

    for (final (width, panel) in [
      (360.0, false),
      (768.0, false),
      (1280.0, true),
    ]) {
      testWidgets('at ${width.toInt()} px brand panel: $panel', (tester) async {
        await setSurfaceWidth(tester, width);
        await tester.pumpWidget(testApp(layout()));
        expect(
          find.byKey(AuthLayout.brandPanelKey),
          panel ? findsOneWidget : findsNothing,
        );
        expect(find.text('Sign in'), findsOneWidget);
        expect(
          tester.getSize(find.byType(TextField)).width,
          lessThanOrEqualTo(AuthLayout.maxFormWidth),
        );
        expect(tester.takeException(), isNull);
      });
    }

    testWidgets('card mode never shows the brand panel', (tester) async {
      await setSurfaceWidth(tester, 1280);
      await tester.pumpWidget(testApp(layout(card: true)));
      expect(find.byKey(AuthLayout.brandPanelKey), findsNothing);
      expect(find.byType(Card), findsOneWidget);
    });
  });

  testWidgets('password field toggles visibility with a labelled button', (
    tester,
  ) async {
    await tester.pumpWidget(
      testApp(const Scaffold(body: AppPasswordField(label: 'Password'))),
    );
    expect(
      tester.widget<EditableText>(find.byType(EditableText)).obscureText,
      isTrue,
    );
    await tester.tap(find.byTooltip('Show password'));
    await tester.pump();
    expect(
      tester.widget<EditableText>(find.byType(EditableText)).obscureText,
      isFalse,
    );
    expect(find.byTooltip('Hide password'), findsOneWidget);
  });
}
