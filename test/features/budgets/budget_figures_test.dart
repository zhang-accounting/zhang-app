import 'package:decimal/decimal.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:zhang_app/data/models/amount.dart';
import 'package:zhang_app/data/models/budget.dart';
import 'package:zhang_app/features/budgets/budget_figures.dart';

Budget _budget(
  String name, {
  required String assigned,
  required String activity,
  String? available,
  String? category,
  bool closed = false,
  String currency = 'CNY',
}) {
  final a = Decimal.parse(assigned);
  final s = Decimal.parse(activity);
  return Budget(
    name: name,
    category: category,
    closed: closed,
    assignedAmount: Amount(a, currency),
    activityAmount: Amount(s, currency),
    availableAmount: Amount(available == null ? a - s : Decimal.parse(available), currency),
  );
}

void main() {
  test('health: over below zero, low under 20 % left, ok otherwise', () {
    expect(_budget('a', assigned: '100', activity: '150').health, BudgetHealth.over);
    expect(_budget('a', assigned: '100', activity: '81').health, BudgetHealth.low);
    expect(_budget('a', assigned: '100', activity: '100').health, BudgetHealth.low);
    expect(_budget('a', assigned: '100', activity: '80').health, BudgetHealth.ok);
    expect(_budget('a', assigned: '0', activity: '0').health, BudgetHealth.ok);
    expect(_budget('a', assigned: '0', activity: '5').health, BudgetHealth.over);
  });

  test('progress is activity / assigned, clamped', () {
    expect(_budget('a', assigned: '1000', activity: '88.50').progress, closeTo(0.0885, 1e-9));
    expect(_budget('a', assigned: '100', activity: '150').progress, 1);
    expect(_budget('a', assigned: '0', activity: '5').progress, 1);
    expect(_budget('a', assigned: '100', activity: '-5').progress, 0);
    expect(_budget('a', assigned: '0', activity: '0').progress, 0);
  });

  test('groups by category, uncategorized last; over first, then low, then by name; closed last', () {
    final groups = groupBudgets([
      _budget('zoo', assigned: '100', activity: '0', category: 'Fun'),
      _budget('rent', assigned: '100', activity: '0'),
      _budget('food', assigned: '100', activity: '90', category: 'Daily'),
      _budget('bus', assigned: '100', activity: '10', category: 'Daily'),
      _budget('cafe', assigned: '100', activity: '130', category: 'Daily'),
      _budget('gym', assigned: '100', activity: '200', category: 'Daily'),
      _budget('old', assigned: '100', activity: '500', category: 'Daily', closed: true),
      _budget('art', assigned: '100', activity: '95', category: 'Daily'),
      _budget('tax', assigned: '100', activity: '0', category: ' '),
    ]);
    expect([for (final g in groups) g.category], ['Daily', 'Fun', null]);
    expect([for (final b in groups[0].budgets) b.name], ['gym', 'cafe', 'art', 'food', 'bus', 'old']);
    expect([for (final b in groups[2].budgets) b.name], ['rent', 'tax']);
  });

  test('totals per currency skip closed budgets and count the ones over', () {
    final totals = budgetTotals([
      _budget('food', assigned: '1000', activity: '88.50'),
      _budget('cafe', assigned: '100', activity: '130'),
      _budget('old', assigned: '100', activity: '0', closed: true),
      _budget('trip', assigned: '50', activity: '10', currency: 'USD'),
    ]);
    expect(totals, hasLength(2));
    expect(totals[0].currency, 'CNY');
    expect(totals[0].assigned, Decimal.parse('1100'));
    expect(totals[0].activity, Decimal.parse('218.50'));
    expect(totals[0].available, Decimal.parse('881.50'));
    expect(totals[0].overCount, 1);
    expect(totals[1].currency, 'USD');
    expect(totals[1].available, Decimal.parse('40'));
  });
}
