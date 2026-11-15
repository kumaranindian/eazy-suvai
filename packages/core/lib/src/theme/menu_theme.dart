import 'package:flutter/foundation.dart';
import 'package:flutter/painting.dart';

import 'contrast.dart';

/// How the public menu lists items (FR-055).
enum MenuLayout {
  list('list'),
  grid('grid');

  const MenuLayout(this.wire);
  final String wire;

  static MenuLayout? fromWire(Object? v) =>
      values.where((e) => e.wire == v).firstOrNull;
}

/// How one item card looks (FR-055).
enum CardLayout {
  compact('compact'),
  imageTop('image-top'),
  imageLeft('image-left');

  const CardLayout(this.wire);
  final String wire;

  static CardLayout? fromWire(Object? v) =>
      values.where((e) => e.wire == v).firstOrNull;
}

/// Light or dark menu (FR-055).
enum MenuMode {
  light('light'),
  dark('dark');

  const MenuMode(this.wire);
  final String wire;

  static MenuMode? fromWire(Object? v) =>
      values.where((e) => e.wire == v).firstOrNull;
}

/// `themes/{id}.tokens` (architecture §4.1). Colours are `#RRGGBB`.
@immutable
class ThemeTokens {
  const ThemeTokens({
    required this.primary,
    required this.secondary,
    required this.background,
    required this.surface,
    required this.text,
    required this.font,
    required this.layout,
    required this.cardLayout,
    required this.mode,
  });

  /// Reads stored tokens, filling gaps from [fallback].
  factory ThemeTokens.fromMap(Object? value) {
    final m = value is Map ? value : const {};
    const d = fallback;
    final font = m['font'];
    return ThemeTokens(
      primary: Contrast.normalizeHex(m['primary']) ?? d.primary,
      secondary: Contrast.normalizeHex(m['secondary']) ?? d.secondary,
      background: Contrast.normalizeHex(m['background']) ?? d.background,
      surface: Contrast.normalizeHex(m['surface']) ?? d.surface,
      text: Contrast.normalizeHex(m['text']) ?? d.text,
      font: font is String && font.trim().isNotEmpty ? font.trim() : d.font,
      layout: MenuLayout.fromWire(m['layout']) ?? d.layout,
      cardLayout: CardLayout.fromWire(m['cardLayout']) ?? d.cardLayout,
      mode: MenuMode.fromWire(m['mode']) ?? d.mode,
    );
  }

  /// Used when a restaurant has no theme yet, or its theme is missing
  /// (`DEFAULT_TOKENS` in functions).
  static const fallback = ThemeTokens(
    primary: '#A8550A',
    secondary: '#3B7A20',
    background: '#FFF8EE',
    surface: '#FFFFFF',
    text: '#2B2B2B',
    font: 'Poppins',
    layout: MenuLayout.list,
    cardLayout: CardLayout.imageLeft,
    mode: MenuMode.light,
  );

  final String primary;
  final String secondary;
  final String background;
  final String surface;
  final String text;
  final String font;
  final MenuLayout layout;
  final CardLayout cardLayout;
  final MenuMode mode;

  Map<String, Object> toMap() => {
    'primary': primary,
    'secondary': secondary,
    'background': background,
    'surface': surface,
    'text': text,
    'font': font,
    'layout': layout.wire,
    'cardLayout': cardLayout.wire,
    'mode': mode.wire,
  };

  @override
  bool operator ==(Object other) =>
      other is ThemeTokens && mapEquals(other.toMap(), toMap());

  @override
  int get hashCode => Object.hashAll(toMap().values);
}

/// A predefined theme, `themes/{id}` (FR-056). Named "preset" because
/// Flutter already has a `MenuTheme`.
@immutable
class ThemePreset {
  const ThemePreset({
    required this.id,
    required this.name,
    required this.tokens,
    this.premium = false,
    this.sort = 0,
    this.retired = false,
  });

  factory ThemePreset.fromMap(String id, Map<String, dynamic> data) =>
      ThemePreset(
        id: id,
        name: data['name'] as String? ?? id,
        tokens: ThemeTokens.fromMap(data['tokens']),
        premium: data['premium'] == true,
        sort: (data['sort'] as num?)?.toInt() ?? 0,
        retired: data['retired'] == true,
      );

  final String id;
  final String name;
  final ThemeTokens tokens;

  /// Not part of the Free plan (M10 enforces it).
  final bool premium;
  final int sort;

  /// Hidden from new choices; restaurants already using it keep it.
  final bool retired;
}

/// `restaurants/{rid}.themeSettings`: the owner's overrides of the chosen
/// theme. Null fields use the theme's value.
@immutable
class ThemeSettings {
  const ThemeSettings({
    this.primary,
    this.secondary,
    this.background,
    this.font,
    this.layout,
    this.cardLayout,
    this.mode,
  });

