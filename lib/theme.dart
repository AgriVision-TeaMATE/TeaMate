import 'package:flutter/material.dart';

class AppTheme {
  // Brand Colors from the mockups
  static const Color primaryDark = Color(0xFF0F1E21); // The very dark background in the main module card
  static const Color primaryGreen = Color(0xFF0C2B29); // The dark green card color
  static const Color accentGreen = Color(0xFFD4E7C5); // Light green tag color
  static const Color accentGreenText = Color(0xFF4C7B38); // Text on light green tag
  static const Color backgroundLight = Color(0xFFF7F8F9); // Light grey app background
  static const Color cardWhite = Colors.white; // White cards
  
  static const Color textPrimary = Color(0xFF1B242C); // Dark text
  static const Color textSecondary = Color(0xFF6E7E8B); // Muted grey text
  
  static const Color alertRedBg = Color(0xFFFDE8E8); // Light red for alert
  static const Color alertRedText = Color(0xFFC04B4B); // Red text
  
  // Compatibility aliases for old screens
  static const Color primaryColor = primaryGreen;
  static const Color secondaryColor = cardWhite;
  static const Color errorColor = alertRedText;
  
  static ThemeData get lightTheme {
    return ThemeData(
      primaryColor: primaryGreen,
      scaffoldBackgroundColor: backgroundLight,
      colorScheme: const ColorScheme.light(
        primary: primaryGreen,
        secondary: accentGreen,
        surface: cardWhite,
      ),
      appBarTheme: const AppBarTheme(
        backgroundColor: cardWhite,
        elevation: 0,
        iconTheme: IconThemeData(color: textPrimary),
        centerTitle: false,
        titleTextStyle: TextStyle(
          color: textPrimary,
          fontSize: 18,
          fontWeight: FontWeight.bold,
          letterSpacing: -0.5,
        ),
      ),
      bottomNavigationBarTheme: const BottomNavigationBarThemeData(
        backgroundColor: cardWhite,
        selectedItemColor: primaryGreen,
        unselectedItemColor: textSecondary,
        type: BottomNavigationBarType.fixed,
        elevation: 16,
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: primaryGreen,
          foregroundColor: Colors.white,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(8),
          ),
          padding: const EdgeInsets.symmetric(vertical: 14),
          elevation: 0,
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: textPrimary,
          side: const BorderSide(color: Color(0xFFE0E5E9)),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(8),
          ),
          padding: const EdgeInsets.symmetric(vertical: 14),
        ),
      ),
      textTheme: const TextTheme(
        bodyLarge: TextStyle(color: textPrimary),
        bodyMedium: TextStyle(color: textSecondary),
      ),
    );
  }
}
