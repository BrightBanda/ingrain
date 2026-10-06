import 'package:flutter/material.dart';
import 'package:ingrain/app/theme/app_colors.dart';

abstract final class AppTheme {
  static ThemeData light = _base(Brightness.light);
  static ThemeData dark = _base(Brightness.dark);

  static ThemeData _base(Brightness brightness) {
    final isLight = brightness == Brightness.light;
    final scheme =
        ColorScheme.fromSeed(
          seedColor: AppColors.primaryMain,
          brightness: brightness,
        ).copyWith(
          primary: isLight ? AppColors.primaryMain : AppColors.primaryLight,
          onPrimary: isLight ? Colors.white : AppColors.primaryDark,
          secondary: AppColors.podcast,
          tertiary: AppColors.dialogue,
          surface: isLight ? AppColors.surface : AppColors.surfaceDark,
          onSurface: isLight ? AppColors.textPrimary : const Color(0xFFE3E8F0),
          error: AppColors.error,
          outlineVariant: isLight
              ? AppColors.outlineLight
              : AppColors.outlineDark,
        );

    final backgroundColor = isLight
        ? AppColors.backgroundLight
        : AppColors.backgroundDark;
    final onBackground = scheme.onSurface;

    final colorTextStyle = TextStyle(color: onBackground);

    return ThemeData(
      useMaterial3: true,
      colorScheme: scheme,
      scaffoldBackgroundColor: backgroundColor,
      splashFactory: InkSparkle.splashFactory,
      visualDensity: VisualDensity.standard,
      textTheme: TextTheme(
        headlineSmall: TextStyle(
          fontWeight: FontWeight.w700,
          color: onBackground,
          letterSpacing: -0.3,
        ),
        titleLarge: TextStyle(
          fontWeight: FontWeight.w600,
          color: onBackground,
          letterSpacing: -0.2,
        ),
        titleMedium: TextStyle(
          fontWeight: FontWeight.w600,
          color: onBackground,
        ),
        bodyLarge: colorTextStyle.copyWith(height: 1.45),
        bodyMedium: colorTextStyle.copyWith(
          height: 1.4,
          color: onBackground.withValues(alpha: 0.72),
        ),
        bodySmall: TextStyle(
          color: onBackground.withValues(alpha: 0.6),
          height: 1.35,
        ),
        labelLarge: TextStyle(fontWeight: FontWeight.w600, color: onBackground),
      ),
      appBarTheme: AppBarTheme(
        // App bars blend into the canvas with no shadow or hairline.
        backgroundColor: backgroundColor,
        foregroundColor: onBackground,
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: false,
        titleTextStyle: TextStyle(
          fontSize: 20,
          fontWeight: FontWeight.w700,
          color: onBackground,
          letterSpacing: -0.3,
        ),
      ),
      cardTheme: CardThemeData(
        elevation: 0,
        color: scheme.surface,
        margin: EdgeInsets.zero,
        clipBehavior: Clip.antiAlias,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
      ),
      dividerTheme: DividerThemeData(
        color: scheme.outlineVariant.withValues(alpha: 0.55),
        thickness: 1,
        space: 1,
      ),
      navigationBarTheme: NavigationBarThemeData(
        height: 68,
        backgroundColor: scheme.surface,
        indicatorColor: scheme.primary.withValues(alpha: 0.14),
        elevation: 0,
        labelTextStyle: WidgetStateProperty.resolveWith((states) {
          final selected = states.contains(WidgetState.selected);
          return TextStyle(
            fontSize: 11.5,
            fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
            color: selected
                ? scheme.primary
                : onBackground.withValues(alpha: 0.6),
          );
        }),
        iconTheme: WidgetStateProperty.resolveWith((states) {
          final selected = states.contains(WidgetState.selected);
          return IconThemeData(
            color: selected
                ? scheme.primary
                : onBackground.withValues(alpha: 0.6),
          );
        }),
      ),
      chipTheme: ChipThemeData(
        backgroundColor: scheme.primary.withValues(alpha: 0.1),
        side: BorderSide.none,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        labelStyle: TextStyle(color: onBackground, fontWeight: FontWeight.w500),
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 2),
      ),
      snackBarTheme: SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        elevation: 3,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: isLight
            ? scheme.primary.withValues(alpha: 0.07)
            : Colors.white.withValues(alpha: 0.06),
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 14,
          vertical: 14,
        ),
        // Borderless fields: the tinted fill marks the field, and only focus
        // draws a ring so the active input is still obvious.
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide.none,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide.none,
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: scheme.primary, width: 1.6),
        ),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          minimumSize: const Size(0, 48),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          textStyle: const TextStyle(fontWeight: FontWeight.w600),
        ),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          minimumSize: const Size(0, 44),
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          textStyle: const TextStyle(fontWeight: FontWeight.w600),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          minimumSize: const Size(0, 44),
          side: BorderSide.none,
          backgroundColor: scheme.primary.withValues(alpha: 0.1),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          textStyle: const TextStyle(fontWeight: FontWeight.w600),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          textStyle: const TextStyle(fontWeight: FontWeight.w600),
        ),
      ),
      floatingActionButtonTheme: FloatingActionButtonThemeData(
        elevation: 2,
        highlightElevation: 4,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      ),
      progressIndicatorTheme: ProgressIndicatorThemeData(
        color: scheme.primary,
        linearTrackColor: scheme.primary.withValues(alpha: 0.12),
      ),
    );
  }
}
