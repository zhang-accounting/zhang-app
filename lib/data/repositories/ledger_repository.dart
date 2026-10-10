import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../api/builtin_query_client.dart';
import '../api/endpoints.dart';
import '../api/zhang_api_client.dart';
import '../models/info.dart';
import '../models/ledger_error.dart';
import '../models/options.dart';
import '../models/pageable.dart';
import 'ledger_revision.dart';

/// Ledger-wide endpoints: info, options, errors, the ledger clock, reload.
class LedgerRepository {
  LedgerRepository(this._client, {this._onMutated});

  final ZhangApiClient _client;
  final OnLedgerMutated? _onMutated;

  /// `GET /api/info`.
  Future<ServerInfo> info() => _client.info();

  /// `GET /api/options`.
  Future<LedgerOptions> options() =>
      _client.get(ZhangEndpoints.options, decode: LedgerOptions.fromJson);

  /// Ledger errors (built-in `journals.errors` with `count_total`), 1-based
  /// [page] of [size] (1–1000) items; `totalCount` counts all errors.
  Future<Pageable<LedgerError>> errors({int page = 1, int size = 100}) {
    final p = page < 1 ? 1 : page;
    final s = size.clamp(1, 1000);
    return _client.builtins.query(
      BuiltinQuery('journals.errors', {'size': s, 'offset': (p - 1) * s}, true),
      (r) {
        final total = r.total ?? r.rows.length;
        return Pageable(
          totalCount: total,
          totalPage: total == 0 ? 0 : (total + s - 1) ~/ s,
          pageSize: s,
          currentPage: p,
          records: [for (final row in r.rows) LedgerError.fromQueryRow(row)],
        );
      },
    );
  }

  /// The ledger's current wall-clock time in its own timezone (built-in
  /// `ledger.now`), as a naive local [DateTime].
  Future<DateTime> now() =>
      _client.builtins.query(const BuiltinQuery('ledger.now'), (r) => r.rows.first.dateTime('date', 'time'));

  /// `POST /api/reload` – reload the ledger now. Answers once the reload is
  /// done; a failing reload is `ApiServerError(409, reason)`. Bumps
  /// `ledgerRevisionProvider` afterwards.
  Future<void> reload() async {
    await _client.send('POST', ZhangEndpoints.reload);
    _onMutated?.call();
  }
}

final ledgerRepositoryProvider = Provider<LedgerRepository>(
  (ref) => LedgerRepository(
    ref.watch(zhangApiClientProvider),
    onMutated: () => ref.read(ledgerRevisionProvider.notifier).bumpAfterWrite(),
  ),
);
