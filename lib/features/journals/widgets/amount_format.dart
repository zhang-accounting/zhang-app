import 'package:flutter/material.dart';

import '../../../core/utils/money.dart';
import '../../../data/models/amount.dart';
import '../../../data/models/commodity.dart';

/// Minus sign used for display (U+2212, same width as `+`; design §3.3).
const displayMinus = '−';

/// Formats [amount] with its commodity's precision and prefix/suffix when
/// [commodities] knows it, else `1,234.50 CODE`. [signed] adds `+` to
/// positive values; negative values always get `−` (U+2212).
String formatAmount(Amount amount, Map<String, Commodity>? commodities, {bool signed = false}) {
  final c = commodities?[amount.commodity];
  final text = c != null
      ? c.format(amount.number, signed: signed)
      : formatMoney(amount.number, amount.commodity, signed: signed);
  return text.startsWith('-') ? '$displayMinus${text.substring(1)}' : text;
}

/// Text style with tabular figures for amounts (design §3.2).
TextStyle? tabular(TextStyle? style) =>
    style?.copyWith(fontFeatures: const [FontFeature.tabularFigures()]);

/// Account name without its type segment (`Assets:CitiBank:9999` →
/// `CitiBank:9999`); the full name when it has a single segment.
String accountLabel(String account) {
  final i = account.indexOf(':');
  return i < 0 || i == account.length - 1 ? account : account.substring(i + 1);
}
