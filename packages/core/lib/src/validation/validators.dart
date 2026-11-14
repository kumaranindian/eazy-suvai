import 'package:phone_numbers_parser/phone_numbers_parser.dart';

import '../l10n/generated/core_localizations.dart';

/// Form validators. Each returns a localized error, or `null` when valid.
abstract final class Validators {
  /// Minimum password length (FRD §7.2). The Firebase password policy on the
  /// project enforces the same on the server.
  static const minPasswordLength = 8;

  static final _email = RegExp(
    r"^[A-Za-z0-9.!#$%&'*+/=?^_`{|}~-]+@[A-Za-z0-9](?:[A-Za-z0-9-]{0,61}[A-Za-z0-9])?(?:\.[A-Za-z0-9](?:[A-Za-z0-9-]{0,61}[A-Za-z0-9])?)+$",
  );

  static String? required(CoreLocalizations l10n, String? value) =>
      (value == null || value.trim().isEmpty) ? l10n.validationRequired : null;

  /// Required text up to [max] characters.
  static String? text(CoreLocalizations l10n, String? value, {int max = 100}) {
    final r = required(l10n, value);
    if (r != null) return r;
    return value!.trim().length > max ? l10n.validationTooLong(max) : null;
  }

  /// Optional text up to [max] characters.
  static String? optionalText(
    CoreLocalizations l10n,
    String? value, {
    int max = 60,
  }) => (value != null && value.trim().length > max)
      ? l10n.validationTooLong(max)
      : null;

  /// FR-003: email format.
  static String? email(CoreLocalizations l10n, String? value) {
    final v = value?.trim() ?? '';
    if (v.isEmpty) return l10n.validationRequired;
    if (v.length > 254 || !_email.hasMatch(v)) return l10n.validationEmail;
    return null;
  }

  /// At least [minPasswordLength] characters.
  static String? password(CoreLocalizations l10n, String? value) {
    if (value == null || value.isEmpty) return l10n.validationRequired;
    if (value.length < minPasswordLength) {
      return l10n.validationPasswordLength(minPasswordLength);
    }
    if (value.length > 128) return l10n.validationTooLong(128);
    return null;
  }

  /// FR-003: a phone number valid for [countryCode] (ISO alpha-2).
  static String? mobile(
    CoreLocalizations l10n,
    String? value,
    String countryCode,
  ) {
    final v = value?.trim() ?? '';
    if (v.isEmpty) return l10n.validationRequired;
    return normalizeMobile(v, countryCode) == null
        ? l10n.validationMobile
        : null;
  }

  /// The number in E.164 form (`+919876543210`) if it is valid for
  /// [countryCode], else `null`.
  static String? normalizeMobile(String value, String countryCode) {
    final iso = IsoCode.values.where((c) => c.name == countryCode);
    if (iso.isEmpty) return null;
    if (!RegExp(r'^[+0-9 ()\-.]{4,32}$').hasMatch(value.trim())) return null;
    try {
      final phone = PhoneNumber.parse(value, callerCountry: iso.first);
      if (phone.isoCode != iso.first || !phone.isValid()) return null;
      return phone.international;
    } on PhoneNumberException {
      return null;
    }
  }
}
