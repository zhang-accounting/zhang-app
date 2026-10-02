import 'package:flutter_test/flutter_test.dart';
import 'package:zhang_app/core/utils/dates.dart';

void main() {
  group('ZhangDates', () {
    test('parses naive ledger datetimes as wall-clock local time', () {
      final dt = ZhangDates.parseNaive('2023-09-16T21:56:16');
      expect(dt.isUtc, isFalse);
      expect([dt.year, dt.month, dt.day, dt.hour, dt.minute, dt.second], [2023, 9, 16, 21, 56, 16]);
    });

    test('accepts fractional seconds leniently', () {
      final dt = ZhangDates.parseNaive('2023-09-16T21:56:16.123456');
      expect(dt.second, 16);
      expect(dt.millisecond, 123);
    });

    test('tryParseNaive returns null for junk', () {
      expect(ZhangDates.tryParseNaive('nope'), isNull);
      expect(ZhangDates.tryParseNaive(null), isNull);
    });

    test('parses naive UTC echoes and Z echoes as the same instant', () {
      final a = ZhangDates.parseNaiveUtc('2023-08-31T15:00:00');
      final b = ZhangDates.parseNaiveUtc('2023-08-31T15:00:00Z');
      expect(a.isUtc, isTrue);
      expect(a, b);
      expect(a.toIso8601String(), '2023-08-31T15:00:00.000Z');
    });

    test('date-only and epoch seconds', () {
      expect(ZhangDates.parseDate('2023-09-06'), DateTime(2023, 9, 6));
      expect(
        ZhangDates.fromEpochSeconds(1694354400).toIso8601String(),
        '2023-09-10T14:00:00.000Z',
      );
    });

    test('toRfc3339 emits UTC with Z and second precision', () {
      final utc = DateTime.utc(2026, 10, 2, 9, 30, 0, 123);
      expect(ZhangDates.toRfc3339(utc), '2026-10-02T09:30:00Z');
      final local = DateTime(2023, 9, 1);
      expect(ZhangDates.toRfc3339(local), ZhangDates.toRfc3339(local.toUtc()));
      expect(ZhangDates.toRfc3339(local).endsWith('Z'), isTrue);
    });

    test('naive / iso date formatting and month bounds', () {
      final dt = DateTime(2023, 2, 5, 7, 8, 9);
      expect(ZhangDates.toIsoDate(dt), '2023-02-05');
      expect(ZhangDates.toNaiveIso(dt), '2023-02-05T07:08:09');
      expect(ZhangDates.startOfMonth(dt), DateTime(2023, 2));
      expect(ZhangDates.endOfMonth(dt), DateTime(2023, 2, 28, 23, 59, 59));
    });
  });
}
