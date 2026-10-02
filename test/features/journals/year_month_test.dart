import 'package:flutter_test/flutter_test.dart';
import 'package:zhang_app/core/utils/dates.dart';
import 'package:zhang_app/features/journals/year_month.dart';

void main() {
  group('YearMonth (summary month-range math)', () {
    test('range covers the whole month, inclusive end at 23:59:59', () {
      final m = YearMonth(2023, 9);
      expect(m.start, DateTime(2023, 9, 1));
      expect(m.end, DateTime(2023, 9, 30, 23, 59, 59));
    });

    test('february in leap and non-leap years', () {
      expect(YearMonth(2024, 2).end, DateTime(2024, 2, 29, 23, 59, 59));
      expect(YearMonth(2023, 2).end, DateTime(2023, 2, 28, 23, 59, 59));
    });

    test('december rolls into the next year', () {
      final dec = YearMonth(2026, 12);
      expect(dec.end, DateTime(2026, 12, 31, 23, 59, 59));
      expect(dec.next, YearMonth(2027, 1));
      expect(YearMonth(2027, 1).previous, dec);
    });

    test('out-of-range months are normalised', () {
      expect(YearMonth(2026, 13), YearMonth(2027, 1));
      expect(YearMonth(2026, 0), YearMonth(2025, 12));
      expect(YearMonth(2026, -11), YearMonth(2025, 1));
    });

    test('of() / contains() use wall-clock fields', () {
      final m = YearMonth.of(DateTime(2023, 9, 30, 23, 59, 59));
      expect(m, YearMonth(2023, 9));
      expect(m.contains(DateTime(2023, 9, 1)), isTrue);
      expect(m.contains(DateTime(2023, 10, 1)), isFalse);
    });

    test('ordering', () {
      expect(YearMonth(2024, 1).isAfter(YearMonth(2023, 12)), isTrue);
      expect(YearMonth(2023, 12).compareTo(YearMonth(2023, 12)), 0);
      final list = [YearMonth(2023, 2), YearMonth(2022, 12), YearMonth(2023, 1)]..sort();
      expect(list, [YearMonth(2022, 12), YearMonth(2023, 1), YearMonth(2023, 2)]);
    });

    test('matches ZhangDates month helpers and is sent as UTC', () {
      final now = DateTime(2026, 10, 2, 18, 30);
      final m = YearMonth.of(now);
      expect(m.start, ZhangDates.startOfMonth(now));
      expect(m.end, ZhangDates.endOfMonth(now));
      expect(ZhangDates.toRfc3339(m.start), endsWith('Z'));
    });
  });
}
