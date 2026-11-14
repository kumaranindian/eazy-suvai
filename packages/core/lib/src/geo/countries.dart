import '../l10n/generated/core_localizations.dart';
import 'address_format.dart';

/// A country an owner can register in (FRD §6.1), with its presets:
/// default currency and time zone, phone format (through [code] and
/// [dialCode]) and address format.
///
/// Keep the code, currency and default time zone in sync with
/// `functions/src/auth/countries.ts`, which sets the restaurant's currency
/// and time zone from the code on the server.
class Country {
  const Country({
    required this.code,
    required this.dialCode,
    required this.currency,
    required this.timezone,
    this.timezones = const [],
    this.address = const AddressFormat(),
  });

  /// ISO 3166-1 alpha-2 code, for example `IN`.
  final String code;

  /// International calling code without `+`, for example `91`.
  final String dialCode;

  /// Default ISO 4217 currency.
  final String currency;

  /// Default IANA time zone.
  final String timezone;

  /// Other IANA zones used in this country, offered first in the time zone
  /// picker. [timezone] is always included (see [suggestedTimezones]).
  final List<String> timezones;

  /// Address parts, order and postal code format.
  final AddressFormat address;

  /// [timezone] followed by the other zones of the country.
  List<String> get suggestedTimezones => [
    timezone,
    for (final z in timezones)
      if (z != timezone) z,
  ];

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
    address: AddressFormat(
      postalLabel: PostalCodeLabel.pinCode,
      postalPattern: r'[1-9][0-9]{5}',
      postalExample: '600017',
    ),
  );

  /// Supported at launch or early expansion. India first (launch market).
  static const all = <Country>[
    india,
    Country(
      code: 'AE',
      dialCode: '971',
      currency: 'AED',
      timezone: 'Asia/Dubai',
      // The UAE has no postal codes.
      address: AddressFormat(order: [AddressPart.address, AddressPart.city]),
    ),
    Country(
      code: 'KW',
      dialCode: '965',
      currency: 'KWD',
      timezone: 'Asia/Kuwait',
      address: AddressFormat(
        postalPattern: r'[0-9]{5}',
        postalExample: '13001',
      ),
    ),
    Country(
      code: 'SA',
      dialCode: '966',
      currency: 'SAR',
      timezone: 'Asia/Riyadh',
      address: AddressFormat(
        postalPattern: r'[0-9]{5}(-[0-9]{4})?',
        postalExample: '12271',
      ),
    ),
    Country(
      code: 'QA',
      dialCode: '974',
      currency: 'QAR',
      timezone: 'Asia/Qatar',
      // Qatar has no postal codes.
      address: AddressFormat(order: [AddressPart.address, AddressPart.city]),
    ),
    Country(
      code: 'BH',
      dialCode: '973',
      currency: 'BHD',
      timezone: 'Asia/Bahrain',
      address: AddressFormat(
        postalPattern: r'[0-9]{3,4}',
        postalExample: '317',
      ),
    ),
    Country(
      code: 'OM',
      dialCode: '968',
      currency: 'OMR',
      timezone: 'Asia/Muscat',
      address: AddressFormat(postalPattern: r'[0-9]{3}', postalExample: '112'),
    ),
    Country(
      code: 'US',
      dialCode: '1',
      currency: 'USD',
      timezone: 'America/New_York',
      timezones: [
        'America/New_York',
        'America/Chicago',
        'America/Denver',
        'America/Phoenix',
        'America/Los_Angeles',
        'America/Anchorage',
        'Pacific/Honolulu',
      ],
      address: AddressFormat(
        postalLabel: PostalCodeLabel.zipCode,
        postalPattern: r'[0-9]{5}(-[0-9]{4})?',
        postalExample: '10001',
      ),
    ),
  ];

  static Country? byCode(String code) {
    for (final c in all) {
      if (c.code == code) return c;
    }
    return null;
  }
}
