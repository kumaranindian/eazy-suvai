import 'package:cloud_functions/cloud_functions.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../errors/app_error.dart';
import '../l10n/generated/core_localizations.dart';

/// Sign-in and account errors shown to users.
enum AuthErrorCode {
  invalidEmail,

  /// Wrong email or password. With email enumeration protection on, Firebase
  /// reports both as `invalid-credential`, so the message never says which.
  invalidCredential,
  userDisabled,
  emailAlreadyInUse,
  weakPassword,
  tooManyRequests,
  network,
  requiresRecentLogin,
  expiredActionCode,
  invalidActionCode,
  invalidMfaCode,
  mfaSessionExpired,

  /// MFA enrolment needs a verified email.
  unverifiedEmail,

  /// FR-091: the owner tried to log in before verifying.
  emailNotVerified,

  /// An owner account used in the admin app.
  notAdmin,

  /// An admin account used in the owner app.
  adminAccount,
  operationNotAllowed,
  unknown;

  /// Maps a Firebase Auth error code.
  static AuthErrorCode fromFirebase(String code) => switch (code) {
    'invalid-email' => invalidEmail,
    'invalid-credential' ||
    'wrong-password' ||
    'user-not-found' ||
    'INVALID_LOGIN_CREDENTIALS' ||
    'invalid-login-credentials' => invalidCredential,
    'user-disabled' => userDisabled,
    'email-already-in-use' || 'credential-already-in-use' => emailAlreadyInUse,
    'weak-password' || 'password-does-not-meet-requirements' => weakPassword,
    'too-many-requests' || 'quota-exceeded' => tooManyRequests,
    'network-request-failed' => network,
    'requires-recent-login' || 'user-token-expired' => requiresRecentLogin,
    'expired-action-code' => expiredActionCode,
    'invalid-action-code' => invalidActionCode,
    'invalid-verification-code' || 'missing-code' => invalidMfaCode,
    'missing-multi-factor-session' ||
    'invalid-multi-factor-session' ||
    'totp-challenge-timeout' ||
    'code-expired' => mfaSessionExpired,
    'unverified-email' => unverifiedEmail,
    'operation-not-allowed' ||
    'admin-restricted-operation' => operationNotAllowed,
    _ => unknown,
  };
}

/// An auth error raised by the apps themselves (not by Firebase).
class AuthFailure implements Exception {
  const AuthFailure(this.code);

  final AuthErrorCode code;

  @override
  String toString() => 'AuthFailure(${code.name})';
}

extension AuthErrorMessage on CoreLocalizations {
  String authMessageFor(AuthErrorCode code) => switch (code) {
    AuthErrorCode.invalidEmail => authErrorInvalidEmail,
    AuthErrorCode.invalidCredential => authErrorInvalidCredential,
    AuthErrorCode.userDisabled => authErrorUserDisabled,
    AuthErrorCode.emailAlreadyInUse => authErrorEmailAlreadyInUse,
    AuthErrorCode.weakPassword => authErrorWeakPassword,
    AuthErrorCode.tooManyRequests => authErrorTooManyRequests,
    AuthErrorCode.network => errorNetwork,
    AuthErrorCode.requiresRecentLogin => authErrorRequiresRecentLogin,
    AuthErrorCode.expiredActionCode => authErrorExpiredActionCode,
    AuthErrorCode.invalidActionCode => authErrorInvalidActionCode,
    AuthErrorCode.invalidMfaCode => authErrorInvalidMfaCode,
    AuthErrorCode.mfaSessionExpired => authErrorMfaSessionExpired,
    AuthErrorCode.unverifiedEmail => authErrorUnverifiedEmail,
    AuthErrorCode.emailNotVerified => errorEmailNotVerified,
    AuthErrorCode.notAdmin => authErrorNotAdmin,
    AuthErrorCode.adminAccount => authErrorAdminAccount,
    AuthErrorCode.operationNotAllowed => authErrorOperationNotAllowed,
    AuthErrorCode.unknown => errorUnknown,
  };

  /// A localized message for any error thrown by auth or a callable.
  String messageForError(Object error) {
    if (error is AuthFailure) return authMessageFor(error.code);
    if (error is FirebaseAuthException) {
      return authMessageFor(AuthErrorCode.fromFirebase(error.code));
    }
    if (error is FirebaseFunctionsException) {
      return messageFor(appErrorCodeOfFunctions(error));
    }
    // Firestore and Storage errors (for example a refused draft write).
    if (error is FirebaseException) {
      return switch (error.code) {
        'permission-denied' => errorPermissionDenied,
        'unavailable' || 'deadline-exceeded' => errorNetwork,
        'not-found' => errorNotFound,
        _ => errorUnknown,
      };
    }
    return errorUnknown;
  }
}

/// The [AppErrorCode] carried by a callable error (`details.code`), or a
/// best guess from the gRPC status.
AppErrorCode appErrorCodeOfFunctions(FirebaseFunctionsException error) {
  final details = error.details;
  if (details is Map && details['code'] is String) {
    return AppErrorCode.fromWire(details['code'] as String);
  }
  return switch (error.code) {
    'unavailable' || 'deadline-exceeded' => AppErrorCode.network,
    'unauthenticated' => AppErrorCode.unauthenticated,
    'permission-denied' => AppErrorCode.permissionDenied,
    'invalid-argument' => AppErrorCode.invalidInput,
    'not-found' => AppErrorCode.notFound,
    'already-exists' => AppErrorCode.alreadyExists,
    _ => AppErrorCode.unknown,
  };
}
