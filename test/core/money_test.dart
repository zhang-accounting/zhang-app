import 'package:decimal/decimal.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:zhang_app/core/utils/money.dart';

Decimal d(String s) => Decimal.parse(s);

void main() {
  group('formatDecimal', () {
    test('groups thousands and pads to 2 decimals by default', () {
      expect(formatDecimal(d('1234567.5')), '1,234,567.50');
      expect(formatDecimal(d('-21')), '-21.00');
      expect(formatDecimal(d('0')), '0.00');
      expect(formatDecimal(d('999')), '999.00');
      expect(formatDecimal(d('1000')), '1,000.00');
    });

    test('keeps a larger own scale when precision is not given', () {
      expect(formatDecimal(d('1E-8')), '0.00000001');
      expect(formatDecimal(d('-474.229')), '-474.229');
    });

    test('honours explicit precision (rounding) and signed', () {
      expect(formatDecimal(d('-474.229'), precision: 2), '-474.23');
      expect(formatDecimal(d('88.5'), precision: 0), '89');
      expect(formatDecimal(d('88.5'), signed: true), '+88.50');
      expect(formatDecimal(d('-0.001'), precision: 2, signed: true), '0.00');
      expect(formatDecimal(d('1234.5'), grouping: false), '1234.50');
    });

    test('handles huge numbers without double precision loss', () {
      expect(formatDecimal(d('12345678901234567890.12')), '12,345,678,901,234,567,890.12');
    });
  });

  group('formatMoney', () {
    test('commodity suffix by default', () {
      expect(formatMoney(d('-1234.5'), 'CNY'), '-1,234.50 CNY');
      expect(formatMoney(d('0.01'), 'BTC', precision: 8), '0.01000000 BTC');
      expect(formatMoney(d('5'), null), '5.00');
    });

    test('prefix symbol goes after the sign', () {
      expect(formatMoney(d('-1234.5'), 'CNY', prefix: '¥'), '-¥1,234.50');
      expect(formatMoney(d('3'), 'USD', prefix: r'$', signed: true), r'+$3.00');
    });
  });

  group('toneOf', () {
    test('positive / negative / neutral, with invert', () {
      expect(toneOf(d('1')), AmountTone.positive);
      expect(toneOf(d('-1')), AmountTone.negative);
      expect(toneOf(d('0')), AmountTone.neutral);
      expect(toneOf(d('-200'), invert: true), AmountTone.positive);
    });
  });
}
