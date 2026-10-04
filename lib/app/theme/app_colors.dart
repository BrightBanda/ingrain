import 'package:flutter/material.dart';

/// Static brand and semantic colors.
///
/// Widgets should prefer `Theme.of(context).colorScheme` over these constants
/// so both the light and dark themes stay supported automatically; the
/// constants exist to seed the schemes and for the few places where a fixed
/// brand color is wanted regardless of brightness.
abstract final class AppColors {
  // Brand hues.
  static const Color primaryDark = Color(0xFF12305E); // deep navy — headings, text on pale containers
  static const Color primaryMain = Color(0xFF2F6FED); // vivid blue — primary interactive color
  static const Color primaryLight = Color(0xFF9DB8F0); // softened blue — accents on dark surfaces

  // Backgrounds.
  static const Color backgroundLight = Color(0xFFF6F8FC);
  static const Color backgroundDark = Color(0xFF0D1015);
  static const Color surface = Color(0xFFFFFFFF);
  static const Color surfaceDark = Color(0xFF161B24);

  // Text.
  static const Color textPrimary = Color(0xFF141B2D);
  static const Color textSecondary = Color(0xFF5B6577);
  static const Color textOnPrimary = Colors.white;

  // Semantic.
  static const Color error = Color(0xFFB3261E);
  static const Color success = Color(0xFF188857);
  static const Color warning = Color(0xFFB25E00);

  // Hairlines.
  static const Color outlineLight = Color(0xFFDCE2EC);
  static const Color outlineDark = Color(0xFF39414F);
}
