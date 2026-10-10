import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
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

Future<void> _wait([int ms = 50]) => Future<void>.delayed(Duration(milliseconds: ms));

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

  test('disabled: no connection, writes fall back to the timer', () async {
    final adapter = FakeAdapter((_) => throw StateError('no request expected'));
    final client = ZhangApiClient(_profile)..dio.httpClientAdapter = adapter;
    final container = ProviderContainer(overrides: [zhangApiClientProvider.overrideWithValue(client)]);
    addTearDown(container.dispose);
    container.listen(ledgerEventsProvider, (_, _) {});
    await _wait();
    expect(adapter.requests, isEmpty);
    expect(container.read(ledgerEventsProvider).connected, isFalse);
    await container.read(ledgerRevisionProvider.notifier).bumpAfterWrite(const Duration(milliseconds: 10));
    expect(container.read(ledgerRevisionProvider), 1);
  });

  test('Reload refreshes, ReloadFailed is kept, reconnects and refetches', () async {
    final streams = <_Stream>[];
    final adapter = FakeAdapter((o) {
      expect(o.path, '/sse');
      expect(o.responseType, ResponseType.stream);
      final s = _Stream();
      streams.add(s);
      return s.body;
    });
    final client = ZhangApiClient(_profile)..dio.httpClientAdapter = adapter;
    final container = ProviderContainer(
      overrides: [
        zhangApiClientProvider.overrideWithValue(client),
        ledgerEventsEnabledProvider.overrideWithValue(true),
      ],
    );
    addTearDown(container.dispose);
    container.listen(ledgerEventsProvider, (_, _) {});
    int revision() => container.read(ledgerRevisionProvider);
    await _wait();
    expect(streams, hasLength(1));

    streams.first.send('{"type":"Connected"}');
    await _wait();
    expect(container.read(ledgerEventsProvider).connected, isTrue);
    expect(revision(), 0, reason: 'the first connect does not refetch');

    // A write while connected waits for the server's Reload event.
    unawaited(container.read(ledgerRevisionProvider.notifier).bumpAfterWrite(const Duration(milliseconds: 10)));
    await _wait(100);
    expect(revision(), 0, reason: 'no fixed timer while the stream is connected');
    // zhang sends two Reloads per write, ~550 ms apart.
    streams.first.send('{"type":"Reload"}');
    await _wait(550);
    expect(revision(), 0, reason: 'trailing debounce');
    streams.first.send('{"type":"Reload"}');
    await _wait(LedgerEvents.reloadDebounce.inMilliseconds - 200);
    expect(revision(), 0, reason: 'the second Reload restarts the debounce');
    await _wait(300);
    expect(revision(), 1, reason: 'the two Reload events of a write refetch once');

    streams.first.send('{"type":"ReloadFailed","file":"data/2023/12.zhang","message":"cannot parse"}');
    await _wait(LedgerEvents.reloadDebounce.inMilliseconds + 100);
    final failed = container.read(ledgerEventsProvider);
    expect(failed.sawReloadEvent, isTrue);
    expect(failed.reloadFailure, const ReloadFailure(file: 'data/2023/12.zhang', message: 'cannot parse'));

    streams.first.send('{"type":"Reload"}');
    await _wait(LedgerEvents.reloadDebounce.inMilliseconds + 100);
    expect(container.read(ledgerEventsProvider).reloadFailure, isNull);
    final before = revision();

    // The server goes away: disconnected, then a reconnect refetches.
    await streams.first.close();
    await _wait();
    expect(container.read(ledgerEventsProvider).connected, isFalse);
    await _wait(1100);
    expect(streams, hasLength(2));
    streams.last.send('{"type":"Connected"}');
    await _wait(LedgerEvents.reloadDebounce.inMilliseconds + 100);
    expect(container.read(ledgerEventsProvider).connected, isTrue);
    expect(revision(), before + 1);
    expect(
      container.read(ledgerEventsProvider).sawReloadEvent,
      isFalse,
      reason: 'a ReloadFailed may have been missed: /api/info is the source again',
    );
  });

  test('the first connect after failed attempts (server was unreachable) refetches', () async {
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
    final container = ProviderContainer(
      overrides: [
        zhangApiClientProvider.overrideWithValue(client),
        ledgerEventsEnabledProvider.overrideWithValue(true),
      ],
    );
    addTearDown(container.dispose);
    container.listen(ledgerEventsProvider, (_, _) {});
    await _wait(1200); // first attempt fails, retried after 1 s
    expect(streams, hasLength(1));
    streams.single.send('{"type":"Connected"}');
    await _wait(LedgerEvents.reloadDebounce.inMilliseconds + 100);
    expect(container.read(ledgerEventsProvider).connected, isTrue);
    expect(container.read(ledgerRevisionProvider), 1);
  });

  test('a silent stream (dead connection) is reopened and refetches', () async {
    final previous = LedgerEvents.idleTimeout;
    LedgerEvents.idleTimeout = const Duration(milliseconds: 600);
    addTearDown(() => LedgerEvents.idleTimeout = previous);
    final streams = <_Stream>[];
    final adapter = FakeAdapter((o) {
      final s = _Stream();
      streams.add(s);
      return s.body;
    });
    final client = ZhangApiClient(_profile)..dio.httpClientAdapter = adapter;
    final container = ProviderContainer(
      overrides: [
        zhangApiClientProvider.overrideWithValue(client),
        ledgerEventsEnabledProvider.overrideWithValue(true),
      ],
    );
    addTearDown(container.dispose);
    container.listen(ledgerEventsProvider, (_, _) {});
    await _wait();
    streams.single.send('{"type":"Connected"}');
    await _wait(400);
    streams.single.controller.add(Uint8List.fromList(utf8.encode(': ping\n\n')));
    await _wait(300);
    expect(container.read(ledgerEventsProvider).connected, isTrue, reason: 'pings keep it open');
    await _wait(600);
    expect(container.read(ledgerEventsProvider).connected, isFalse);
    // The reconnected stream (opened after the 1 s backoff) gets the normal
    // timeout, so it cannot time out itself on a slow machine.
    LedgerEvents.idleTimeout = previous;
    await _wait(1100);
    expect(streams, hasLength(2));
    streams.last.send('{"type":"Connected"}');
    await _wait(LedgerEvents.reloadDebounce.inMilliseconds + 100);
    expect(container.read(ledgerRevisionProvider), 1);
  });

  test('a version gate that failed (server unreachable) is re-checked when the stream connects', () async {
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
    final container = ProviderContainer(
      overrides: [
        zhangApiClientProvider.overrideWithValue(client),
        ledgerEventsEnabledProvider.overrideWithValue(true),
      ],
      retry: (_, _) => null,
    );
    addTearDown(container.dispose);
    container.listen(serverGateProvider, (_, _) {});
    await expectLater(container.read(serverGateProvider.future), throwsA(isA<ApiNetworkError>()));
    container.listen(ledgerEventsProvider, (_, _) {});
    await _wait();
    online = true;
    // The stream retries after 1 s (allow for a loaded machine).
    for (var i = 0; i < 40 && streams.isEmpty; i++) {
      await _wait(100);
    }
    expect(streams, hasLength(1));
    streams.single.send('{"type":"Connected"}');
    for (var i = 0; i < 40 && !container.read(serverGateProvider).hasValue; i++) {
      await _wait(50);
    }
    final gate = container.read(serverGateProvider);
    expect(gate.hasError, isFalse);
    expect(gate.value?.isSupported, isFalse, reason: 'an old server is now caught by the gate');
    expect([for (final r in adapter.requests) if (r.path == '/info') r.path], hasLength(2));
  });

  test('a profile switch closes the old stream and never reconnects to the old server', () async {
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
    final container = ProviderContainer(
      overrides: [
        zhangApiClientProvider.overrideWith((ref) => ref.watch(active)),
        ledgerEventsEnabledProvider.overrideWithValue(true),
      ],
    );
    addTearDown(container.dispose);
    container.listen(ledgerEventsProvider, (_, _) {});
    await _wait();
    oldStreams.single.send('{"type":"Connected"}');
    await _wait();
    expect(container.read(ledgerEventsProvider).connected, isTrue);

    container.read(active.notifier).switchTo(newClient);
    await _wait();
    expect(newStreams, hasLength(1));
    newStreams.single.send('{"type":"Connected"}');
    await _wait();
    expect(container.read(ledgerEventsProvider).connected, isTrue);

    // Longer than the first reconnect backoff (1 s).
    await _wait(1500);
    expect(oldAdapter.requests, hasLength(1), reason: 'no reconnect to the previous server');
    expect(newAdapter.requests, hasLength(1));
    expect(container.read(ledgerEventsProvider).connected, isTrue);
  });
}
