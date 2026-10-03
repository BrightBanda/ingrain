import 'package:flutter/material.dart';
import 'package:ingrain/app/theme/app_colors.dart';

abstract final class AppTheme {
  static ThemeData light = ThemeData(
    brightness: Brightness.light,
    colorScheme:
        ColorScheme.fromSeed(
          seedColor: AppColors.primaryMain,
          brightness: Brightness.light,
        ).copyWith(
          primary: AppColors.primaryMain,
          onPrimary: AppColors.textOnPrimary,
          surface: AppColors.surface,
          onSurface: AppColors.textPrimary,
          error: AppColors.error,
        ),
    scaffoldBackgroundColor: AppColors.surface,
    textTheme: const TextTheme(
      bodyLarge: TextStyle(color: AppColors.textPrimary),
      bodyMedium: TextStyle(color: AppColors.textSecondary),
    ),
    appBarTheme: const AppBarTheme(
      backgroundColor: AppColors.primaryMain,
      foregroundColor: AppColors.textOnPrimary,
    ),
    useMaterial3: true,
  );

  static ThemeData dark = ThemeData(
    brightness: Brightness.dark,
    colorScheme:
        ColorScheme.fromSeed(
          seedColor: AppColors.primaryMain,
          brightness: Brightness.dark,
        ).copyWith(
          primary: AppColors.primaryLight,
          onPrimary: AppColors.textPrimary,
          surface: AppColors.surfaceDark,
          onSurface: Colors.grey.shade300,
          error: AppColors.error,
        ),
    scaffoldBackgroundColor: AppColors.surfaceDark,
    appBarTheme: const AppBarTheme(
      backgroundColor: AppColors.primaryDark,
      foregroundColor: AppColors.textOnPrimary,
    ),
    useMaterial3: true,
  );
}
