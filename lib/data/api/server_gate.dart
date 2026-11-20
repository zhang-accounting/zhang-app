import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/info.dart';
import 'api_exception.dart';
import 'endpoints.dart';
import 'zhang_api_client.dart';

/// The version gate of the active server: `GET /api/info` once per ledger
/// session (not refetched on revision bumps). Its [ServerInfo.isSupported]
/// decides whether the server may be queried at all:
///
/// * [ServerGateInterceptor] holds every request of the session's client
///   except the probes ([ServerGateInterceptor.probes]) until it has passed,
///   and fails them with [ApiServerTooOld] on a server older than zhang 0.2;
/// * `AppShell` shows "server too old" instead of the tabs.
///
/// When it failed (server unreachable, 401) the next request asks again, and
/// so does `ledgerEventsProvider` once the event stream connects.
final serverGateProvider = FutureProvider<ServerInfo>((ref) => ref.watch(zhangApiClientProvider).info());

/// Puts [client] behind the version gate of [ref]'s container
/// ([serverGateProvider]) and closes it when [ref] is disposed. Used by
/// `zhangApiClientProvider`; tests that build their own client for a
/// profile can use it to get the same behaviour.
ZhangApiClient gatedClient(Ref ref, ZhangApiClient client) {
  final container = ref.container;
  client.dio.interceptors.insert(
    0,
    ServerGateInterceptor(() {
      if (!ref.mounted) {
        throw const ApiNetworkError(NetworkErrorKind.cancelled, 'the ledger session has ended');
      }
      return waitForServerGate(container);
    }),
  );
  ref.onDispose(client.close);
  return client;
}

/// Completes once [serverGateProvider] of [container] has passed; throws
/// [ApiServerTooOld] for a server older than zhang 0.2, or the probe's error
/// when the server could not be asked. A gate that failed before is asked
/// again (without a loading state: `AppShell` keeps what it shows).
Future<void> waitForServerGate(ProviderContainer container) async {
  // Listen while waiting: a pending retry (the container's retry policy)
  // only rebuilds a provider that is listened to, and `AppShell`'s listener
  // is paused while another page covers the shell.
  final subscription = container.listen(serverGateProvider, (_, _) {});
  try {
    final gate = subscription.read();
    if (gate.hasError && !gate.isLoading) container.invalidate(serverGateProvider);
    final info = await container.read(serverGateProvider.future);
    if (!info.isSupported) throw ApiServerTooOld(info.version);
  } finally {
    subscription.close();
  }
}

/// Holds each request until [passed] completes and fails it with
/// [passed]'s error (nothing is sent). The [probes] that decide the gate go
/// through at once.
class ServerGateInterceptor extends Interceptor {
  ServerGateInterceptor(this.passed);

  /// Completes when the server may be queried, else throws a
  /// `ZhangApiException`.
  final Future<void> Function() passed;

  /// Requests allowed before the gate has passed: they only tell what the
  /// server is.
  static const probes = {ZhangEndpoints.info, ZhangEndpoints.authStatus};

  @override
  Future<void> onRequest(RequestOptions options, RequestInterceptorHandler handler) async {
    if (probes.contains(Uri.parse(options.path).path)) return handler.next(options);
    try {
      await passed();
    } catch (e) {
      return handler.reject(DioException(requestOptions: options, error: e, message: '$e'));
    }
    handler.next(options);
  }
}
