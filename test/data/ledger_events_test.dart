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
    streams.first.send('{"type":"Reload"}');
    streams.first.send('{"type":"Reload"}');
    await _wait(LedgerEvents.reloadDebounce.inMilliseconds + 100);
    expect(revision(), 1, reason: 'a burst of Reload events refetches once');

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
  });
}
