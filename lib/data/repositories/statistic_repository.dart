import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/utils/dates.dart';
import '../api/endpoints.dart';
import '../api/zhang_api_client.dart';
import '../models/account.dart';
import '../models/statistic.dart';

/// `/api/statistic/*`. [from] / [to] are inclusive instants (pass local
/// `DateTime`s, e.g. `ZhangDates.startOfMonth(now)` / `endOfMonth(now)`); they
/// are sent as RFC 3339 UTC.
class StatisticRepository {
  StatisticRepository(this._client);

  final ZhangApiClient _client;

  /// `GET /api/statistic/summary`.
  Future<StatisticSummary> summary(DateTime from, DateTime to) => _client.get(
    ZhangEndpoints.statisticSummary,
    query: _range(from, to),
    decode: StatisticSummary.fromJson,
  );

  /// `GET /api/statistic/graph` (always daily, whatever [interval]).
  Future<StatisticGraph> graph(DateTime from, DateTime to, {GraphInterval interval = GraphInterval.day}) =>
      _client.get(
        ZhangEndpoints.statisticGraph,
        query: {..._range(from, to), 'interval': interval.wire},
        decode: StatisticGraph.fromJson,
      );

  /// `GET /api/statistic/{account_type}` – per-account totals + top 10.
  Future<StatisticRank> rank(AccountType type, DateTime from, DateTime to) => _client.get(
    ZhangEndpoints.statisticRank(type.wire),
    query: _range(from, to),
    decode: StatisticRank.fromJson,
  );

  static Map<String, Object?> _range(DateTime from, DateTime to) => {
    'from': ZhangDates.toRfc3339(from),
    'to': ZhangDates.toRfc3339(to),
  };
}

final statisticRepositoryProvider = Provider<StatisticRepository>(
  (ref) => StatisticRepository(ref.watch(zhangApiClientProvider)),
);
