import 'package:flutter/material.dart';

import 'app_colors.dart';

/// Single dark theme.
///
/// A responder works at night, in dust, often in gloves. The interface is high
/// contrast, generously spaced for touch, and free of decorative effects.
class AppTheme {
  const AppTheme._();

  static ThemeData get dark {
    const scheme = ColorScheme.dark(
      primary: AppColors.accent,
      onPrimary: Colors.white,
      secondary: AppColors.accentSoft,
      onSecondary: AppColors.navy950,
      surface: AppColors.navy850,
      onSurface: AppColors.ink200,
      error: AppColors.critical,
      onError: Colors.white,
      outline: AppColors.navy600,
    );

    final base = ThemeData(
      useMaterial3: true,
      brightness: Brightness.dark,
      colorScheme: scheme,
      scaffoldBackgroundColor: AppColors.navy950,
      splashFactory: InkSparkle.splashFactory,
    );

    return base.copyWith(
      appBarTheme: const AppBarThemeData(
        backgroundColor: AppColors.navy900,
        foregroundColor: AppColors.ink100,
        elevation: 0,
        centerTitle: false,
        titleTextStyle: TextStyle(
          fontSize: 16,
          fontWeight: FontWeight.w600,
          color: AppColors.ink100,
        ),
      ),
      cardTheme: CardThemeData(
        color: AppColors.navy850,
        elevation: 0,
        margin: EdgeInsets.zero,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(8),
          side: const BorderSide(color: AppColors.navy700),
        ),
      ),
      dividerTheme: const DividerThemeData(
        color: AppColors.navy700,
        space: 1,
        thickness: 1,
      ),
      inputDecorationTheme: InputDecorationThemeData(
        filled: true,
        fillColor: AppColors.navy850,
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
        hintStyle: const TextStyle(color: AppColors.ink500),
        border: _inputBorder(AppColors.navy600),
        enabledBorder: _inputBorder(AppColors.navy600),
        focusedBorder: _inputBorder(AppColors.accent, width: 1.5),
        errorBorder: _inputBorder(AppColors.critical),
        focusedErrorBorder: _inputBorder(AppColors.critical, width: 1.5),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: AppColors.accent,
          foregroundColor: Colors.white,
          minimumSize: const Size.fromHeight(48),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(6),
          ),
          textStyle: const TextStyle(fontWeight: FontWeight.w600),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: AppColors.ink200,
          minimumSize: const Size.fromHeight(48),
          side: const BorderSide(color: AppColors.navy600),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(6),
          ),
        ),
      ),
      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: AppColors.navy900,
        indicatorColor: AppColors.accent.withValues(alpha: 0.16),
        surfaceTintColor: Colors.transparent,
        height: 64,
        labelTextStyle: WidgetStateProperty.all(
          const TextStyle(fontSize: 11, fontWeight: FontWeight.w600),
        ),
      ),
      drawerTheme: const DrawerThemeData(
        backgroundColor: AppColors.navy900,
        surfaceTintColor: Colors.transparent,
      ),
      listTileTheme: const ListTileThemeData(
        iconColor: AppColors.ink400,
        textColor: AppColors.ink200,
      ),
      textTheme: base.textTheme.apply(
        bodyColor: AppColors.ink200,
        displayColor: AppColors.ink100,
      ),
    );
  }

  static OutlineInputBorder _inputBorder(Color color, {double width = 1}) =>
      OutlineInputBorder(
        borderRadius: BorderRadius.circular(6),
        borderSide: BorderSide(color: color, width: width),
      );
}
