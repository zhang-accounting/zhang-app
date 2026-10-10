import 'package:flutter/foundation.dart';

import '../../core/utils/dates.dart';
import '../models/json_utils.dart';
import '../models/query_result.dart';
import 'endpoints.dart';
import 'zhang_api_client.dart';

/// One built-in query call: its [name] (see `GET /api/query/builtins`) and
/// every parameter by name. Dates are ledger dates `YYYY-MM-DD` (use
/// [BuiltinQuery.date]); `set` parameters are string lists.
@immutable
class BuiltinQuery {
  const BuiltinQuery(this.name, [this.params = const {}, this.countTotal = false]);

  final String name;
  final Map<String, Object?> params;

  /// Ask for `total` (rows before `LIMIT`/`OFFSET`).
  final bool countTotal;

  /// A `date` parameter: the wall-clock date of [value].
  static String date(DateTime value) => ZhangDates.toIsoDate(value);

  /// Body of `POST /api/query/builtins/{name}`.
  Map<String, Object?> toRunJson() => {'params': params, if (countTotal) 'count_total': true};

  /// Element of the batch body `POST /api/query/builtins`.
  Map<String, Object?> toBatchJson() => {'name': name, ...toRunJson()};

  @override
  String toString() => 'BuiltinQuery($name, $params)';
}

/// Runs zhang's built-in BQL queries (zhang ≥ 0.2), which replaced the
/// typed report / error / budget / document endpoints.
///
/// Errors arrive as the usual `ZhangApiException`s: an unknown query name is
/// `ApiNotFound` (`there is no built-in query x`), a missing or mistyped
/// parameter `ApiServerError(400, 'parameter :to of report.flows is missing')`.
class BuiltinQueryClient {
  const BuiltinQueryClient(this._client);

  final ZhangApiClient _client;

  /// `POST /api/query/builtins/{name}`.
  Future<QueryResult> run(BuiltinQuery query) => _client.post(
    ZhangEndpoints.builtinQuery(query.name),
    body: query.toRunJson(),
    decode: QueryResult.fromJson,
  );

  /// `POST /api/query/builtins`: several queries over **one** read of the
  /// ledger (consistent figures); results in request order. One failing
  /// query fails the whole batch.
  Future<List<QueryResult>> runBatch(List<BuiltinQuery> queries) => _client.post(
    ZhangEndpoints.builtinQueries,
    body: [for (final q in queries) q.toBatchJson()],
    decode: (d) {
      final list = asList(d, 'batch result');
      if (list.length != queries.length) {
        throw FormatException('expected ${queries.length} results, got ${list.length}');
      }
      return [for (final r in list) QueryResult.fromJson(r)];
    },
  );
}

extension BuiltinQueries on ZhangApiClient {
  /// Built-in query access over this client.
  BuiltinQueryClient get builtins => BuiltinQueryClient(this);
}
