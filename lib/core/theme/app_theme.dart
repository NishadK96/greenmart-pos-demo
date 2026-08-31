import 'package:flutter/material.dart';

abstract final class AppColors {
  static const primary = Color(0xFF176B5B);
  static const primaryDark = Color(0xFF0D3933);
  static const navy = Color(0xFF10231F);
  static const accent = Color(0xFFE9A23B);
  static const canvas = Color(0xFFF3F6F5);
  static const ink = Color(0xFF17211F);
  static const muted = Color(0xFF63706D);
  static const danger = Color(0xFFC94C4C);
}

abstract final class AppSpacing {
  static const xs = 6.0, sm = 10.0, md = 16.0, lg = 24.0, xl = 32.0;
}

abstract final class AppRadius {
  static const sm = 10.0, md = 16.0, lg = 24.0;
}

ThemeData buildTheme() {
  final scheme = ColorScheme.fromSeed(
    seedColor: AppColors.primary,
    brightness: Brightness.light,
  );
  return ThemeData(
    useMaterial3: true,
    colorScheme: scheme,
    scaffoldBackgroundColor: AppColors.canvas,
    fontFamily: 'NotoSans',
    fontFamilyFallback: const ['NotoSansArabic'],
    visualDensity: VisualDensity.compact,
    dividerTheme: const DividerThemeData(
      color: Color(0xFFE8ECEA),
      thickness: 1,
    ),
    navigationBarTheme: const NavigationBarThemeData(
      height: 72,
      backgroundColor: Colors.white,
      indicatorColor: Color(0xFFDCECE8),
      elevation: 8,
    ),
    appBarTheme: const AppBarTheme(
      backgroundColor: Colors.transparent,
      surfaceTintColor: Colors.transparent,
    ),
    cardTheme: const CardThemeData(
      elevation: 0,
      color: Colors.white,
      margin: EdgeInsets.zero,
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: Colors.white,
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(AppRadius.sm),
        borderSide: BorderSide.none,
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(AppRadius.sm),
        borderSide: const BorderSide(color: Color(0xFFE3E8E6)),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(AppRadius.sm),
        borderSide: const BorderSide(color: AppColors.primary, width: 1.5),
      ),
      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
    ),
    hoverColor: AppColors.primary.withValues(alpha: .04),
    focusColor: AppColors.primary.withValues(alpha: .08),
    checkboxTheme: CheckboxThemeData(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
      side: const BorderSide(color: Color(0xFFB7C1BE)),
    ),
    popupMenuTheme: PopupMenuThemeData(
      color: Colors.white,
      surfaceTintColor: Colors.transparent,
      elevation: 10,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: const BorderSide(color: Color(0xFFE3E8E6)),
      ),
    ),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        minimumSize: const Size(48, 48),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadius.sm),
        ),
      ),
    ),
  );
}
