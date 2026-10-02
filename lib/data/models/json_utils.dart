import 'package:decimal/decimal.dart';

import '../../core/utils/dates.dart';

/// Small, strict helpers for hand-written `fromJson` factories.
///
/// They throw [FormatException] on shape mismatches; `ZhangApiClient` turns
/// any decoding exception into an `ApiParseError`.
typedef JsonMap = Map<String, Object?>;

JsonMap asMap(Object? value, [String what = 'object']) {
  if (value is Map<String, Object?>) return value;
  if (value is Map) return value.cast<String, Object?>();
  throw FormatException('expected $what to be a JSON object, got ${value.runtimeType}');
}

List<Object?> asList(Object? value, [String what = 'array']) {
  if (value is List) return value;
  throw FormatException('expected $what to be a JSON array, got ${value.runtimeType}');
}

String reqString(JsonMap json, String key) {
  final v = json[key];
  if (v is String) return v;
  throw FormatException('expected "$key" to be a string, got ${v.runtimeType}');
}

String? optString(JsonMap json, String key) {
  final v = json[key];
  if (v == null) return null;
  if (v is String) return v;
  throw FormatException('expected "$key" to be a string or null, got ${v.runtimeType}');
}

int reqInt(JsonMap json, String key) {
  final v = json[key];
  if (v is int) return v;
  if (v is num) return v.toInt();
  if (v is String) {
    final p = int.tryParse(v);
    if (p != null) return p;
  }
  throw FormatException('expected "$key" to be an integer, got ${v.runtimeType}');
}

bool optBool(JsonMap json, String key, {bool fallback = false}) {
  final v = json[key];
  return v is bool ? v : fallback;
}

List<String> stringList(Object? value) =>
    value == null ? const [] : [for (final e in asList(value)) '$e'];

/// Parses a decimal sent as a string (`"-32.50"`, `"1E-8"`, `"-1E+3"`) or,
/// defensively, as a JSON number.
Decimal parseDecimal(Object? value, [String what = 'number']) {
  if (value is String) {
    final d = Decimal.tryParse(value.trim());
    if (d != null) return d;
  } else if (value is int) {
    return Decimal.fromInt(value);
  } else if (value is num) {
    final d = Decimal.tryParse(value.toString());
    if (d != null) return d;
  }
  throw FormatException('expected $what to be a decimal string, got "$value"');
}

Decimal? parseDecimalOrNull(Object? value, [String what = 'number']) =>
    value == null ? null : parseDecimal(value, what);

/// Serialises a decimal for requests: always a JSON **string** in plain
/// notation (never a JSON number, never exponent notation).
String decimalToJson(Decimal value) => value.toString();

DateTime reqNaiveDateTime(JsonMap json, String key) =>
    ZhangDates.parseNaive(reqString(json, key));

DateTime? optNaiveDateTime(JsonMap json, String key) {
  final v = optString(json, key);
  return v == null || v.isEmpty ? null : ZhangDates.parseNaive(v);
}

/// `{"<key>": "<decimal>"}` maps (e.g. `CalculatedAmount.detail`).
Map<String, Decimal> decimalMap(Object? value) {
  if (value == null) return const {};
  final m = asMap(value);
  return {for (final e in m.entries) e.key: parseDecimal(e.value, e.key)};
}

/// Parses a list with [item], naming the failing element in errors.
List<T> parseList<T>(Object? value, T Function(JsonMap json) item, [String what = 'array']) {
  final list = asList(value, what);
  return [for (final e in list) item(asMap(e, '$what element'))];
}
