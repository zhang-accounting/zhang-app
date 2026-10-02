import 'package:decimal/decimal.dart';
import 'package:flutter/foundation.dart';

import '../../data/models/account.dart';
import '../../data/models/statistic.dart';
import 'report_period.dart';

// ---------------------------------------------------------------------------
// Cash flow (grouped bars + net line)
// ---------------------------------------------------------------------------

/// Income and expense of one bar group, both presented as positive numbers
/// (income is negated from the ledger's natural sign).
@immutable
class CashflowBucket {
  const CashflowBucket(this.start, this.income, this.expense);

  /// Local midnight of the bucket's first day.
  final DateTime start;
  final Decimal income;
  final Decimal expense;

  Decimal get net => income - expense;
}

/// Groups the daily `changes` of [graph] into the buckets of [period]
/// (converted `calculated` amounts in the operating currency). Days outside
/// the period are ignored.
List<CashflowBucket> bucketCashflow(StatisticGraph graph, ReportPeriod period) {
  final starts = period.bucketStarts;
  final income = List<Decimal>.filled(starts.length, Decimal.zero);
  final expense = List<Decimal>.filled(starts.length, Decimal.zero);
  for (final day in graph.changes) {
    final i = period.bucketIndexOf(day.date, starts);
    if (i < 0) continue;
    final inc = day.byType[AccountType.income];
    final exp = day.byType[AccountType.expenses];
    if (inc != null) income[i] -= inc.calculated.number;
    if (exp != null) expense[i] += exp.calculated.number;
  }
  return [
    for (var i = 0; i < starts.length; i++) CashflowBucket(starts[i], income[i], expense[i]),
  ];
}

// ---------------------------------------------------------------------------
// Category ranking with drill-down
// ---------------------------------------------------------------------------

/// One row of the category ranking at a drill-down level.
@immutable
class RankItem {
  const RankItem({
    required this.key,
    required this.value,
    required this.hasChildren,
    required this.isDirect,
  });

  /// Account path prefix of this group, e.g. `Expenses:Food`; for a leaf it
  /// is the account name itself.
  final String key;

  /// Total in the operating currency, sign-flipped for naturally negative
  /// types so income reads positive.
  final Decimal value;

  /// Deeper accounts exist below [key] (tap drills down).
  final bool hasChildren;

  /// Postings booked directly on the parent of this level (the account named
  /// exactly like the current drill-down level).
  final bool isDirect;

  /// Last segment of [key].
  String get label => key.split(':').last;
}

/// Aggregates rank `detail` rows one level below [parent] (`Expenses`,
/// `Expenses:Food`, …): every account under [parent] is summed into the
/// prefix with one more segment. An account named exactly [parent] becomes a
/// direct item. Sorted by value (desc), then key.
List<RankItem> aggregateRank(List<AccountAmount> detail, String parent) {
  final type = AccountType.ofAccount(parent);
  final flip = type?.isNaturallyNegative ?? false;
  final depth = parent.split(':').length + 1;
  final sums = <String, Decimal>{};
  final deeper = <String>{};
  var direct = Decimal.zero;
  var hasDirect = false;
  for (final row in detail) {
    final value = flip ? -row.amount.calculated.number : row.amount.calculated.number;
    if (row.account == parent) {
      direct += value;
      hasDirect = true;
      continue;
    }
    if (!row.account.startsWith('$parent:')) continue;
    final segments = row.account.split(':');
    final key = segments.take(depth).join(':');
    sums[key] = (sums[key] ?? Decimal.zero) + value;
    if (segments.length > depth) deeper.add(key);
  }
  final items = [
    for (final e in sums.entries)
      RankItem(key: e.key, value: e.value, hasChildren: deeper.contains(e.key), isDirect: false),
    if (hasDirect) RankItem(key: parent, value: direct, hasChildren: false, isDirect: true),
  ];
  items.sort((a, b) {
    final c = b.value.compareTo(a.value);
    return c != 0 ? c : a.key.compareTo(b.key);
  });
  return items;
}

/// Ancestor levels of [path] for the breadcrumb: `Expenses:Food:Lunch` →
/// `[Expenses, Expenses:Food, Expenses:Food:Lunch]`.
List<String> breadcrumbOf(String path) {
  final segments = path.split(':');
  return [for (var i = 1; i <= segments.length; i++) segments.take(i).join(':')];
}

// ---------------------------------------------------------------------------
// Donut: top N + "Other"
// ---------------------------------------------------------------------------

/// A donut slice. [key] is `null` for the "Other" slice.
@immutable
class DonutSlice {
  const DonutSlice({required this.key, required this.value, this.count = 1});

  final String? key;
  final Decimal value;

  /// Number of rank items folded into this slice.
  final int count;

  bool get isOther => key == null;
}

/// At most [maxSlices] largest positive items, plus one "Other" slice summing
/// the remaining positive items when there are more. Non-positive items
/// (refunds exceeding spending) cannot be drawn and are left out.
List<DonutSlice> groupDonut(List<RankItem> items, {int maxSlices = 6}) {
  final positive = items.where((i) => i.value > Decimal.zero).toList()
    ..sort((a, b) {
      final c = b.value.compareTo(a.value);
      return c != 0 ? c : a.key.compareTo(b.key);
    });
  if (positive.length <= maxSlices) {
    return [for (final i in positive) DonutSlice(key: i.key, value: i.value)];
  }
  final rest = positive.skip(maxSlices).toList();
  return [
    for (final i in positive.take(maxSlices)) DonutSlice(key: i.key, value: i.value),
    DonutSlice(
      key: null,
      value: rest.fold(Decimal.zero, (sum, i) => sum + i.value),
      count: rest.length,
    ),
  ];
}

/// Share of [value] in [total] as a fraction 0..1 (0 when total ≤ 0).
double shareOf(Decimal value, Decimal total) {
  if (total <= Decimal.zero || value <= Decimal.zero) return 0;
  return (value.toDouble() / total.toDouble()).clamp(0.0, 1.0);
}

// ---------------------------------------------------------------------------
// Stable category colours
// ---------------------------------------------------------------------------

/// FNV-1a 32-bit hash: stable across runs and platforms (unlike
/// `String.hashCode`).
int stableHash(String s) {
  var h = 0x811c9dc5;
  for (final unit in s.codeUnits) {
    h ^= unit;
    h = (h * 0x01000193) & 0xffffffff;
  }
  return h;
}

/// Assigns palette slots (0 ≤ slot < [paletteSize]) to [keys] in order: each
/// key prefers `stableHash(key) % paletteSize` (so an account keeps its colour
/// across periods and charts) and probes forward on collision, so the shown
/// keys never share a colour while there are free slots.
Map<String, int> assignColorSlots(List<String> keys, {int paletteSize = 8}) {
  final used = <int>{};
  final result = <String, int>{};
  for (final key in keys) {
    if (result.containsKey(key)) continue;
    var slot = stableHash(key) % paletteSize;
    if (used.length < paletteSize) {
      while (used.contains(slot)) {
        slot = (slot + 1) % paletteSize;
      }
    }
    used.add(slot);
    result[key] = slot;
  }
  return result;
}
