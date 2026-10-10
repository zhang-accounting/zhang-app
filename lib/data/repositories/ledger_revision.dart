import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'ledger_events.dart';

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
/// It is bumped when the server reloads the ledger (SSE `Reload`, see
/// [ledgerEventsProvider]), after successful writes ([bumpAfterWrite]) and
/// for pull-to-refresh ([bump]).
final ledgerRevisionProvider = NotifierProvider<LedgerRevision, int>(LedgerRevision.new);

class LedgerRevision extends Notifier<int> {
  /// Without the event stream: how long to wait after a write before
  /// refetching (the server reloads after answering).
  static const writeSettleDelay = Duration(milliseconds: 600);

  /// With the event stream: refetch anyway if no `Reload` arrived this long
  /// after a write (a lost event).
  static const eventSafetyDelay = Duration(seconds: 5);

  @override
  int build() => 0;

  /// Refetch now.
  void bump() => state = state + 1;

  /// Refetch once the server has reloaded after a write: on its SSE `Reload`
  /// event when the stream is connected (with [eventSafetyDelay] as a safety
  /// net), else after [delay].
  Future<void> bumpAfterWrite([Duration delay = writeSettleDelay]) async {
    final connected = ref.read(ledgerEventsProvider).connected;
    final before = state;
    await Future<void>.delayed(connected ? eventSafetyDelay : delay);
    if (!ref.mounted) return;
    if (connected && state != before) return; // the Reload event refetched
    bump();
  }
}

/// Called by repositories after a successful mutation.
typedef OnLedgerMutated = void Function();
