import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../api/endpoints.dart';
import '../api/zhang_api_client.dart';
import '../models/info.dart';
import '../models/ledger_error.dart';
import '../models/options.dart';
import '../models/pageable.dart';
import 'ledger_revision.dart';

/// Ledger-wide endpoints: info, options, errors, reload.
class LedgerRepository {
  LedgerRepository(this._client, {this._onMutated});

  final ZhangApiClient _client;
  final OnLedgerMutated? _onMutated;

  /// `GET /api/info`.
  Future<ServerInfo> info() => _client.info();

  /// `GET /api/options`.
  Future<LedgerOptions> options() =>
      _client.get(ZhangEndpoints.options, decode: LedgerOptions.fromJson);

  /// `GET /api/errors` (1-based [page]; [size] must be > 0 – 0 crashes the
  /// server handler).
  Future<Pageable<LedgerError>> errors({int page = 1, int size = 100}) => _client.get(
    ZhangEndpoints.errors,
    query: {'page': page < 1 ? 1 : page, 'size': size < 1 ? 1 : size},
    decode: (d) => Pageable.fromJson(d, LedgerError.fromJson),
  );

  /// `POST /api/reload` – queue a full ledger reload (completion is only
  /// signalled via SSE). Bumps `ledgerRevisionProvider` afterwards.
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
