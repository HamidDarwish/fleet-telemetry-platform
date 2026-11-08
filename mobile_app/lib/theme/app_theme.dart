import 'dart:math' as math;

import 'package:flutter/material.dart';

/// Brand and status colors shared by the whole app.
class AppColors {
  AppColors._();

  static const Color primary = Color(0xFF2563EB);
  static const Color success = Color(0xFF16A34A);
  static const Color warning = Color(0xFFF59E0B);
  static const Color error = Color(0xFFDC2626);
  static const Color offline = Color(0xFF94A3B8);
  static const Color orange = Color(0xFFEA580C);
}

class AppRadius {
  AppRadius._();

  static const double card = 16;
  static const double control = 12;
  static const double pill = 999;
}

/// Neutral colors that differ between the light and the dark theme.
class AppPalette {
  final Color background;
  final Color surface;
  final Color surfaceAlt;
  final Color border;
  final Color textPrimary;
  final Color textSecondary;
  final Color textMuted;
  final Color skeleton;
  final List<BoxShadow> shadow;

  const AppPalette({
    required this.background,
    required this.surface,
    required this.surfaceAlt,
    required this.border,
    required this.textPrimary,
    required this.textSecondary,
    required this.textMuted,
    required this.skeleton,
    required this.shadow,
  });

  static const AppPalette light = AppPalette(
    background: Color(0xFFF8FAFC),
    surface: Colors.white,
    surfaceAlt: Color(0xFFF1F5F9),
    border: Color(0xFFE2E8F0),
    textPrimary: Color(0xFF0F172A),
    textSecondary: Color(0xFF64748B),
    textMuted: Color(0xFF94A3B8),
    skeleton: Color(0xFFE2E8F0),
    shadow: [BoxShadow(color: Color(0x0D0F172A), blurRadius: 14, offset: Offset(0, 4))],
  );

  static const AppPalette dark = AppPalette(
    background: Color(0xFF0B1220),
    surface: Color(0xFF111B2E),
    surfaceAlt: Color(0xFF182338),
    border: Color(0xFF243350),
    textPrimary: Color(0xFFE5EDF8),
    textSecondary: Color(0xFF94A3B8),
    textMuted: Color(0xFF64748B),
    skeleton: Color(0xFF1E2B44),
    shadow: [],
  );

  static AppPalette of(BuildContext context) =>
      Theme.of(context).brightness == Brightness.dark ? dark : light;
}

/// A text-safe variant of a status color (darker on light, lighter on dark)
/// so colored labels stay readable on their tinted backgrounds.
Color readableOn(BuildContext context, Color c) {
  final hsl = HSLColor.fromColor(c);
  final isDark = Theme.of(context).brightness == Brightness.dark;
  final l = isDark ? math.max(hsl.lightness, 0.68) : math.min(hsl.lightness, 0.38);
  return hsl.withLightness(l).toColor();
}

class AppTheme {
  AppTheme._();

  static ThemeData get light => _build(Brightness.light);
  static ThemeData get dark => _build(Brightness.dark);

  static OutlineInputBorder _border(Color c, [double width = 1]) => OutlineInputBorder(
        borderRadius: BorderRadius.circular(AppRadius.control),
        borderSide: BorderSide(color: c, width: width),
      );

  static ThemeData _build(Brightness brightness) {
    final isDark = brightness == Brightness.dark;
    final p = isDark ? AppPalette.dark : AppPalette.light;
    final primary = isDark ? const Color(0xFF60A5FA) : AppColors.primary;
    final error = isDark ? const Color(0xFFF87171) : AppColors.error;

    final scheme = ColorScheme.fromSeed(seedColor: AppColors.primary, brightness: brightness).copyWith(
      primary: primary,
      onPrimary: isDark ? const Color(0xFF0B1220) : Colors.white,
      primaryContainer: isDark ? const Color(0xFF1E3A8A) : const Color(0xFFDBEAFE),
      onPrimaryContainer: isDark ? const Color(0xFFDBEAFE) : const Color(0xFF1E3A8A),
      secondary: primary,
      secondaryContainer: primary.withAlpha(isDark ? 60 : 32),
      onSecondaryContainer: primary,
      surface: p.surface,
      onSurface: p.textPrimary,
      onSurfaceVariant: p.textSecondary,
      outline: p.border,
      outlineVariant: p.border,
      error: error,
      onError: isDark ? const Color(0xFF0B1220) : Colors.white,
    );

    final base = ThemeData(useMaterial3: true, brightness: brightness, colorScheme: scheme);
    final text = base.textTheme.apply(bodyColor: p.textPrimary, displayColor: p.textPrimary);

    return base.copyWith(
      scaffoldBackgroundColor: p.background,
      textTheme: text,
      appBarTheme: AppBarTheme(
        backgroundColor: p.background,
        foregroundColor: p.textPrimary,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: false,
        titleTextStyle: TextStyle(fontSize: 18, fontWeight: FontWeight.w700, color: p.textPrimary),
      ),
      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: p.surface,
        surfaceTintColor: Colors.transparent,
        indicatorColor: scheme.secondaryContainer,
        elevation: 0,
        height: 68,
        labelBehavior: NavigationDestinationLabelBehavior.alwaysShow,
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          minimumSize: const Size(0, 48),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadius.control)),
          textStyle: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          minimumSize: const Size(0, 48),
          foregroundColor: p.textPrimary,
          side: BorderSide(color: p.border),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadius.control)),
          textStyle: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadius.control)),
          textStyle: const TextStyle(fontWeight: FontWeight.w600),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: p.surface,
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        hintStyle: TextStyle(color: p.textMuted),
        labelStyle: TextStyle(color: p.textSecondary),
        border: _border(p.border),
        enabledBorder: _border(p.border),
        focusedBorder: _border(primary, 1.6),
        errorBorder: _border(error),
        focusedErrorBorder: _border(error, 1.6),
        disabledBorder: _border(p.border.withAlpha(120)),
      ),
      dividerTheme: DividerThemeData(color: p.border, thickness: 1, space: 1),
      snackBarTheme: SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadius.control)),
      ),
      bottomSheetTheme: BottomSheetThemeData(
        backgroundColor: p.surface,
        surfaceTintColor: Colors.transparent,
        showDragHandle: true,
        shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      ),
      progressIndicatorTheme: ProgressIndicatorThemeData(color: primary),
    );
  }
}
