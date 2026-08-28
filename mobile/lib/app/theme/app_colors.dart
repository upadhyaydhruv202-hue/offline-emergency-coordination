import 'package:flutter/material.dart';

/// Operational palette, matched to the web command centre.
///
/// Navy and slate carry the interface. Blue means "interactive". Red, orange,
/// amber and green are reserved for severity and status - never decoration.
class AppColors {
  const AppColors._();

  static const Color navy950 = Color(0xFF060B14);
  static const Color navy900 = Color(0xFF0A1120);
  static const Color navy850 = Color(0xFF0E1728);
  static const Color navy800 = Color(0xFF131F34);
  static const Color navy700 = Color(0xFF1B2B45);
  static const Color navy600 = Color(0xFF26395A);

  static const Color ink100 = Color(0xFFF4F7FB);
  static const Color ink200 = Color(0xFFDDE5F0);
  static const Color ink300 = Color(0xFFB6C4DA);
  static const Color ink400 = Color(0xFF8496B4);
  static const Color ink500 = Color(0xFF61738F);

  static const Color accent = Color(0xFF2F81F7);
  static const Color accentSoft = Color(0xFF58A6FF);

  static const Color critical = Color(0xFFE5484D);
  static const Color high = Color(0xFFF76808);
  static const Color elevated = Color(0xFFFFB224);
  static const Color nominal = Color(0xFF30A46C);
  static const Color inactive = Color(0xFF61738F);
}
