import 'package:flutter/material.dart';

import 'app_colors.dart';

const _fontFamily = 'Iosevka';

ThemeData buildAppTheme() {
  return ThemeData(
    fontFamily: _fontFamily,
    scaffoldBackgroundColor: AppColors.bg,
    colorScheme: const ColorScheme.light(
      primary: AppColors.teal,
      secondary: AppColors.pink,
      surface: AppColors.card,
      onPrimary: Colors.white,
      onSecondary: Colors.white,
      onSurface: AppColors.dark,
    ),
    appBarTheme: const AppBarTheme(
      backgroundColor: AppColors.bg,
      foregroundColor: AppColors.dark,
      elevation: 0,
      scrolledUnderElevation: 0,
    ),
    textTheme: const TextTheme(
      displayLarge: TextStyle(
        fontFamily: _fontFamily,
        fontSize: 68,
        fontWeight: FontWeight.w900,
        letterSpacing: -3,
        height: 1,
        color: AppColors.dark,
      ),
      displayMedium: TextStyle(
        fontFamily: _fontFamily,
        fontSize: 52,
        fontWeight: FontWeight.w900,
        letterSpacing: -2,
        height: 1,
        color: AppColors.dark,
      ),
      displaySmall: TextStyle(
        fontFamily: _fontFamily,
        fontSize: 30,
        fontWeight: FontWeight.w900,
        letterSpacing: -1,
        height: 1,
        color: AppColors.dark,
      ),
      headlineLarge: TextStyle(
        fontFamily: _fontFamily,
        fontSize: 22,
        fontWeight: FontWeight.w900,
        letterSpacing: -1,
        color: AppColors.dark,
      ),
      headlineMedium: TextStyle(
        fontFamily: _fontFamily,
        fontSize: 20,
        fontWeight: FontWeight.w900,
        letterSpacing: -0.5,
        color: AppColors.dark,
      ),
      headlineSmall: TextStyle(
        fontFamily: _fontFamily,
        fontSize: 18,
        fontWeight: FontWeight.w900,
        color: AppColors.dark,
      ),
      labelSmall: TextStyle(
        fontFamily: _fontFamily,
        fontSize: 9,
        fontWeight: FontWeight.w700,
        letterSpacing: 2,
        color: AppColors.muted,
      ),
      bodyLarge: TextStyle(
        fontFamily: _fontFamily,
        fontSize: 14,
        fontWeight: FontWeight.w400,
        color: AppColors.dark,
      ),
      bodyMedium: TextStyle(
        fontFamily: _fontFamily,
        fontSize: 13,
        fontWeight: FontWeight.w400,
        color: AppColors.dark,
      ),
      bodySmall: TextStyle(
        fontFamily: _fontFamily,
        fontSize: 9,
        fontWeight: FontWeight.w400,
        letterSpacing: 1,
        color: AppColors.muted,
      ),
    ),
    useMaterial3: true,
  );
}
