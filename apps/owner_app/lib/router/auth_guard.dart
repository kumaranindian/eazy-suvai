import 'package:core/core.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'app_router.dart';

/// Routes a signed-out or unverified user may open.
const publicRoutes = {
  Routes.signIn,
  Routes.signUp,
  Routes.verifyEmail,
  Routes.forgotPassword,
};

/// Redirect hook for every navigation (M01).
///
/// * Session still loading → splash (remembers where the user was going).
/// * Signed out → `/sign-in?from=…`.
/// * Signed in but email not verified → `/verify-email` (FR-091). The
///   sign-in flow signs such users out at once; this covers the brief window
///   and the middle of sign-up.
/// * Verified but no owner claims → `/finishing-setup` (or `/sign-up` to
///   add restaurant details).
/// * Verified owner on an auth page → `from` or home.
///
/// Return a path to redirect, or `null` to continue.
String? authGuard(Ref ref, GoRouterState state) =>
    ownerRedirect(ref.read(authSessionProvider), state.uri);

/// Pure version of [authGuard], for tests.
String? ownerRedirect(AsyncValue<AuthSession?> session, Uri uri) {
  final loc = uri.path;
  final from = safeFromParam(uri.queryParameters['from']);

  if (session.isLoading && !session.hasValue) {
    if (loc == Routes.splash) return null;
    return _withFrom(Routes.splash, uri.toString());
  }

  final s = session.hasError ? null : session.value;
  if (s == null) {
    if (publicRoutes.contains(loc)) return null;
    final target = loc == Routes.splash ? from : uri.toString();
    return _withFrom(Routes.signIn, target);
  }
  if (!s.emailVerified) {
    return publicRoutes.contains(loc) ? null : Routes.verifyEmail;
  }
  if (!s.isOwner) {
    return loc == Routes.finishingSetup || loc == Routes.signUp
        ? null
        : Routes.finishingSetup;
  }
  if (publicRoutes.contains(loc) ||
      loc == Routes.finishingSetup ||
      loc == Routes.splash) {
    return from ?? Routes.home;
  }
  return null;
}

String _withFrom(String path, String? target) {
  if (target == null || target == Routes.home || target == path) return path;
  return Uri(path: path, queryParameters: {'from': target}).toString();
}
