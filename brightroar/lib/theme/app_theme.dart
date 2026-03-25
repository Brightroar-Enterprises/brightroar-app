import 'package:flutter/material.dart';

class AppTheme {
  // Color Palette
  static const Color background = Color(0xFF0A0A0A);
  static const Color surface = Color(0xFF141414);
  static const Color surfaceElevated = Color(0xFF1C1C1C);
  static const Color surfaceCard = Color(0xFF1A1A1A);
  static const Color border = Color(0xFF2A2A2A);
  static const Color borderLight = Color(0xFF333333);

  static const Color primary = Color(0xFFD4AF37); // Gold
  static const Color primaryLight = Color(0xFFE8C84A);
  static const Color primaryDark = Color(0xFFA08020);

  static const Color textPrimary = Color(0xFFFFFFFF);
  static const Color textSecondary = Color(0xFF9A9A9A);
  static const Color textTertiary = Color(0xFF555555);

  static const Color positive = Color(0xFF00C896);
  static const Color negative = Color(0xFFFF4560);
  static const Color warning = Color(0xFFFFB800);

  static const Color btcColor = Color(0xFFF7931A);
  static const Color ethColor = Color(0xFF627EEA);
  static const Color usdtColor = Color(0xFF26A17B);
  static const Color solColor = Color(0xFF9945FF);

  static ThemeData get darkTheme {
    return ThemeData(
      brightness: Brightness.dark,
      scaffoldBackgroundColor: background,
      colorScheme: const ColorScheme.dark(
        primary: primary,
        surface: surface,
      ),
      fontFamily: 'SF Pro Display',
      appBarTheme: const AppBarTheme(
        backgroundColor: background,
        elevation: 0,
        titleTextStyle: TextStyle(
          color: textPrimary,
          fontSize: 20,
          fontWeight: FontWeight.w600,
          letterSpacing: 0.3,
        ),
        iconTheme: IconThemeData(color: textPrimary),
      ),
      textTheme: const TextTheme(
        displayLarge: TextStyle(
          color: textPrimary,
          fontSize: 32,
          fontWeight: FontWeight.w700,
          letterSpacing: -0.5,
        ),
        displayMedium: TextStyle(
          color: textPrimary,
          fontSize: 24,
          fontWeight: FontWeight.w700,
          letterSpacing: -0.3,
        ),
        titleLarge: TextStyle(
          color: textPrimary,
          fontSize: 18,
          fontWeight: FontWeight.w600,
        ),
        titleMedium: TextStyle(
          color: textPrimary,
          fontSize: 16,
          fontWeight: FontWeight.w500,
        ),
        bodyLarge: TextStyle(color: textPrimary, fontSize: 14),
        bodyMedium: TextStyle(color: textSecondary, fontSize: 13),
        bodySmall: TextStyle(color: textTertiary, fontSize: 11),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: primary,
          foregroundColor: background,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          padding: const EdgeInsets.symmetric(vertical: 16),
          textStyle: const TextStyle(
            fontSize: 15,
            fontWeight: FontWeight.w600,
            letterSpacing: 0.5,
          ),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: textPrimary,
          side: const BorderSide(color: border, width: 1.5),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          padding: const EdgeInsets.symmetric(vertical: 16),
          textStyle: const TextStyle(
            fontSize: 15,
            fontWeight: FontWeight.w500,
          ),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: surfaceElevated,
        hintStyle: const TextStyle(color: textTertiary, fontSize: 14),
        labelStyle: const TextStyle(color: textSecondary, fontSize: 12),
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: const BorderSide(color: border),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: const BorderSide(color: border),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: const BorderSide(color: primary, width: 1.5),
        ),
      ),
      bottomNavigationBarTheme: const BottomNavigationBarThemeData(
        backgroundColor: surface,
        selectedItemColor: primary,
        unselectedItemColor: textTertiary,
        type: BottomNavigationBarType.fixed,
        elevation: 0,
      ),
      dividerTheme: const DividerThemeData(
        color: border,
        thickness: 1,
        space: 0,
      ),
    );
  }
}
