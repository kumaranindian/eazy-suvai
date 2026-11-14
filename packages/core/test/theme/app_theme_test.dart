import 'dart:math' as math;

import 'package:core/core.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

double contrast(Color a, Color b) {
  final la = a.computeLuminance();
  final lb = b.computeLuminance();
  return (math.max(la, lb) + 0.05) / (math.min(la, lb) + 0.05);
}

void main() {
  // WCAG 2.1 AA: 4.5:1 for normal text.
  const aa = 4.5;

  void expectPairs(ColorScheme s, String name) {
    final pairs = <String, (Color, Color)>{
      'onPrimary/primary': (s.onPrimary, s.primary),
      'onSecondary/secondary': (s.onSecondary, s.secondary),
      'onTertiary/tertiary': (s.onTertiary, s.tertiary),
      'onSurface/surface': (s.onSurface, s.surface),
      'onSurfaceVariant/surface': (s.onSurfaceVariant, s.surface),
      'onSurface/surfaceContainerLow': (s.onSurface, s.surfaceContainerLow),
      'onSurfaceVariant/surfaceContainerLow': (
        s.onSurfaceVariant,
        s.surfaceContainerLow,
      ),
      'primary/surface': (s.primary, s.surface),
      'primary/surfaceContainerLow': (s.primary, s.surfaceContainerLow),
      'secondary/surface': (s.secondary, s.surface),
      'onPrimaryContainer/primaryContainer': (
        s.onPrimaryContainer,
        s.primaryContainer,
      ),
      'onSecondaryContainer/secondaryContainer': (
        s.onSecondaryContainer,
        s.secondaryContainer,
      ),
      'onError/error': (s.onError, s.error),
      'error/surface': (s.error, s.surface),
    };
    pairs.forEach((label, pair) {
      expect(
        contrast(pair.$1, pair.$2),
        greaterThanOrEqualTo(aa),
        reason: '$name $label is below AA',
      );
    });
  }

  test(
    'light scheme meets WCAG AA',
    () => expectPairs(AppTheme.lightScheme, 'light'),
  );
  test(
    'dark scheme meets WCAG AA',
    () => expectPairs(AppTheme.darkScheme, 'dark'),
  );

  test('accessible brand text colours pass on white and cream', () {
    for (final bg in [BrandColors.white, BrandColors.cream]) {
      expect(contrast(BrandColors.orangeText, bg), greaterThanOrEqualTo(aa));
      expect(contrast(BrandColors.greenText, bg), greaterThanOrEqualTo(aa));
    }
    // Documented brand colours pass the 3:1 large-text threshold.
    expect(
      contrast(BrandColors.deepOrange, BrandColors.white),
      greaterThanOrEqualTo(3),
    );
  });

  test('buttons have 48 px minimum height', () {
    final style = AppTheme.light.filledButtonTheme.style!;
    expect(style.minimumSize!.resolve({})!.height, 48);
  });
}
