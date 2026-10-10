import 'package:decimal/decimal.dart';
import 'package:flutter/foundation.dart';

import '../../core/utils/dates.dart';
import 'amount.dart';
import 'json_utils.dart';

/// A column of a query result: `{"name": "units", "type": "inventory"}`.
@immutable
class QueryColumn {
  const QueryColumn(this.name, this.type);

  factory QueryColumn.fromJson(JsonMap m) => QueryColumn(reqString(m, 'name'), optString(m, 'type') ?? '');

  final String name;

  /// `int`, `bool`, `decimal`, `str`, `date`, `interval`, `set`, `amount`,
  /// `position`, `inventory` or `metas`.
  final String type;
}

/// The answer of a built-in query (`POST /api/query/builtins/{name}`, one
/// entry of the batch `POST /api/query/builtins`):
/// `{"columns": [QueryColumn], "rows": [[cell, …]], "total"?: int}`.
///
/// Read cells by column **name** through [QueryRow]'s typed getters (they
/// throw [FormatException] on a type mismatch, which the client reports as
/// `ApiParseError`). Cell encoding (zhang `QueryCell`):
///
/// | type | JSON |
/// |---|---|
/// | `int`, `bool` | number / boolean |
/// | `decimal`, `str`, `date` (`YYYY-MM-DD`), `interval` | string |
/// | `set` | sorted string array |
/// | `amount` | `{"number": "-12.50", "currency": "USD"}` |
/// | `position` | `{"units": amount, "cost": {number, currency, date, label} \| null}` |
/// | `inventory` | `{"positions": [position, …]}` |
/// | `metas` | `[{"key", "value"}, …]` |
/// | any | `null` |
class QueryResult {
  QueryResult({required this.columns, required List<List<Object?>> rows, this.total})
    : _index = {for (final (i, c) in columns.indexed) c.name: i} {
    this.rows = [for (final r in rows) QueryRow._(this, r)];
  }

  factory QueryResult.fromJson(Object? json) {
    final m = asMap(json, 'query result');
    return QueryResult(
      columns: parseList(m['columns'], QueryColumn.fromJson, 'columns'),
      rows: [for (final r in asList(m['rows'], 'rows')) asList(r, 'row')],
      total: m['total'] == null ? null : reqInt(m, 'total'),
    );
  }

  final List<QueryColumn> columns;
  late final List<QueryRow> rows;

  /// Number of rows before `LIMIT`/`OFFSET`, when the query was run with
  /// `count_total`.
  final int? total;

  final Map<String, int> _index;

  bool get isEmpty => rows.isEmpty;
  QueryRow? get firstOrNull => rows.isEmpty ? null : rows.first;

  bool hasColumn(String name) => _index.containsKey(name);

  /// Index of column [name]; [FormatException] when the server did not send it.
  int indexOf(String name) {
    final i = _index[name];
    if (i == null) throw FormatException('query result has no column "$name"');
    return i;
  }
}

/// One row of a [QueryResult] with typed cell readers. `xOrNull` variants
/// accept a JSON `null`; the others throw [FormatException] on `null`.
class QueryRow {
  const QueryRow._(this._result, this.cells);

  final QueryResult _result;

  /// Raw cells in column order.
  final List<Object?> cells;

  /// Raw cell of column [name].
  Object? operator [](String name) {
    final i = _result.indexOf(name);
    if (i >= cells.length) throw FormatException('row has no cell for column "$name"');
    return cells[i];
  }

  String string(String name) => _req(name, stringOrNull(name));

  String? stringOrNull(String name) {
    final v = this[name];
    if (v == null || v is String) return v as String?;
    throw FormatException('column "$name": expected a string, got ${v.runtimeType}');
  }

  int integer(String name) => _req(name, integerOrNull(name));

  int? integerOrNull(String name) {
    final v = this[name];
    if (v == null) return null;
    if (v is int) return v;
    if (v is num && v == v.roundToDouble()) return v.toInt();
    throw FormatException('column "$name": expected an integer, got "$v"');
  }

  bool boolean(String name) => _req(name, booleanOrNull(name));

  bool? booleanOrNull(String name) {
    final v = this[name];
    if (v == null || v is bool) return v as bool?;
    throw FormatException('column "$name": expected a boolean, got ${v.runtimeType}');
  }

  /// `decimal` cells are plain-notation strings (`"88.50"`).
  Decimal decimal(String name) => _req(name, decimalOrNull(name));

  Decimal? decimalOrNull(String name) => parseDecimalOrNull(this[name], 'column "$name"');

  /// `date` cells (`YYYY-MM-DD`) as local midnight.
  DateTime date(String name) => _req(name, dateOrNull(name));

