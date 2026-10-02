import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../api/endpoints.dart';
import '../api/zhang_api_client.dart';
import '../models/commodity.dart';
import '../models/json_utils.dart';

/// Commodities (currencies, stocks, crypto…).
class CommodityRepository {
  CommodityRepository(this._client);

  final ZhangApiClient _client;

  /// `GET /api/commodities`, sorted by name.
  Future<List<Commodity>> list() => _client.get(
    ZhangEndpoints.commodities,
    decode: (d) => parseList(d, Commodity.fromJson, 'commodities')..sort((a, b) => a.name.compareTo(b.name)),
  );

  /// `GET /api/commodities/{name}`. Only pass names returned by [list]: the
  /// server handler crashes (connection closed) on unknown names.
  Future<CommodityDetail> get(String name) =>
      _client.get(ZhangEndpoints.commodity(name), decode: CommodityDetail.fromJson);
}

final commodityRepositoryProvider = Provider<CommodityRepository>(
  (ref) => CommodityRepository(ref.watch(zhangApiClientProvider)),
);
