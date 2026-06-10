import 'package:flutter/material.dart';

class AppColors {
  static const Color primary = Color(0xFF306EC7);
  static const Color primaryDark = Color(0xFF2F374C);
  static const Color primaryLight = Color(0xFFE6F0FF);

  static const Color background = Color(0xFFF7FAFF);
  static const Color card = Color(0xFFFFFFFF);

  static const Color textMain = Color(0xFF1B1B1B);
  static const Color textSub = Color(0xFF67707B);
  static const Color border = Color(0xFFE1E1E1);

  static const Color danger = Color(0xFFFF3B30);
  static const Color warning = Color(0xFFFFCC00);
  static const Color safe = Color(0xFF34C759);

  static const Color glassWhite = Color(0xB3FFFFFF);

  // iOS-style "liquid glass" tokens
  static const Color glassFill = Color(0x8FFFFFFF); // translucent surface
  static const Color glassFillStrong = Color(0xCCFFFFFF);
  static const Color glassBorder = Color(0x73FFFFFF); // bright rim light
  static const Color glassStroke = Color(0x1A306EC7); // faint tinted edge
  static const Color glassHighlight = Color(0x59FFFFFF); // top sheen

  // Soft gradient backdrop so glass surfaces have something to sit on
  static const Color bgGradientTop = Color(0xFFF5F9FF);
  static const Color bgGradientBottom = Color(0xFFE9F1FF);
}