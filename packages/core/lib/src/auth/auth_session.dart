import 'package:flutter/foundation.dart';

/// Roles set as custom claims by Cloud Functions (architecture §5).
enum UserRole {
  owner,
  platformAdmin;

  static UserRole? fromClaim(Object? value) => switch (value) {
    'owner' => UserRole.owner,
    'platformAdmin' => UserRole.platformAdmin,
    _ => null,
  };
}

/// The signed-in user as the apps see it: the ID token's claims.
///
/// Built from the ID token, not the `User` object, so it matches what
/// security rules and Functions see (`email_verified`, `role`,
/// `restaurantId`, `firebase.sign_in_second_factor`).
@immutable
class AuthSession {
  const AuthSession({
    required this.uid,
    required this.email,
    required this.emailVerified,
    this.role,
    this.restaurantId,
    this.secondFactor,
  });

  /// Reads the session from ID token [claims].
  factory AuthSession.fromClaims(
    String uid,
    Map<String, dynamic> claims, {
    String? email,
    String? secondFactor,
  }) {
    final rid = claims['restaurantId'];
    final firebase = claims['firebase'];
    final factor =
        secondFactor ??
        (firebase is Map ? firebase['sign_in_second_factor'] as String? : null);
    return AuthSession(
      uid: uid,
      email: email ?? claims['email'] as String?,
      emailVerified: claims['email_verified'] == true,
      role: UserRole.fromClaim(claims['role']),
      restaurantId: rid is String && rid.isNotEmpty ? rid : null,
      secondFactor: factor,
    );
  }

  final String uid;
  final String? email;

  /// `email_verified` in the token (FR-091).
  final bool emailVerified;

  final UserRole? role;

  /// Tenant id from the `restaurantId` claim (owners only).
  final String? restaurantId;

  /// Second factor used at sign-in, for example `totp` (FR-084).
  final String? secondFactor;

  /// Owner claims are present (set by `completeRegistration`).
  bool get isOwner => role == UserRole.owner && restaurantId != null;

  bool get isAdmin => role == UserRole.platformAdmin;

  bool get signedInWithTotp => secondFactor == 'totp';

  @override
  bool operator ==(Object other) =>
      other is AuthSession &&
      other.uid == uid &&
      other.email == email &&
      other.emailVerified == emailVerified &&
      other.role == role &&
      other.restaurantId == restaurantId &&
      other.secondFactor == secondFactor;

  @override
  int get hashCode =>
      Object.hash(uid, email, emailVerified, role, restaurantId, secondFactor);

  @override
  String toString() =>
      'AuthSession($uid, verified: $emailVerified, role: ${role?.name}, '
      'restaurantId: $restaurantId, secondFactor: $secondFactor)';
}
