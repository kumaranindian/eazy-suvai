/// An ISO 4217 currency with its minor-unit exponent and display rules.
///
/// The defaults below follow FRD §6.2. They can be overridden or extended at
/// runtime from `config/platform.currencies` with [Currencies.register], so a
/// new market needs no code change.
class Currency {
  const Currency({
    required this.code,
    required this.decimals,
    required this.defaultLocale,
    this.symbol,
  });

  /// ISO 4217 code, for example `INR`.
  final String code;

  /// Minor-unit exponent: 2 for INR (paise), 3 for KWD (fils).
  final int decimals;

  /// CLDR locale used to format amounts when the caller gives none.
  final String defaultLocale;

  /// Symbol shown before the amount. When null, the ISO code is shown
  /// followed by a space, for example `KWD 1.250`.
  final String? symbol;

  /// Number of minor units in one major unit (100 for INR, 1000 for KWD).
  int get minorPerMajor {
    var result = 1;
    for (var i = 0; i < decimals; i++) {
      result *= 10;
    }
    return result;
  }

  @override
  bool operator ==(Object other) =>
      other is Currency && other.code == code && other.decimals == decimals;

  @override
  int get hashCode => Object.hash(code, decimals);

  @override
  String toString() => 'Currency($code, $decimals)';
}

/// Registry of known currencies.
class Currencies {
  Currencies._();

  static const inr = Currency(
    code: 'INR',
    decimals: 2,
    defaultLocale: 'en_IN',
    symbol: '₹',
  );
  static const aed = Currency(code: 'AED', decimals: 2, defaultLocale: 'en');
  static const kwd = Currency(code: 'KWD', decimals: 3, defaultLocale: 'en');
  static const sar = Currency(code: 'SAR', decimals: 2, defaultLocale: 'en');
  static const qar = Currency(code: 'QAR', decimals: 2, defaultLocale: 'en');
  static const bhd = Currency(code: 'BHD', decimals: 3, defaultLocale: 'en');
  static const omr = Currency(code: 'OMR', decimals: 3, defaultLocale: 'en');
  static const usd = Currency(
    code: 'USD',
    decimals: 2,
    defaultLocale: 'en_US',
    symbol: r'$',
  );

  static final Map<String, Currency> _byCode = {
    for (final c in const [inr, aed, kwd, sar, qar, bhd, omr, usd]) c.code: c,
  };

  /// All registered currencies, in registration order.
  static Iterable<Currency> get all => _byCode.values;

  /// Returns the currency for [code], or throws [ArgumentError] if unknown.
  static Currency of(String code) {
    final currency = _byCode[code.toUpperCase()];
    if (currency == null) {
      throw ArgumentError.value(code, 'code', 'Unknown currency');
    }
    return currency;
  }

  /// Whether [code] is a registered currency.
  static bool isKnown(String code) => _byCode.containsKey(code.toUpperCase());

  /// Adds or replaces a currency, for example from `config/platform`.
  static void register(Currency currency) {
    if (!RegExp(r'^[A-Z]{3}$').hasMatch(currency.code)) {
      throw ArgumentError.value(currency.code, 'code', 'Must be ISO 4217');
    }
    if (currency.decimals < 0 || currency.decimals > 4) {
      throw ArgumentError.value(currency.decimals, 'decimals', 'Must be 0–4');
    }
    _byCode[currency.code] = currency;
  }
}
