import 'package:core/core.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:owner_app/router/app_router.dart';
import 'package:owner_app/router/auth_guard.dart';

void main() {
  const owner = AuthSession(
    uid: 'u1',
    email: 'a@b.co',
    emailVerified: true,
    role: UserRole.owner,
    restaurantId: 'r1',
  );
  const unverifiedOwner = AuthSession(
    uid: 'u1',
    email: 'a@b.co',
    emailVerified: false,
    role: UserRole.owner,
    restaurantId: 'r1',
  );
  const noClaims = AuthSession(uid: 'u1', email: 'a@b.co', emailVerified: true);

  String? at(AsyncValue<AuthSession?> s, String uri) =>
      ownerRedirect(s, Uri.parse(uri));

  test('while loading, goes to splash and remembers the target', () {
    const loading = AsyncLoading<AuthSession?>();
    expect(at(loading, '/menu'), '/splash?from=%2Fmenu');
    expect(at(loading, '/'), '/splash');
    expect(at(loading, '/splash?from=/menu'), isNull);
  });

  test('signed out: protected routes go to sign-in with from', () {
    const out = AsyncData<AuthSession?>(null);
    expect(at(out, '/'), Routes.signIn);
    expect(at(out, '/menu'), '/sign-in?from=%2Fmenu');
    expect(at(out, '/splash?from=/settings'), '/sign-in?from=%2Fsettings');
    expect(at(out, '/finishing-setup'), '/sign-in?from=%2Ffinishing-setup');
    for (final r in publicRoutes) {
      expect(at(out, r), isNull, reason: r);
    }
  });

  test('auth errors count as signed out', () {
    final err = AsyncError<AuthSession?>(Exception('x'), StackTrace.empty);
    expect(at(err, '/menu'), '/sign-in?from=%2Fmenu');
  });

  test('unverified: only public routes, else verify page (FR-091)', () {
    const s = AsyncData<AuthSession?>(unverifiedOwner);
    expect(at(s, '/'), Routes.verifyEmail);
    expect(at(s, '/menu'), Routes.verifyEmail);
    expect(at(s, Routes.signUp), isNull);
    expect(at(s, Routes.verifyEmail), isNull);
  });

  test('verified without claims: finishing setup or complete sign-up', () {
    const s = AsyncData<AuthSession?>(noClaims);
    expect(at(s, '/'), Routes.finishingSetup);
    expect(at(s, Routes.signIn), Routes.finishingSetup);
    expect(at(s, Routes.finishingSetup), isNull);
    expect(at(s, Routes.signUp), isNull);
  });

  test('verified owner: auth pages go to from or home', () {
    const s = AsyncData<AuthSession?>(owner);
    expect(at(s, '/menu'), isNull);
    expect(at(s, Routes.signIn), Routes.home);
    expect(at(s, '/sign-in?from=/menu'), '/menu');
    expect(at(s, '/sign-in?from=https://evil.com'), Routes.home);
    expect(at(s, Routes.finishingSetup), Routes.home);
    expect(at(s, '/splash?from=/share'), '/share');
  });

  test('admin accounts never reach the owner dashboard', () {
    const admin = AsyncData<AuthSession?>(
      AuthSession(
        uid: 'a1',
        email: 'x@y.co',
        emailVerified: true,
        role: UserRole.platformAdmin,
      ),
    );
    expect(at(admin, '/'), Routes.finishingSetup);
  });
}
