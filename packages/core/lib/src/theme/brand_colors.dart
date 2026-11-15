import 'package:flutter/painting.dart';

/// EazySuvai brand colours (architecture §6) plus accessible variants.
///
/// The brand orange and the documented deep orange are below the WCAG 2.1 AA
/// 4.5:1 ratio for normal-size text on white (#FF7A00 ≈ 2.6:1,
/// #C8650A ≈ 3.95:1). They are used for decoration and large text only.
/// Small text and filled-button backgrounds use [orangeText] and
/// [greenText], which pass AA on both white and cream. The theme tests check
/// every pair.
abstract final class BrandColors {
  /// Primary orange: decoration, large text, dark-mode primary.
  static const orange = Color(0xFFFF7A00);

  /// Deep orange from the brand guide: large text and icons on light surfaces.
  static const deepOrange = Color(0xFFC8650A);

  /// Accessible orange for normal-size text and filled buttons on light
  /// surfaces (≈ 5.3:1 on white, ≈ 5.0:1 on cream).
  static const orangeText = Color(0xFFA8550A);

  static const charcoal = Color(0xFF2B2B2B);

  /// Leaf green: decoration and large text.
  static const leafGreen = Color(0xFF4C9A2A);

  /// Accessible green for normal-size text on light surfaces (≈ 5.2:1).
  static const greenText = Color(0xFF3B7A20);

  /// Light green for use on dark surfaces.
  static const greenOnDark = Color(0xFF8FCB6B);

  static const white = Color(0xFFFFFFFF);
  static const cream = Color(0xFFFFF8EE);

  /// Dark-mode surfaces, derived from charcoal.
  static const darkSurface = Color(0xFF1C1B1A);
  static const darkSurfaceHigh = Color(0xFF2B2B2B);
}
