import 'package:decimal/decimal.dart';
import 'package:flutter/foundation.dart';

/// `+` / `−` keys of the amount keypad.
enum AmountOperator {
  plus('+'),
  minus('−');

  const AmountOperator(this.symbol);

  /// Display symbol (`−` is U+2212, docs/design-research.md §3.3).
  final String symbol;
}

/// The amount typed on the calculator keypad (docs/design-research.md §2.5):
/// positive numbers joined by `+` / `−`, evaluated exactly with [Decimal].
///
/// Immutable: every input method returns a new expression, or `this` when the
/// key is rejected (too many decimals, a leading operator, …) so callers can
/// detect rejections with `identical(next, current)` and give feedback.
@immutable
class AmountExpression {
  const AmountExpression._(this.tokens);

  static const empty = AmountExpression._([]);

  /// Expression holding a single number (e.g. an amount hint).
  factory AmountExpression.number(Decimal value) => AmountExpression._([value.toString()]);

  /// Max digits before the decimal point (guards against stray taps).
  static const maxIntegerDigits = 12;

  /// Alternating number / operator tokens. Numbers are digit strings that may
  /// end with `.` while typing; only the first number can be negative (the
  /// result of evaluating `3 − 5`). Operators are [AmountOperator.symbol]s.
  final List<String> tokens;

  bool get isEmpty => tokens.isEmpty;

  /// The expression contains an operator, i.e. it is an unfinished
  /// calculation: the save key shows `=` until it is evaluated.
  bool get hasOperator => tokens.any(_isOperator);

  static bool _isOperator(String token) =>
      token == AmountOperator.plus.symbol || token == AmountOperator.minus.symbol;

  /// The number currently being typed, or `''` after an operator / when empty.
  String get _current => tokens.isEmpty || _isOperator(tokens.last) ? '' : tokens.last;

  AmountExpression _withCurrent(String number) {
    final next = [...tokens];
    if (_current.isEmpty) {
      next.add(number);
    } else {
      next[next.length - 1] = number;
    }
    return AmountExpression._(List.unmodifiable(next));
  }

  /// Appends digit [digit] (0–9). Rejected when the current number already
  /// has [precision] decimals or [maxIntegerDigits] integer digits. A lone
  /// leading `0` is replaced (`0` then `5` → `5`).
  AmountExpression inputDigit(int digit, {required int precision}) {
    assert(digit >= 0 && digit <= 9);
    final current = _current;
    final dot = current.indexOf('.');
    if (dot >= 0) {
      if (current.length - dot - 1 >= precision) return this;
      return _withCurrent('$current$digit');
    }
    final unsigned = current.startsWith('-') ? current.substring(1) : current;
    if (unsigned == '0') {
      if (digit == 0) return this;
      return _withCurrent('${current.substring(0, current.length - 1)}$digit');
    }
    if (unsigned.length >= maxIntegerDigits) return this;
    return _withCurrent('$current$digit');
  }

  /// Appends the decimal point (`.` on an empty number becomes `0.`).
  /// Rejected for zero-precision commodities or when there already is one.
  AmountExpression inputDot({required int precision}) {
    if (precision <= 0) return this;
    final current = _current;
    if (current.contains('.')) return this;
    return _withCurrent(current.isEmpty || current == '-' ? '${current}0.' : '$current.');
  }

  /// Appends an operator; replaces a trailing one. Rejected on an empty
  /// expression (amounts are typed as positives, the mode gives the sign).
  AmountExpression inputOperator(AmountOperator op) {
    if (tokens.isEmpty) return this;
    final next = [...tokens];
    if (_isOperator(next.last)) {
      next[next.length - 1] = op.symbol;
    } else {
      next.add(op.symbol);
    }
    return AmountExpression._(List.unmodifiable(next));
  }

  /// Deletes the last character (or the trailing operator).
  AmountExpression backspace() {
    if (tokens.isEmpty) return this;
    final next = [...tokens];
    final last = next.removeLast();
    if (!_isOperator(last)) {
      final shorter = last.substring(0, last.length - 1);
      if (shorter.isNotEmpty && shorter != '-') next.add(shorter);
    }
    return AmountExpression._(List.unmodifiable(next));
  }

  /// Exact value of the expression (a trailing operator is ignored), or
  /// `null` when nothing was typed.
  Decimal? get value {
    if (tokens.isEmpty) return null;
    var sum = Decimal.zero;
    var negate = false;
    for (final token in tokens) {
      if (_isOperator(token)) {
        negate = token == AmountOperator.minus.symbol;
        continue;
      }
      final number = _parse(token);
      sum = negate ? sum - number : sum + number;
    }
    return sum;
  }

  static Decimal _parse(String token) {
    final t = token.endsWith('.') ? token.substring(0, token.length - 1) : token;
    return Decimal.parse(t.isEmpty || t == '-' ? '0' : t);
  }

  /// Replaces the calculation with its result (the `=` key).
  AmountExpression evaluate() {
    final v = value;
    if (v == null || !hasOperator) return this;
    return AmountExpression._(List.unmodifiable([v.toString()]));
  }

  /// Human-readable expression, e.g. `12 + 3.5`.
  String get display => tokens.join(' ');

  @override
  bool operator ==(Object other) => other is AmountExpression && listEquals(other.tokens, tokens);

  @override
  int get hashCode => Object.hashAll(tokens);

  @override
  String toString() => 'AmountExpression($display)';
}
