import 'package:decimal/decimal.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/models/amount.dart';
import '../../data/models/journal.dart';
import '../../data/models/pageable.dart';
import '../../data/models/statistic.dart';
import '../../data/repositories/journal_repository.dart';
import '../../data/repositories/ledger_revision.dart';
import '../journals/journal_providers.dart' show browseRetry;
import '../journals/year_month.dart';

/// Number of rows in Home's "recent transactions".
const homeRecentCount = 10;

/// Month shown by the Home summary card (defaults to the current month).
final homeMonthProvider = NotifierProvider<HomeMonthController, YearMonth>(HomeMonthController.new);

class HomeMonthController extends Notifier<YearMonth> {
  @override
  YearMonth build() => YearMonth.now();

  void previous() => state = state.previous;

  /// Moves forward, never past the current month.
  void next() {
    if (canGoNext) state = state.next;
  }

  bool get canGoNext => YearMonth.now().isAfter(state);
}

/// `GET /api/journals?page=1&size=10` – Home always shows the newest items,
/// whatever month the summary card shows.
final homeRecentProvider = FutureProvider<Pageable<JournalItem>>((ref) {
  ref.watch(ledgerRevisionProvider);
  return ref.watch(journalRepositoryProvider).list(const JournalQuery(page: 1, size: homeRecentCount));
}, retry: browseRetry);

/// Figures of the Home summary card in display signs: [expense] and
/// [income] positive when money was spent / earned (the ledger stores income
/// as negative), [net] = income − expense.
@immutable
class HomeSummaryFigures {
  const HomeSummaryFigures({required this.expense, required this.income, required this.net});

  factory HomeSummaryFigures.from(StatisticSummary summary) {
    // Both `calculated` values are in the operating currency.
    final expense = summary.expense.calculated;
    final income = -summary.income.calculated;
    final net = Amount(income.number - expense.number, expense.commodity);
    return HomeSummaryFigures(expense: expense, income: income, net: net);
  }

  final Amount expense;
  final Amount income;
  final Amount net;

  bool get isEmpty => expense.number == Decimal.zero && income.number == Decimal.zero;
}
