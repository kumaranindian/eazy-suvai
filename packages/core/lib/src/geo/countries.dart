import '../l10n/generated/core_localizations.dart';

/// A country an owner can register in (FRD §6.1).
///
/// Keep in sync with `functions/src/auth/countries.ts`, which sets the
/// restaurant's currency and time zone from the code on the server.
class Country {
  const Country({
    required this.code,
    required this.dialCode,
    required this.currency,
    required this.timezone,
  });

  /// ISO 3166-1 alpha-2 code, for example `IN`.
  final String code;

  /// International calling code without `+`, for example `91`.
  final String dialCode;

  /// Default ISO 4217 currency.
  final String currency;

  /// Default IANA time zone.
  final String timezone;

  /// Localized country name.
  String name(CoreLocalizations l10n) => switch (code) {
    'IN' => l10n.countryIN,
    'AE' => l10n.countryAE,
    'KW' => l10n.countryKW,
    'SA' => l10n.countrySA,
    'QA' => l10n.countryQA,
    'BH' => l10n.countryBH,
    'OM' => l10n.countryOM,
    'US' => l10n.countryUS,
    _ => code,
  };

  @override
  bool operator ==(Object other) => other is Country && other.code == code;

  @override
  int get hashCode => code.hashCode;
}

abstract final class Countries {
  static const india = Country(
    code: 'IN',
    dialCode: '91',
    currency: 'INR',
    timezone: 'Asia/Kolkata',
  );

  /// Supported at launch or early expansion. India first (launch market).
  static const all = <Country>[
    india,
    Country(
      code: 'AE',
      dialCode: '971',
      currency: 'AED',
      timezone: 'Asia/Dubai',
    ),
    Country(
      code: 'KW',
      dialCode: '965',
      currency: 'KWD',
      timezone: 'Asia/Kuwait',
    ),
    Country(
      code: 'SA',
      dialCode: '966',
      currency: 'SAR',
      timezone: 'Asia/Riyadh',
    ),
    Country(
      code: 'QA',
      dialCode: '974',
      currency: 'QAR',
      timezone: 'Asia/Qatar',
    ),
    Country(
      code: 'BH',
      dialCode: '973',
      currency: 'BHD',
      timezone: 'Asia/Bahrain',
    ),
    Country(
      code: 'OM',
      dialCode: '968',
      currency: 'OMR',
      timezone: 'Asia/Muscat',
    ),
    Country(
      code: 'US',
      dialCode: '1',
      currency: 'USD',
      timezone: 'America/New_York',
    ),
  ];

  static Country? byCode(String code) {
    for (final c in all) {
      if (c.code == code) return c;
    }
    return null;
  }
}
