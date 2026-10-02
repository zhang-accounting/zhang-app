import 'package:decimal/decimal.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../../core/theme/app_theme.dart';
import '../../../core/utils/money.dart';
import '../../../data/models/commodity.dart';

/// Formats [value] of [commodity] with the commodity's precision and symbol
/// when known (`commoditiesProvider`), else with the generic formatter.
String formatAmount(
  Map<String, Commodity> commodities,
  Decimal value,
  String commodity, {
  bool signed = false,
}) =>
    commodities[commodity]?.format(value, signed: signed) ??
    formatMoney(value, commodity, signed: signed);

/// Compact number for chart axes: `1.2万` (zh) / `12K` (en).
String formatCompactNumber(BuildContext context, double value) =>
    NumberFormat.compact(locale: Localizations.localeOf(context).toLanguageTag()).format(value);

/// [base] with tabular figures, so digits line up in lists.
TextStyle amountStyle(TextStyle? base) =>
    (base ?? const TextStyle()).copyWith(fontFeatures: kAmountFontFeatures);

/// Monospace style for full account paths.
TextStyle accountPathStyle(BuildContext context) {
  final theme = Theme.of(context);
  return (theme.textTheme.bodySmall ?? const TextStyle()).copyWith(
    fontFamily: 'Menlo',
    fontFamilyFallback: const ['RobotoMono', 'Roboto Mono', 'monospace'],
    color: theme.colorScheme.onSurfaceVariant,
  );
}
