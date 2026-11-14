import 'package:core/core.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/admin_mfa_repository.dart';

/// Admin sign-in flows (M01, FR-084).
class AdminAuthService {
  AdminAuthService(this.ref);

  final Ref ref;

  AuthRepository get _auth => ref.read(authRepositoryProvider);
  AdminMfaRepository get _mfa => ref.read(adminMfaRepositoryProvider);

  /// Step 1. Returns a TOTP challenge if the admin has enrolled one. A
  /// non-admin account is signed out. An admin without a factor stays
  /// signed in; the router sends them to enrolment.
  Future<MfaChallenge?> signIn(String email, String password) async {
    final challenge = await _mfa.signIn(email, password);
    if (challenge != null) return challenge;
    await _checkAdmin();
    return null;
  }

  /// Step 2: the 6-digit code.
  Future<void> verifyCode(MfaChallenge challenge, String code) async {
    await _mfa.resolve(challenge, code.trim());
    await _checkAdmin();
  }

  Future<TotpEnrollment> startEnrollment() async {
    final email = _auth.currentEmail ?? '';
    return _mfa.startEnrollment(accountName: email);
  }

  /// Enrols the factor, then signs out: the next sign-in asks for the code,
  /// which gives a token with `sign_in_second_factor: totp`.
  Future<void> finishEnrollment(TotpEnrollment enrollment, String code) async {
    await _mfa.finishEnrollment(enrollment, code.trim());
    await _auth.signOut();
  }

  Future<void> signOut() => _auth.signOut();

  Future<void> _checkAdmin() async {
    final session = await _auth.refreshSession();
    if (session == null || !session.isAdmin) {
      await _auth.signOut();
      throw const AuthFailure(AuthErrorCode.notAdmin);
    }
    if (!session.emailVerified) {
      // TOTP enrolment needs a verified email.
      await _auth.sendEmailVerification();
      await _auth.signOut();
      throw const AuthFailure(AuthErrorCode.unverifiedEmail);
    }
  }
}

final adminAuthServiceProvider = Provider<AdminAuthService>(
  AdminAuthService.new,
);
