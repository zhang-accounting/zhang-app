import 'package:flutter/material.dart';

/// 8-hue categorical palette for category charts (light / dark steps of the
/// same hues, CVD-checked in this order). Slots are picked per account via
/// `assignColorSlots`, so a category keeps its colour across charts.
const _lightPalette = [
  Color(0xFF2A78D6), // blue
  Color(0xFFEB6834), // orange
  Color(0xFF1BAF7A), // aqua
  Color(0xFFEDA100), // yellow
  Color(0xFFE87BA4), // magenta
  Color(0xFF008300), // green
  Color(0xFF4A3AA7), // violet
  Color(0xFFE34948), // red
];

const _darkPalette = [
  Color(0xFF3987E5),
  Color(0xFFD95926),
  Color(0xFF199E70),
  Color(0xFFC98500),
  Color(0xFFD55181),
  Color(0xFF008300),
  Color(0xFF9085E9),
  Color(0xFFE66767),
];

const int kCategoryPaletteSize = 8;

/// Colour of palette [slot] for the current brightness.
Color categoryColor(BuildContext context, int slot) {
  final dark = Theme.of(context).brightness == Brightness.dark;
  final palette = dark ? _darkPalette : _lightPalette;
  return palette[slot % palette.length];
}

/// Neutral colour of the "Other" slice.
Color otherCategoryColor(BuildContext context) => Theme.of(context).colorScheme.outline;