  /// Reads a stored map, dropping unknown keys and invalid values.
  factory ThemeSettings.fromMap(Object? value) {
    if (value is! Map) return const ThemeSettings();
    final font = value['font'];
    return ThemeSettings(
      primary: Contrast.normalizeHex(value['primary']),
      secondary: Contrast.normalizeHex(value['secondary']),
      background: Contrast.normalizeHex(value['background']),
      font: font is String && font.trim().isNotEmpty ? font.trim() : null,
      layout: MenuLayout.fromWire(value['layout']),
      cardLayout: CardLayout.fromWire(value['cardLayout']),
      mode: MenuMode.fromWire(value['mode']),
    );
  }

  final String? primary;
  final String? secondary;
  final String? background;
  final String? font;
  final MenuLayout? layout;
  final CardLayout? cardLayout;
  final MenuMode? mode;

  bool get isEmpty => toMap().isEmpty;

  /// The stored form: only the overrides, colours in upper-case hex (the
  /// security rules accept exactly this).
  Map<String, String> toMap() => {
    if (primary case final v?) 'primary': v,
    if (secondary case final v?) 'secondary': v,
    if (background case final v?) 'background': v,
    if (font case final v?) 'font': v,
    if (layout case final v?) 'layout': v.wire,
    if (cardLayout case final v?) 'cardLayout': v.wire,
    if (mode case final v?) 'mode': v.wire,
  };

  ThemeSettings copyWith({
    ValueGetter<String?>? primary,
    ValueGetter<String?>? secondary,
    ValueGetter<String?>? background,
    ValueGetter<String?>? font,
    ValueGetter<MenuLayout?>? layout,
    ValueGetter<CardLayout?>? cardLayout,
    ValueGetter<MenuMode?>? mode,
  }) => ThemeSettings(
    primary: primary != null ? primary() : this.primary,
    secondary: secondary != null ? secondary() : this.secondary,
    background: background != null ? background() : this.background,
    font: font != null ? font() : this.font,
    layout: layout != null ? layout() : this.layout,
    cardLayout: cardLayout != null ? cardLayout() : this.cardLayout,
    mode: mode != null ? mode() : this.mode,
  );

  @override
  bool operator ==(Object other) =>
      other is ThemeSettings && mapEquals(other.toMap(), toMap());

  @override
  int get hashCode => Object.hashAll(toMap().entries.map((e) => e.toString()));
}

/// Which colour pair failed WCAG AA (FR-060).
enum ContrastIssueKind {
  /// Body text on the background.
  text('text'),

  /// Text on cards (the surface).
  surfaceText('surfaceText'),

  /// The primary colour used as text (headings, prices).
  accent('accent');

  const ContrastIssueKind(this.wire);
  final String wire;
}

/// A colour below AA and the colour used instead.
@immutable
class ContrastIssue {
  const ContrastIssue({
    required this.kind,
    required this.original,
    required this.ratio,
    required this.adjusted,
  });

  final ContrastIssueKind kind;
  final String original;

  /// The original ratio, rounded to 2 decimals.
  final double ratio;
  final String adjusted;

  @override
  bool operator ==(Object other) =>
      other is ContrastIssue &&
      other.kind == kind &&
      other.original == original &&
      other.ratio == ratio &&
      other.adjusted == adjusted;

  @override
  int get hashCode => Object.hash(kind, original, ratio, adjusted);

  @override
  String toString() =>
      'ContrastIssue(${kind.wire}, $original $ratio → $adjusted)';
}

/// The colours the menu actually uses, after overrides and contrast fixes.
///
/// Token names match the CSS custom properties M07 sets (`--es-primary`,
/// `--es-on-primary`, `--es-surface-text`, …; see `cssVariables()` in
/// `functions/src/theme/resolve.ts`).
@immutable
class ResolvedMenuTheme {
  const ResolvedMenuTheme({
    required this.primary,
    required this.onPrimary,
    required this.secondary,
    required this.onSecondary,
    required this.background,
    required this.surface,
    required this.text,
    required this.surfaceText,
    required this.mutedText,
    required this.accent,
    required this.border,
    required this.font,
    required this.layout,
    required this.cardLayout,
    required this.mode,
    this.issues = const [],
  });

  final String primary;
  final String onPrimary;
  final String secondary;
  final String onSecondary;
  final String background;
  final String surface;

  /// Body text on [background].
  final String text;

  /// Text on [surface] (cards).
  final String surfaceText;

  /// Descriptions; AA on both background and surface.
  final String mutedText;

  /// Primary as a text colour; AA on both background and surface.
  final String accent;

  /// Dividers and card outlines (decorative).
  final String border;
  final String font;
  final MenuLayout layout;
  final CardLayout cardLayout;
  final MenuMode mode;
  final List<ContrastIssue> issues;

  bool get hasIssues => issues.isNotEmpty;

  ContrastIssue? issue(ContrastIssueKind kind) =>
      issues.where((i) => i.kind == kind).firstOrNull;

