import 'package:flutter/material.dart';

/// App-wide colors tuned to the warm/sky cartoon art.
class AppColors {
  AppColors._();

  static const Color sky = Color(0xFF59B4F0);
  static const Color skyDeep = Color(0xFF2E78C9);
  static const Color sunset = Color(0xFFF6A623);
  static const Color brick = Color(0xFFC9603A);
  static const Color cream = Color(0xFFFDF3E3);
  static const Color woodDark = Color(0xFF3E2C23);
  static const Color panel = Color(0xFFEED9B6);
  static const Color panelBorder = Color(0xFF8A5A38);
  static const Color star = Color(0xFFFFC94D);
  static const Color starEmpty = Color(0xFF6E6256);
  static const Color boardBg = Color(0xFF8A5A38);
  static const Color boardCell = Color(0xFFB98A5E);
}

class AppTheme {
  AppTheme._();

  static ThemeData build() {
    final ColorScheme scheme = ColorScheme.fromSeed(
      seedColor: AppColors.sunset,
      primary: AppColors.sunset,
      surface: AppColors.cream,
    );

    return ThemeData(
      useMaterial3: true,
      colorScheme: scheme,
      scaffoldBackgroundColor: AppColors.sky,
      fontFamily: 'Roboto',
      textTheme: const TextTheme().apply(
        bodyColor: AppColors.woodDark,
        displayColor: AppColors.woodDark,
      ),
    );
  }

  /// Reusable text style for crisp white titles with a soft shadow.
  static TextStyle titleStyle({double size = 28, Color color = Colors.white}) {
    return TextStyle(
      fontSize: size,
      fontWeight: FontWeight.w800,
      color: color,
      letterSpacing: 0.5,
      shadows: const <Shadow>[
        Shadow(
          color: Color(0x99000000),
          offset: Offset(0, 2),
          blurRadius: 4,
        ),
      ],
    );
  }
}
