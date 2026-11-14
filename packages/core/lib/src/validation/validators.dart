import 'package:phone_numbers_parser/phone_numbers_parser.dart';

import '../geo/address_format.dart';
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

  /// Optional postal code in the [format] of the restaurant's country.
  static String? optionalPostalCode(
    CoreLocalizations l10n,
    String? value,
    AddressFormat format,
  ) {
    final v = value?.trim() ?? '';
    if (v.isEmpty) return null;
    return format.isValidPostalCode(v)
        ? null
        : l10n.validationPostalCode(format.postalLabel.label(l10n));
  }

  /// FR-011 contact number: optional, but when given it must be valid for
  /// [countryCode] (mobile or landline).
  static String? optionalPhone(
    CoreLocalizations l10n,
    String? value,
    String countryCode,
  ) {
    final v = value?.trim() ?? '';
    if (v.isEmpty) return null;
    return normalizeMobile(v, countryCode) == null
        ? l10n.validationPhone
        : null;
  }

  /// Optional email address.
  static String? optionalEmail(CoreLocalizations l10n, String? value) {
    final v = value?.trim() ?? '';
    if (v.isEmpty) return null;
    return email(l10n, v);
  }

  /// Optional website (FR-011: "valid https URL").
  static String? optionalHttpsUrl(CoreLocalizations l10n, String? value) {
    final v = value?.trim() ?? '';
    if (v.isEmpty) return null;
    if (v.toLowerCase().startsWith('http://')) return l10n.validationHttps;
    return normalizeHttpsUrl(v) == null ? l10n.validationUrl : null;
  }

  /// `https://` URL from what the owner typed, adding the scheme when it is
  /// missing (`spicegarden.in` → `https://spicegarden.in`). Null when not a
  /// valid web address, or when it uses another scheme (`http:`,
  /// `javascript:`). The result matches the security rules' URL pattern.
  static String? normalizeHttpsUrl(String value) {
    var v = value.trim();
    if (v.isEmpty || v.length > 300 || RegExp(r'\s').hasMatch(v)) return null;
    if (!v.contains('://')) {
      if (RegExp(r'^[a-zA-Z][a-zA-Z0-9+.-]*:').hasMatch(v) &&
          !RegExp(r'^[^:/]+:\d').hasMatch(v)) {
        return null; // mailto:, javascript:, …
      }
      v = 'https://$v';
    }
    final uri = Uri.tryParse(v.replaceAll('|', '%7C'));
    if (uri == null || uri.scheme.toLowerCase() != 'https') return null;
    final host = uri.host;
    if (host.isEmpty ||
        !host.contains('.') ||
        host.startsWith('.') ||
        host.endsWith('.')) {
      return null;
    }
    if (!RegExp(r'^[a-zA-Z0-9.-]+$').hasMatch(host)) return null;
    final out = uri.toString();
    return out.length > 300 ? null : out;
  }

  static const _socialHosts = {
    'instagram': ['instagram.com'],
    'facebook': ['facebook.com', 'fb.com', 'fb.me'],
    'x': ['x.com', 'twitter.com'],
    'youtube': ['youtube.com', 'youtu.be'],
    'googleMaps': [
      'maps.google.com',
      'google.com',
      'maps.app.goo.gl',
      'goo.gl',
      'g.page',
    ],
  };

  static const _socialProfileBase = {
    'instagram': 'https://instagram.com/',
    'facebook': 'https://facebook.com/',
    'x': 'https://x.com/',
    'youtube': 'https://youtube.com/@',
  };

  /// A link to the restaurant's page on [network] (its key, for example
  /// `instagram`), from a URL or, except for Google Maps, a handle
  /// (`@spicegarden`). Null when not recognised.
  static String? normalizeSocialLink(String network, String value) {
    final v = value.trim();
    if (v.isEmpty) return null;
    final base = _socialProfileBase[network];
    final handle = RegExp(r'^@?([A-Za-z0-9._-]{1,100})$').firstMatch(v);
    // "@spicegarden", or a bare "spicegarden" (no dot, so not a domain).
    if (base != null &&
        handle != null &&
        (v.startsWith('@') || !v.contains('.'))) {
      return '$base${handle.group(1)}';
    }
    final url = normalizeHttpsUrl(
      v.toLowerCase().startsWith('http://') ? 'https://${v.substring(7)}' : v,
    );
    if (url == null) return null;
    final host = Uri.parse(url).host.toLowerCase();
    final allowed = _socialHosts[network] ?? const [];
    final ok = allowed.any((h) => host == h || host.endsWith('.$h'));
    if (!ok) return null;
    if (network == 'googleMaps' &&
        (host == 'google.com' || host.endsWith('.google.com')) &&
        host != 'maps.google.com' &&
        !Uri.parse(url).path.startsWith('/maps')) {
      return null;
    }
    if (network == 'googleMaps' &&
        host == 'goo.gl' &&
        !Uri.parse(url).path.startsWith('/maps')) {
      return null;
    }
    return url;
  }

  /// Optional social link for [network] (see [normalizeSocialLink]).
  static String? optionalSocialLink(
    CoreLocalizations l10n,
    String network,
    String? value,
    String networkLabel,
  ) {
    final v = value?.trim() ?? '';
    if (v.isEmpty) return null;
    return normalizeSocialLink(network, v) == null
        ? l10n.validationSocialLink(networkLabel)
        : null;
  }

  /// A stored E.164 number in national form for editing (`+914423456789`
  /// → `44 2345 6789`), or [e164] unchanged if it cannot be parsed.
  static String nationalNumber(String e164) {
    try {
      return PhoneNumber.parse(e164).formatNsn();
    } on PhoneNumberException {
      return e164;
    }
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
