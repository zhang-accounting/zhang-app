import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/utils/dates.dart';
import '../api/api_exception.dart';
import '../api/builtin_query_client.dart';
import '../api/zhang_api_client.dart';
import '../models/account.dart';
import '../models/budget.dart';
import 'ledger_repository.dart';

/// Budgets (read-only), from the `budgets.*` built-in queries. A month is
/// given as [year] / [month]; without it the ledger's current month
/// (`ledger.now`) is used.
class BudgetRepository {
  BudgetRepository(this._client);

  final ZhangApiClient _client;

  /// Budgets existing in the month (`budgets.month`).
  Future<List<Budget>> list({int? year, int? month}) async {
    final first = await _month(year, month);
    return _client.builtins.query(
      BuiltinQuery('budgets.month', {'month': first}),
      (r) => [for (final row in r.rows) Budget.fromQueryRow(row)],
    );
  }

  /// One budget in the month with its linked accounts (`budgets.budget` +
  /// `budgets.budget_month`). Throws `ApiNotFound` for unknown names.
  Future<BudgetDetail> get(String name, {int? year, int? month}) async {
    final first = await _month(year, month);
    final detail = await _client.builtins.batch(
      [
        BuiltinQuery('budgets.budget', {'name': name}),
        BuiltinQuery('budgets.budget_month', {'name': name, 'month': first}),
      ],
      (r) {
        final budget = r[0].firstOrNull;
        final inMonth = r[1].firstOrNull;
        return budget == null || inMonth == null ? null : BudgetDetail.fromQueryRows(inMonth, budget);
      },
    );
    if (detail == null) throw ApiNotFound('budget $name not found');
    return detail;
  }

  /// Events (`budgets.events`: `assign` for a `budget-add`, `transfer_out`
  /// with a negative amount / `transfer_in` for the two sides of a
  /// `budget-transfer`) and postings on linked accounts (`budgets.postings`)
  /// of the month, newest first; at the same instant events stay before
  /// postings, each in query order.
  Future<List<BudgetIntervalItem>> interval(String name, int year, int month) {
    final first = BuiltinQuery.date(DateTime(year, month));
    final params = {'name': name, 'month': first};
    return _client.builtins.batch(
      [BuiltinQuery('budgets.events', params), BuiltinQuery('budgets.postings', params)],
      (r) {
        final items = <BudgetIntervalItem>[
          for (final row in r[0].rows) BudgetEvent.fromQueryRow(row),
          for (final row in r[1].rows) BudgetPosting(AccountJournalEntry.fromBudgetPosting(row)),
        ];
        // List.sort is not stable: break ties on the original position.
        final order = List.generate(items.length, (i) => i)
          ..sort((a, b) {
            final byTime = items[b].timestamp.compareTo(items[a].timestamp);
            return byTime != 0 ? byTime : a.compareTo(b);
          });
        return [for (final i in order) items[i]];
      },
    );
  }

  /// `YYYY-MM-01` of the month ([year]/[month] normalised by [DateTime]),
  /// or of the ledger's current month.
  Future<String> _month(int? year, int? month) async {
    if (year != null && month != null) return BuiltinQuery.date(DateTime(year, month));
    final now = await LedgerRepository(_client).now();
    return BuiltinQuery.date(ZhangDates.startOfMonth(DateTime(year ?? now.year, month ?? now.month)));
  }
}

final budgetRepositoryProvider = Provider<BudgetRepository>(
  (ref) => BudgetRepository(ref.watch(zhangApiClientProvider)),
);
