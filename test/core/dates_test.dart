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

    test('date-only and epoch seconds', () {
      expect(ZhangDates.parseDate('2023-09-06'), DateTime(2023, 9, 6));
      expect(
        ZhangDates.fromEpochSeconds(1694354400).toIso8601String(),
        '2023-09-10T14:00:00.000Z',
      );
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
