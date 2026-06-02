import 'package:flutter/material.dart';

abstract final class AppColors {
  // ── Liquid Glass – Apple TV 26 palette ──────────────────────────────────────
  // Backgrounds: near-black with a very subtle cool-blue tint
  static const background        = Color(0xFF060608);
  static const backgroundAlt     = Color(0xFF0C0C10);

  // Glass surfaces – semi-transparent, rendered via BackdropFilter
  static const glassFill         = Color(0x26FFFFFF);   // white 15 %
  static const glassFillHover    = Color(0x33FFFFFF);   // white 20 %
  static const glassFillStrong   = Color(0x40FFFFFF);   // white 25 %
  static const glassBorder       = Color(0x30FFFFFF);   // subtle white rim
  static const glassBorderFocus  = Color(0xCCFFFFFF);   // bright focus rim

  // Solid surfaces (used when blur is not needed / too expensive)
  static const surface           = Color(0xFF16161A);
  static const surfaceVariant    = Color(0xFF1E1E24);
  static const surfaceCard       = Color(0xFF26262E);
  static const separator         = Color(0xFF2A2A32);

  // Accent – iridescent blue-violet (Apple tvOS 26 system tint)
  static const accent            = Color(0xFF2C7DFF);   // vivid blue
  static const accentSecondary   = Color(0xFF7B5CF0);   // violet
  static const accentGlow        = Color(0x662C7DFF);   // blue glow

  // Typography
  static const onBackground      = Colors.white;
  static const onSurface         = Color(0xFFEEEEF4);
  static const onSurfaceMuted    = Color(0xFF8E8E9A);
  static const onSurfaceSubtle   = Color(0xFF5A5A66);
}

/// TV safe-zone margins — keeps content inside the overscan area on all TVs.
/// Use [h] for horizontal padding and [v] for vertical padding.
abstract final class TvSafe {
  static const double h   = 64.0;  // left / right safe margin
  static const double v   = 48.0;  // top / bottom safe margin
  /// Height of the glass top-navigation bar (incl. its own vertical padding).
  static const double navBarHeight = 72.0;
  /// Top content offset: below the nav bar + safe margin.
  static const double contentTop = navBarHeight + 8.0;
}

abstract final class LiquidGlass {
  // Blur radius for glass surfaces
  static const double blurLight  = 12.0;
  static const double blurMedium = 24.0;
  static const double blurHeavy  = 40.0;

  // Standard glass decoration (unfocused)
  static BoxDecoration surface({double radius = 16, bool strong = false}) => BoxDecoration(
    borderRadius: BorderRadius.circular(radius),
    border: Border.all(color: AppColors.glassBorder, width: 1),
    gradient: LinearGradient(
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
      colors: [
        strong ? AppColors.glassFillStrong : AppColors.glassFill,
        Colors.white.withAlpha(8),
      ],
    ),
  );

  // Focused state: bright rim + stronger fill + glow
  static BoxDecoration focused({double radius = 16}) => BoxDecoration(
    borderRadius: BorderRadius.circular(radius),
    border: Border.all(color: AppColors.glassBorderFocus, width: 2.5),
    gradient: const LinearGradient(
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
      colors: [
        Color(0x55FFFFFF),
        Color(0x22FFFFFF),
      ],
    ),
    boxShadow: const [
      BoxShadow(color: Color(0x60FFFFFF), blurRadius: 22, spreadRadius: 0),
      BoxShadow(color: AppColors.accentGlow, blurRadius: 32, spreadRadius: -4),
    ],
  );

  // Iridescent top-rim highlight (thin linear gradient overlay)
  static const topRimGradient = LinearGradient(
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
    colors: [Color(0x50FFFFFF), Colors.transparent],
    stops: [0.0, 0.18],
  );
}

abstract final class AppTheme {
  static ThemeData get theme {
    const colorScheme = ColorScheme.dark(
      surface: AppColors.surface,
      primary: AppColors.accent,
      onPrimary: Colors.white,
      secondary: AppColors.accentSecondary,
      onSecondary: Colors.white,
    );

    return ThemeData(
      brightness: Brightness.dark,
      colorScheme: colorScheme,
      scaffoldBackgroundColor: AppColors.background,
      canvasColor: AppColors.background,
      cardColor: AppColors.surface,
      splashFactory: NoSplash.splashFactory,
      highlightColor: Colors.transparent,
      hoverColor: Colors.transparent,
      focusColor: Colors.transparent,
      cardTheme: CardThemeData(
        color: AppColors.surface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        elevation: 0,
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: AppColors.glassFill,
        labelStyle: const TextStyle(color: AppColors.onSurfaceMuted, fontSize: 18),
        hintStyle: const TextStyle(color: AppColors.onSurfaceMuted),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: AppColors.glassBorder),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: AppColors.glassBorderFocus, width: 2),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: Colors.redAccent),
        ),
        focusedErrorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: Colors.redAccent, width: 2),
        ),
        contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 18),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: AppColors.accent,
          foregroundColor: Colors.white,
          padding: const EdgeInsets.symmetric(horizontal: 40, vertical: 18),
          textStyle: const TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
          elevation: 0,
        ),
      ),
      textTheme: const TextTheme(
        displayLarge:   TextStyle(fontSize: 52, fontWeight: FontWeight.w800, color: AppColors.onBackground, height: 1.05, letterSpacing: -2.0),
        displayMedium:  TextStyle(fontSize: 42, fontWeight: FontWeight.w800, color: AppColors.onBackground, height: 1.05, letterSpacing: -1.5),
        headlineLarge:  TextStyle(fontSize: 34, fontWeight: FontWeight.w700, color: AppColors.onBackground, letterSpacing: -0.8),
        headlineMedium: TextStyle(fontSize: 28, fontWeight: FontWeight.w700, color: AppColors.onBackground, letterSpacing: -0.5),
        headlineSmall:  TextStyle(fontSize: 22, fontWeight: FontWeight.w600, color: AppColors.onBackground, letterSpacing: -0.3),
        titleLarge:     TextStyle(fontSize: 20, fontWeight: FontWeight.w600, color: AppColors.onBackground),
        titleMedium:    TextStyle(fontSize: 17, fontWeight: FontWeight.w500, color: AppColors.onBackground),
        titleSmall:     TextStyle(fontSize: 15, fontWeight: FontWeight.w500, color: AppColors.onSurface),
        bodyLarge:      TextStyle(fontSize: 17, fontWeight: FontWeight.normal, color: AppColors.onSurface, height: 1.55),
        bodyMedium:     TextStyle(fontSize: 15, fontWeight: FontWeight.normal, color: AppColors.onSurface),
        bodySmall:      TextStyle(fontSize: 13, fontWeight: FontWeight.normal, color: AppColors.onSurfaceMuted),
        labelLarge:     TextStyle(fontSize: 17, fontWeight: FontWeight.w600, color: AppColors.onBackground),
        labelMedium:    TextStyle(fontSize: 15, fontWeight: FontWeight.w600, color: AppColors.onSurface),
        labelSmall:     TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: AppColors.onSurfaceMuted, letterSpacing: 0.3),
      ),
    );
  }
}
