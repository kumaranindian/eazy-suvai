import 'dart:math' as math;

import 'package:flutter/painting.dart';

/// WCAG 2.1 contrast helpers (M05, FR-060).
///
/// The TypeScript copy is `functions/src/theme/contrast.ts` (M07 renders the
/// public menu with it). Both are tested against
/// `functions/src/theme/contrast-cases.json`, so change them together.
///
/// Colours are `#RRGGBB` strings (upper case when produced here), the format
/// stored in Firestore; [hexToColor] converts for widgets.
abstract final class Contrast {
  /// WCAG 2.1 AA for normal-size text.
  static const aaText = 4.5;

  /// The preferred readable text colours (FR-060: "near-black or white").
  static const nearBlack = '#1A1A1A';
  static const white = '#FFFFFF';
  static const _black = '#000000';

  static final _hex = RegExp(r'^#?([0-9a-fA-F]{6})$');

  /// `#RRGGBB` in upper case, or null when [value] is not a 6-digit hex colour.
  static String? normalizeHex(Object? value) {
    if (value is! String) return null;
    final m = _hex.firstMatch(value.trim());
    return m == null ? null : '#${m.group(1)!.toUpperCase()}';
  }

  static List<int> _channels(String hex) {
    final h = normalizeHex(hex);
    if (h == null) throw ArgumentError.value(hex, 'hex', 'Not a hex colour');
    final n = int.parse(h.substring(1), radix: 16);
    return [(n >> 16) & 0xff, (n >> 8) & 0xff, n & 0xff];
  }

  static String _toHex(List<int> c) =>
      '#${c.map((v) => v.toRadixString(16).padLeft(2, '0')).join()}'
          .toUpperCase();

  static double _linear(int c) {
    final s = c / 255;
    return s <= 0.03928
        ? s / 12.92
        : math.pow((s + 0.055) / 1.055, 2.4).toDouble();
  }

  /// WCAG relative luminance, 0 (black) to 1 (white).
  static double relativeLuminance(String hex) {
    final c = _channels(hex);
    return 0.2126 * _linear(c[0]) +
        0.7152 * _linear(c[1]) +
        0.0722 * _linear(c[2]);
  }

  /// WCAG contrast ratio of two colours, 1 to 21. Order does not matter.
  static double ratio(String a, String b) {
    final la = relativeLuminance(a);
    final lb = relativeLuminance(b);
    return (math.max(la, lb) + 0.05) / (math.min(la, lb) + 0.05);
  }

  /// Linear blend in sRGB: [t] = 0 gives [a], 1 gives [b].
  static String mix(String a, String b, double t) {
    final ca = _channels(a);
    final cb = _channels(b);
    return _toHex([
      for (var i = 0; i < 3; i++) _roundHalfUp(ca[i] + (cb[i] - ca[i]) * t),
    ]);
  }

  /// JavaScript's `Math.round` (half toward +∞), so both copies agree.
  static int _roundHalfUp(double v) => (v + 0.5).floor();

  /// The better of near-black and white for text on [background]; pure
  /// black or white when neither reaches AA, which always does (≥ 4.58:1).
  static String readableTextOn(String background) {
    final dark = ratio(nearBlack, background);
    final light = ratio(white, background);
    if (math.max(dark, light) >= aaText) {
      return dark >= light ? nearBlack : white;
    }
    return ratio(_black, background) >= light ? _black : white;
  }

  /// Whether dark text reads better than white on [color].
  static bool isLight(String color) =>
      ratio(nearBlack, color) >= ratio(white, color);

  /// [color] if it reaches AA on every one of [backgrounds]; otherwise
  /// [color] blended toward [fallback] in steps of 10 % until it does.
  static String ensure(
    String color,
    List<String> backgrounds,
    String fallback,
  ) {
    for (var step = 0; step <= 10; step++) {
      final c = step == 0
          ? normalizeHex(color)!
          : mix(color, fallback, step / 10);
      if (backgrounds.every((bg) => ratio(c, bg) >= aaText)) return c;
    }
    return normalizeHex(fallback)!;
  }
}

/// `#RRGGBB` (or `RRGGBB`) to an opaque [Color]. Throws on other input.
Color hexToColor(String hex) {
  final h = Contrast.normalizeHex(hex);
  if (h == null) throw ArgumentError.value(hex, 'hex', 'Not a hex colour');
  return Color(0xFF000000 | int.parse(h.substring(1), radix: 16));
}

/// An opaque [Color] as `#RRGGBB` (alpha is dropped).
String colorToHex(Color color) {
  int ch(double v) => (v * 255).round().clamp(0, 255);
  return '#${[ch(color.r), ch(color.g), ch(color.b)].map((v) => v.toRadixString(16).padLeft(2, '0')).join()}'
      .toUpperCase();
}
