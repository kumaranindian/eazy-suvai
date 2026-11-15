import 'dart:convert';
import 'dart:io';

import 'package:core/core.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// The cases shared with `functions/src/theme/theme.test.ts`, so the Dart
/// and TypeScript copies of the contrast rules cannot drift apart.
Map<String, dynamic> _sharedCases() {
  var dir = Directory.current;
  while (!File(
    '${dir.path}/functions/src/theme/contrast-cases.json',
  ).existsSync()) {
    final parent = dir.parent;
    if (parent.path == dir.path) {
      throw StateError(
        'contrast-cases.json not found above ${Directory.current.path}',
      );
    }
    dir = parent;
  }
  return jsonDecode(
        File(
          '${dir.path}/functions/src/theme/contrast-cases.json',
        ).readAsStringSync(),
      )
      as Map<String, dynamic>;
}

double _round2(double n) => (n * 100).round() / 100;

void main() {
  final cases = _sharedCases();

  group('Contrast (WCAG 2.1)', () {
    test('matches published reference ratios', () {
      expect(Contrast.ratio('#000000', '#FFFFFF'), closeTo(21, 1e-9));
      expect(Contrast.ratio('#FFFFFF', '#FFFFFF'), closeTo(1, 1e-9));
      expect(_round2(Contrast.ratio('#777777', '#FFFFFF')), 4.48);
      expect(_round2(Contrast.ratio('#767676', '#FFFFFF')), 4.54);
      expect(Contrast.relativeLuminance('#000000'), 0);
    });

    test('agrees with Flutter\'s luminance', () {
      for (final hex in ['#A8550A', '#FFF8EE', '#3B7A20', '#121417']) {
        expect(
          Contrast.relativeLuminance(hex),
          closeTo(hexToColor(hex).computeLuminance(), 1e-6),
        );
      }
    });

    for (final c in (cases['contrast'] as List).cast<Map<String, dynamic>>()) {
      test('ratio ${c['a']} on ${c['b']} = ${c['ratio']}', () {
        expect(
          _round2(Contrast.ratio(c['a'] as String, c['b'] as String)),
          (c['ratio'] as num).toDouble(),
        );
      });
    }

    for (final c in (cases['readable'] as List).cast<Map<String, dynamic>>()) {
      test('readable text on ${c['background']}', () {
        final bg = c['background'] as String;
        expect(Contrast.readableTextOn(bg), c['text']);
        expect(
          Contrast.ratio(Contrast.readableTextOn(bg), bg),
          greaterThanOrEqualTo(Contrast.aaText),
        );
      });
    }

    test('always finds AA text for every grey', () {
      for (var v = 0; v <= 255; v++) {
        final hex = '#${v.toRadixString(16).padLeft(2, '0') * 3}';
        expect(
          Contrast.ratio(Contrast.readableTextOn(hex), hex),
          greaterThanOrEqualTo(Contrast.aaText),
          reason: hex,
        );
      }
    });

    for (final c in (cases['mix'] as List).cast<Map<String, dynamic>>()) {
      test('mix ${c['a']} and ${c['b']} by ${c['t']}', () {
        expect(
          Contrast.mix(
            c['a'] as String,
            c['b'] as String,
            (c['t'] as num).toDouble(),
          ),
          c['result'],
        );
      });
    }

    test('hex parsing and formatting', () {
      expect(Contrast.normalizeHex('#ff7a00'), '#FF7A00');
      expect(Contrast.normalizeHex('ff7a00'), '#FF7A00');
      expect(Contrast.normalizeHex('#fff'), isNull);
      expect(Contrast.normalizeHex(12), isNull);
      expect(hexToColor('#FF7A00'), const Color(0xFFFF7A00));
      expect(colorToHex(const Color(0xFFA8550A)), '#A8550A');
    });
  });

  group('resolveMenuTheme', () {
    final themes = {
      for (final e in (cases['themes'] as Map<String, dynamic>).entries)
        e.key: ThemeTokens.fromMap(e.value),
    };

    for (final c in (cases['resolve'] as List).cast<Map<String, dynamic>>()) {
      test('${c['theme']} with ${jsonEncode(c['settings'])}', () {
        final id = c['theme'] as String?;
        final r = resolveMenuTheme(
          id == null ? null : themes[id],
          ThemeSettings.fromMap(c['settings']),
        );
        expect(jsonDecode(jsonEncode(r.toMap())), c['expected']);
      });
    }

    test('a low-contrast background is reported and the text adjusted', () {
      final r = resolveMenuTheme(
        themes['saffron'],
        const ThemeSettings(background: '#2B2B2B'),
      );
      expect(r.issue(ContrastIssueKind.text)?.adjusted, '#FFFFFF');
      expect(r.text, '#FFFFFF');
      expect(r.textColor, Colors.white);
    });

    test('seed themes pass AA without adjustment', () {
      for (final t in themes.values) {
        expect(resolveMenuTheme(t).issues, isEmpty);
        expect(MenuFonts.defaults, contains(t.font));
      }
    });
  });

  group('ThemeSettings', () {
    test('round-trips the stored map and drops invalid values', () {
      final s = ThemeSettings.fromMap({
        'primary': '#abcdef',
        'secondary': 'red',
        'font': ' Lora ',
        'layout': 'grid',
        'cardLayout': 'image-top',
        'mode': 'sepia',
        'extra': 1,
      });
      expect(s.toMap(), {
        'primary': '#ABCDEF',
        'font': 'Lora',
        'layout': 'grid',
        'cardLayout': 'image-top',
      });
      expect(ThemeSettings.fromMap(null).isEmpty, isTrue);
      expect(
        s.copyWith(primary: () => null, mode: () => MenuMode.dark).toMap(),
        {
          'font': 'Lora',
          'layout': 'grid',
          'cardLayout': 'image-top',
          'mode': 'dark',
        },
      );
    });

    test('ThemePreset reads a theme document', () {
      final p = ThemePreset.fromMap('midnight', {
        'name': 'Midnight',
        'premium': true,
        'sort': 40,
        'tokens': {'mode': 'dark', 'primary': '#ffb454'},
      });
      expect(p.premium, isTrue);
      expect(p.tokens.mode, MenuMode.dark);
      expect(p.tokens.primary, '#FFB454');
      expect(p.tokens.font, ThemeTokens.fallback.font);
    });

    test('Restaurant reads themeSettings', () {
      final r = Restaurant.fromMap('r1', {
        'country': 'IN',
        'currency': 'INR',
        'timezone': 'Asia/Kolkata',
        'themeId': 'saffron',
        'themeSettings': {'mode': 'dark'},
      });
      expect(r.themeId, 'saffron');
      expect(r.themeSettings.mode, MenuMode.dark);
      expect(r.copyWith(themeId: () => null).themeId, isNull);
    });
  });

  test('PlainMenuFontResolver sets the family without loading it', () {
    const resolver = PlainMenuFontResolver();
    expect(
      resolver.style('Lora', const TextStyle(fontSize: 14)).fontFamily,
      'Lora',
    );
    final theme = resolver.textTheme('Inter', ThemeData.light().textTheme);
    expect(theme.bodyMedium?.fontFamily, 'Inter');
  });
}