  DateTime? dateOrNull(String name) {
    final v = stringOrNull(name);
    if (v == null) return null;
    final d = ZhangDates.tryParseDate(v);
    if (d == null) throw FormatException('column "$name": expected a date, got "$v"');
    return d;
  }

  /// Naive ledger-local datetime from a `date` column and an optional `time`
  /// column (`HH:MM:SS`), e.g. `dateTime('date', 'time')`.
  DateTime dateTime(String dateColumn, [String? timeColumn]) {
    final d = date(dateColumn);
    final t = timeColumn == null ? null : stringOrNull(timeColumn);
    if (t == null || t.isEmpty) return d;
    final parsed = ZhangDates.tryParseNaive('${ZhangDates.toIsoDate(d)}T$t');
    if (parsed == null) throw FormatException('column "$timeColumn": expected HH:MM:SS, got "$t"');
    return parsed;
  }

  /// `amount` cell → [Amount] (the wire key is `currency`).
  Amount amount(String name) => _req(name, amountOrNull(name));

  Amount? amountOrNull(String name) {
    final v = this[name];
    return v == null ? null : queryAmount(v, 'column "$name"');
  }

  /// `inventory` cell; `null` reads as an empty inventory.
  QueryInventory inventory(String name) {
    final v = this[name];
    return v == null ? const QueryInventory([]) : QueryInventory.fromJson(v);
  }

  /// `set` cell (sorted strings); `null` reads as empty.
  List<String> stringSet(String name) {
    final v = this[name];
    return v == null ? const [] : [for (final e in asList(v, 'column "$name"')) '$e'];
  }

  /// `metas` cell (`[{key, value}]`); `null` reads as empty.
  List<Meta> metas(String name) {
    final v = this[name];
    return v == null ? const [] : [for (final e in asList(v, 'column "$name"')) Meta.fromJson(e)];
  }

  static T _req<T>(String name, T? value) {
    if (value == null) throw FormatException('column "$name" is null');
    return value;
  }
}

/// `{"number": "…", "currency": "…"}` → [Amount].
Amount queryAmount(Object? json, [String what = 'amount']) {
  final m = asMap(json, what);
  return Amount(parseDecimal(m['number'], '$what.number'), reqString(m, 'currency'));
}

/// Per-unit cost of a [QueryPosition].
@immutable
class QueryCost {
  const QueryCost({required this.amount, this.date, this.label});

  factory QueryCost.fromJson(Object? json) {
    final m = asMap(json, 'cost');
    return QueryCost(
      amount: queryAmount(m, 'cost'),
      date: ZhangDates.tryParseDate(m['date']),
      label: optString(m, 'label'),
    );
  }

  final Amount amount;
  final DateTime? date;
  final String? label;
}

/// `position` cell: units and an optional cost.
@immutable
class QueryPosition {
  const QueryPosition(this.units, [this.cost]);

  factory QueryPosition.fromJson(Object? json) {
    final m = asMap(json, 'position');
    return QueryPosition(
      queryAmount(m['units'], 'position.units'),
      m['cost'] == null ? null : QueryCost.fromJson(m['cost']),
    );
  }

  final Amount units;
  final QueryCost? cost;
}

/// `inventory` cell: a list of positions (a currency may appear in several
/// lots).
@immutable
class QueryInventory {
  const QueryInventory(this.positions);

  factory QueryInventory.fromJson(Object? json) {
    final m = asMap(json, 'inventory');
    return QueryInventory([for (final p in asList(m['positions'] ?? const [], 'positions')) QueryPosition.fromJson(p)]);
  }

  final List<QueryPosition> positions;

  bool get isEmpty => positions.isEmpty;

  /// Units summed per currency (lots merged), in first-seen order.
  Map<String, Decimal> get unitsByCurrency {
    final out = <String, Decimal>{};
    for (final p in positions) {
      out[p.units.commodity] = (out[p.units.commodity] ?? Decimal.zero) + p.units.number;
    }
    return out;
  }

  /// Sum of the positions in [currency] (zero when there is none).
  Decimal sumIn(String currency) => positions
      .where((p) => p.units.commodity == currency)
      .fold(Decimal.zero, (sum, p) => sum + p.units.number);
}

/// Combines a `units` and a `value` inventory of the `report.*` queries into
/// the app's [CalculatedAmount]: `calculated` = the `value` positions in
/// [currency] (value is already converted by the server), `detail` = `units`
/// per currency (the same as the web UI's `calculatedAmount`).
CalculatedAmount calculatedFromInventories({
  required QueryInventory units,
  required QueryInventory value,
  required String currency,
}) => CalculatedAmount(calculated: Amount(value.sumIn(currency), currency), detail: units.unitsByCurrency);
