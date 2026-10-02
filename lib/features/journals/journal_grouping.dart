import 'package:decimal/decimal.dart';

import '../../data/models/amount.dart';
import '../../data/models/journal.dart';
import 'classify.dart';
import 'year_month.dart';

/// Client-side type filter of the journal list (the API cannot filter by
/// type).
enum JournalTypeFilter {
  all,
  expense,
  income,
  transfer;

  /// Whether [item] is shown under this filter. Balance items, compound
  /// and adjustment transactions only appear under [all].
  bool accepts(JournalItem item, {String? operatingCurrency}) {
    if (this == all) return true;
    if (item is! JournalTransaction) return false;
    final kind = classify(item, operatingCurrency: operatingCurrency).kind;
    return switch (this) {
      all => true,
      expense => kind == TxnKind.expense,
      income => kind == TxnKind.income,
      transfer => kind == TxnKind.transfer,
    };
  }
}

/// Items of one calendar day.
class JournalDayGroup {
  JournalDayGroup({required this.day, required this.items, required this.complete, this.operatingCurrency});

  /// Local midnight of the day.
  final DateTime day;

  /// Newest first, as returned by the server.
  final List<JournalItem> items;

  /// `false` when the list is paginated and more items of this day may still
  /// be on the next page – the day net is then not shown (design S07).
  final bool complete;

  final String? operatingCurrency;

  /// Net of the day per commodity (income − expense; transfers, adjustments
  /// and balance items excluded), primary commodity first.
  late final List<Amount> net = dayNet(items, operatingCurrency: operatingCurrency);
}

/// Days of one month.
class JournalMonthGroup {
  const JournalMonthGroup({required this.month, required this.days});

  final YearMonth month;
  final List<JournalDayGroup> days;

  int get itemCount => days.fold(0, (n, d) => n + d.items.length);
}

/// Groups [items] (newest first) into months and days, preserving order.
/// Items of the same day are merged even if not adjacent. When [hasMore] is
/// true the oldest day is marked incomplete.
List<JournalMonthGroup> groupJournal(
  List<JournalItem> items, {
  required bool hasMore,
  String? operatingCurrency,
}) {
  final days = <DateTime, List<JournalItem>>{};
  for (final item in items) {
    final d = item.datetime;
    days.putIfAbsent(DateTime(d.year, d.month, d.day), () => []).add(item);
  }
  final months = <YearMonth, List<JournalDayGroup>>{};
  final dayKeys = days.keys.toList();
  for (var i = 0; i < dayKeys.length; i++) {
    final day = dayKeys[i];
    final isLast = i == dayKeys.length - 1;
    months.putIfAbsent(YearMonth.of(day), () => []).add(
      JournalDayGroup(
        day: day,
        items: days[day]!,
        complete: !(hasMore && isLast),
        operatingCurrency: operatingCurrency,
      ),
    );
  }
  return [
    for (final e in months.entries) JournalMonthGroup(month: e.key, days: e.value),
  ];
}

/// Net of [items] per commodity: the signed display amounts of expense,
/// income (incl. refunds) and compound transactions. Primary commodity
/// ([operatingCurrency], else first seen) first; empty when nothing counts.
List<Amount> dayNet(List<JournalItem> items, {String? operatingCurrency}) {
  final totals = <String, Decimal>{};
  for (final item in items) {
    if (item is! JournalTransaction) continue;
    final c = classify(item, operatingCurrency: operatingCurrency);
    if (!c.isDirectional) continue;
    for (final a in c.amounts) {
      totals[a.commodity] = (totals[a.commodity] ?? Decimal.zero) + a.number;
    }
  }
  final keys = totals.keys.toList();
  if (operatingCurrency != null && keys.remove(operatingCurrency)) keys.insert(0, operatingCurrency);
  return [for (final k in keys) Amount(totals[k]!, k)];
}
