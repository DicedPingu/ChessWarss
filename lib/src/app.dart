import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import 'presentation/alpha_game_screen.dart';

class ChessWarssApp extends StatelessWidget {
  const ChessWarssApp({super.key});

  @override
  Widget build(BuildContext context) {
    final baseScheme = ColorScheme.fromSeed(
      seedColor: const Color(0xFF2A6152),
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

    return MaterialApp(
      title: 'ChessWarss Alpha',
      theme: baseTheme.copyWith(
        textTheme: textTheme,
        scaffoldBackgroundColor: const Color(0xFFF3ECDD),
        appBarTheme: AppBarTheme(
          backgroundColor: const Color(0xFFF6EFE2),
          foregroundColor: const Color(0xFF23332D),
          elevation: 0,
          surfaceTintColor: Colors.transparent,
          titleTextStyle: textTheme.titleLarge?.copyWith(
            color: const Color(0xFF23332D),
          ),
        ),
        cardTheme: CardThemeData(
          color: Colors.white.withValues(alpha: 0.92),
          elevation: 6,
          shadowColor: Colors.black.withValues(alpha: 0.12),
          margin: EdgeInsets.zero,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(18),
            side: BorderSide(
              color: const Color(0xFF335E50).withValues(alpha: 0.16),
            ),
          ),
        ),
        inputDecorationTheme: InputDecorationTheme(
          filled: true,
          fillColor: Colors.white.withValues(alpha: 0.75),
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 12,
            vertical: 10,
          ),
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
        ),
        filledButtonTheme: FilledButtonThemeData(
          style: FilledButton.styleFrom(
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
          ),
        ),
        elevatedButtonTheme: ElevatedButtonThemeData(
          style: ElevatedButton.styleFrom(
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
          ),
        ),
        floatingActionButtonTheme: FloatingActionButtonThemeData(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
        ),
      ),
      home: const AlphaGameScreen(),
    );
  }
}
