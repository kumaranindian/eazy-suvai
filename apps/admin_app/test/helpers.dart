import 'package:admin_app/app.dart';
import 'package:admin_app/features/auth/data/admin_mfa_repository.dart';
import 'package:admin_app/router/app_router.dart';
import 'package:core/core.dart';
import 'package:core/testing.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

const validCode = '123456';

class _Challenge implements MfaChallenge {
  _Challenge(this.user);
  final FakeUser user;
}

/// TOTP behaviour on top of [FakeAuthRepository]. The right code is
/// [validCode].
class FakeAdminMfaRepository implements AdminMfaRepository {
  FakeAdminMfaRepository(this.auth);

  final FakeAuthRepository auth;

  @override
  Future<MfaChallenge?> signIn(String email, String password) async {
    final u = auth.users[email.trim().toLowerCase()];
    if (u != null && u.totpEnrolled && u.password == password) {
      return _Challenge(u);
    }
    await auth.signIn(email, password);
    return null;
  }

  @override
  Future<void> resolve(MfaChallenge challenge, String code) async {
    if (code != validCode) {
      throw FirebaseAuthException(code: 'invalid-verification-code');
    }
    auth.current = (challenge as _Challenge).user;
    auth.secondFactor = 'totp';
    auth.emit();
  }

  @override
  Future<TotpEnrollment> startEnrollment({
    required String accountName,
  }) async => TotpEnrollment(
    secretKey: 'JBSWY3DPEHPK3PXP',
    qrCodeUrl:
        'otpauth://totp/EazySuvai%20Admin:$accountName?secret=JBSWY3DPEHPK3PXP',
  );

  @override
  Future<void> finishEnrollment(TotpEnrollment enrollment, String code) async {
    if (code != validCode) {
      throw FirebaseAuthException(code: 'invalid-verification-code');
    }
    auth.current!.totpEnrolled = true;
  }
}

FakeUser adminUser({bool totp = false, bool verified = true}) => FakeUser(
  uid: 'a1',
  email: 'admin@example.com',
  password: 'Secret123!',
  emailVerified: verified,
  claims: {'role': 'platformAdmin'},
  totpEnrolled: totp,
);

class AdminTestApp {
  AdminTestApp(this.tester, this.auth);

  final WidgetTester tester;
  final FakeAuthRepository auth;

  GoRouter get router => ProviderScope.containerOf(
    tester.element(find.byType(AdminApp)),
  ).read(appRouterProvider);

  String get location =>
      router.routerDelegate.currentConfiguration.uri.toString();

  Future<void> go(String path) async {
    router.go(path);
    await tester.pumpAndSettle();
  }

  Future<void> enter(String key, String text) async {
    final f = find.byKey(ValueKey(key));
    await tester.ensureVisible(f);
    await tester.enterText(f, text);
    await tester.pump();
  }

  Future<void> tap(Finder f) async {
    await tester.ensureVisible(f.first);
    await tester.pumpAndSettle();
    await tester.tap(f.first);
    await tester.pumpAndSettle();
  }

  Future<void> signIn({String email = 'admin@example.com'}) async {
    await enter('admin.email', email);
    await enter('admin.password', 'Secret123!');
    await tap(find.byKey(const ValueKey('admin.submit')));
  }
}

Future<AdminTestApp> pumpAdminApp(
  WidgetTester tester, {
  double width = 1280,
  List<FakeUser> users = const [],
  FakeUser? signedIn,
  String? secondFactor,
  bool mfaRequired = true,
}) async {
  tester.view.devicePixelRatio = 1;
  tester.view.physicalSize = Size(width, 900);
  addTearDown(tester.view.reset);
  final auth = FakeAuthRepository(users: [...users, ?signedIn]);
  if (signedIn != null) {
    auth.current = signedIn;
    auth.secondFactor = secondFactor;
  }
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        authRepositoryProvider.overrideWithValue(auth),
        adminMfaRepositoryProvider.overrideWithValue(
          FakeAdminMfaRepository(auth),
        ),
        adminMfaRequiredProvider.overrideWithValue(mfaRequired),
      ],
      child: const AdminApp(),
    ),
  );
  await tester.pumpAndSettle();
  return AdminTestApp(tester, auth);
}
