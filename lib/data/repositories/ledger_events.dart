import 'dart:async';
import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../api/endpoints.dart';
import '../api/zhang_api_client.dart';
import '../models/info.dart';
import '../models/server_event.dart';
import 'ledger_revision.dart';

/// Whether the app listens to `GET /api/sse`. `bootstrap()` turns it on;
/// tests that pump the app directly keep it off (no long-lived request) and
/// get the timer fallback of [LedgerRevision.bumpAfterWrite].
final ledgerEventsEnabledProvider = Provider<bool>((ref) => false);

/// State of the server-event stream of the active profile.
@immutable
class LedgerEventsState {
  const LedgerEventsState({this.connected = false, this.sawReloadEvent = false, this.reloadFailure});

  /// The stream is open (`Connected` received).
  final bool connected;

  /// A `Reload` / `ReloadFailed` arrived since the stream opened, so
  /// [reloadFailure] is current (before that, `/api/info.reload_failure`
  /// is the source).
  final bool sawReloadEvent;

  /// Set by `ReloadFailed`, cleared by `Reload`.
  final ReloadFailure? reloadFailure;

  LedgerEventsState copyWith({bool? connected, bool? sawReloadEvent, ReloadFailure? reloadFailure, bool clearFailure = false}) =>
      LedgerEventsState(
        connected: connected ?? this.connected,
        sawReloadEvent: sawReloadEvent ?? this.sawReloadEvent,
        reloadFailure: clearFailure ? null : (reloadFailure ?? this.reloadFailure),
      );
}

/// Listens to `GET /api/sse` of the active server and refetches on its
/// events: `Reload` bumps [ledgerRevisionProvider] (after a write or an edit
/// of the ledger files), `ReloadFailed` is kept in the state for the Home
/// banner. Reconnects with a backoff (and refetches once reconnected, since
/// events may have been missed). Kept alive by `AppShell` while the server
/// passes the version gate.
final ledgerEventsProvider = NotifierProvider<LedgerEvents, LedgerEventsState>(LedgerEvents.new);

class LedgerEvents extends Notifier<LedgerEventsState> {
  /// Coalesces bursts of `Reload` events (a batch write reloads once per
  /// file) into one refetch.
  static const reloadDebounce = Duration(milliseconds: 150);
  static const _backoff = [Duration(seconds: 1), Duration(seconds: 3), Duration(seconds: 10), Duration(seconds: 30)];

  /// zhang sends a `: ping` comment every ~10 s; a stream silent for this
  /// long is a dead connection (e.g. after a network switch) and is
  /// reopened.
  @visibleForTesting
  static Duration idleTimeout = const Duration(seconds: 45);

  CancelToken? _cancel;
  Timer? _retry;
  Timer? _debounce;
  int _failures = 0;
  bool _wasConnected = false;

  /// Bumped by every build and dispose: a connection loop of an earlier
  /// build (the previous profile's client) sees a different value and
  /// stops instead of reconnecting to the old server.
  int _session = 0;

  @override
  LedgerEventsState build() {
    final session = ++_session;
    if (!ref.watch(ledgerEventsEnabledProvider)) return const LedgerEventsState();
    final client = ref.watch(zhangApiClientProvider);
    _wasConnected = false;
    _failures = 0;
    ref.onDispose(() {
      _session++;
      _cancel?.cancel();
      _retry?.cancel();
      _debounce?.cancel();
    });
    scheduleMicrotask(() => _connect(client, session));
    return const LedgerEventsState();
  }

  Future<void> _connect(ZhangApiClient client, int session) async {
    if (session != _session) return;
    final cancel = _cancel = CancelToken();
    try {
      final res = await client.dio.get<ResponseBody>(
        ZhangEndpoints.sse,
        options: Options(
          responseType: ResponseType.stream,
          receiveTimeout: Duration.zero, // long-lived: no timeout between events
          headers: {'Accept': 'text/event-stream'},
        ),
        cancelToken: cancel,
      );
      final body = res.data;
      if (body == null) throw StateError('empty event stream');
      final lines = body.stream.timeout(idleTimeout).cast<List<int>>().transform(utf8.decoder);
      await for (final line in lines.transform(const LineSplitter())) {
        if (session != _session) return;
        final data = sseData(line);
        if (data == null) continue;
        ServerEvent event;
        try {
          event = ServerEvent.parse(data);
        } on FormatException {
          continue;
        }
        _handle(event);
      }
    } catch (_) {
      // Network error, 401, cancelled: fall through to the reconnect.
    }
    if (session != _session) return;
    if (state.connected) state = state.copyWith(connected: false);
    final delay = _backoff[_failures.clamp(0, _backoff.length - 1)];
    _failures++;
    _retry = Timer(delay, () => _connect(client, session));
  }

  void _handle(ServerEvent event) {
    switch (event) {
      case ServerConnected():
        // Events may have been missed while disconnected, or the screens
        // failed while the server was unreachable (failed attempts before the
        // first connect): refetch. `/api/info.reload_failure`, refetched by
        // the bump, is the reload state again until the next reload event.
        final missed = _wasConnected || _failures > 0;
        _failures = 0;
        state = missed ? const LedgerEventsState(connected: true) : state.copyWith(connected: true);
        if (missed) _bumpSoon();
        _wasConnected = true;
      case ServerReload():
        state = state.copyWith(sawReloadEvent: true, clearFailure: true);
        _bumpSoon();
      case ServerReloadFailed(:final file, :final message):
        state = state.copyWith(sawReloadEvent: true, reloadFailure: ReloadFailure(file: file, message: message));
        _bumpSoon();
      case ServerNewVersionFound() || ServerUnknownEvent():
        break;
    }
  }

  void _bumpSoon() {
    _debounce?.cancel();
    final session = _session;
    _debounce = Timer(reloadDebounce, () {
      if (session == _session) ref.read(ledgerRevisionProvider.notifier).bump();
    });
  }
}

/// The payload of an SSE `data:` line, else `null` (comments, `event:`,
/// blank separators).
@visibleForTesting
String? sseData(String line) {
  if (!line.startsWith('data:')) return null;
  final data = line.substring(5).trim();
  return data.isEmpty ? null : data;
}
