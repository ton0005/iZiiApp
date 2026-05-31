import 'package:flutter/material.dart';
import 'izii_colors.dart';

class IZiiTheme {
  static ThemeData get light {
    return ThemeData(
      brightness: Brightness.light,
      primaryColor: IZiiColors.primary,
      scaffoldBackgroundColor: IZiiColors.lightBackground,
      colorScheme: const ColorScheme.light(
        primary: IZiiColors.primary,
        secondary: IZiiColors.secondary,
        surface: IZiiColors.lightSurface,
        error: IZiiColors.error,
      ),
      appBarTheme: const AppBarTheme(
        backgroundColor: IZiiColors.lightBackground,
        elevation: 0,
        centerTitle: true,
        iconTheme: IconThemeData(color: Colors.black87),
        titleTextStyle: TextStyle(color: Colors.black87, fontSize: 18, fontWeight: FontWeight.w600),
      ),
      useMaterial3: true,
    );
  }

  static ThemeData get dark {
    return ThemeData(
      brightness: Brightness.dark,
      primaryColor: IZiiColors.primary,
      scaffoldBackgroundColor: IZiiColors.darkBackground,
      colorScheme: const ColorScheme.dark(
        primary: IZiiColors.primary,
        secondary: IZiiColors.secondary,
        surface: IZiiColors.darkSurface,
        error: IZiiColors.error,
      ),
      appBarTheme: const AppBarTheme(
        backgroundColor: IZiiColors.darkBackground,
        elevation: 0,
        centerTitle: true,
        iconTheme: IconThemeData(color: Colors.white),
        titleTextStyle: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.w600),
      ),
      useMaterial3: true,
    );
  }
}
