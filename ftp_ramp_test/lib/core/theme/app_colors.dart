import 'package:flutter/material.dart';

abstract final class AppColors {
  // Primary: Teal
  static const teal = Color(0xFF0D9488);
  static const tealDark = Color(0xFF0F766E);
  static const tealLight = Color(0xFF5EEAD4);
  static const tealBg = Color(0x0F0D9488); // ~6% opacity

  // Secondary: Pink
  static const pink = Color(0xFFEC4899);
  static const pinkDark = Color(0xFFDB2777);
  static const pinkLight = Color(0xFFF9A8D4);
  static const pinkBg = Color(0x0FEC4899); // ~6% opacity

  // Confirm/Hover: Yellow (only on press, never at rest)
  static const yellow = Color(0xFFFACC15);
  static const yellowDeep = Color(0xFFEAB308);
  static const yellowLight = Color(0xFFFDE047);
  static const yellowBg = Color(0x14EAB308); // ~8% opacity

  // Neutrals
  static const dark = Color(0xFF1A1A1A);
  static const darkSoft = Color(0xFF333333);
  static const bg = Color(0xFFF5F5F0);
  static const card = Color(0xFFFFFFFF);
  static const muted = Color(0xFFAAAAAA);
  static const borderLight = Color(0xFFF0F0F0);

  // Semantic icon backgrounds
  static const trainerBg = Color(0xFFFEF3C7);
  static const hrBg = Color(0xFFFCE7F3);
  static const cadenceBg = Color(0xFFF0FDF4);
  static const speedBg = Color(0xFFE0F2FE);
}
