import 'package:flutter/material.dart';

/// Couleurs de la marque Quantis.
class QuantisColors {
  QuantisColors._();

  // Couleurs principales
  static const Color royalBlue = Color(0xFF1E2F97);
  static const Color luxuryGold = Color(0xFFD4AF37);
  static const Color white = Color(0xFFFFFFFF);

  // Variantes de bleu
  static const Color blueLight = Color(0xFF3A4FC7);
  static const Color blueDark = Color(0xFF0A1A5E);
  static const Color blueGlow = Color(0xFF2B44C0);

  // Variantes de gold
  static const Color goldLight = Color(0xFFE8C84A);
  static const Color goldDark = Color(0xFFB8941F);

  // Neutres
  static const Color bgLight = Color(0xFFF8F9FC);
  static const Color bgCard = Color(0xFFFFFFFF);
  static const Color bgDark = Color(0xFF050816);
  static const Color bgDarkCard = Color(0xFF0A0F2E);
  static const Color textPrimary = Color(0xFF1A1A2E);
  static const Color textSecondary = Color(0xFF6B7280);
  static const Color textMuted = Color(0xFF9CA3AF);
  static const Color border = Color(0xFFE5E7EB);
  static const Color borderDark = Color(0xFF1F2937);

  // États
  static const Color success = Color(0xFF10B981);
  static const Color warning = Color(0xFFF59E0B);
  static const Color error = Color(0xFFEF4444);
  static const Color info = Color(0xFF3B82F6);

  // Statuts stock
  static const Color stockOk = Color(0xFF10B981);
  static const Color stockLow = Color(0xFFF59E0B);
  static const Color stockOut = Color(0xFFEF4444);
}

/// Thème clair Quantis.
class QuantisTheme {
  QuantisTheme._();

  static ThemeData get lightTheme {
    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.light,
      colorScheme: ColorScheme.fromSeed(
        seedColor: QuantisColors.royalBlue,
        primary: QuantisColors.royalBlue,
        secondary: QuantisColors.luxuryGold,
        surface: QuantisColors.bgLight,
        error: QuantisColors.error,
      ),
      scaffoldBackgroundColor: QuantisColors.bgLight,

      // AppBar
      appBarTheme: const AppBarTheme(
        backgroundColor: QuantisColors.white,
        foregroundColor: QuantisColors.royalBlue,
        elevation: 0,
        centerTitle: false,
        titleTextStyle: TextStyle(
          fontFamily: 'SpaceGrotesk',
          fontSize: 20,
          fontWeight: FontWeight.w600,
          color: QuantisColors.royalBlue,
        ),
      ),

      // Cards
      cardTheme: CardThemeData(
        color: QuantisColors.bgCard,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
          side: const BorderSide(color: QuantisColors.border, width: 1),
        ),
      ),

      // Boutons
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: QuantisColors.royalBlue,
          foregroundColor: QuantisColors.white,
          elevation: 0,
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10),
          ),
          textStyle: const TextStyle(
            fontFamily: 'Inter',
            fontSize: 14,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),

      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: QuantisColors.royalBlue,
          side: const BorderSide(color: QuantisColors.royalBlue),
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10),
          ),
          textStyle: const TextStyle(
            fontFamily: 'Inter',
            fontSize: 14,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),

      // Inputs
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: QuantisColors.white,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: const BorderSide(color: QuantisColors.border),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: const BorderSide(color: QuantisColors.border),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: const BorderSide(color: QuantisColors.royalBlue, width: 2),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: const BorderSide(color: QuantisColors.error),
        ),
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        labelStyle: const TextStyle(
          fontFamily: 'Inter',
          color: QuantisColors.textSecondary,
        ),
      ),

      // Navigation Rail (desktop sidebar)
      navigationRailTheme: const NavigationRailThemeData(
        backgroundColor: QuantisColors.royalBlue,
        selectedIconTheme: IconThemeData(color: QuantisColors.luxuryGold),
        unselectedIconTheme: IconThemeData(color: Colors.white70),
        selectedLabelTextStyle: TextStyle(
          fontFamily: 'Inter',
          color: QuantisColors.luxuryGold,
          fontWeight: FontWeight.w600,
        ),
        unselectedLabelTextStyle: TextStyle(
          fontFamily: 'Inter',
          color: Colors.white70,
        ),
      ),

      // Textes
      textTheme: const TextTheme(
        displayLarge: TextStyle(fontFamily: 'SpaceGrotesk', fontWeight: FontWeight.w700, color: QuantisColors.textPrimary),
        displayMedium: TextStyle(fontFamily: 'SpaceGrotesk', fontWeight: FontWeight.w700, color: QuantisColors.textPrimary),
        headlineLarge: TextStyle(fontFamily: 'SpaceGrotesk', fontWeight: FontWeight.w600, color: QuantisColors.textPrimary),
        headlineMedium: TextStyle(fontFamily: 'SpaceGrotesk', fontWeight: FontWeight.w600, color: QuantisColors.textPrimary),
        titleLarge: TextStyle(fontFamily: 'Inter', fontWeight: FontWeight.w600, color: QuantisColors.textPrimary),
        titleMedium: TextStyle(fontFamily: 'Inter', fontWeight: FontWeight.w500, color: QuantisColors.textPrimary),
        bodyLarge: TextStyle(fontFamily: 'Inter', color: QuantisColors.textPrimary),
        bodyMedium: TextStyle(fontFamily: 'Inter', color: QuantisColors.textSecondary),
        bodySmall: TextStyle(fontFamily: 'Inter', color: QuantisColors.textMuted),
        labelLarge: TextStyle(fontFamily: 'Inter', fontWeight: FontWeight.w600),
      ),

      // Divider
      dividerTheme: const DividerThemeData(
        color: QuantisColors.border,
        thickness: 1,
      ),
    );
  }

  static ThemeData get darkTheme {
    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.dark,
      colorScheme: ColorScheme.fromSeed(
        seedColor: QuantisColors.royalBlue,
        brightness: Brightness.dark,
        primary: QuantisColors.blueLight,
        secondary: QuantisColors.luxuryGold,
        surface: QuantisColors.bgDark,
        error: QuantisColors.error,
      ),
      scaffoldBackgroundColor: QuantisColors.bgDark,
      cardTheme: CardThemeData(
        color: QuantisColors.bgDarkCard,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
          side: const BorderSide(color: QuantisColors.borderDark, width: 1),
        ),
      ),
    );
  }
}
