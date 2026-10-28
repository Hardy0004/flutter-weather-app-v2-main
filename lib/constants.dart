import 'package:flutter/material.dart';

class Constants {
  // ==========================================
  // WEATHER API CONFIGURATION
  // ==========================================

  // Pass your API key at runtime using:
  // flutter run --dart-define=WEATHER_API_KEY=your_key
  static const String apiKey = String.fromEnvironment(
    'WEATHER_API_KEY',
    defaultValue: '',
  );

  // ==========================================
  // ORIGINAL APP COLORS
  // ==========================================

  // Preserved for compatibility with existing UI.
  final Color primaryColor = const Color(0xff6b9dfc);
  final Color secondaryColor = const Color(0xffa1c6fd);
  final Color tertiaryColor = const Color(0xff205cf1);
  final Color blackColor = const Color(0xff1a1d26);
  final Color greyColor = const Color(0xffd9dadb);

  // ==========================================
  // GLASSMORPHISM THEME COLORS
  // ==========================================

  static const Color backgroundNavy = Color(0xFF07172F);
  static const Color backgroundBlue = Color(0xFF193A78);
  static const Color backgroundLightBlue = Color(0xFF376DB5);
  static const Color backgroundDeepBlue = Color(0xFF102B58);

  static const Color accentCyan = Color(0xFF8CEAFF);
  static const Color accentBlue = Color(0xFF65CBFF);
  static const Color accentPurple = Color(0xFF9B8FFF);

  static const Color textPrimary = Colors.white;
  static const Color textSecondary = Color(0xFFBDD5F6);
  static const Color textMuted = Color(0xFFB8D0EF);
  static const Color textSoft = Color(0xFFB2C7E4);

  static const Color searchBackground = Color(0xFF10264A);

  // ==========================================
  // GLASSMORPHISM SURFACES
  // ==========================================

  static const Color glassBackground = Color(0x1AFFFFFF);
  static const Color glassBorder = Color(0x38FFFFFF);
  static const Color glassDivider = Color(0x24FFFFFF);
  static const Color glassHighlight = Color(0x33FFFFFF);

  static const double glassBlur = 14.0;
  static const double glassBorderWidth = 1.0;

  static const double cardRadius = 24.0;
  static const double heroRadius = 32.0;
  static const double searchRadius = 30.0;

  // ==========================================
  // GLASSMORPHISM GRADIENTS
  // ==========================================

  static const LinearGradient backgroundGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [
      backgroundNavy,
      backgroundBlue,
      backgroundLightBlue,
      backgroundDeepBlue,
    ],
    stops: [0.0, 0.38, 0.70, 1.0],
  );

  static const LinearGradient glassHighlightGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [Color(0x33FFFFFF), Color(0x1A80CFFF)],
  );

  static const LinearGradient scrollFadeGradient = LinearGradient(
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
    colors: [Color(0xFF17366C), Color(0xF017366C), Color(0x0017366C)],
    stops: [0.0, 0.35, 1.0],
  );

  // ==========================================
  // ORIGINAL SHADER
  // ==========================================

  final Shader shader = const LinearGradient(
    colors: <Color>[Color(0xffABCFF2), Color(0xff9AC6F3)],
  ).createShader(const Rect.fromLTWH(0.0, 0.0, 200.0, 70.0));

  // ==========================================
  // ORIGINAL GRADIENTS
  // ==========================================

  final LinearGradient linearGradientBlue = const LinearGradient(
    begin: Alignment.bottomRight,
    end: Alignment.topLeft,
    colors: [Color(0xff6b9dfc), Color(0xff205cf1)],
    stops: [0.0, 1.0],
  );

  final LinearGradient linearGradientPurple = const LinearGradient(
    begin: Alignment.bottomRight,
    end: Alignment.topLeft,
    colors: [Color(0xff51087E), Color(0xff6C0BA9)],
    stops: [0.0, 1.0],
  );
}
