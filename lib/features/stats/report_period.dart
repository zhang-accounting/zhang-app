import 'package:flutter/foundation.dart';
import 'package:intl/intl.dart';

/// Kind of reporting period.
enum PeriodKind { week, month, year, custom }

/// Granularity of the cash-flow bars.
enum BucketUnit { day, week, month }

/// Whole calendar days from [a] to [b] (DST-safe).
int calendarDaysBetween(DateTime a, DateTime b) => DateTime.utc(
  b.year,
  b.month,
  b.day,
).difference(DateTime.utc(a.year, a.month, a.day)).inDays;

DateTime _day(DateTime d) => DateTime(d.year, d.month, d.day);

DateTime _addDays(DateTime d, int days) => DateTime(d.year, d.month, d.day + days);

/// Monday of the week containing [d] (weeks start on Monday, ISO 8601).
DateTime startOfWeek(DateTime d) => DateTime(d.year, d.month, d.day - (d.weekday - DateTime.monday));

/// A reporting period made of whole **device-local** days: [start] is local
/// midnight of the first day, [endExclusive] local midnight after the last
/// day. Requests use [start] and [end] (inclusive last second); the
/// repository sends them as UTC instants.
@immutable
class ReportPeriod {
  const ReportPeriod._(this.kind, this.start, this.endExclusive);

  /// Monday-to-Sunday week containing [anchor].
  factory ReportPeriod.week(DateTime anchor) {
    final s = startOfWeek(anchor);
    return ReportPeriod._(PeriodKind.week, s, _addDays(s, 7));
  }

  /// Calendar month containing [anchor].
  factory ReportPeriod.month(DateTime anchor) =>
      ReportPeriod._(PeriodKind.month, DateTime(anchor.year, anchor.month), DateTime(anchor.year, anchor.month + 1));

  /// Calendar year containing [anchor].
  factory ReportPeriod.year(DateTime anchor) =>
      ReportPeriod._(PeriodKind.year, DateTime(anchor.year), DateTime(anchor.year + 1));

  /// Custom range of whole days, [first] to [last] inclusive (order-insensitive).
  factory ReportPeriod.custom(DateTime first, DateTime last) {
    final a = _day(first);
    final b = _day(last);
    final (from, to) = a.isAfter(b) ? (b, a) : (a, b);
    return ReportPeriod._(PeriodKind.custom, from, _addDays(to, 1));
  }

  /// Period of [kind] containing [anchor]; `custom` becomes the month.
  factory ReportPeriod.of(PeriodKind kind, DateTime anchor) => switch (kind) {
    PeriodKind.week => ReportPeriod.week(anchor),
    PeriodKind.month || PeriodKind.custom => ReportPeriod.month(anchor),
    PeriodKind.year => ReportPeriod.year(anchor),
  };

  final PeriodKind kind;

  /// Local midnight of the first day.
  final DateTime start;

  /// Local midnight of the day after the last day.
  final DateTime endExclusive;

  /// Last second of the period (local 23:59:59 of [lastDay]); the statistic
  /// endpoints treat `to` as inclusive.
  DateTime get end => endExclusive.subtract(const Duration(seconds: 1));

  /// Local midnight of the last day.
  DateTime get lastDay => _addDays(endExclusive, -1);

  /// Number of days in the period.
  int get dayCount => calendarDaysBetween(start, endExclusive);

  /// Whether the local instant [t] falls inside the period.
  bool contains(DateTime t) => !t.isBefore(start) && t.isBefore(endExclusive);

  /// The period [delta] steps away (negative = earlier). Custom ranges move
  /// by their own length.
  ReportPeriod step(int delta) => switch (kind) {
    PeriodKind.week => ReportPeriod.week(_addDays(start, 7 * delta)),
    PeriodKind.month => ReportPeriod.month(DateTime(start.year, start.month + delta)),
    PeriodKind.year => ReportPeriod.year(DateTime(start.year + delta)),
    PeriodKind.custom => ReportPeriod.custom(
      _addDays(start, dayCount * delta),
      _addDays(lastDay, dayCount * delta),
    ),
  };

  /// Bar granularity: days for weeks, months and custom ranges up to 31 days;
  /// weeks for custom ranges up to 26 weeks; months otherwise.
  BucketUnit get bucketUnit => switch (kind) {
    PeriodKind.week || PeriodKind.month => BucketUnit.day,
    PeriodKind.year => BucketUnit.month,
    PeriodKind.custom =>
      dayCount <= 31 ? BucketUnit.day : (dayCount <= 26 * 7 ? BucketUnit.week : BucketUnit.month),
  };

  /// Start (local midnight) of every bucket. The first bucket starts at
  /// [start]; later week / month buckets start on Mondays / the 1st.
  List<DateTime> get bucketStarts {
    final result = <DateTime>[start];
    while (true) {
      final last = result.last;
      final next = switch (bucketUnit) {
        BucketUnit.day => _addDays(last, 1),
        BucketUnit.week => _addDays(startOfWeek(last), 7),
        BucketUnit.month => DateTime(last.year, last.month + 1),
      };
      if (!next.isBefore(endExclusive)) break;
      result.add(next);
    }
    return result;
  }

  /// Index of the bucket containing the day [date], or -1 when outside.
  int bucketIndexOf(DateTime date, [List<DateTime>? starts]) {
    final d = _day(date);
    if (d.isBefore(start) || !d.isBefore(endExclusive)) return -1;
    final s = starts ?? bucketStarts;
    switch (bucketUnit) {
      case BucketUnit.day:
        return calendarDaysBetween(start, d);
      case BucketUnit.week:
      case BucketUnit.month:
        for (var i = s.length - 1; i >= 0; i--) {
          if (!d.isBefore(s[i])) return i;
        }
        return -1;
    }
  }

  /// Human label: `October 2026`, `2026`, `Sep 28 – Oct 4, 2026`, …
  String label([String? locale]) {
    switch (kind) {
      case PeriodKind.month:
        return DateFormat.yMMMM(locale).format(start);
      case PeriodKind.year:
        return DateFormat.y(locale).format(start);
      case PeriodKind.week:
      case PeriodKind.custom:
        final last = lastDay;
        if (dayCount == 1) return DateFormat.yMMMd(locale).format(start);
        final sameYear = start.year == last.year;
        final from = sameYear ? DateFormat.MMMd(locale).format(start) : DateFormat.yMMMd(locale).format(start);
        return '$from – ${DateFormat.yMMMd(locale).format(last)}';
    }
  }

  @override
  bool operator ==(Object other) =>
      other is ReportPeriod && other.kind == kind && other.start == start && other.endExclusive == endExclusive;

  @override
  int get hashCode => Object.hash(kind, start, endExclusive);

  @override
  String toString() => 'ReportPeriod(${kind.name}, $start – $endExclusive)';
}
