import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import 'app_palette.dart';

class AppTheme {
  AppTheme._();

  static ThemeData build(Brightness brightness) {
    final isDark = brightness == Brightness.dark;
    final scheme = isDark
        ? const ColorScheme.dark(
            surface: Color(0xFF131314),
            onSurface: Color(0xFFE8EAED),
            onSurfaceVariant: Color(0xFF9AA0A6),
            outline: Color(0xFF3C4043),
            primary: Color(0xFF8AB4F8),
          )
        : const ColorScheme.light(
            surface: AppPalette.lightSurface,
            onSurface: AppPalette.lightGreenText,
            onSurfaceVariant: AppPalette.lightGreenMuted,
            outline: AppPalette.lightGreenBorder,
            primary: AppPalette.lightGreenPrimary,
            primaryContainer: AppPalette.lightMintMid,
          );

    final base = ThemeData(
      useMaterial3: true,
      brightness: brightness,
      colorScheme: scheme,
      scaffoldBackgroundColor: scheme.surface,
    );

    final inter = GoogleFonts.interTextTheme(
      base.textTheme,
    ).apply(bodyColor: scheme.onSurface, displayColor: scheme.onSurface);

    return base.copyWith(
      textTheme: inter.copyWith(
        headlineLarge: GoogleFonts.plusJakartaSans(
          fontSize: 36,
          fontWeight: FontWeight.w500,
          letterSpacing: -0.6,
          height: 1.2,
          color: scheme.onSurface,
        ),
        titleMedium: GoogleFonts.plusJakartaSans(
          fontSize: 16,
          fontWeight: FontWeight.w500,
          height: 1.45,
          color: scheme.onSurface,
        ),
        bodyLarge: GoogleFonts.inter(
          fontSize: 16,
          fontWeight: FontWeight.w400,
          height: 1.65,
          color: scheme.onSurface,
        ),
        bodyMedium: GoogleFonts.inter(
          fontSize: 15,
          fontWeight: FontWeight.w400,
          height: 1.5,
          color: scheme.onSurfaceVariant,
        ),
        labelLarge: GoogleFonts.inter(
          fontSize: 16,
          fontWeight: FontWeight.w400,
          color: scheme.onSurface,
        ),
        labelMedium: GoogleFonts.inter(
          fontSize: 13,
          fontWeight: FontWeight.w500,
          color: scheme.onSurface,
        ),
      ),
    );
  }
}
