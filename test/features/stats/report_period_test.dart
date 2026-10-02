import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:zhang_app/features/stats/report_period.dart';
import 'package:zhang_app/features/stats/reports_providers.dart';

void main() {
  group('month', () {
    test('boundaries are local midnights; end is the last second', () {
      final p = ReportPeriod.month(DateTime(2026, 10, 2, 15, 30));
      expect(p.kind, PeriodKind.month);
      expect(p.start, DateTime(2026, 10));
      expect(p.endExclusive, DateTime(2026, 11));
      expect(p.end, DateTime(2026, 10, 31, 23, 59, 59));
      expect(p.lastDay, DateTime(2026, 10, 31));
      expect(p.dayCount, 31);
      expect(p.start.isUtc, isFalse);
    });

    test('steps across year boundaries', () {
      final jan = ReportPeriod.month(DateTime(2026, 1, 15));
      expect(jan.step(-1), ReportPeriod.month(DateTime(2025, 12)));
      expect(jan.step(-1).start, DateTime(2025, 12));
      expect(ReportPeriod.month(DateTime(2025, 12, 31)).step(1).start, DateTime(2026, 1));
      expect(jan.step(13).start, DateTime(2027, 2));
    });

    test('February lengths', () {
      expect(ReportPeriod.month(DateTime(2024, 2, 10)).dayCount, 29);
      expect(ReportPeriod.month(DateTime(2026, 2, 10)).dayCount, 28);
      expect(ReportPeriod.month(DateTime(2026, 2, 10)).end, DateTime(2026, 2, 28, 23, 59, 59));
    });

    test('contains', () {
      final p = ReportPeriod.month(DateTime(2026, 10, 2));
      expect(p.contains(DateTime(2026, 10)), isTrue);
      expect(p.contains(DateTime(2026, 10, 31, 23, 59, 59)), isTrue);
      expect(p.contains(DateTime(2026, 11)), isFalse);
      expect(p.contains(DateTime(2026, 9, 30, 23, 59, 59)), isFalse);
    });
  });

  group('week', () {
    test('Monday to Sunday', () {
      // 2026-10-04 is a Sunday.
      final p = ReportPeriod.week(DateTime(2026, 10, 4, 22));
      expect(p.start, DateTime(2026, 9, 28));
      expect(p.start.weekday, DateTime.monday);
      expect(p.lastDay, DateTime(2026, 10, 4));
      expect(p.dayCount, 7);
      expect(ReportPeriod.week(DateTime(2026, 9, 28)), p);
    });

    test('steps by 7 days across month and year boundaries', () {
      final p = ReportPeriod.week(DateTime(2026, 10, 2));
      expect(p.step(1).start, DateTime(2026, 10, 5));
      expect(p.step(-1).start, DateTime(2026, 9, 21));
      final newYear = ReportPeriod.week(DateTime(2027, 1, 1)); // Friday
      expect(newYear.start, DateTime(2026, 12, 28));
      expect(newYear.step(1).start, DateTime(2027, 1, 4));
    });
  });

  group('year', () {
    test('boundaries and stepping', () {
      final p = ReportPeriod.year(DateTime(2026, 6, 1));
      expect(p.start, DateTime(2026));
      expect(p.end, DateTime(2026, 12, 31, 23, 59, 59));
      expect(p.dayCount, 365);
      expect(p.step(-2).start, DateTime(2024));
      expect(p.step(-2).dayCount, 366);
    });
  });

  group('custom', () {
    test('inclusive whole days, order-insensitive', () {
      final p = ReportPeriod.custom(DateTime(2026, 9, 10, 18), DateTime(2026, 9, 1, 7));
      expect(p.kind, PeriodKind.custom);
      expect(p.start, DateTime(2026, 9, 1));
      expect(p.lastDay, DateTime(2026, 9, 10));
      expect(p.end, DateTime(2026, 9, 10, 23, 59, 59));
      expect(p.dayCount, 10);
    });

    test('steps by its own length', () {
      final p = ReportPeriod.custom(DateTime(2026, 9, 1), DateTime(2026, 9, 10));
      final prev = p.step(-1);
      expect(prev.start, DateTime(2026, 8, 22));
      expect(prev.lastDay, DateTime(2026, 8, 31));
      expect(p.step(1).start, DateTime(2026, 9, 11));
      expect(p.step(1).dayCount, 10);
    });

    test('ReportPeriod.of maps custom to the month', () {
      expect(ReportPeriod.of(PeriodKind.custom, DateTime(2026, 10, 2)), ReportPeriod.month(DateTime(2026, 10)));
    });
  });

  group('buckets', () {
    test('month → one bucket per day', () {
      final p = ReportPeriod.month(DateTime(2026, 10));
      expect(p.bucketUnit, BucketUnit.day);
      final s = p.bucketStarts;
      expect(s.length, 31);
      expect(s.first, DateTime(2026, 10, 1));
      expect(s.last, DateTime(2026, 10, 31));
      expect(p.bucketIndexOf(DateTime(2026, 10, 15, 23, 59)), 14);
      expect(p.bucketIndexOf(DateTime(2026, 11, 1)), -1);
      expect(p.bucketIndexOf(DateTime(2026, 9, 30)), -1);
    });

    test('week → 7 days; year → 12 months', () {
      expect(ReportPeriod.week(DateTime(2026, 10, 2)).bucketStarts.length, 7);
      final y = ReportPeriod.year(DateTime(2026));
      expect(y.bucketUnit, BucketUnit.month);
      expect(y.bucketStarts, [for (var m = 1; m <= 12; m++) DateTime(2026, m)]);
      expect(y.bucketIndexOf(DateTime(2026, 9, 30)), 8);
    });

    test('custom: days ≤ 31, weeks ≤ 26 weeks, months beyond', () {
      expect(ReportPeriod.custom(DateTime(2026, 1, 1), DateTime(2026, 1, 31)).bucketUnit, BucketUnit.day);
      final weeks = ReportPeriod.custom(DateTime(2026, 9, 3), DateTime(2026, 10, 20)); // Thu → Tue
      expect(weeks.bucketUnit, BucketUnit.week);
      final ws = weeks.bucketStarts;
      expect(ws.first, DateTime(2026, 9, 3)); // partial first week
      expect(ws[1], DateTime(2026, 9, 7)); // then Mondays
      expect(ws.last, DateTime(2026, 10, 19));
      expect(ws.length, 8);
      expect(weeks.bucketIndexOf(DateTime(2026, 9, 6)), 0);
      expect(weeks.bucketIndexOf(DateTime(2026, 9, 7)), 1);
      expect(weeks.bucketIndexOf(DateTime(2026, 10, 20)), 7);

      final months = ReportPeriod.custom(DateTime(2025, 11, 15), DateTime(2026, 10, 2));
      expect(months.bucketUnit, BucketUnit.month);
      final ms = months.bucketStarts;
      expect(ms.first, DateTime(2025, 11, 15));
      expect(ms[1], DateTime(2025, 12));
      expect(ms.last, DateTime(2026, 10));
      expect(ms.length, 12);
      expect(months.bucketIndexOf(DateTime(2025, 11, 30)), 0);
    });
  });

  group('labels (en)', () {
    setUpAll(() => initializeDateFormatting('en'));

    test('month / year / week / custom', () {
      expect(ReportPeriod.month(DateTime(2026, 10)).label('en'), 'October 2026');
      expect(ReportPeriod.year(DateTime(2026)).label('en'), '2026');
      expect(ReportPeriod.week(DateTime(2026, 10, 2)).label('en'), 'Sep 28 – Oct 4, 2026');
      expect(
        ReportPeriod.custom(DateTime(2025, 12, 30), DateTime(2026, 1, 2)).label('en'),
        'Dec 30, 2025 – Jan 2, 2026',
      );
      expect(ReportPeriod.custom(DateTime(2026, 1, 2), DateTime(2026, 1, 2)).label('en'), 'Jan 2, 2026');
    });
  });

  group('ReportPeriodController', () {
    ProviderContainer container(DateTime now) {
      final c = ProviderContainer(overrides: [reportsClockProvider.overrideWithValue(() => now)]);
      addTearDown(c.dispose);
      return c;
    }

    test('starts at the current month and steps', () {
      final c = container(DateTime(2026, 10, 2, 9));
      expect(c.read(reportPeriodProvider), ReportPeriod.month(DateTime(2026, 10)));
      c.read(reportPeriodProvider.notifier).step(-1);
      expect(c.read(reportPeriodProvider).start, DateTime(2026, 9));
    });

    test('switching kind keeps "now" inside the current period, else anchors on its start', () {
      final c = container(DateTime(2026, 10, 2, 9));
      final n = c.read(reportPeriodProvider.notifier);
      n.setKind(PeriodKind.week);
      expect(c.read(reportPeriodProvider).start, DateTime(2026, 9, 28));
      n.setKind(PeriodKind.month);
      n.step(-3); // July 2026
      n.setKind(PeriodKind.week);
      expect(c.read(reportPeriodProvider).start, DateTime(2026, 6, 29)); // week of Jul 1
      n.setKind(PeriodKind.year);
      expect(c.read(reportPeriodProvider), ReportPeriod.year(DateTime(2026)));
    });

    test('custom range', () {
      final c = container(DateTime(2026, 10, 2));
      c.read(reportPeriodProvider.notifier).setCustom(DateTime(2026, 9, 1), DateTime(2026, 9, 14));
      final p = c.read(reportPeriodProvider);
      expect(p.kind, PeriodKind.custom);
      expect(p.dayCount, 14);
    });
  });
}
