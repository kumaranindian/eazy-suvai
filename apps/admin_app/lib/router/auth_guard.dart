import 'package:core/core.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../features/auth/data/admin_mfa_repository.dart';
import 'app_router.dart';

/// Redirect hook for every navigation (M01, FR-084).
///
/// * Loading → splash. Signed out → `/sign-in`.
/// * Not a platform admin, or email not verified → `/sign-in` (the sign-in
///   flow signs them out and explains why).
/// * Admin without a TOTP sign-in → `/mfa-setup` to enrol, unless MFA is
///   relaxed on the emulators.
/// * Admin with TOTP on an auth page → `from` or the dashboard.
String? authGuard(Ref ref, GoRouterState state) => adminRedirect(
  ref.read(authSessionProvider),
  state.uri,
  mfaRequired: ref.read(adminMfaRequiredProvider),
);

/// Pure version of [authGuard], for tests.
String? adminRedirect(
  AsyncValue<AuthSession?> session,
  Uri uri, {
  required bool mfaRequired,
}) {
  final loc = uri.path;
  final from = safeFromParam(uri.queryParameters['from']);

  if (session.isLoading && !session.hasValue) {
    if (loc == Routes.splash) return null;
    return _withFrom(Routes.splash, uri.toString());
  }
  final s = session.hasError ? null : session.value;
  if (s == null || !s.isAdmin || !s.emailVerified) {
    if (loc == Routes.signIn) return null;
    return _withFrom(
      Routes.signIn,
      loc == Routes.splash ? from : uri.toString(),
    );
  }
  if (mfaRequired && !s.signedInWithTotp) {
    return loc == Routes.mfaSetup ? null : Routes.mfaSetup;
  }
  if (loc == Routes.signIn || loc == Routes.mfaSetup || loc == Routes.splash) {
    return from ?? Routes.dashboard;
  }
  return null;
}

String _withFrom(String path, String? target) {
  if (target == null ||
      target == Routes.dashboard ||
      target == path ||
      Uri.parse(target).path == Routes.mfaSetup) {
    return path;
  }
  return Uri(path: path, queryParameters: {'from': target}).toString();
}
