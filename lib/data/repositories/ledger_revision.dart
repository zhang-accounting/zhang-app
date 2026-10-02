import 'package:flutter_riverpod/flutter_riverpod.dart';

/// A counter that every server-data provider should `ref.watch` so it can be
/// refetched in one go:
///
/// ```dart
/// final accountsProvider = FutureProvider<List<Account>>((ref) {
///   ref.watch(ledgerRevisionProvider);
///   return ref.watch(accountRepositoryProvider).list();
/// });
/// ```
///
/// Repositories bump it automatically after successful writes (with a short
/// delay because the server reloads asynchronously, docs §1.7). Bump it
/// manually for pull-to-refresh, or when an SSE `Reload` event arrives.
final ledgerRevisionProvider = NotifierProvider<LedgerRevision, int>(LedgerRevision.new);

class LedgerRevision extends Notifier<int> {
  /// How long to wait after a write before refetching.
  static const writeSettleDelay = Duration(milliseconds: 600);

  @override
  int build() => 0;

  /// Refetch now.
  void bump() => state = state + 1;

  /// Refetch after the server had time to reload the ledger.
  Future<void> bumpAfterWrite([Duration delay = writeSettleDelay]) async {
    await Future<void>.delayed(delay);
    if (ref.mounted) bump();
  }
}

/// Called by repositories after a successful mutation.
typedef OnLedgerMutated = void Function();
