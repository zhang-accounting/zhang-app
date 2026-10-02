import 'package:decimal/decimal.dart';
import 'package:flutter/foundation.dart';

import 'json_utils.dart';

/// `{"number": "<decimal string>", "commodity": "CNY"}`.
@immutable
class Amount {
  const Amount(this.number, this.commodity);

  factory Amount.fromJson(Object? json) {
    final m = asMap(json, 'amount');
    return Amount(parseDecimal(m['number'], 'amount.number'), reqString(m, 'commodity'));
  }

  /// Convenience for `Amount(Decimal.parse(number), commodity)`.
  factory Amount.parse(String number, String commodity) =>
      Amount(Decimal.parse(number), commodity);

  static Amount? fromJsonOrNull(Object? json) =>
      json == null ? null : Amount.fromJson(json);

  final Decimal number;
  final String commodity;

  bool get isZero => number == Decimal.zero;
  bool get isNegative => number < Decimal.zero;

  Amount operator -() => Amount(-number, commodity);

  /// Number serialised as a string (see [decimalToJson]).
  Map<String, Object?> toJson() => {'number': decimalToJson(number), 'commodity': commodity};

  @override
  bool operator ==(Object other) =>
      other is Amount && other.number == number && other.commodity == commodity;

  @override
  int get hashCode => Object.hash(number, commodity);

  @override
  String toString() => '$number $commodity';
}

/// `{"calculated": Amount, "detail": {"<commodity>": "<decimal>"}}`.
///
/// [calculated] is converted to the operating currency by the server (only
/// via direct prices, earliest price – see docs §1.4); [detail] holds the raw
/// per-commodity sums.
@immutable
class CalculatedAmount {
  const CalculatedAmount({required this.calculated, this.detail = const {}});

  factory CalculatedAmount.fromJson(Object? json) {
    final m = asMap(json, 'calculated amount');
    return CalculatedAmount(
      calculated: Amount.fromJson(m['calculated']),
      detail: decimalMap(m['detail']),
    );
  }

  final Amount calculated;
  final Map<String, Decimal> detail;

  /// Non-zero per-commodity entries, sorted by commodity name.
  List<Amount> get nonZeroDetail {
    final keys = detail.keys.toList()..sort();
    return [
      for (final k in keys)
        if (detail[k] != Decimal.zero) Amount(detail[k]!, k),
    ];
  }

  Map<String, Object?> toJson() => {
    'calculated': calculated.toJson(),
    'detail': {for (final e in detail.entries) e.key: decimalToJson(e.value)},
  };

  @override
  bool operator ==(Object other) =>
      other is CalculatedAmount &&
      other.calculated == calculated &&
      mapEquals(other.detail, detail);

  @override
  int get hashCode => Object.hash(
    calculated,
    Object.hashAllUnordered(detail.entries.map((e) => Object.hash(e.key, e.value))),
  );
}

/// `{key, value}` pairs used for transaction metas and options.
@immutable
class Meta {
  const Meta(this.key, this.value);

  factory Meta.fromJson(Object? json) {
    final m = asMap(json, 'meta');
    return Meta(reqString(m, 'key'), '${m['value'] ?? ''}');
  }

  final String key;
  final String value;

  Map<String, Object?> toJson() => {'key': key, 'value': value};

  @override
  bool operator ==(Object other) => other is Meta && other.key == key && other.value == value;

  @override
  int get hashCode => Object.hash(key, value);
}
