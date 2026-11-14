import 'package:core/core.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  final l10n = lookupCoreLocalizations(const Locale('en'));

  group('email (FR-003)', () {
    for (final ok in ['a@b.co', 'priya.raman+menu@example.co.in', 'X@Y.ORG']) {
      test('accepts $ok', () => expect(Validators.email(l10n, ok), isNull));
    }
    for (final bad in [
      '',
      'a',
      'a@b',
      'a@@b.com',
      'a b@c.com',
      '@b.com',
      'a@b.c-',
    ]) {
      test('rejects "$bad"', () {
        expect(Validators.email(l10n, bad), isNotNull);
      });
    }
  });

  test('password needs 8 characters (FRD 7.2)', () {
    expect(
      Validators.password(l10n, '1234567'),
      l10n.validationPasswordLength(8),
    );
    expect(Validators.password(l10n, '12345678'), isNull);
    expect(Validators.password(l10n, ''), l10n.validationRequired);
  });

  group('mobile by country (FR-003)', () {
    final cases = <(String, String, String?)>[
      ('IN', '98765 43210', '+919876543210'),
      ('IN', '+91 98765 43210', '+919876543210'),
      ('IN', '09876543210', '+919876543210'),
      ('AE', '050 123 4567', '+971501234567'),
      ('KW', '5123 4567', '+96551234567'),
      ('US', '(201) 555-0123', '+12015550123'),
      ('IN', '12345', null),
      ('IN', '+971501234567', null),
      ('AE', '98765 43210', null),
      ('IN', 'abc', null),
      ('XX', '9876543210', null),
    ];
    for (final (country, input, expected) in cases) {
      test('$country "$input" -> $expected', () {
        expect(Validators.normalizeMobile(input, country), expected);
        expect(
          Validators.mobile(l10n, input, country),
          expected == null ? l10n.validationMobile : isNull,
        );
      });
    }
  });

  test('text limits', () {
    expect(Validators.text(l10n, '  '), l10n.validationRequired);
    expect(Validators.text(l10n, 'x' * 101), l10n.validationTooLong(100));
    expect(Validators.optionalText(l10n, ''), isNull);
    expect(Validators.optionalText(l10n, 'x' * 61), l10n.validationTooLong(60));
  });

  test('countries and business types are localized', () {
    for (final c in Countries.all) {
      expect(c.name(l10n), isNot(c.code));
    }
    for (final t in BusinessType.values) {
      expect(t.label(l10n), isNotEmpty);
      expect(BusinessType.fromName(t.name), t);
    }
  });
}