  Color get primaryColor => hexToColor(primary);
  Color get onPrimaryColor => hexToColor(onPrimary);
  Color get secondaryColor => hexToColor(secondary);
  Color get onSecondaryColor => hexToColor(onSecondary);
  Color get backgroundColor => hexToColor(background);
  Color get surfaceColor => hexToColor(surface);
  Color get textColor => hexToColor(text);
  Color get surfaceTextColor => hexToColor(surfaceText);
  Color get mutedTextColor => hexToColor(mutedText);
  Color get accentColor => hexToColor(accent);
  Color get borderColor => hexToColor(border);

  /// The same shape as `resolveTheme()` returns in functions (tests).
  Map<String, Object> toMap() => {
    'primary': primary,
    'onPrimary': onPrimary,
    'secondary': secondary,
    'onSecondary': onSecondary,
    'background': background,
    'surface': surface,
    'text': text,
    'surfaceText': surfaceText,
    'mutedText': mutedText,
    'accent': accent,
    'border': border,
    'font': font,
    'layout': layout.wire,
    'cardLayout': cardLayout.wire,
    'mode': mode.wire,
    'issues': [
      for (final i in issues)
        {
          'kind': i.kind.wire,
          'original': i.original,
          'ratio': i.ratio,
          'adjusted': i.adjusted,
        },
    ],
  };
}

/// Background when the owner flips the mode and has not chosen one.
const modeBackground = {MenuMode.light: '#FFFFFF', MenuMode.dark: '#121212'};

double _round2(double n) => (n * 100).round() / 100;

/// Applies [settings] to [base] and fixes text colours below AA (FR-060).
///
/// Same rules as `resolveTheme()` in `functions/src/theme/resolve.ts`:
/// 1. Overrides win over the theme's tokens.
/// 2. Changing the mode without choosing a background uses [modeBackground].
/// 3. The surface is the theme's while the background is the theme's;
///    otherwise it is derived from the background.
/// 4. Text is the theme's text colour (or the readable one after a mode
///    change). Below 4.5:1 it becomes near-black or white and an issue is
///    reported. The same for text on the surface.
/// 5. The accent (primary as text) must reach AA on background and
///    surface; otherwise it is blended toward the readable text colour.
ResolvedMenuTheme resolveMenuTheme(
  ThemeTokens? base, [
  ThemeSettings settings = const ThemeSettings(),
]) {
  final t = base ?? ThemeTokens.fallback;
  final s = settings;
  final mode = s.mode ?? t.mode;
  final sameMode = mode == t.mode;
  final primary = s.primary ?? t.primary;
  final secondary = s.secondary ?? t.secondary;
  final background =
      s.background ?? (sameMode ? t.background : modeBackground[mode]!);
  final themeBackground = background == t.background && sameMode;
  final surface = themeBackground
      ? t.surface
      : Contrast.isLight(background)
      ? Contrast.mix(background, '#000000', 0.04)
      : Contrast.mix(background, '#FFFFFF', 0.08);

  final issues = <ContrastIssue>[];

  final wanted = sameMode ? t.text : Contrast.readableTextOn(background);
  var text = wanted;
  final textRatio = Contrast.ratio(wanted, background);
  if (textRatio < Contrast.aaText) {
    text = Contrast.readableTextOn(background);
    issues.add(
      ContrastIssue(
        kind: ContrastIssueKind.text,
        original: wanted,
        ratio: _round2(textRatio),
        adjusted: text,
      ),
    );
  }

  var surfaceText = text;
  final surfaceRatio = Contrast.ratio(text, surface);
  if (surfaceRatio < Contrast.aaText) {
    surfaceText = Contrast.readableTextOn(surface);
    issues.add(
      ContrastIssue(
        kind: ContrastIssueKind.surfaceText,
        original: text,
        ratio: _round2(surfaceRatio),
        adjusted: surfaceText,
      ),
    );
  }

  final accentRatio = [
    Contrast.ratio(primary, background),
    Contrast.ratio(primary, surface),
  ].reduce((a, b) => a < b ? a : b);
  final accent = Contrast.ensure(primary, [
    background,
    surface,
  ], Contrast.readableTextOn(background));
  if (accentRatio < Contrast.aaText) {
    issues.add(
      ContrastIssue(
        kind: ContrastIssueKind.accent,
        original: primary,
        ratio: _round2(accentRatio),
        adjusted: accent,
      ),
    );
  }

  var mutedText = text;
  for (final amount in const [0.3, 0.2, 0.1]) {
    final m = Contrast.mix(text, background, amount);
    if (Contrast.ratio(m, background) >= Contrast.aaText &&
        Contrast.ratio(m, surface) >= Contrast.aaText) {
      mutedText = m;
      break;
    }
  }

  return ResolvedMenuTheme(
    primary: primary,
    onPrimary: Contrast.readableTextOn(primary),
    secondary: secondary,
    onSecondary: Contrast.readableTextOn(secondary),
    background: background,
    surface: surface,
    text: text,
    surfaceText: surfaceText,
    mutedText: mutedText,
    accent: accent,
    border: Contrast.mix(background, text, 0.15),
    font: s.font ?? t.font,
    layout: s.layout ?? t.layout,
    cardLayout: s.cardLayout ?? t.cardLayout,
    mode: mode,
    issues: issues,
  );
}
