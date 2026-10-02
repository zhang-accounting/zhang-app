import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../api/endpoints.dart';
import '../api/zhang_api_client.dart';
import '../models/budget.dart';
import '../models/json_utils.dart';

/// Budgets (read-only API).
class BudgetRepository {
  BudgetRepository(this._client);

  final ZhangApiClient _client;

  /// `GET /api/budgets?year&month` – budgets existing in that month
  /// (defaults to the server's current month).
  Future<List<Budget>> list({int? year, int? month}) => _client.get(
    ZhangEndpoints.budgets,
    query: _period(year, month),
    decode: (d) => parseList(d, Budget.fromJson, 'budgets'),
  );

  /// `GET /api/budgets/{name}?year&month` (throws `ApiNotFound`).
  Future<BudgetDetail> get(String name, {int? year, int? month}) => _client.get(
    ZhangEndpoints.budget(name),
    query: _period(year, month),
    decode: (d) => BudgetDetail.fromJson(asMap(d, 'budget')),
  );

  /// `GET /api/budgets/{name}/interval/{year}/{month}` – events and postings,
  /// newest first. Unknown item types are skipped.
  Future<List<BudgetIntervalItem>> interval(String name, int year, int month) {
    _checkMonth(month);
    return _client.get(
      ZhangEndpoints.budgetInterval(name, year, month),
      decode: (d) => [
        for (final e in asList(d, 'budget interval'))
          if (const {'BudgetEvent', 'Posting'}.contains(asMap(e)['type']))
            BudgetIntervalItem.fromJson(asMap(e)),
      ],
    );
  }

  static Map<String, Object?> _period(int? year, int? month) {
    if (month != null) _checkMonth(month);
    return {'year': year, 'month': month};
  }

  /// Months outside 1–12 crash the server handler.
  static void _checkMonth(int month) {
    if (month < 1 || month > 12) throw ArgumentError.value(month, 'month', 'must be 1-12');
  }
}

final budgetRepositoryProvider = Provider<BudgetRepository>(
  (ref) => BudgetRepository(ref.watch(zhangApiClientProvider)),
);
