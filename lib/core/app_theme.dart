import 'package:flutter/material.dart';

abstract final class AppColors {
  static const ink = Color(0xFF102A3A);
  static const teal = Color(0xFF0D9488);
  static const tealDark = Color(0xFF0F766E);
  static const mint = Color(0xFFE6F7F4);
  static const canvas = Color(0xFFF5F7F8);
  static const line = Color(0xFFE3E9EC);
  static const canvasDark = Color(0xFF081218);
  static const surfaceDark = Color(0xFF10212B);
  static const lineDark = Color(0xFF29414D);
  static const textDark = Color(0xFFE9F4F6);
  static const mutedDark = Color(0xFFA9C0C8);
  static const pending = Color(0xFFF59E0B);
  static const pendingSoft = Color(0xFFFFF5D8);
  static const success = Color(0xFF16A34A);
  static const successSoft = Color(0xFFE8F8ED);
  static const danger = Color(0xFFDC2626);
}

abstract final class AppTheme {
  static ThemeData get light => _build(Brightness.light);
  static ThemeData get dark => _build(Brightness.dark);

  static ThemeData _build(Brightness brightness) {
    final isDark = brightness == Brightness.dark;
    final foreground = isDark ? AppColors.textDark : AppColors.ink;
    final muted = isDark ? AppColors.mutedDark : const Color(0xFF4A626F);
    final surface = isDark ? AppColors.surfaceDark : Colors.white;
    final canvas = isDark ? AppColors.canvasDark : AppColors.canvas;
    final line = isDark ? AppColors.lineDark : AppColors.line;
    final scheme = ColorScheme.fromSeed(
      seedColor: AppColors.teal,
      brightness: brightness,
      primary: isDark ? const Color(0xFF38D4C4) : AppColors.teal,
      secondary: AppColors.pending,
      surface: surface,
    );

    return ThemeData(
      useMaterial3: true,
      brightness: brightness,
      colorScheme: scheme,
      scaffoldBackgroundColor: canvas,
      fontFamilyFallback: const [
        'Noto Sans Arabic',
        'Segoe UI',
        'Arial',
      ],
      textTheme: TextTheme(
        headlineLarge: TextStyle(
          color: foreground,
          fontWeight: FontWeight.w800,
          height: 1.25,
        ),
        headlineMedium: TextStyle(
          color: foreground,
          fontWeight: FontWeight.w800,
          height: 1.25,
        ),
        titleLarge: TextStyle(
          color: foreground,
          fontWeight: FontWeight.w800,
        ),
        titleMedium: TextStyle(
          color: foreground,
          fontWeight: FontWeight.w700,
        ),
        bodyLarge: TextStyle(color: foreground, height: 1.5),
        bodyMedium: TextStyle(color: muted, height: 1.45),
      ),
      appBarTheme: AppBarTheme(
        elevation: 0,
        scrolledUnderElevation: 0,
        backgroundColor: Colors.transparent,
        foregroundColor: foreground,
        centerTitle: false,
        titleTextStyle: TextStyle(
          color: foreground,
          fontSize: 20,
          fontWeight: FontWeight.w800,
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: surface,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 18,
          vertical: 17,
        ),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(18),
          borderSide: BorderSide(color: line),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(18),
          borderSide: BorderSide(color: line),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(18),
          borderSide: BorderSide(color: scheme.primary, width: 1.6),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(18),
          borderSide: const BorderSide(color: AppColors.danger),
        ),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: AppColors.teal,
          foregroundColor: Colors.white,
          minimumSize: const Size.fromHeight(54),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(18),
          ),
          textStyle: const TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w800,
          ),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: foreground,
          minimumSize: const Size.fromHeight(52),
          side: BorderSide(color: line),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(18),
          ),
          textStyle: const TextStyle(fontWeight: FontWeight.w700),
        ),
      ),
      cardTheme: CardThemeData(
        color: surface,
        elevation: 0,
        margin: EdgeInsets.zero,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(24),
          side: BorderSide(color: line),
        ),
      ),
      chipTheme: ChipThemeData(
        backgroundColor: surface,
        selectedColor: isDark
            ? AppColors.teal.withValues(alpha: .28)
            : AppColors.mint,
        side: BorderSide(color: line),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(14),
        ),
        labelStyle: TextStyle(color: foreground, fontWeight: FontWeight.w700),
      ),
      dividerColor: line,
      snackBarTheme: SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        backgroundColor: isDark ? const Color(0xFF18313D) : AppColors.ink,
        contentTextStyle: const TextStyle(color: Colors.white),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
        ),
      ),
    );
  }
}
