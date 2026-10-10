import 'amount.dart';
import 'json_utils.dart';

/// `GET /api/options`: all ledger options (values are always strings).
class LedgerOptions {
  const LedgerOptions(this.values);

  factory LedgerOptions.fromJson(Object? json) {
    final list = parseList(json, (m) => Meta.fromJson(m), 'options');
    return LedgerOptions({for (final m in list) m.key: m.value});
  }

  final Map<String, String> values;

  String? operator [](String key) => values[key];

  /// Option `operating_currency`, e.g. `CNY` (always present).
  String get operatingCurrency => values['operating_currency'] ?? 'CNY';

  /// IANA ledger timezone, e.g. `Asia/Tokyo` (always present).
  String? get timezone => values['timezone'];

  String? get title => values['title'];

  /// Default display precision when a commodity has none (`2`).
  int get defaultCommodityPrecision =>
      int.tryParse(values['default_commodity_precision'] ?? '') ?? 2;
}
