import 'package:decimal/decimal.dart';
import 'package:flutter/widgets.dart';

import '../theme/app_colors.dart';

/// Money / decimal formatting helpers.
///
/// All amounts in the app are [Decimal]s (never `double`). The server sends
/// numbers as strings whose scale is not normalised (`"-21"`, `"132768.0"`,
/// `"1E-8"`), so always format for display with the commodity precision from
/// `/api/commodities` (see `commoditiesProvider`).

/// Formats [value] with thousands separators and a fixed number of decimals.
///
/// * [precision]: number of fraction digits. When `null`, uses the value's own
///   scale but at least 2 (so `21` → `21.00`, `0.00000001` stays intact).
/// * [signed]: prefix positive values with `+` (negative values always get `-`).
/// * [grouping]: insert `,` every three integer digits.
String formatDecimal(
  Decimal value, {
  int? precision,
  bool signed = false,
  bool grouping = true,
}) {
  final digits = precision ?? (value.scale > 2 ? value.scale : 2);
  var text = value.abs().toStringAsFixed(digits);
  if (grouping) {
    final dot = text.indexOf('.');
    final intPart = dot < 0 ? text : text.substring(0, dot);
    final fracPart = dot < 0 ? '' : text.substring(dot);
    text = _group(intPart) + fracPart;
  }
  final isZero = value.round(scale: digits) == Decimal.zero;
  if (value < Decimal.zero && !isZero) return '-$text';
  if (signed && value > Decimal.zero && !isZero) return '+$text';
  return text;
}

String _group(String digits) {
  if (digits.length <= 3) return digits;
  final buf = StringBuffer();
  final lead = digits.length % 3;
  if (lead > 0) buf.write(digits.substring(0, lead));
  for (var i = lead; i < digits.length; i += 3) {
    if (buf.isNotEmpty) buf.write(',');
    buf.write(digits.substring(i, i + 3));
  }
  return buf.toString();
}

/// Minus sign for displayed amounts (U+2212, as wide as `+`; design §3.3).
/// [formatDecimal] keeps the ASCII `-` for machine-readable text.
const displayMinus = '−';

/// Formats an amount of a commodity for display.
///
/// Default output is `"−1,234.50 CNY"` (commodity suffix, U+2212 minus). Pass
/// the commodity's display [prefix] (e.g. `"¥"`, from `Commodity.prefix`) to
/// get `"−¥1,234.50"` instead; [suffix] (e.g. `Commodity.suffix`) replaces the
/// commodity code.
String formatMoney(
  Decimal value,
  String? commodity, {
  int? precision,
  bool signed = false,
  bool grouping = true,
  String? prefix,
  String? suffix,
}) {
  final plain = formatDecimal(
    value,
    precision: precision,
    signed: signed,
    grouping: grouping,
  );
  final number = plain.startsWith('-') ? '$displayMinus${plain.substring(1)}' : plain;
  if (prefix != null && prefix.isNotEmpty) {
    final hasSign = number.startsWith(displayMinus) || number.startsWith('+');
    final sign = hasSign ? number[0] : '';
    final rest = hasSign ? number.substring(1) : number;
    return '$sign$prefix$rest';
  }
  if (suffix != null && suffix.isNotEmpty) return '$number$suffix';
  if (commodity == null || commodity.isEmpty) return number;
  return '$number $commodity';
}

/// The visual tone of an amount.
enum AmountTone { positive, negative, neutral }

/// Tone of [value]: positive / negative / neutral (zero).
///
/// Set [invert] for account types whose natural sign is negative (Income,
/// Liabilities, Equity) when you want "earned" / "owed" to read as positive,
/// or for Expenses when spending (positive) should be shown as negative.
AmountTone toneOf(Decimal value, {bool invert = false}) {
  if (value == Decimal.zero) return AmountTone.neutral;
  final positive = value > Decimal.zero;
  return (positive != invert) ? AmountTone.positive : AmountTone.negative;
}

/// Colour for an [AmountTone]: income colour for positive, expense colour for
/// negative and the neutral colour for zero.
Color toneColor(BuildContext context, AmountTone tone) {
  final colors = context.zhangColors;
  return switch (tone) {
    AmountTone.positive => colors.income,
    AmountTone.negative => colors.expense,
    AmountTone.neutral => colors.neutral,
  };
}

/// Shortcut for `toneColor(context, toneOf(value, invert: invert))`.
Color amountColor(BuildContext context, Decimal value, {bool invert = false}) =>
    toneColor(context, toneOf(value, invert: invert));
