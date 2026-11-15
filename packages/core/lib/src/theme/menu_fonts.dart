import 'package:flutter/material.dart' show TextStyle, TextTheme;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';

/// The curated menu fonts (FR-055, FR-059).
///
/// The live list is `config/platform.fonts` (admins change it in M11);
/// [defaults] is used until it loads or when it is missing. Keep it in sync
/// with `SEED_FONTS` in `functions/src/theme/seed-themes.ts`. Names are
/// Google Fonts families; the public menu (M07) loads the same family.
abstract final class MenuFonts {
  static const defaults = [
    'Poppins',
    'Inter',
    'Lora',
    'Nunito',
    'Playfair Display',
    'Noto Sans',
  ];
}

/// Applies a menu font family to text styles. Previews use it so the owner
/// sees the real typeface.
abstract class MenuFontResolver {
  const MenuFontResolver();

  /// [base] in [family]; [base] unchanged when the family is unknown.
  TextStyle style(String family, TextStyle base);

  TextTheme textTheme(String family, TextTheme base) => TextTheme(
    displayLarge: _apply(family, base.displayLarge),
    displayMedium: _apply(family, base.displayMedium),
    displaySmall: _apply(family, base.displaySmall),
    headlineLarge: _apply(family, base.headlineLarge),
    headlineMedium: _apply(family, base.headlineMedium),
    headlineSmall: _apply(family, base.headlineSmall),
    titleLarge: _apply(family, base.titleLarge),
    titleMedium: _apply(family, base.titleMedium),
    titleSmall: _apply(family, base.titleSmall),
    bodyLarge: _apply(family, base.bodyLarge),
    bodyMedium: _apply(family, base.bodyMedium),
    bodySmall: _apply(family, base.bodySmall),
    labelLarge: _apply(family, base.labelLarge),
    labelMedium: _apply(family, base.labelMedium),
    labelSmall: _apply(family, base.labelSmall),
  );

  TextStyle? _apply(String family, TextStyle? s) =>
      s == null ? null : style(family, s);
}

/// Loads the family from Google Fonts at run time (cached by the browser
/// and on the device). Unknown families fall back to the default font.
class GoogleMenuFontResolver extends MenuFontResolver {
  const GoogleMenuFontResolver();

  @override
  TextStyle style(String family, TextStyle base) {
    try {
      return GoogleFonts.getFont(family, textStyle: base);
    } on Exception {
      return base;
    }
  }
}

/// Sets only `fontFamily`, without loading anything (widget tests, and
/// platforms without network access to Google Fonts).
class PlainMenuFontResolver extends MenuFontResolver {
  const PlainMenuFontResolver();

  @override
  TextStyle style(String family, TextStyle base) =>
      base.copyWith(fontFamily: family);
}

/// The font resolver the apps use. Widget tests override it with
/// [PlainMenuFontResolver].
final menuFontResolverProvider = Provider<MenuFontResolver>(
  (ref) => const GoogleMenuFontResolver(),
);
