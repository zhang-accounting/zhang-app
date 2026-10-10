import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/utils/dates.dart';
import '../api/builtin_query_client.dart';
import '../api/endpoints.dart';
import '../api/zhang_api_client.dart';
import '../models/account.dart';
import '../models/statistic.dart';

/// Report figures. [from] / [to] are **ledger dates**, both included (only
/// their wall-clock date is sent, e.g. `YearMonth.start` / `YearMonth.end`).
/// [currency] is the ledger's operating currency (`LedgerOptions`): the
/// server converts every `value` into it.
class StatisticRepository {
  StatisticRepository(this._client);

  final ZhangApiClient _client;

  /// The batch behind [summary]: `report.net_worth`, `report.liabilities`
  /// (as of [to]), `report.flows` and `report.transaction_count`.
  static List<BuiltinQuery> summaryQueries(DateTime from, DateTime to, String currency) {
    final f = BuiltinQuery.date(from);
    final t = BuiltinQuery.date(to);
    return [
      BuiltinQuery('report.net_worth', {'to': t, 'currency': currency}),
      BuiltinQuery('report.liabilities', {'to': t, 'currency': currency}),
      BuiltinQuery('report.flows', {'from': f, 'to': t, 'currency': currency}),
      BuiltinQuery('report.transaction_count', {'from': f, 'to': t}),
    ];
  }

  /// Net worth, liabilities, income, expense and transaction count (one
  /// batch of built-in queries, one consistent read of the ledger).
  Future<StatisticSummary> summary(DateTime from, DateTime to, {required String currency}) =>
      _client.builtins.batch(
        summaryQueries(from, to, currency),
        (r) => StatisticSummary.fromResults(
          r,
          from: ZhangDates.dateOnly(from),
          to: ZhangDates.dateOnly(to),
          currency: currency,
        ),
      );

  /// `GET /api/statistic/graph` with ledger dates; daily by default,
  /// [GraphInterval.week] / [GraphInterval.month] buckets otherwise.
  Future<StatisticGraph> graph(DateTime from, DateTime to, {GraphInterval interval = GraphInterval.day}) =>
      _client.get(
        ZhangEndpoints.statisticGraph,
        query: {'from': ZhangDates.toIsoDate(from), 'to': ZhangDates.toIsoDate(to), 'interval': interval.wire},
        decode: StatisticGraph.fromJson,
      );

  /// Per-account totals (`report.account_totals`) and the largest postings
  /// (`report.top_postings`, ranked by value in [currency]) of [type].
  Future<StatisticRank> rank(AccountType type, DateTime from, DateTime to, {required String currency}) {
    final params = {
      'type': type.wire,
      'from': BuiltinQuery.date(from),
      'to': BuiltinQuery.date(to),
      'currency': currency,
    };
    return _client.builtins.batch(
      [BuiltinQuery('report.account_totals', params), BuiltinQuery('report.top_postings', params)],
      (r) => StatisticRank.fromResults(
        r[0],
        r[1],
        from: ZhangDates.dateOnly(from),
        to: ZhangDates.dateOnly(to),
        currency: currency,
      ),
    );
  }
}

final statisticRepositoryProvider = Provider<StatisticRepository>(
  (ref) => StatisticRepository(ref.watch(zhangApiClientProvider)),
);
