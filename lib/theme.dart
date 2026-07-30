import 'package:flutter/material.dart';

class AppTheme {
  static const Color brandGreen = Color.fromARGB(255, 116, 195, 19);
  static const Color primaryButton = Color.fromARGB(255, 0, 0, 0);
  static const Color screenBackground = Color.fromARGB(255, 254, 255, 253);

  // Brand Colors from the mockups
  static const Color primaryDark = Color(
    0xFF0F1E21,
  ); // The very dark background in the main module card
  static const Color primaryGreen = Color(
    0xFF0C2B29,
  ); // The dark green card color
  static const Color accentGreen = Color(0xFFD4E7C5); // Light green tag color
  static const Color accentGreenText = Color(
    0xFF4C7B38,
  ); // Text on light green tag
  static const Color backgroundLight = Color(
    0xFFF7F8F9,
  ); // Light grey app background
  static const Color cardWhite = Colors.white; // White cards

  static const Color textPrimary = Color(0xFF1B242C); // Dark text
  static const Color textSecondary = Color(0xFF6E7E8B); // Muted grey text
  static const Color inputHint = Color(0xFF9AA3AF);

  static const Color alertRedBg = Color(0xFFFDE8E8); // Light red for alert
  static const Color alertRedText = Color(0xFFC04B4B); // Red text

  // Compatibility aliases for old screens
  static const Color primaryColor = brandGreen;
  static const Color secondaryColor = cardWhite;
  static const Color errorColor = alertRedText;

  // Plucking-status colors, ranked by priority (most urgent first).
  static const Color statusUrgent = Color(0xFFD94A4A); // Overgrown / review maturity
  static const Color statusReady = brandGreen; // Ready to pluck — act now
  static const Color statusApproaching = Color(0xFFE69A2E); // Maturing / pluck soon
  static const Color statusMonitor = Color(0xFF64748B); // Needs more growth — low priority
  static const Color statusAnalyzing = Color(0xFF5F6C7B); // Analysis in progress
  static const Color statusPending = Color(0xFF9AA3AF); // Awaiting analysis / no data
  static const Color statusCompleted = Color(0xFF1E4A3D); // Round completed — matches app's green gradient theme

  /// Resolves the priority color for a field measurement's plucking status.
  static Color pluckingStatusColor({
    required bool isCompleted,
    required String pluckingStatus,
  }) {
    if (isCompleted || pluckingStatus == 'completed') {
      return statusCompleted;
    }
    switch (pluckingStatus) {
      case 'ready_to_pluck':
        return statusReady;
      case 'overgrown':
        return statusUrgent;
      case 'maturing':
        return statusApproaching;
      case 'needs_growth':
        return statusMonitor;
      case 'analyzing':
        return statusAnalyzing;
      case 'awaiting_analysis':
      default:
        return statusPending;
    }
  }

  static ThemeData get lightTheme {
    return ThemeData(
      primaryColor: brandGreen,
      scaffoldBackgroundColor: backgroundLight,
      colorScheme: const ColorScheme.light(
        primary: brandGreen,
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
        selectedItemColor: primaryButton,
        unselectedItemColor: textSecondary,
        type: BottomNavigationBarType.fixed,
        elevation: 16,
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: primaryButton,
          foregroundColor: Colors.white,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
          padding: const EdgeInsets.symmetric(vertical: 14),
          elevation: 0,
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: textPrimary,
          side: const BorderSide(color: Color(0xFFE0E5E9)),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
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
