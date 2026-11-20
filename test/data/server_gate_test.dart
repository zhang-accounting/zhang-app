import 'package:dio/dio.dart';
import 'package:fake_async/fake_async.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:zhang_app/data/api/api_exception.dart';
import 'package:zhang_app/data/api/zhang_api_client.dart';
import 'package:zhang_app/data/profiles/profile_providers.dart';
import 'package:zhang_app/data/profiles/server_profile.dart';
import 'package:zhang_app/data/repositories/repositories.dart';
import 'package:zhang_app/main.dart' show zhangRetryPolicy;

import '../helpers/fake_adapter.dart';
import '../helpers/fixtures.dart';

const _profile = ServerProfile(id: 'p', name: 'Test', baseUrl: 'http://127.0.0.1:18010');

/// A container whose client is the production one (`gatedClient`) answered
/// by [handler]; returns the container and the request log.
(ProviderContainer, FakeAdapter) _gated(FakeHandler handler, {Duration? Function(int, Object)? retry}) {
  final adapter = FakeAdapter(handler);
  final container = ProviderContainer(
    overrides: [
      activeProfileProvider.overrideWithValue(_profile),
      zhangApiClientProvider.overrideWith(
        (ref) => gatedClient(ref, ZhangApiClient(_profile)..dio.httpClientAdapter = adapter),
      ),
    ],
    retry: retry ?? (_, _) => null,
  );
  return (container, adapter);
}

List<String> _paths(FakeAdapter adapter) => [for (final r in adapter.requests) r.uri.path];

/// Runs [future] to its end on fake time; returns its error (or `null`).
Object? _errorOf(FakeAsync async, Future<Object?> future, {Duration within = const Duration(seconds: 5)}) {
  Object? error;
  var done = false;
  future.then<void>(
    (_) => done = true,
    onError: (Object e) {
      error = e;
      done = true;
    },
  );
  async.elapse(within);
  expect(done, isTrue, reason: 'the request must not hang');
  return error;
}

ResponseBody _oldInfo() => jsonResponse({
  'data': {'title': 'Old', 'version': '0.1.0', 'build_date': '2026-10-02'},
});

void main() {
  test('probes go at once; everything else waits for a passed gate', () {
    fakeAsync((async) {
      final (container, adapter) = _gated((o) {
        if (o.path == '/info') return jsonResponse(fixture('info.json'));
        if (o.path == '/auth/status') return jsonResponse(fixture('auth_status.json'));
        return jsonResponse(fixture('options.json'));
      });
      expect(_errorOf(async, container.read(ledgerRepositoryProvider).options()), isNull);
      expect(_paths(adapter), ['/api/info', '/api/options'], reason: 'the gate first');
      expect(_errorOf(async, container.read(zhangApiClientProvider).authStatus()), isNull);
      expect(_errorOf(async, container.read(ledgerRepositoryProvider).options()), isNull);
      expect(_paths(adapter), ['/api/info', '/api/options', '/api/auth/status', '/api/options']);
      container.dispose();
    });
  });

  test('a zhang < 0.2 server gets the probes only; the rest fails with ApiServerTooOld', () {
    fakeAsync((async) {
      final (container, adapter) = _gated((o) => o.path == '/info' ? _oldInfo() : jsonResponse({}, status: 404));
      for (final request in <Future<Object?> Function()>[
        () => container.read(ledgerRepositoryProvider).options(),
        () => container.read(journalRepositoryProvider).list(const JournalQuery()),
        () => container.read(ledgerRepositoryProvider).now(),
        () => container.read(zhangApiClientProvider).dio.get<Object?>('/sse'),
      ]) {
        final error = _errorOf(async, request());
        expect(error is ApiServerTooOld || (error is DioException && error.error is ApiServerTooOld), isTrue);
      }
      expect(_errorOf(async, container.read(serverInfoProvider.future)), isNull, reason: '/api/info is a probe');
      expect(_paths(adapter).toSet(), {'/api/info'});
      container.dispose();
    });
  });

  test('a gate that failed is asked again by the next request', () {
    fakeAsync((async) {
      var online = false;
      final (container, adapter) = _gated((o) {
        if (!online) throw DioException.connectionError(requestOptions: o, reason: 'offline');
        return jsonResponse(fixture(o.path == '/info' ? 'info.json' : 'options.json'));
      });
      expect(_errorOf(async, container.read(ledgerRepositoryProvider).options()), isA<ApiNetworkError>());
      expect(_paths(adapter), ['/api/info'], reason: 'nothing but the probe while the gate is unknown');
      online = true;
      expect(_errorOf(async, container.read(ledgerRepositoryProvider).options()), isNull);
      expect(_paths(adapter), ['/api/info', '/api/info', '/api/options']);
      expect(container.read(serverGateProvider).value?.isSupported, isTrue);
      container.dispose();
    });
  });

  test('a request waits through the gate\'s retries even when nothing else listens to it', () {
    fakeAsync((async) {
      var attempts = 0;
      final (container, adapter) = _gated((o) {
        if (o.path == '/info' && attempts++ == 0) {
          throw DioException.connectionError(requestOptions: o, reason: 'offline');
        }
        return jsonResponse(fixture(o.path == '/info' ? 'info.json' : 'options.json'));
      }, retry: zhangRetryPolicy);
      container.read(serverGateProvider); // probed (fails, retry pending), not listened
      async.elapse(const Duration(milliseconds: 10));
      expect(_errorOf(async, container.read(ledgerRepositoryProvider).options()), isNull);
      expect(_paths(adapter), ['/api/info', '/api/info', '/api/options']);
      container.dispose();
    });
  });
}
