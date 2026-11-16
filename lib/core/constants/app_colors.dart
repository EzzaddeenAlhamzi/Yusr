import 'package:flutter/material.dart';

/// لوحة ألوان تطبيق يسر (Yusr App Colors)
class AppColors {
  AppColors._();

  static const Color mainColor = Color(0xFF125D73);
  static const Color primaryTeal = Color(0xFF176E82);
  static const Color secondaryTeal = Color(0xFF2C806B);
  static const Color iconColor = Color(0xFF2C806B);

  // الألوان الموحدة المطلوبة
  static const Color backgroundColor = Color(0xFFF6F4EE); // خلفية التطبيق
  static const Color cardColor = Color(0xFFFEFBF7);       // لون البطاقات والحقول
  static const Color cardBorderColor = Color(0xFFD9D9D9); // لون حدود البطاقات والحقول

  static const Color cream = Color(0xFFFBF9F5);
  static const Color creamLight = Color(0xFFFFFCF5);

  static const Color darkBackground = Color(0xFF101010);
  static const Color cardDarkBackground = Color(0xFF202020);

  static const Color textPrimary = Color(0xFF1F1F1F);
  static const Color textColor = Color(0xFF1F1F1F);
  static const Color textSecondary = Color(0xFF787878);
  static const Color textLight = Colors.white;
  static const Color white = Colors.white;

  static const Color appbarColor = Color(0xFF125D73);
  static const Color dotInactive = Color(0xFFA8C5C7);
  static const Color dotSecondary = Color(0xFF9CC4CC);
}

// ثوابت للتوافقية مع أي استدعاءات مباشرة
const Color appbarColor = AppColors.appbarColor;
const Color mainColor = AppColors.mainColor;
const Color iconColor = AppColors.iconColor;
const Color backgroundColor = AppColors.backgroundColor;
const Color cardColor = AppColors.cardColor;
const Color cardBorderColor = AppColors.cardBorderColor;
const Color cream = AppColors.cream;
const Color creamLight = AppColors.creamLight;
const Color dotInactive = AppColors.dotInactive;
const Color dotSecondary = AppColors.dotSecondary;
const Color textPrimary = AppColors.textPrimary;
const Color textColor = AppColors.textColor;
const Color textSecondary = AppColors.textSecondary;

