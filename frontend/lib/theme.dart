import 'package:flutter/material.dart';

/// Cambia esta paleta para personalizar toda la aplicación.
abstract final class AppColors {
  static const ink = Color(0xFF202B31);
  static const muted = Color(0xFF738087);
  static const accent = Color(0xFF36766B);
  static const background = Color(0xFFF5F6F7);
  static const line = Color(0xFFE6E9EB);
  static const soft = Color(0xFFEDF4F1);
}

ThemeData appTheme() => ThemeData(
  useMaterial3: true,
  colorScheme: ColorScheme.fromSeed(
    seedColor: AppColors.accent,
    primary: AppColors.accent,
    surface: Colors.white,
  ),
  scaffoldBackgroundColor: AppColors.background,
  fontFamily: 'Arial',
  textTheme: const TextTheme(
    headlineLarge: TextStyle(
      fontSize: 32,
      fontWeight: FontWeight.w700,
      color: AppColors.ink,
      letterSpacing: -1,
    ),
    headlineSmall: TextStyle(
      fontSize: 23,
      fontWeight: FontWeight.w700,
      color: AppColors.ink,
      letterSpacing: -.5,
    ),
    titleLarge: TextStyle(
      fontSize: 18,
      fontWeight: FontWeight.w700,
      color: AppColors.ink,
    ),
    bodyMedium: TextStyle(fontSize: 14, color: AppColors.ink, height: 1.5),
  ),
  inputDecorationTheme: InputDecorationTheme(
    filled: true,
    fillColor: AppColors.background,
    border: OutlineInputBorder(
      borderRadius: BorderRadius.circular(12),
      borderSide: BorderSide.none,
    ),
    contentPadding: const EdgeInsets.all(17),
  ),
  filledButtonTheme: FilledButtonThemeData(
    style: FilledButton.styleFrom(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
    ),
  ),
  outlinedButtonTheme: OutlinedButtonThemeData(
    style: OutlinedButton.styleFrom(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 19),
      side: const BorderSide(color: AppColors.line),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
    ),
  ),
  dividerTheme: const DividerThemeData(color: AppColors.line, thickness: 1),
);
