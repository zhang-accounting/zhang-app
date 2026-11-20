import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/models/budget.dart';
import '../../data/repositories/budget_repository.dart';
import '../../data/repositories/ledger_revision.dart';

/// Budgets are read per calendar month; a month is given as local midnight
/// of its first day (`DateTime(year, month)`).

/// The budgets of a month (`budgets.month`).
final budgetsProvider = FutureProvider.autoDispose.family<List<Budget>, DateTime>((ref, month) {
  ref.watch(ledgerRevisionProvider);
  return ref.watch(budgetRepositoryProvider).list(year: month.year, month: month.month);
});

/// One budget in a month with its linked accounts (`budgets.budget` +
/// `budgets.budget_month`); `ApiNotFound` for a budget unknown in that month.
final budgetDetailProvider = FutureProvider.autoDispose.family<BudgetDetail, (String, DateTime)>((ref, arg) {
  ref.watch(ledgerRevisionProvider);
  final (name, month) = arg;
  return ref.watch(budgetRepositoryProvider).get(name, year: month.year, month: month.month);
});

/// Assignments and the postings counted toward a budget in a month, newest
/// first (`budgets.events` + `budgets.postings`).
final budgetIntervalProvider = FutureProvider.autoDispose.family<List<BudgetIntervalItem>, (String, DateTime)>((
  ref,
  arg,
) {
  ref.watch(ledgerRevisionProvider);
  final (name, month) = arg;
  return ref.watch(budgetRepositoryProvider).interval(name, month.year, month.month);
});
