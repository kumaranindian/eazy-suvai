import 'package:flutter/material.dart';

import 'brand_colors.dart';

/// Light and dark Material 3 themes built from the brand colours.
abstract final class AppTheme {
  /// Minimum touch target (accessibility rule in AGENTS.md).
  static const double minTouchTarget = 48;

  static ColorScheme get lightScheme =>
      ColorScheme.fromSeed(seedColor: BrandColors.orange).copyWith(
        primary: BrandColors.orangeText,
        onPrimary: BrandColors.white,
        primaryContainer: const Color(0xFFFFDCC2),
        onPrimaryContainer: const Color(0xFF3A1A00),
        secondary: BrandColors.greenText,
        onSecondary: BrandColors.white,
        secondaryContainer: const Color(0xFFFFE6CC),
        onSecondaryContainer: BrandColors.charcoal,
        tertiary: BrandColors.orange,
        onTertiary: BrandColors.charcoal,
        surface: BrandColors.white,
        onSurface: BrandColors.charcoal,
        onSurfaceVariant: const Color(0xFF55504A),
        surfaceContainerLowest: BrandColors.white,
        surfaceContainerLow: BrandColors.cream,
        surfaceContainer: const Color(0xFFFFF3E3),
        surfaceContainerHigh: const Color(0xFFFCEEDC),
        surfaceContainerHighest: const Color(0xFFF7E8D4),
        outline: const Color(0xFF857A6F),
        error: const Color(0xFFB3261E),
        onError: BrandColors.white,
      );

  static ColorScheme get darkScheme =>
      ColorScheme.fromSeed(
        seedColor: BrandColors.orange,
        brightness: Brightness.dark,
      ).copyWith(
        primary: BrandColors.orange,
        onPrimary: const Color(0xFF1C1B1A),
        primaryContainer: const Color(0xFF6B3400),
        onPrimaryContainer: const Color(0xFFFFDCC2),
        secondary: BrandColors.greenOnDark,
        onSecondary: const Color(0xFF10260A),
        secondaryContainer: const Color(0xFF4A3622),
        onSecondaryContainer: const Color(0xFFFFE6CC),
        tertiary: BrandColors.orange,
        onTertiary: const Color(0xFF1C1B1A),
        surface: BrandColors.darkSurface,
        onSurface: const Color(0xFFF2EDE8),
        onSurfaceVariant: const Color(0xFFD4C8BC),
        surfaceContainerLowest: const Color(0xFF151413),
        surfaceContainerLow: const Color(0xFF232120),
        surfaceContainer: const Color(0xFF272523),
        surfaceContainerHigh: BrandColors.darkSurfaceHigh,
        surfaceContainerHighest: const Color(0xFF363432),
        outline: const Color(0xFFA0958A),
        error: const Color(0xFFF2B8B5),
        onError: const Color(0xFF601410),
      );

  static ThemeData get light => _build(lightScheme);
  static ThemeData get dark => _build(darkScheme);

  static ThemeData _build(ColorScheme scheme) {
    const buttonShape = RoundedRectangleBorder(
      borderRadius: BorderRadius.all(Radius.circular(12)),
    );
    const buttonMin = Size(64, minTouchTarget);
    return ThemeData(
      useMaterial3: true,
      colorScheme: scheme,
      scaffoldBackgroundColor: scheme.surface,
      materialTapTargetSize: MaterialTapTargetSize.padded,
      visualDensity: VisualDensity.standard,
      appBarTheme: AppBarTheme(
        backgroundColor: scheme.surface,
        foregroundColor: scheme.onSurface,
        surfaceTintColor: Colors.transparent,
        centerTitle: false,
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          minimumSize: buttonMin,
          shape: buttonShape,
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          minimumSize: buttonMin,
          shape: buttonShape,
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(minimumSize: buttonMin),
      ),
      inputDecorationTheme: InputDecorationTheme(
        border: const OutlineInputBorder(
          borderRadius: BorderRadius.all(Radius.circular(12)),
        ),
        filled: true,
        fillColor: scheme.surfaceContainerLowest,
      ),
      navigationBarTheme: NavigationBarThemeData(
        indicatorColor: scheme.secondaryContainer,
      ),
      navigationRailTheme: NavigationRailThemeData(
        indicatorColor: scheme.secondaryContainer,
        backgroundColor: scheme.surfaceContainerLow,
      ),
      cardTheme: CardThemeData(
        color: scheme.surfaceContainerLowest,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(
          borderRadius: const BorderRadius.all(Radius.circular(16)),
          side: BorderSide(color: scheme.outlineVariant),
        ),
        elevation: 0,
      ),
    );
  }
}
