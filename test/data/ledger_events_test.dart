import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:fake_async/fake_async.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:flutter_test/flutter_test.dart';
import 'package:zhang_app/data/api/zhang_api_client.dart';
import 'package:zhang_app/data/models/info.dart';
import 'package:zhang_app/data/models/server_event.dart';
import 'package:zhang_app/data/profiles/server_profile.dart';
import 'package:zhang_app/data/api/api_exception.dart';
import 'package:zhang_app/data/repositories/ledger_data_providers.dart';
import 'package:zhang_app/data/repositories/ledger_events.dart';
import 'package:zhang_app/data/repositories/ledger_revision.dart';

import '../helpers/fake_adapter.dart';

const _profile = ServerProfile(id: 'p', name: 'Test', baseUrl: 'http://127.0.0.1:18080');

/// One fake `/api/sse` connection: push lines with [send], end it with
/// [close].
class _Stream {
  final controller = StreamController<Uint8List>();

  void send(String json) => controller.add(Uint8List.fromList(utf8.encode('data: $json\n\n')));
  Future<void> close() => controller.close();

  ResponseBody get body => ResponseBody(
    controller.stream,
    200,
    headers: {
      Headers.contentTypeHeader: ['text/event-stream'],
    },
  );
}

/// Runs [body] on fake time: the event stream's timers (reconnect backoff,
/// Reload debounce, idle timeout, write settle delays) fire exactly when
/// [wait] passes them, however loaded the machine is. Everything – the
/// container, the client, the fake streams – must be created inside [body].
void _fakeTime(void Function(FakeAsync async, void Function([int ms]) wait) body) {
  fakeAsync((async) {
    body(async, ([int ms = 50]) => async.elapse(Duration(milliseconds: ms)));
  });
}

/// A container for these tests, disposed at the end of [_fakeTime]'s body by
/// [dispose] (inside the fake zone, so its timers are cancelled there).
ProviderContainer _container(List<Override> overrides, {Duration? Function(int, Object)? retry}) =>
    ProviderContainer(overrides: overrides, retry: retry);

/// The active client, switchable like a profile change.
class _ActiveClient extends Notifier<ZhangApiClient> {
  _ActiveClient(this._initial);

  final ZhangApiClient _initial;

  @override
  ZhangApiClient build() => _initial;

  void switchTo(ZhangApiClient client) => state = client;
}

