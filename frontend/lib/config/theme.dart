import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class AppTheme {
  // Colors
  static const Color primary = Color(0xFF1A56DB);
  static const Color primaryDark = Color(0xFF1E3A5F);
  static const Color accent = Color(0xFFF59E0B);
  static const Color success = Color(0xFF10B981);
  static const Color error = Color(0xFFEF4444);
  static const Color background = Color(0xFFF8FAFC);
  static const Color surface = Color(0xFFFFFFFF);
  static const Color textPrimary = Color(0xFF0F172A);
  static const Color textSecondary = Color(0xFF64748B);
  static const Color border = Color(0xFFE2E8F0);

  // Typography
  static TextTheme get textTheme {
    return TextTheme(
      headlineLarge: GoogleFonts.nunito(
          fontSize: 28, fontWeight: FontWeight.bold, color: textPrimary),
      headlineMedium: GoogleFonts.nunito(
          fontSize: 22, fontWeight: FontWeight.bold, color: textPrimary),
      headlineSmall: GoogleFonts.nunito(
          fontSize: 18, fontWeight: FontWeight.w600, color: textPrimary),
      bodyLarge: GoogleFonts.inter(
          fontSize: 16, fontWeight: FontWeight.normal, color: textPrimary),
      bodyMedium: GoogleFonts.inter(
          fontSize: 14, fontWeight: FontWeight.normal, color: textPrimary),
      bodySmall: GoogleFonts.inter(
          fontSize: 12, fontWeight: FontWeight.normal, color: textSecondary),
    );
  }

  static ThemeData get lightTheme {
    return ThemeData(
      primaryColor: primary,
      scaffoldBackgroundColor: background,
      colorScheme: const ColorScheme.light(
        primary: primary,
        secondary: accent,
        error: error,
        surface: surface,
      ),
      textTheme: textTheme,
      primaryTextTheme: textTheme,
      appBarTheme: AppBarTheme(
        backgroundColor: background,
        elevation: 0,
        centerTitle: true,
        iconTheme: const IconThemeData(color: primaryDark),
        titleTextStyle: GoogleFonts.nunito(
            fontSize: 22, fontWeight: FontWeight.bold, color: primaryDark),
      ),
      cardTheme: CardTheme(
        color: surface,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
        ),
        margin: EdgeInsets.zero,
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: primary,
          foregroundColor: Colors.white,
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          minimumSize: const Size(double.infinity, 52),
          textStyle: GoogleFonts.inter(
              fontSize: 16, fontWeight: FontWeight.w600),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: const Color(0xFFF1F5F9),
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
          borderSide: const BorderSide(color: primary, width: 2),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: error, width: 2),
        ),
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
        hintStyle: GoogleFonts.inter(color: textSecondary, fontSize: 16),
      ),
      dividerTheme: const DividerThemeData(
        color: border,
        thickness: 1,
        space: 1,
      ),
    );
  }

  // BoxShadow for cards
  static List<BoxShadow> get cardShadow {
    return [
      BoxShadow(
        color: const Color(0xFF000000).withOpacity(0.06),
        blurRadius: 12,
        offset: const Offset(0, 4),
      ),
    ];
  }
}
