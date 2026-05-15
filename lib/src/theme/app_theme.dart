import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class AppTheme {
  static ThemeData get lightTheme {
    final baseScheme = ColorScheme.fromSeed(
      seedColor: const Color(0xFF1D5A70),
      brightness: Brightness.light,
    );
    final baseTheme = ThemeData(useMaterial3: true, colorScheme: baseScheme);

    final bodyText = GoogleFonts.plusJakartaSansTextTheme(baseTheme.textTheme);
    final displayText = GoogleFonts.cinzelTextTheme(baseTheme.textTheme);

    final textTheme = bodyText.copyWith(
      headlineLarge: displayText.headlineLarge?.copyWith(
        fontWeight: FontWeight.w700,
      ),
      headlineMedium: displayText.headlineMedium?.copyWith(
        fontWeight: FontWeight.w700,
      ),
      titleLarge: displayText.titleLarge?.copyWith(fontWeight: FontWeight.w700),
      titleMedium: bodyText.titleMedium?.copyWith(fontWeight: FontWeight.w700),
      titleSmall: bodyText.titleSmall?.copyWith(fontWeight: FontWeight.w700),
      bodyMedium: bodyText.bodyMedium?.copyWith(height: 1.3),
      bodySmall: bodyText.bodySmall?.copyWith(height: 1.25),
    );

    return baseTheme.copyWith(
      textTheme: textTheme,
      scaffoldBackgroundColor: const Color(0xFFF4F1E8),
      appBarTheme: AppBarTheme(
        backgroundColor: const Color(0xFF1D5A70),
        foregroundColor: const Color(0xFFF7F2E6),
        elevation: 0,
        surfaceTintColor: Colors.transparent,
        titleTextStyle: textTheme.titleLarge?.copyWith(
          color: const Color(0xFFF7F2E6),
        ),
      ),
      cardTheme: CardThemeData(
        color: const Color(0xFFFEFCF6).withValues(alpha: 0.96),
        elevation: 2,
        shadowColor: const Color(0xFF0F2B35).withValues(alpha: 0.16),
        margin: EdgeInsets.zero,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(8),
          side: BorderSide(
            color: const Color(0xFF1D5A70).withValues(alpha: 0.14),
          ),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: const Color(0xFFFEFCF6).withValues(alpha: 0.86),
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 12,
          vertical: 10,
        ),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        ),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        ),
      ),
      floatingActionButtonTheme: FloatingActionButtonThemeData(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      ),
    );
  }
}
