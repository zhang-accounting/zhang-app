import 'package:flutter/foundation.dart';

/// A calendar month (ledger wall-clock), used as cache key for per-month
/// statistics and for month headers.
@immutable
class YearMonth implements Comparable<YearMonth> {
  /// [month] may be out of range (0, 13, -1 …); it is normalised, so
  /// `YearMonth(2026, 13)` == `YearMonth(2027, 1)`.
  factory YearMonth(int year, int month) {
    final index = year * 12 + (month - 1);
    return YearMonth._(index ~/ 12, index % 12 + 1);
  }

  const YearMonth._(this.year, this.month);

  /// Month containing [value] (wall-clock fields, no timezone conversion).
  factory YearMonth.of(DateTime value) => YearMonth(value.year, value.month);

  /// The current month on this device.
  factory YearMonth.now() => YearMonth.of(DateTime.now());

  final int year;

  /// 1–12.
  final int month;

  /// First instant: local midnight of day 1.
  DateTime get start => DateTime(year, month);

  /// Last second of the month (local 23:59:59 of the last day). The
  /// statistic endpoints treat `to` as inclusive.
  DateTime get end => DateTime(year, month + 1).subtract(const Duration(seconds: 1));

  YearMonth get previous => YearMonth(year, month - 1);
  YearMonth get next => YearMonth(year, month + 1);

  /// Whether [value]'s wall-clock date falls in this month.
  bool contains(DateTime value) => value.year == year && value.month == month;

  @override
  int compareTo(YearMonth other) =>
      year != other.year ? year.compareTo(other.year) : month.compareTo(other.month);

  bool isAfter(YearMonth other) => compareTo(other) > 0;

  @override
  bool operator ==(Object other) => other is YearMonth && other.year == year && other.month == month;

  @override
  int get hashCode => Object.hash(year, month);

  @override
  String toString() => '$year-${month.toString().padLeft(2, '0')}';
}
