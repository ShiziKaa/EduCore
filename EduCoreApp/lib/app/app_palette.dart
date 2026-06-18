import 'package:flutter/material.dart';

/// Light-theme greens — saturated enough to read, still soft on the eyes.
class AppPalette {
  AppPalette._();

  static const lightSurface = Color(0xFFFFFFFF);

  static const lightMintDeep = Color(0xFFB5DDB8);
  static const lightMintMid = Color(0xFFC5E6C8);
  static const lightMintSoft = Color(0xFFD0ECD2);
  static const lightMintWash = Color(0xFFDAF0DC);

  static const lightGreenPrimary = Color(0xFF1F8A40);
  static const lightGreenText = Color(0xFF163D20);
  static const lightGreenMuted = Color(0xFF3A6B42);
  static const lightGreenBorder = Color(0xFF6FAF76);
  static const lightChipFill = Color(0xFFA5D9AB);
  static const lightCardFill = Color(0xFFC2E4C5);

  /// Plain white — main screen and title bar in light theme.
  static const Color lightBackground = Color(0xFFFFFFFF);

  static const LinearGradient lightSearchField = LinearGradient(
    begin: Alignment.centerLeft,
    end: Alignment.centerRight,
    colors: [
      lightBackground,
      Color(0xFFFAFDFA),
      Color(0xFFF2F9F3),
      lightMintWash,
      lightMintSoft,
    ],
    stops: [0.0, 0.22, 0.45, 0.72, 1.0],
  );

  static const darkFieldBase = Color.fromARGB(255, 20, 27, 50);
  static const darkFieldBlend1 = Color.fromARGB(255, 30, 36, 51);
  static const darkFieldBlend2 = Color.fromARGB(255, 26, 42, 85);
  static const darkFieldBlend3 = Color.fromARGB(255, 31, 36, 59);
  static const darkFieldBlueEnd = Color.fromARGB(255, 21, 25, 46);

  static const LinearGradient darkSearchField = LinearGradient(
    begin: Alignment.centerLeft,
    end: Alignment.centerRight,
    colors: [
      darkFieldBase,
      darkFieldBlend1,
      darkFieldBlend2,
      darkFieldBlend3,
      darkFieldBlueEnd,
    ],
    stops: [0.0, 0.25, 0.5, 0.75, 1.0],
  );

  static const LinearGradient lightQuickTag = lightSearchField;
  static const LinearGradient darkQuickTag = darkSearchField;

  static const LinearGradient lightUserBubble = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [Color(0xFFA8D8AE), Color(0xFFC8E8CB)],
  );
}
