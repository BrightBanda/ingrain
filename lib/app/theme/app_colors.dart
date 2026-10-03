import 'package:flutter/material.dart';

class AppColors {
  static const MaterialColor primary = MaterialColor(
    0xFF0D47A1,
    _primarySwatch,
  );
  static const Color primaryDark = Color(0xFF0D47A1);
  static const Color primaryMain = Color(0xFF2196F3);
  static const Color primaryLight = Color(0xFF90CAF9);
  static const Color primaryPale = Color(0xFFE3F2FD);

  static const Color textPrimary = Color(0xFF212121);
  static const Color textSecondary = Color(0xFF757575);
  static const Color textOnPrimary = Color(0xFFFFFFFF);
  static const Color surface = Color(0xFFFFFFFF);
  static const Color surfaceDark = Color(0xFF121212);
  static const Color error = Color(0xFFB00020);

  static const double subtitleFontSize = 16.0;
  static const double subtitleFontSizeLarge = 20.0;
  static const double subtitleFontSizeSmall = 14.0;
}

const _primarySwatch = <int, Color>{
  50: Color(0xFFE3F2FD),
  100: Color(0xFFBBDEFB),
  200: Color(0xFF90CAF9),
  300: Color(0xFF64B5F6),
  400: Color(0xFF42A5F5),
  500: Color(0xFF2196F3),
  600: Color(0xFF1E88E5),
  700: Color(0xFF1976D2),
  800: Color(0xFF1565C0),
  900: Color(0xFF0D47A1),
};
