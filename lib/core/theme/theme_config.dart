import 'package:flutter/material.dart';

import 'brand_palette.dart';

abstract final class ThemeConfig {
  static ThemeData light() {
    const scheme = ColorScheme.light(
      primary: BrandPalette.terracotta,
      onPrimary: Colors.white,
      secondary: BrandPalette.forest,
      onSecondary: Colors.white,
      surface: Colors.white,
      onSurface: BrandPalette.ink,
      error: BrandPalette.streamRed,
    );

    return ThemeData(
      useMaterial3: true,
      scaffoldBackgroundColor: BrandPalette.sand,
      colorScheme: scheme,
      appBarTheme: const AppBarTheme(
        centerTitle: true,
        elevation: 0,
        scrolledUnderElevation: 0,
        backgroundColor: BrandPalette.terracotta,
        foregroundColor: Colors.white,
        titleTextStyle: TextStyle(
          fontSize: 18,
          fontWeight: FontWeight.w700,
          color: Colors.white,
        ),
      ),
      cardTheme: CardThemeData(
        color: Colors.white,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(18),
          side: const BorderSide(color: BrandPalette.sandDeep, width: 1.2),
        ),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: BrandPalette.terracotta,
          foregroundColor: Colors.white,
          elevation: 0,
          padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 14),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: BrandPalette.terracotta,
          side: const BorderSide(color: BrandPalette.terracotta),
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        ),
      ),
      snackBarTheme: SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        backgroundColor: BrandPalette.ink,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      ),
      progressIndicatorTheme: const ProgressIndicatorThemeData(
        color: BrandPalette.terracotta,
      ),
    );
  }
}
