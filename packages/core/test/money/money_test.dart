import 'package:core/core.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('Money.format', () {
    test('INR uses ₹, 2 decimals and Indian grouping', () {
      expect(Money(129900, 'INR').format(), '₹1,299.00');
      expect(Money(12500050, 'INR').format(), '₹1,25,000.50');
    });

    test('KWD uses 3 decimals and the ISO code', () {
      expect(Money(1250, 'KWD').format(), 'KWD 1.250');
    });

    test('every currency in FRD §6.2 has the right decimals', () {
      const expected = {
        'INR': 2, 'AED': 2, 'SAR': 2, 'QAR': 2, 'USD': 2, //
        'KWD': 3, 'BHD': 3, 'OMR': 3,
      };
      expected.forEach((code, decimals) {
        expect(Currencies.of(code).decimals, decimals, reason: code);
      });
      expect(Money(4500, 'AED').format(), 'AED 45.00');
      expect(Money(3000, 'SAR').format(), 'SAR 30.00');
      expect(Money(3000, 'QAR').format(), 'QAR 30.00');
      expect(Money(2500, 'BHD').format(), 'BHD 2.500');
      expect(Money(2500, 'OMR').format(), 'OMR 2.500');
      expect(Money(1299, 'USD').format(), r'$12.99');
    });

    test('large amounts keep exact minor units', () {
      expect(Money(99999999999, 'INR').format(), '₹99,99,99,999.99');
    });

    test('zero and negative amounts', () {
      expect(Money.zero('INR').format(), '₹0.00');
      expect(Money(-150, 'INR').format(), '-₹1.50');
    });
  });

  group('Money.parse', () {
    test('parses user input without doubles', () {
      expect(Money.parse('1299', 'INR'), Money(129900, 'INR'));
      expect(Money.parse('1,299.5', 'INR'), Money(129950, 'INR'));
      expect(Money.parse(' 0.10 ', 'INR'), Money(10, 'INR'));
      expect(Money.parse('1.25', 'KWD'), Money(1250, 'KWD'));
      expect(Money.parse('1.', 'KWD'), Money(1000, 'KWD'));
    });

    test('rejects too many decimals and junk', () {
      expect(() => Money.parse('1.234', 'INR'), throwsFormatException);
      expect(() => Money.parse('1.2345', 'KWD'), throwsFormatException);
      expect(() => Money.parse('abc', 'INR'), throwsFormatException);
      expect(() => Money.parse('', 'INR'), throwsFormatException);
      expect(() => Money.parse('1e3', 'INR'), throwsFormatException);
    });

    test('round-trips through toDecimalString', () {
      for (final m in [
        Money(129900, 'INR'),
        Money(1250, 'KWD'),
        Money(5, 'BHD'),
      ]) {
        expect(Money.parse(m.toDecimalString(), m.currencyCode), m);
      }
      expect(Money(5, 'BHD').toDecimalString(), '0.005');
    });
  });

  group('Money arithmetic and equality', () {
    test('adds, subtracts and multiplies in minor units', () {
      final a = Money(1050, 'INR');
      final b = Money(250, 'INR');
      expect(a + b, Money(1300, 'INR'));
      expect(a - b, Money(800, 'INR'));
      expect(b * 3, Money(750, 'INR'));
      expect(-b, Money(-250, 'INR'));
      expect(a.compareTo(b), greaterThan(0));
    });

    test('refuses to mix currencies', () {
      expect(() => Money(1, 'INR') + Money(1, 'AED'), throwsArgumentError);
      expect(Money(1, 'INR') == Money(1, 'AED'), isFalse);
    });

    test('unknown currency throws', () {
      expect(() => Money(1, 'XYZ'), throwsArgumentError);
    });

    test('JSON shape matches Firestore', () {
      final m = Money(129900, 'INR');
      expect(m.toJson(), {'amountMinor': 129900, 'currency': 'INR'});
      expect(Money.fromJson(m.toJson()), m);
    });
  });

  test('Currencies.register adds a currency from config', () {
    Currencies.register(
      const Currency(code: 'JOD', decimals: 3, defaultLocale: 'en'),
    );
    expect(Money(1500, 'JOD').format(), 'JOD 1.500');
    expect(
      () => Currencies.register(
        const Currency(code: 'bad', decimals: 2, defaultLocale: 'en'),
      ),
      throwsArgumentError,
    );
  });
}
