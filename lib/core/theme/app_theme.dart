import 'package:flutter/material.dart';

import 'app_colors.dart';

/// Calm blue/teal seed for the Material 3 colour scheme.
const Color kZhangSeedColor = Color(0xFF1F6F8B);

/// Builds the app's Material 3 theme for the given [brightness].
ThemeData buildZhangTheme(Brightness brightness) {
  final scheme = ColorScheme.fromSeed(
    seedColor: kZhangSeedColor,
    brightness: brightness,
  );
  final isDark = brightness == Brightness.dark;
  return ThemeData(
    useMaterial3: true,
    colorScheme: scheme,
    brightness: brightness,
    extensions: [isDark ? ZhangColors.dark : ZhangColors.light],
    appBarTheme: AppBarTheme(
      centerTitle: false,
      backgroundColor: scheme.surface,
      foregroundColor: scheme.onSurface,
      scrolledUnderElevation: 1,
    ),
    inputDecorationTheme: const InputDecorationTheme(
      border: OutlineInputBorder(),
    ),
    listTileTheme: const ListTileThemeData(
      contentPadding: EdgeInsets.symmetric(horizontal: 16),
    ),
  );
}

/// Font features for amounts: tabular figures keep digits aligned in lists.
/// `style.copyWith(fontFeatures: kAmountFontFeatures)`.
const List<FontFeature> kAmountFontFeatures = [FontFeature.tabularFigures()];

final ThemeData zhangLightTheme = buildZhangTheme(Brightness.light);
final ThemeData zhangDarkTheme = buildZhangTheme(Brightness.dark);
