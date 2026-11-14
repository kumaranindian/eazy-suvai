import 'package:core/core.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/registration_repository.dart';

/// Credentials kept in memory (never stored) between sign-up or a refused
/// sign-in and the "Check your email" screen, so "Resend" can sign in,
/// send the link and sign out again. Lost on reload by design.
typedef PendingCredentials = ({String email, String password});

class PendingCredentialsNotifier extends Notifier<PendingCredentials?> {
  @override
  PendingCredentials? build() => null;

  void set(PendingCredentials? value) => state = value;
}

final pendingCredentialsProvider =
    NotifierProvider<PendingCredentialsNotifier, PendingCredentials?>(
      PendingCredentialsNotifier.new,
    );

/// What happened when "Resend" was pressed.
enum ResendOutcome { sent, alreadyVerified }

/// Owner account flows (M01): sign-up, sign-in with the FR-091 check,
/// resend verification, password reset, sign-out.
class OwnerAuthService {
  OwnerAuthService(this.ref);

  final Ref ref;

  AuthRepository get _auth => ref.read(authRepositoryProvider);
  RegistrationRepository get _registration =>
      ref.read(registrationRepositoryProvider);

  /// FR-001/002: creates the Firebase account (unless this email is already
  /// signed in from an earlier failed attempt), creates the restaurant,
  /// sends the verification email and signs out (FR-091).
  Future<RegistrationResult> register({
    required String email,
    required String password,
    required RegistrationDetails details,
  }) async {
    final normalized = email.trim().toLowerCase();
    final current = _auth.currentEmail?.toLowerCase();
    if (current != normalized) {
      if (current != null) await _auth.signOut();
      await _auth.createAccount(normalized, password);
    }
    final result = await _registration.complete(details);
    await _auth.sendEmailVerification();
    ref.read(pendingCredentialsProvider.notifier).set((
      email: normalized,
      password: password,
    ));
    await _auth.signOut();
    return result;
  }

  /// For a verified user whose restaurant was never created: creates it and
  /// refreshes the token so the owner claims arrive.
  Future<void> completeForCurrentUser(RegistrationDetails details) async {
    await _registration.complete(details);
    await _auth.refreshSession();
  }

  /// Re-applies claims if the restaurant exists (for example after a failed
  /// claim update), then refreshes the token. Throws
  /// `registration-incomplete` if there is no restaurant.
  Future<void> resumeSetup() async {
    await _registration.complete(null);
    await _auth.refreshSession();
  }

  /// FR-005 and FR-091: unverified users are signed out at once and the
  /// credentials kept for "Resend". Admin accounts are refused here.
  Future<void> signIn(String email, String password) async {
    final session = await _auth.signIn(email, password);
    if (!session.emailVerified) {
      ref.read(pendingCredentialsProvider.notifier).set((
        email: email.trim().toLowerCase(),
        password: password,
      ));
      await _auth.signOut();
      throw const AuthFailure(AuthErrorCode.emailNotVerified);
    }
    if (session.isAdmin) {
      await _auth.signOut();
      throw const AuthFailure(AuthErrorCode.adminAccount);
    }
    ref.read(pendingCredentialsProvider.notifier).set(null);
  }

  /// Sends the verification email again using the pending credentials.
  Future<ResendOutcome> resendVerification() async {
    final creds = ref.read(pendingCredentialsProvider);
    if (creds == null) {
      throw const AuthFailure(AuthErrorCode.requiresRecentLogin);
    }
    final session = await _auth.signIn(creds.email, creds.password);
    if (session.emailVerified) {
      // Verified in the meantime: stay signed in; the router moves on.
      ref.read(pendingCredentialsProvider.notifier).set(null);
      return ResendOutcome.alreadyVerified;
    }
    try {
      await _auth.sendEmailVerification();
    } finally {
      await _auth.signOut();
    }
    return ResendOutcome.sent;
  }

  Future<void> sendPasswordReset(String email) =>
      _auth.sendPasswordReset(email);

  Future<void> signOut() async {
    ref.read(pendingCredentialsProvider.notifier).set(null);
    await _auth.signOut();
  }
}

final ownerAuthServiceProvider = Provider<OwnerAuthService>(
  OwnerAuthService.new,
);
