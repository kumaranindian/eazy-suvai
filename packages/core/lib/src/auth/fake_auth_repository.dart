import 'dart:async';

import 'package:firebase_auth/firebase_auth.dart';

import 'auth_repository.dart';
import 'auth_session.dart';

/// A user in [FakeAuthRepository].
class FakeUser {
  FakeUser({
    required this.uid,
    required this.email,
    required this.password,
    this.emailVerified = false,
    this.claims = const {},
    this.totpEnrolled = false,
  });

  final String uid;
  final String email;
  String password;
  bool emailVerified;
  Map<String, Object?> claims;
  bool totpEnrolled;
}

/// In-memory [AuthRepository] for widget tests. Throws the same
/// [FirebaseAuthException] codes as Firebase (with email enumeration
/// protection on).
class FakeAuthRepository implements AuthRepository {
  FakeAuthRepository({List<FakeUser> users = const []}) {
    for (final u in users) {
      this.users[u.email] = u;
    }
  }

  final Map<String, FakeUser> users = {};
  final _changes = StreamController<AuthSession?>.broadcast();
  FakeUser? current;
  String? secondFactor;
  final List<String> verificationEmailsSent = [];
  final List<String> passwordResetsSent = [];
  int _nextUid = 1;

  /// Makes the next call throw this.
  Object? nextError;

  void _maybeThrow() {
    final e = nextError;
    if (e != null) {
      nextError = null;
      throw e;
    }
  }

  AuthSession? get session {
    final u = current;
    if (u == null) return null;
    return AuthSession.fromClaims(
      u.uid,
      {...u.claims, 'email_verified': u.emailVerified},
      email: u.email,
      secondFactor: secondFactor,
    );
  }

  void emit() => _changes.add(session);

  @override
  Stream<AuthSession?> sessionChanges() async* {
    yield session;
    yield* _changes.stream;
  }

  @override
  Future<AuthSession> signIn(String email, String password) async {
    _maybeThrow();
    final u = users[email.trim().toLowerCase()];
    if (u == null || u.password != password) {
      throw FirebaseAuthException(code: 'invalid-credential');
    }
    current = u;
    secondFactor = null;
    emit();
    return session!;
  }

  @override
  Future<void> createAccount(String email, String password) async {
    _maybeThrow();
    final key = email.trim().toLowerCase();
    if (users.containsKey(key)) {
      throw FirebaseAuthException(code: 'email-already-in-use');
    }
    if (password.length < 6) {
      throw FirebaseAuthException(code: 'weak-password');
    }
    final u = FakeUser(uid: 'uid${_nextUid++}', email: key, password: password);
    users[key] = u;
    current = u;
    emit();
  }

  @override
  Future<void> sendEmailVerification() async {
    _maybeThrow();
    final u = current;
    if (u == null) throw FirebaseAuthException(code: 'user-not-found');
    verificationEmailsSent.add(u.email);
  }

  @override
  Future<void> sendPasswordReset(String email) async {
    _maybeThrow();
    passwordResetsSent.add(email.trim().toLowerCase());
  }

  @override
  Future<AuthSession?> refreshSession() async {
    _maybeThrow();
    emit();
    return session;
  }

  @override
  Future<void> signOut() async {
    current = null;
    secondFactor = null;
    emit();
  }

  @override
  String? get currentEmail => current?.email;
}
