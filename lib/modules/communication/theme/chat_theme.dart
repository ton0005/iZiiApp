import 'package:flutter/material.dart';

enum ChatFontSizeOption {
  small,
  medium,
  large,
  extraLarge,
}

class ChatTheme {
  // Light Mode Tokens
  static const Color bgPrimaryLight = Color(0xFFF8F9FA); // warm off-white
  static const Color bgBubbleMineLight = Color(0xFF4A90D9);
  static const Color bgBubbleTheirsLight = Color(0xFFFFFFFF);
  static const Color textPrimaryLight = Color(0xFF1C1C1E);
  static const Color textMutedLight = Color(0xFF8E8E93);
  static const Color accentLight = Color(0xFF4A90D9);
  static const Color dangerLight = Color(0xFFFF3B30);
  static const Color onlineLight = Color(0xFF34C759);

  // Dark Mode Tokens
  static const Color bgPrimaryDark = Color(0xFF1A1A2E);
  static const Color bgBubbleMineDark = Color(0xFF3A7BD5);
  static const Color bgBubbleTheirsDark = Color(0xFF2A2A3E);
  static const Color textPrimaryDark = Color(0xFFF2F2F7);
  static const Color textMutedDark = Color(0xFF6E6E73);
  static const Color accentDark = Color(0xFF5AA0E8);
  static const Color dangerDark = Color(0xFFFF453A);
  static const Color onlineDark = Color(0xFF30D158);

  // Helpers to get theme-aware colors
  static Color getBgPrimary(bool isDark) => isDark ? bgPrimaryDark : bgPrimaryLight;
  static Color getBgBubbleMine(bool isDark) => isDark ? bgBubbleMineDark : bgBubbleMineLight;
  static Color getBgBubbleTheirs(bool isDark) => isDark ? bgBubbleTheirsDark : bgBubbleTheirsLight;
  static Color getTextPrimary(bool isDark) => isDark ? textPrimaryDark : textPrimaryLight;
  static Color getTextMuted(bool isDark) => isDark ? textMutedDark : textMutedLight;
  static Color getAccent(bool isDark) => isDark ? accentDark : accentLight;
  static Color getDanger(bool isDark) => isDark ? dangerDark : dangerLight;
  static Color getOnline(bool isDark) => isDark ? onlineDark : onlineLight;

  // Font size configuration mapping
  static double getFontSize(ChatFontSizeOption option) {
    switch (option) {
      case ChatFontSizeOption.small:
        return 14.0;
      case ChatFontSizeOption.medium:
        return 16.0;
      case ChatFontSizeOption.large:
        return 18.0;
      case ChatFontSizeOption.extraLarge:
        return 20.0;
    }
  }

  // Large tap target utility
  static const BoxConstraints tapTargetConstraints = BoxConstraints(
    minWidth: 44.0,
    minHeight: 44.0,
  );
}
