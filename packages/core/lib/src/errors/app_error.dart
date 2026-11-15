import '../l10n/generated/core_localizations.dart';

/// Stable error codes shared with Cloud Functions.
///
/// Functions throw `HttpsError(code, message, {code: '<AppErrorCode.wire>'})`;
/// see `functions/src/lib/errors.ts`. Keep both lists in sync.
enum AppErrorCode {
  unauthenticated('unauthenticated'),
  emailNotVerified('email-not-verified'),
  permissionDenied('permission-denied'),
  accountInactive('account-inactive'),
  invalidInput('invalid-input'),
  limitReached('limit-reached'),
  notFound('not-found'),
  alreadyExists('already-exists'),
  registrationIncomplete('registration-incomplete'),
  mfaRequired('mfa-required'),
  slugInvalid('slug-invalid'),
  slugReserved('slug-reserved'),
  slugTaken('slug-taken'),
  categoryDeleted('category-deleted'),
  publishBlocked('publish-blocked'),
  network('network'),
  unknown('unknown');

  const AppErrorCode(this.wire);

  /// The string sent over the wire in the error's `details.code`.
  final String wire;

  static AppErrorCode fromWire(String? value) => AppErrorCode.values.firstWhere(
    (c) => c.wire == value,
    orElse: () => AppErrorCode.unknown,
  );
}

/// Localized message for an [AppErrorCode].
extension AppErrorMessage on CoreLocalizations {
  String messageFor(AppErrorCode code) => switch (code) {
    AppErrorCode.unauthenticated => errorUnauthenticated,
    AppErrorCode.emailNotVerified => errorEmailNotVerified,
    AppErrorCode.permissionDenied => errorPermissionDenied,
    AppErrorCode.accountInactive => errorAccountInactive,
    AppErrorCode.invalidInput => errorInvalidInput,
    AppErrorCode.limitReached => errorLimitReached,
    AppErrorCode.notFound => errorNotFound,
    AppErrorCode.alreadyExists => errorAlreadyExists,
    AppErrorCode.registrationIncomplete => errorRegistrationIncomplete,
    AppErrorCode.mfaRequired => errorMfaRequired,
    AppErrorCode.slugInvalid => errorSlugInvalid,
    AppErrorCode.slugReserved => errorSlugReserved,
    AppErrorCode.slugTaken => errorSlugTaken,
    AppErrorCode.categoryDeleted => errorCategoryDeleted,
    AppErrorCode.publishBlocked => errorPublishBlocked,
    AppErrorCode.network => errorNetwork,
    AppErrorCode.unknown => errorUnknown,
  };
}