void main() {
  test('sse data lines and the ReloadFailed event', () {
    expect(sseData('data: {"type":"Reload"}'), '{"type":"Reload"}');
    expect(sseData(': keep-alive'), isNull);
    expect(sseData(''), isNull);
    expect(sseData('event: message'), isNull);
    final failed = ServerEvent.parse(
      '{"type":"ReloadFailed","file":"data/2023/12.zhang","message":"cannot parse data/2023/12.zhang"}',
    );
    expect(failed, isA<ServerReloadFailed>());
    expect((failed as ServerReloadFailed).file, 'data/2023/12.zhang');
    expect(failed.message, 'cannot parse data/2023/12.zhang');
  });

  test('disabled: no connection, writes fall back to the timer', () {
    _fakeTime((async, wait) {
      final adapter = FakeAdapter((_) => throw StateError('no request expected'));
      final client = ZhangApiClient(_profile)..dio.httpClientAdapter = adapter;
      final container = _container([zhangApiClientProvider.overrideWithValue(client)]);
      container.listen(ledgerEventsProvider, (_, _) {});
      wait();
      expect(adapter.requests, isEmpty);
      expect(container.read(ledgerEventsProvider).connected, isFalse);
      container.read(ledgerRevisionProvider.notifier).bumpAfterWrite(const Duration(milliseconds: 10));
      wait(9);
      expect(container.read(ledgerRevisionProvider), 0);
      wait(1);
      expect(container.read(ledgerRevisionProvider), 1);
      container.dispose();
    });
  });

  test('Reload refreshes, ReloadFailed is kept, reconnects and refetches', () {
    _fakeTime((async, wait) {
      final streams = <_Stream>[];
      final adapter = FakeAdapter((o) {
        expect(o.path, '/sse');
        expect(o.responseType, ResponseType.stream);
        final s = _Stream();
        streams.add(s);
        return s.body;
      });
      final client = ZhangApiClient(_profile)..dio.httpClientAdapter = adapter;
      final container = _container([
        zhangApiClientProvider.overrideWithValue(client),
        ledgerEventsEnabledProvider.overrideWithValue(true),
      ]);
      container.listen(ledgerEventsProvider, (_, _) {});
      int revision() => container.read(ledgerRevisionProvider);
      wait();
      expect(streams, hasLength(1));

      streams.first.send('{"type":"Connected"}');
      wait();
      expect(container.read(ledgerEventsProvider).connected, isTrue);
      expect(revision(), 0, reason: 'the first connect does not refetch');

      // A write while connected waits for the server's Reload event.
      container.read(ledgerRevisionProvider.notifier).bumpAfterWrite(const Duration(milliseconds: 10));
      wait(100);
      expect(revision(), 0, reason: 'no fixed timer while the stream is connected');
      // zhang sends two Reloads per write, ~550 ms apart.
      streams.first.send('{"type":"Reload"}');
      wait(550);
      expect(revision(), 0, reason: 'trailing debounce');
      streams.first.send('{"type":"Reload"}');
      wait(LedgerEvents.reloadDebounce.inMilliseconds - 1);
      expect(revision(), 0, reason: 'the second Reload restarts the debounce');
      wait(1);
      expect(revision(), 1, reason: 'the two Reload events of a write refetch once');
      // The write's safety net (5 s) sees the refetch and does not bump again.
      wait(LedgerRevision.eventSafetyDelay.inMilliseconds);
      expect(revision(), 1);

      streams.first.send('{"type":"ReloadFailed","file":"data/2023/12.zhang","message":"cannot parse"}');
      wait(LedgerEvents.reloadDebounce.inMilliseconds);
      final failed = container.read(ledgerEventsProvider);
      expect(failed.sawReloadEvent, isTrue);
      expect(failed.reloadFailure, const ReloadFailure(file: 'data/2023/12.zhang', message: 'cannot parse'));
      expect(revision(), 2);

      streams.first.send('{"type":"Reload"}');
      wait(LedgerEvents.reloadDebounce.inMilliseconds);
      expect(container.read(ledgerEventsProvider).reloadFailure, isNull);
      expect(revision(), 3);

      // The server goes away: disconnected, then a reconnect (after the 1 s
      // backoff) refetches.
      streams.first.close();
      wait();
      expect(container.read(ledgerEventsProvider).connected, isFalse);
      wait(900);
      expect(streams, hasLength(1), reason: 'backoff');
      wait(100);
      expect(streams, hasLength(2));
      streams.last.send('{"type":"Connected"}');
      wait(LedgerEvents.reloadDebounce.inMilliseconds);
      expect(container.read(ledgerEventsProvider).connected, isTrue);
      expect(revision(), 4);
      expect(
        container.read(ledgerEventsProvider).sawReloadEvent,
        isFalse,
        reason: 'a ReloadFailed may have been missed: /api/info is the source again',
      );
      container.dispose();
    });
  });

  test('the first connect after failed attempts (server was unreachable) refetches', () {
    _fakeTime((async, wait) {
      final streams = <_Stream>[];
      var attempts = 0;
      final adapter = FakeAdapter((o) {
        if (attempts++ == 0) {
          throw DioException.connectionError(requestOptions: o, reason: 'offline');
        }
        final s = _Stream();
        streams.add(s);
        return s.body;
      });
      final client = ZhangApiClient(_profile)..dio.httpClientAdapter = adapter;
      final container = _container([
        zhangApiClientProvider.overrideWithValue(client),
        ledgerEventsEnabledProvider.overrideWithValue(true),
      ]);
      container.listen(ledgerEventsProvider, (_, _) {});
      wait(950);
      expect(streams, isEmpty, reason: 'the first attempt failed; retried after 1 s');
      wait(100);
      expect(streams, hasLength(1));
      streams.single.send('{"type":"Connected"}');
      wait(LedgerEvents.reloadDebounce.inMilliseconds);
      expect(container.read(ledgerEventsProvider).connected, isTrue);
      expect(container.read(ledgerRevisionProvider), 1);
      container.dispose();
    });
  });

  test('a silent stream (dead connection) is reopened and refetches', () {
    _fakeTime((async, wait) {
      final streams = <_Stream>[];
      final adapter = FakeAdapter((o) {
        final s = _Stream();
        streams.add(s);
        return s.body;
      });
      final client = ZhangApiClient(_profile)..dio.httpClientAdapter = adapter;
      final container = _container([
        zhangApiClientProvider.overrideWithValue(client),
        ledgerEventsEnabledProvider.overrideWithValue(true),
      ]);
      container.listen(ledgerEventsProvider, (_, _) {});
      final idle = LedgerEvents.idleTimeout.inMilliseconds;
      wait();
      streams.single.send('{"type":"Connected"}');
      wait(idle - 1000);
      streams.single.controller.add(Uint8List.fromList(utf8.encode(': ping\n\n')));
      wait(idle - 1000);
      expect(container.read(ledgerEventsProvider).connected, isTrue, reason: 'pings keep it open');
      wait(1000);
      expect(container.read(ledgerEventsProvider).connected, isFalse);
      wait(1000); // backoff
      expect(streams, hasLength(2));
      streams.last.send('{"type":"Connected"}');
      wait(LedgerEvents.reloadDebounce.inMilliseconds);
      expect(container.read(ledgerEventsProvider).connected, isTrue);
      expect(container.read(ledgerRevisionProvider), 1);
      container.dispose();
    });
  });

  test('a version gate that failed (server unreachable) is re-checked when the stream connects', () {
    _fakeTime((async, wait) {
      final streams = <_Stream>[];
      var online = false;
      final adapter = FakeAdapter((o) {
        if (!online) throw DioException.connectionError(requestOptions: o, reason: 'offline');
        if (o.path == '/info') {
          return jsonResponse({
            'data': {'title': 'Old', 'version': '0.1.0', 'build_date': '2026-10-02'},
          });
        }
        final s = _Stream();
        streams.add(s);
        return s.body;
      });
      final client = ZhangApiClient(_profile)..dio.httpClientAdapter = adapter;
      final container = _container([
        zhangApiClientProvider.overrideWithValue(client),
        ledgerEventsEnabledProvider.overrideWithValue(true),
      ], retry: (_, _) => null);
      container.listen(serverGateProvider, (_, _) {});
      wait();
      expect(container.read(serverGateProvider).error, isA<ApiNetworkError>());
      container.listen(ledgerEventsProvider, (_, _) {});
      wait();
      online = true;
      wait(1000); // the stream retries after 1 s
      expect(streams, hasLength(1));
      streams.single.send('{"type":"Connected"}');
      wait();
      final gate = container.read(serverGateProvider);
      expect(gate.hasError, isFalse);
      expect(gate.value?.isSupported, isFalse, reason: 'an old server is now caught by the gate');
      expect([for (final r in adapter.requests) if (r.path == '/info') r.path], hasLength(2));
      container.dispose();
    });
  });

  test('a profile switch closes the old stream and never reconnects to the old server', () {
    _fakeTime((async, wait) {
      final oldStreams = <_Stream>[];
      final newStreams = <_Stream>[];
      final oldAdapter = FakeAdapter((o) {
        final s = _Stream();
        oldStreams.add(s);
        return s.body;
      });
      final newAdapter = FakeAdapter((o) {
        final s = _Stream();
        newStreams.add(s);
        return s.body;
      });
      final oldClient = ZhangApiClient(_profile)..dio.httpClientAdapter = oldAdapter;
      final newClient = ZhangApiClient(const ServerProfile(id: 'q', name: 'Other', baseUrl: 'http://127.0.0.1:18081'))
        ..dio.httpClientAdapter = newAdapter;
      final active = NotifierProvider<_ActiveClient, ZhangApiClient>(() => _ActiveClient(oldClient));
      final container = _container([
        zhangApiClientProvider.overrideWith((ref) => ref.watch(active)),
        ledgerEventsEnabledProvider.overrideWithValue(true),
      ]);
      container.listen(ledgerEventsProvider, (_, _) {});
      wait();
      oldStreams.single.send('{"type":"Connected"}');
      wait();
      expect(container.read(ledgerEventsProvider).connected, isTrue);

      container.read(active.notifier).switchTo(newClient);
      wait();
      expect(newStreams, hasLength(1));
      expect(oldStreams.single.controller.hasListener, isFalse, reason: 'the old stream is closed');
      newStreams.single.send('{"type":"Connected"}');
      wait();
      expect(container.read(ledgerEventsProvider).connected, isTrue);

      // Past the old stream's first reconnect backoffs (1 s, 3 s, 10 s) and
      // within the new one's idle timeout.
      wait(LedgerEvents.idleTimeout.inMilliseconds - 1000);
      expect(oldAdapter.requests, hasLength(1), reason: 'no reconnect to the previous server');
      expect(newAdapter.requests, hasLength(1));
      container.dispose();
    });
  });
}
