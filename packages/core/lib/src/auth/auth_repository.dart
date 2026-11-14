import 'dart:async';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'auth_session.dart';

/// Email and password authentication shared by both apps.
///
/// Errors are thrown as [FirebaseAuthException] (map them with
/// `CoreLocalizations.messageForError`). The admin app adds TOTP on top.
abstract class AuthRepository {
  /// The current session, re-emitted on sign-in, sign-out, token refresh and
  /// [refreshSession].
  Stream<AuthSession?> sessionChanges();

  /// Signs in and returns the session from a freshly minted ID token, so
  /// claims and `email_verified` are current.
  Future<AuthSession> signIn(String email, String password);

  /// Creates and signs in a new email and password account (FR-001).
  Future<void> createAccount(String email, String password);

  /// Sends the verification email to the signed-in user (FR-091).
  Future<void> sendEmailVerification();

  /// Sends a password reset link (FR-006). Succeeds silently for unknown
  /// addresses when email enumeration protection is on.
  Future<void> sendPasswordReset(String email);

  /// Reloads the user and forces a new ID token, for example after
  /// `completeRegistration` set the claims.
  Future<AuthSession?> refreshSession();

  Future<void> signOut();

  /// Email of the signed-in Firebase user, verified or not.
  String? get currentEmail;
}

/// [AuthRepository] backed by Firebase Authentication.
class FirebaseAuthRepository implements AuthRepository {
  FirebaseAuthRepository(this.auth);

  final FirebaseAuth auth;
  final _manual = StreamController<AuthSession?>.broadcast();

  static Future<AuthSession?> sessionOf(
    User? user, {
    bool force = false,
  }) async {
    if (user == null) return null;
    final token = await user.getIdTokenResult(force);
    return AuthSession.fromClaims(
      user.uid,
      token.claims ?? const {},
      email: user.email,
      secondFactor: token.signInSecondFactor,
    );
  }

  @override
  Stream<AuthSession?> sessionChanges() {
    late StreamController<AuthSession?> out;
    StreamSubscription<AuthSession?>? a;
    StreamSubscription<AuthSession?>? b;
    out = StreamController<AuthSession?>(
      onListen: () {
        a = auth
            .idTokenChanges()
            .asyncMap(sessionOf)
            .listen(out.add, onError: out.addError);
        b = _manual.stream.listen(out.add);
      },
      onCancel: () async {
        await a?.cancel();
        await b?.cancel();
      },
    );
    return out.stream.distinct();
  }

  @override
  Future<AuthSession> signIn(String email, String password) async {
    final cred = await auth.signInWithEmailAndPassword(
      email: email.trim(),
      password: password,
    );
    final session = await sessionOf(cred.user, force: true);
    _manual.add(session);
    return session!;
  }

  @override
  Future<void> createAccount(String email, String password) => auth
      .createUserWithEmailAndPassword(email: email.trim(), password: password);

  @override
  Future<void> sendEmailVerification() async {
    final user = auth.currentUser;
    if (user == null) {
      throw FirebaseAuthException(code: 'user-not-found');
    }
    await user.sendEmailVerification();
  }

  @override
  Future<void> sendPasswordReset(String email) =>
      auth.sendPasswordResetEmail(email: email.trim());

  @override
  Future<AuthSession?> refreshSession() async {
    final user = auth.currentUser;
    if (user == null) return null;
    await user.reload();
    final session = await sessionOf(auth.currentUser, force: true);
    _manual.add(session);
    return session;
  }

  @override
  Future<void> signOut() => auth.signOut();

  @override
  String? get currentEmail => auth.currentUser?.email;
}

/// Firebase Auth instance. Override in tests.
final firebaseAuthProvider = Provider<FirebaseAuth>(
  (ref) => FirebaseAuth.instance,
);

/// The app's [AuthRepository]. Override with a fake in widget tests.
final authRepositoryProvider = Provider<AuthRepository>(
  (ref) => FirebaseAuthRepository(ref.watch(firebaseAuthProvider)),
);

/// The current [AuthSession], or `null` when signed out.
final authSessionProvider = StreamProvider<AuthSession?>(
  (ref) => ref.watch(authRepositoryProvider).sessionChanges(),
);
