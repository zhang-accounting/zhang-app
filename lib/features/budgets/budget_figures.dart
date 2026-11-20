import 'package:decimal/decimal.dart';
import 'package:flutter/foundation.dart';

import '../../data/models/budget.dart';

/// How a budget stands in a month (design §2.9): the available amount is
/// the main reading.
enum BudgetHealth {
  /// Available is negative: more was spent than assigned.
  over,

  /// Less than [budgetLowShare] of the assigned money is left.
  low,

  /// Enough left (or nothing assigned and nothing spent).
  ok,
}

/// Share of the assigned money under which a budget counts as running low.
final budgetLowShare = Decimal.parse('0.2');

extension BudgetFigures on Budget {
  BudgetHealth get health {
    final available = availableAmount.number;
    if (available < Decimal.zero) return BudgetHealth.over;
    final assigned = assignedAmount.number;
    if (assigned <= Decimal.zero) return BudgetHealth.ok;
    return available < assigned * budgetLowShare ? BudgetHealth.low : BudgetHealth.ok;
  }

  /// Activity / assigned, clamped to 0…1: full whenever the budget is over
  /// (also when the overspending was carried over from last month), 0 for
  /// refunds.
  double get progress {
    if (availableAmount.number < Decimal.zero) return 1;
    final assigned = assignedAmount.number;
    final activity = activityAmount.number;
    if (activity <= Decimal.zero) return 0;
    if (assigned <= Decimal.zero) return 1;
    return (activity / assigned).toDouble().clamp(0, 1);
  }

  /// Available / assigned, for ordering the budgets that run low.
  double get availableShare {
    final assigned = assignedAmount.number;
    if (assigned <= Decimal.zero) return 0;
    return (availableAmount.number / assigned).toDouble();
  }
}

/// Order inside a group (design §2.9): open before closed; over budget first
/// (most overspent first), then the ones running low (least left first),
/// then the rest by name.
int compareBudgets(Budget a, Budget b) {
  if (a.closed != b.closed) return a.closed ? 1 : -1;
  final byHealth = a.health.index.compareTo(b.health.index);
  if (byHealth != 0) return byHealth;
  final byFigure = switch (a.health) {
    BudgetHealth.over => a.availableAmount.number.compareTo(b.availableAmount.number),
    BudgetHealth.low => a.availableShare.compareTo(b.availableShare),
    BudgetHealth.ok => 0,
  };
  if (byFigure != 0) return byFigure;
  return a.displayName.toLowerCase().compareTo(b.displayName.toLowerCase());
}

/// Budgets of one `category` meta ([category] `null` = uncategorized).
@immutable
class BudgetGroup {
  const BudgetGroup(this.category, this.budgets);

  final String? category;
  final List<Budget> budgets;
}

/// Groups [budgets] by category (named categories alphabetically,
/// uncategorized last), each group sorted with [compareBudgets].
List<BudgetGroup> groupBudgets(List<Budget> budgets) {
  final byCategory = <String?, List<Budget>>{};
  for (final b in budgets) {
    final category = b.category?.trim();
    byCategory.putIfAbsent(category == null || category.isEmpty ? null : category, () => []).add(b);
  }
  final keys = byCategory.keys.toList()
    ..sort((a, b) {
      if (a == null) return b == null ? 0 : 1;
      if (b == null) return -1;
      return a.toLowerCase().compareTo(b.toLowerCase());
    });
  return [for (final k in keys) BudgetGroup(k, byCategory[k]!..sort(compareBudgets))];
}

/// Month totals of one currency.
@immutable
class BudgetTotals {
  const BudgetTotals({
    required this.currency,
    required this.assigned,
    required this.activity,
    required this.available,
    required this.overCount,
  });

  final String currency;
  final Decimal assigned;
  final Decimal activity;
  final Decimal available;

  /// Budgets of this currency over budget.
  final int overCount;
}

/// Totals per currency (in order of first appearance). Like zhang's web UI,
/// a closed budget is listed but no longer counts.
List<BudgetTotals> budgetTotals(List<Budget> budgets) {
  final out = <String, BudgetTotals>{};
  for (final b in budgets) {
    if (b.closed) continue;
    final currency = b.assignedAmount.commodity;
    final t = out[currency];
    out[currency] = BudgetTotals(
      currency: currency,
      assigned: (t?.assigned ?? Decimal.zero) + b.assignedAmount.number,
      activity: (t?.activity ?? Decimal.zero) + b.activityAmount.number,
      available: (t?.available ?? Decimal.zero) + b.availableAmount.number,
      overCount: (t?.overCount ?? 0) + (b.health == BudgetHealth.over ? 1 : 0),
    );
  }
  return out.values.toList();
}
