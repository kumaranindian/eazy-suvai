import 'dart:async';

import 'package:core/core.dart';
import 'package:owner_app/features/theme/data/theme_repository.dart';

/// Three of the seed themes (`functions/src/theme/seed-themes.ts`): two for
/// the Free plan and one premium dark theme.
final seedPresets = [
  ThemePreset(
    id: 'saffron',
    name: 'Saffron',
    sort: 10,
    tokens: ThemeTokens.fromMap({
      'primary': '#A8550A',
      'secondary': '#3B7A20',
      'background': '#FFF8EE',
      'surface': '#FFFFFF',
      'text': '#2B2B2B',
      'font': 'Poppins',
      'layout': 'list',
      'cardLayout': 'image-left',
      'mode': 'light',
    }),
  ),
  ThemePreset(
    id: 'minimal',
    name: 'Minimal',
    sort: 20,
    tokens: ThemeTokens.fromMap({
      'primary': '#222222',
      'secondary': '#5C5C5C',
      'background': '#FFFFFF',
      'surface': '#F6F6F6',
      'text': '#1A1A1A',
      'font': 'Inter',
      'layout': 'list',
      'cardLayout': 'compact',
      'mode': 'light',
    }),
  ),
  ThemePreset(
    id: 'midnight',
    name: 'Midnight',
    premium: true,
    sort: 40,
    tokens: ThemeTokens.fromMap({
      'primary': '#FFB454',
      'secondary': '#8FCB6B',
      'background': '#121417',
      'surface': '#1E2126',
      'text': '#F2EDE8',
      'font': 'Inter',
      'layout': 'grid',
      'cardLayout': 'image-top',
      'mode': 'dark',
    }),
  ),
];

/// In-memory `themes/*` and `config/platform.fonts`.
class FakeThemeRepository implements ThemeRepository {
  FakeThemeRepository({List<ThemePreset>? themes, this.fonts})
    : themes = themes ?? seedPresets;

  final List<ThemePreset> themes;

  /// Null: the font list is missing (the app falls back to the defaults).
  final List<String>? fonts;

  @override
  Stream<List<ThemePreset>> watchThemes() => Stream.value(themes);

  @override
  Stream<List<String>?> watchFonts() => Stream.value(fonts);
}
