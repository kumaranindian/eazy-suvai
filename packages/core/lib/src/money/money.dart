import 'package:intl/intl.dart';

import 'currency.dart';

/// An amount of money in integer minor units plus an ISO 4217 code (BR-019).
///
/// Never use `double` for money. `Money(129900, 'INR')` is ₹1,299.00 and
/// `Money(1250, 'KWD')` is KWD 1.250.
class Money implements Comparable<Money> {
  /// Creates an amount of [minor] units of [currencyCode].
  ///
  /// Throws [ArgumentError] if the currency is unknown.
  Money(this.minor, String currencyCode)
    : currency = Currencies.of(currencyCode);

  /// Creates an amount from a known [Currency].
  const Money.of(this.minor, this.currency);

  /// Zero in [currencyCode].
  factory Money.zero(String currencyCode) => Money(0, currencyCode);

  /// Parses a price typed by a user, for example `"1299.5"` or `"1,299.50"`,
  /// without going through `double`.
  ///
  /// Throws [FormatException] if the text is not a valid amount or has more
  /// fraction digits than the currency allows.
  factory Money.parse(String text, String currencyCode) {
    final currency = Currencies.of(currencyCode);
    final cleaned = text.trim().replaceAll(',', '').replaceAll(' ', '');
    final match = RegExp(r'^(-)?(\d+)(?:\.(\d*))?$').firstMatch(cleaned);
    if (match == null) {
      throw FormatException('Not a valid amount', text);
    }
    final negative = match.group(1) != null;
    final whole = int.parse(match.group(2)!);
    final fraction = match.group(3) ?? '';
    if (fraction.length > currency.decimals) {
      throw FormatException(
        '${currency.code} allows ${currency.decimals} decimal places',
        text,
      );
    }
    final fractionMinor = fraction.isEmpty
        ? 0
        : int.parse(fraction.padRight(currency.decimals, '0'));
    final minor = whole * currency.minorPerMajor + fractionMinor;
    return Money.of(negative ? -minor : minor, currency);
  }

  /// Reads `{amountMinor, currency}` as stored in Firestore.
  factory Money.fromJson(Map<String, dynamic> json) =>
      Money(json['amountMinor'] as int, json['currency'] as String);

  /// Amount in minor units (paise, fils, cents).
  final int minor;

  /// The currency of this amount.
  final Currency currency;

  /// ISO 4217 code.
  String get currencyCode => currency.code;

  bool get isZero => minor == 0;
  bool get isNegative => minor < 0;

  Map<String, dynamic> toJson() => {
    'amountMinor': minor,
    'currency': currency.code,
  };

  Money operator +(Money other) {
    _assertSameCurrency(other);
    return Money.of(minor + other.minor, currency);
  }

  Money operator -(Money other) {
    _assertSameCurrency(other);
    return Money.of(minor - other.minor, currency);
  }

  /// Multiplies by a whole quantity.
  Money operator *(int quantity) => Money.of(minor * quantity, currency);

  Money operator -() => Money.of(-minor, currency);

  /// Formats the amount for display with CLDR separators for [locale]
  /// (defaults to the currency's own locale, for example `en_IN` for INR,
  /// which groups as ₹1,25,000.50).
  String format({String? locale}) {
    final formatter = NumberFormat.currency(
      locale: locale ?? currency.defaultLocale,
      symbol: currency.symbol ?? '${currency.code} ',
      decimalDigits: currency.decimals,
    );
    return formatter.format(_majorAsNum());
  }

  /// The amount as a plain decimal string with no symbol, for example
  /// `"1299.00"`. Suitable for editing fields.
  String toDecimalString() {
    final abs = minor.abs();
    final whole = abs ~/ currency.minorPerMajor;
    final fraction = abs % currency.minorPerMajor;
    final sign = minor < 0 ? '-' : '';
    if (currency.decimals == 0) return '$sign$whole';
    return '$sign$whole.${fraction.toString().padLeft(currency.decimals, '0')}';
  }

  // NumberFormat needs a num. Parsing the exact decimal string keeps
  // the value correct for any amount a menu price can hold.
  num _majorAsNum() => num.parse(toDecimalString());

  void _assertSameCurrency(Money other) {
    if (other.currency.code != currency.code) {
      throw ArgumentError(
        'Currency mismatch: ${currency.code} and ${other.currency.code}',
      );
    }
  }

  @override
  int compareTo(Money other) {
    _assertSameCurrency(other);
    return minor.compareTo(other.minor);
  }

  @override
  bool operator ==(Object other) =>
      other is Money &&
      other.minor == minor &&
      other.currency.code == currency.code;

  @override
  int get hashCode => Object.hash(minor, currency.code);

  @override
  String toString() => 'Money($minor, ${currency.code})';
}
