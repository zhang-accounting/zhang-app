import 'package:decimal/decimal.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:zhang_app/features/transaction_new/amount_expression.dart';

const _plus = AmountOperator.plus;
const _minus = AmountOperator.minus;

/// Types [keys] ('0'-'9', '.', '+', '-') with [precision] decimals allowed.
AmountExpression _type(String keys, {int precision = 2, AmountExpression start = AmountExpression.empty}) {
  var e = start;
  for (final k in keys.split('')) {
    e = switch (k) {
      '.' => e.inputDot(precision: precision),
      '+' => e.inputOperator(_plus),
      '-' => e.inputOperator(_minus),
      _ => e.inputDigit(int.parse(k), precision: precision),
    };
  }
  return e;
}

Decimal d(String s) => Decimal.parse(s);

void main() {
  group('AmountExpression', () {
    test('12+3.5 shows the expression, evaluates exactly and needs "="', () {
      final e = _type('12+3.5');
      expect(e.display, '12 + 3.5');
      expect(e.hasOperator, isTrue);
      expect(e.value, d('15.5'));
      final evaluated = e.evaluate();
      expect(evaluated.hasOperator, isFalse);
      expect(evaluated.tokens, ['15.5']);
      expect(evaluated.value, d('15.5'));
    });

    test('decimal maths is exact (no binary floating point)', () {
      expect(_type('0.1+0.2').value, d('0.3'));
      expect(_type('100-0.01-0.01').value, d('99.98'));
      expect(_type('3-5').evaluate().value, d('-2'));
    });

    test('decimals are capped at the commodity precision', () {
      final e = _type('1.239', precision: 2);
      expect(e.tokens, ['1.23']);
      final rejected = e.inputDigit(9, precision: 2);
      expect(identical(rejected, e), isTrue, reason: 'rejected keys return the same instance');
      expect(_type('7.12345678', precision: 8).value, d('7.12345678'));
      expect(_type('7.123456789', precision: 8).value, d('7.12345678'));
    });

    test('precision 0 rejects the decimal point', () {
      final e = _type('5', precision: 0);
      expect(identical(e.inputDot(precision: 0), e), isTrue);
      expect(_type('5.3', precision: 0).tokens, ['53']);
    });

    test('leading dot becomes 0., double dots are ignored, leading zero is replaced', () {
      expect(_type('.5').tokens, ['0.5']);
      expect(_type('1..2').tokens, ['1.2']);
      expect(_type('05').tokens, ['5']);
      expect(_type('00').tokens, ['0']);
      expect(_type('0.05').value, d('0.05'));
      expect(_type('1+.5').display, '1 + 0.5');
    });

    test('integer part is capped at 12 digits', () {
      final e = _type('1234567890123');
      expect(e.tokens, ['123456789012']);
    });

    test('operators: no leading operator, a second operator replaces the first', () {
      expect(_type('+').isEmpty, isTrue);
      expect(_type('-5').tokens, ['5']);
      final e = _type('12+-');
      expect(e.display, '12 −');
      expect(e.value, d('12'), reason: 'a trailing operator is ignored');
    });

    test('backspace removes characters, then operators, then numbers', () {
      var e = _type('12+3.');
      e = e.backspace();
      expect(e.display, '12 + 3');
      e = e.backspace();
      expect(e.display, '12 +');
      e = e.backspace();
      expect(e.display, '12');
      e = e.backspace().backspace();
      expect(e.isEmpty, isTrue);
      expect(e.value, isNull);
      expect(identical(e.backspace(), e), isTrue);
    });

    test('evaluate without an operator is a no-op; number() seeds a value', () {
      final e = _type('42');
      expect(identical(e.evaluate(), e), isTrue);
      final seeded = AmountExpression.number(d('98.5'));
      expect(seeded.value, d('98.5'));
      expect(seeded.inputDigit(1, precision: 2).value, d('98.51'));
    });

    test('equality is by tokens', () {
      expect(_type('1+2'), _type('1+2'));
      expect(_type('1+2').hashCode, _type('1+2').hashCode);
      expect(_type('1+2') == _type('1-2'), isFalse);
    });
  });
}
