import 'package:flutter/material.dart';

/// Semantic colours that Material's [ColorScheme] does not cover.
///
/// Read them with `Theme.of(context).extension<ZhangColors>()!` or the
/// shorter `context.zhangColors` (see [ZhangColorsX]).
///
/// * [expense] / [expenseContainer]: money going out (red-ish).
/// * [income] / [incomeContainer]: money coming in (green-ish).
/// * [neutral]: zero amounts, transfers, equity movements.
@immutable
class ZhangColors extends ThemeExtension<ZhangColors> {
  const ZhangColors({
    required this.expense,
    required this.onExpenseContainer,
    required this.expenseContainer,
    required this.income,
    required this.onIncomeContainer,
    required this.incomeContainer,
    required this.neutral,
    required this.warning,
  });

  final Color expense;
  final Color expenseContainer;
  final Color onExpenseContainer;
  final Color income;
  final Color incomeContainer;
  final Color onIncomeContainer;
  final Color neutral;
  final Color warning;

  static const light = ZhangColors(
    expense: Color(0xFFC62828),
    expenseContainer: Color(0xFFFFDAD6),
    onExpenseContainer: Color(0xFF410002),
    income: Color(0xFF2E7D32),
    incomeContainer: Color(0xFFC8F0C6),
    onIncomeContainer: Color(0xFF002204),
    neutral: Color(0xFF5F6368),
    warning: Color(0xFFB26A00),
  );

  static const dark = ZhangColors(
    expense: Color(0xFFFF8A80),
    expenseContainer: Color(0xFF93000A),
    onExpenseContainer: Color(0xFFFFDAD6),
    income: Color(0xFF81C784),
    incomeContainer: Color(0xFF1B5E20),
    onIncomeContainer: Color(0xFFC8F0C6),
    neutral: Color(0xFFBDC1C6),
    warning: Color(0xFFFFB74D),
  );

  @override
  ZhangColors copyWith({
    Color? expense,
    Color? expenseContainer,
    Color? onExpenseContainer,
    Color? income,
    Color? incomeContainer,
    Color? onIncomeContainer,
    Color? neutral,
    Color? warning,
  }) {
    return ZhangColors(
      expense: expense ?? this.expense,
      expenseContainer: expenseContainer ?? this.expenseContainer,
      onExpenseContainer: onExpenseContainer ?? this.onExpenseContainer,
      income: income ?? this.income,
      incomeContainer: incomeContainer ?? this.incomeContainer,
      onIncomeContainer: onIncomeContainer ?? this.onIncomeContainer,
      neutral: neutral ?? this.neutral,
      warning: warning ?? this.warning,
    );
  }

  @override
  ZhangColors lerp(ThemeExtension<ZhangColors>? other, double t) {
    if (other is! ZhangColors) return this;
    return ZhangColors(
      expense: Color.lerp(expense, other.expense, t)!,
      expenseContainer: Color.lerp(expenseContainer, other.expenseContainer, t)!,
      onExpenseContainer:
          Color.lerp(onExpenseContainer, other.onExpenseContainer, t)!,
      income: Color.lerp(income, other.income, t)!,
      incomeContainer: Color.lerp(incomeContainer, other.incomeContainer, t)!,
      onIncomeContainer:
          Color.lerp(onIncomeContainer, other.onIncomeContainer, t)!,
      neutral: Color.lerp(neutral, other.neutral, t)!,
      warning: Color.lerp(warning, other.warning, t)!,
    );
  }
}

extension ZhangColorsX on BuildContext {
  /// The [ZhangColors] of the current theme (falls back to the light palette
  /// when a widget is pumped without the app theme, e.g. in tests).
  ZhangColors get zhangColors =>
      Theme.of(this).extension<ZhangColors>() ?? ZhangColors.light;
}
