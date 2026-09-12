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

ThemeData buildTheme({bool compact = false}) {
  final scheme = ColorScheme.fromSeed(
    seedColor: AppColors.primary,
    brightness: Brightness.light,
  );
  final theme = ThemeData(
    useMaterial3: true,
    colorScheme: scheme,
    scaffoldBackgroundColor: AppColors.canvas,
    fontFamily: 'NotoSans',
    fontFamilyFallback: const ['NotoSansArabic'],
    visualDensity: compact
        ? const VisualDensity(horizontal: -2, vertical: -2)
        : VisualDensity.compact,
    dividerTheme: const DividerThemeData(
      color: Color(0xFFE8ECEA),
      thickness: 1,
    ),
    navigationBarTheme: NavigationBarThemeData(
      height: compact ? 62 : 72,
      backgroundColor: Colors.white,
      indicatorColor: Color(0xFFDCECE8),
      elevation: 8,
      iconTheme: compact
          ? const WidgetStatePropertyAll(IconThemeData(size: 21))
          : null,
      labelTextStyle: compact
          ? const WidgetStatePropertyAll(
              TextStyle(fontSize: 10, fontWeight: FontWeight.w600),
            )
          : null,
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
      contentPadding: EdgeInsets.symmetric(
        horizontal: compact ? 12 : 14,
        vertical: compact ? 10 : 13,
      ),
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
        minimumSize: Size(44, compact ? 44 : 48),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadius.sm),
        ),
      ),
    ),
  );
  if (!compact) return theme;
  return theme.copyWith(
    textTheme: theme.textTheme.copyWith(
      headlineLarge: theme.textTheme.headlineLarge?.copyWith(fontSize: 22),
      headlineMedium: theme.textTheme.headlineMedium?.copyWith(fontSize: 20),
      headlineSmall: theme.textTheme.headlineSmall?.copyWith(fontSize: 18),
      titleLarge: theme.textTheme.titleLarge?.copyWith(fontSize: 18),
      titleMedium: theme.textTheme.titleMedium?.copyWith(fontSize: 15),
      titleSmall: theme.textTheme.titleSmall?.copyWith(fontSize: 13),
      bodyLarge: theme.textTheme.bodyLarge?.copyWith(fontSize: 14),
      bodyMedium: theme.textTheme.bodyMedium?.copyWith(fontSize: 13),
      bodySmall: theme.textTheme.bodySmall?.copyWith(fontSize: 11),
      labelLarge: theme.textTheme.labelLarge?.copyWith(fontSize: 13),
      labelMedium: theme.textTheme.labelMedium?.copyWith(fontSize: 12),
    ),
    iconButtonTheme: IconButtonThemeData(
      style: IconButton.styleFrom(minimumSize: const Size(42, 42)),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        minimumSize: const Size(44, 44),
        padding: const EdgeInsets.symmetric(horizontal: 12),
      ),
    ),
    textButtonTheme: TextButtonThemeData(
      style: TextButton.styleFrom(
        minimumSize: const Size(44, 42),
        padding: const EdgeInsets.symmetric(horizontal: 10),
      ),
    ),
    dialogTheme: const DialogThemeData(
      insetPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 12),
      titleTextStyle: TextStyle(
        color: AppColors.ink,
        fontFamily: 'NotoSans',
        fontSize: 19,
        fontWeight: FontWeight.w800,
      ),
    ),
    bottomSheetTheme: const BottomSheetThemeData(
      backgroundColor: Colors.white,
      surfaceTintColor: Colors.white,
      showDragHandle: true,
      constraints: BoxConstraints(maxWidth: 600),
    ),
  );
}
