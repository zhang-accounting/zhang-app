import 'dart:developer' as developer;
import 'dart:io';

import 'package:dio/dio.dart';
import 'package:dio/io.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/auth_status.dart';
import '../models/info.dart';
import '../profiles/profile_providers.dart';
import '../profiles/server_profile.dart';
import 'api_exception.dart';
import 'auth_interceptor.dart';

/// Decodes the payload inside the `{"data": …}` envelope.
typedef DataDecoder<T> = T Function(Object? data);

/// HTTP client for one zhang server ([ServerProfile]).
///
/// * Base URL is `<profile.baseUrl>/api`; pass paths like `/journals`
///   (see `ZhangEndpoints`).
/// * Auth headers are injected by [AuthInterceptor].
/// * The `{"data": …}` envelope is unwrapped; your [DataDecoder] receives the
///   inner value.
/// * Every failure is thrown as a [ZhangApiException] (never a raw
///   [DioException]).
///
/// Feature code normally uses the repositories in `lib/data/repositories/`,
/// which wrap this client; read the client itself with
/// `ref.watch(zhangApiClientProvider)`.
class ZhangApiClient {
  ZhangApiClient(this.profile, {Dio? dio}) : dio = dio ?? createDio(profile);

  final ServerProfile profile;

  /// Underlying dio instance (exposed for tests / special requests).
  final Dio dio;

  static const connectTimeout = Duration(seconds: 10);
  static const receiveTimeout = Duration(seconds: 30);

  /// Builds the dio instance for [profile]: base URL, timeouts, auth
  /// interceptor and (on IO platforms) the self-signed certificate policy.
  static Dio createDio(ServerProfile profile) {
    final dio = Dio(
      BaseOptions(
        baseUrl: profile.apiBaseUrl,
        connectTimeout: connectTimeout,
        receiveTimeout: receiveTimeout,
        sendTimeout: receiveTimeout,
        responseType: ResponseType.json,
        headers: {'Accept': 'application/json'},
      ),
    );
    if (profile.allowSelfSigned && !kIsWeb) {
      final host = profile.host;
      dio.httpClientAdapter = IOHttpClientAdapter(
        createHttpClient: () {
          final client = HttpClient();
          // Only trust bad certificates for this profile's own host.
          client.badCertificateCallback = (cert, certHost, port) => certHost == host;
          return client;
        },
      );
    }
    dio.interceptors.add(AuthInterceptor(profile));
    if (kDebugMode) dio.interceptors.add(_SafeLogInterceptor());
    return dio;
  }

  /// `GET /api/info` – cheapest health/identity/credentials check.
  Future<ServerInfo> info() => get('/info', decode: ServerInfo.fromJson);

  /// `GET /api/auth/status` – sign-in methods of the server; needs no
  /// credentials (zhang ≥ 0.2).
  Future<AuthStatus> authStatus() => get('/auth/status', decode: AuthStatus.fromJson);

  /// `GET /api/info`, then the version gate: throws [ApiServerTooOld] when
  /// the server predates the v0.2 API (no `format` key).
  Future<ServerInfo> supportedInfo() async {
    final info = await this.info();
    if (!info.isSupported) throw ApiServerTooOld(info.version);
    return info;
  }

  /// GET [path] and decode the envelope's `data`.
  ///
  /// [path] may already contain a hand-built query string (`/journals?…`);
  /// [query] values are url-encoded by dio.
  Future<T> get<T>(String path, {Map<String, Object?>? query, required DataDecoder<T> decode}) =>
      _json('GET', path, query: query, decode: decode);

  Future<T> post<T>(String path, {Object? body, required DataDecoder<T> decode}) =>
      _json('POST', path, body: body, decode: decode);

  Future<T> put<T>(String path, {Object? body, required DataDecoder<T> decode}) =>
      _json('PUT', path, body: body, decode: decode);

  /// For endpoints whose result is irrelevant: `201` with empty body, or
  /// `200 {"data":"Ok"}` / `{"data":null}`. A non-JSON `200` (the server's
  /// text fallback for unknown paths) is still an [ApiParseError].
  Future<void> send(String method, String path, {Object? body, Map<String, Object?>? query}) async {
    final res = await _send(method, path, body: body, query: query);
    final data = res.data;
    if (data == null || (data is String && data.isEmpty) || data is Map) return;
    if (res.statusCode == 201 || res.statusCode == 204) return;
    throw ApiParseError(_notJsonMessage(res));
  }

  /// GET raw bytes (document downloads).
  Future<Uint8List> getBytes(String path) async {
    final res = await _send('GET', path, responseType: ResponseType.bytes);
    final data = res.data;
    if (data is Uint8List) return data;
    if (data is List<int>) return Uint8List.fromList(data);
    return Uint8List(0);
  }

  /// Releases sockets. Called automatically by [zhangApiClientProvider].
  void close() => dio.close(force: true);

  /// Percent-encodes one path segment (account names may contain non-ASCII;
  /// `:` becomes `%3A`, which the server accepts).
  static String encodeSegment(String segment) => Uri.encodeComponent(segment);

  Future<T> _json<T>(
    String method,
    String path, {
    Object? body,
    Map<String, Object?>? query,
    required DataDecoder<T> decode,
  }) async {
    final res = await _send(method, path, body: body, query: query);
    final inner = unwrapEnvelope(res);
    try {
      return decode(inner);
    } on ZhangApiException {
      rethrow;
    } catch (e) {
      throw ApiParseError('could not decode ${res.requestOptions.path}: $e', cause: e);
    }
  }

  Future<Response<Object?>> _send(
    String method,
    String path, {
    Object? body,
    Map<String, Object?>? query,
    ResponseType? responseType,
  }) async {
    try {
      return await dio.request<Object?>(
        path,
        data: body,
        queryParameters: query == null
            ? null
            : {
                for (final e in query.entries)
                  if (e.value != null) e.key: e.value,
              },
        options: Options(
          method: method,
          responseType: responseType,
          contentType: body == null ? null : Headers.jsonContentType,
        ),
      );
    } on DioException catch (e) {
      throw mapDioException(e);
    }
  }

  /// Returns the `data` member of a JSON envelope or throws [ApiParseError]
  /// (non-JSON body, e.g. the `200 text/plain` fallback, or no envelope).
  @visibleForTesting
  static Object? unwrapEnvelope(Response<Object?> res) {
    final data = res.data;
    if (data is Map && data.containsKey('data')) return data['data'];
    if (data is Map) throw const ApiParseError('response has no "data" envelope');
    throw ApiParseError(_notJsonMessage(res));
  }

  static String _notJsonMessage(Response<Object?> res) {
    final type = res.headers.value(Headers.contentTypeHeader) ?? 'unknown';
    return 'expected a JSON response from ${res.requestOptions.uri.path} '
        'but got "$type" (is this a zhang server URL?)';
  }

  /// Maps a [DioException] into the [ZhangApiException] hierarchy.
  static ZhangApiException mapDioException(DioException e) {
    switch (e.type) {
      case DioExceptionType.badResponse:
        final status = e.response?.statusCode ?? 0;
        final message = errorMessageOf(e.response?.data, status);
        if (status == 401 || status == 403) {
          return ApiUnauthorized(status: status, message: message);
        }
        if (status == 404) return ApiNotFound(message);
        return ApiServerError(status, message);
      case DioExceptionType.connectionTimeout:
      case DioExceptionType.sendTimeout:
      case DioExceptionType.receiveTimeout:
      case DioExceptionType.transformTimeout:
        return ApiNetworkError(NetworkErrorKind.timeout, 'timeout (${e.type.name})', cause: e);
      case DioExceptionType.badCertificate:
        return ApiNetworkError(NetworkErrorKind.certificate, 'bad TLS certificate', cause: e);
      case DioExceptionType.cancel:
        return ApiNetworkError(NetworkErrorKind.cancelled, 'request cancelled', cause: e);
      case DioExceptionType.connectionError:
        return _fromError(e.error, e) ??
            ApiNetworkError(NetworkErrorKind.connection, e.message ?? 'connection error', cause: e);
      case DioExceptionType.unknown:
        return _fromError(e.error, e) ??
            ApiNetworkError(NetworkErrorKind.unknown, '${e.error ?? e.message}', cause: e);
    }
  }

  static ZhangApiException? _fromError(Object? error, DioException e) {
    if (error is ZhangApiException) return error;
    if (error is HandshakeException || error is TlsException) {
      return ApiNetworkError(NetworkErrorKind.certificate, error.toString(), cause: e);
    }
    if (error is SocketException || error is HttpException) {
      return ApiNetworkError(NetworkErrorKind.connection, error.toString(), cause: e);
    }
    if (error is FormatException) {
      return ApiParseError('malformed JSON: ${error.message}', cause: e);
    }
    return null;
  }

  /// Error text per docs §1.2: JSON `message`, else the plain-text body,
  /// else `HTTP <status>`.
  static String errorMessageOf(Object? body, int status) {
    if (body is Map && body['message'] is String) return body['message'] as String;
    if (body is String && body.trim().isNotEmpty) {
      final text = body.trim();
      return text.length > 300 ? '${text.substring(0, 300)}…' : text;
    }
    if (body is List<int> && body.isNotEmpty) {
      final text = String.fromCharCodes(body.take(300));
      return text.trim().isEmpty ? 'HTTP $status' : text.trim();
    }
    return 'HTTP $status';
  }
}

/// Debug-only request log: method, path, status and duration. Never logs
/// headers, bodies or query values (they may contain credentials).
class _SafeLogInterceptor extends Interceptor {
  static const _startKey = '_zhangStart';

  @override
  void onRequest(RequestOptions options, RequestInterceptorHandler handler) {
    options.extra[_startKey] = DateTime.now();
    handler.next(options);
  }

  @override
  void onResponse(Response<dynamic> response, ResponseInterceptorHandler handler) {
    _log(response.requestOptions, response.statusCode);
    handler.next(response);
  }

  @override
  void onError(DioException err, ErrorInterceptorHandler handler) {
    _log(err.requestOptions, err.response?.statusCode, err.type.name);
    handler.next(err);
  }

  void _log(RequestOptions o, int? status, [String? error]) {
    final start = o.extra[_startKey];
    final ms = start is DateTime ? DateTime.now().difference(start).inMilliseconds : -1;
    developer.log(
      '${o.method} ${o.uri.path} -> ${status ?? error} (${ms}ms)',
      name: 'zhang.http',
    );
  }
}

/// The client for the **active** profile. Rebuilt (and the old one closed)
/// whenever the active profile changes or is edited, so everything that
/// watches it (repositories, data providers) refreshes automatically.
///
/// Throws [NoActiveProfileException] when no profile is active; the router
/// never shows feature screens in that state.
final zhangApiClientProvider = Provider<ZhangApiClient>((ref) {
  final profile = ref.watch(activeProfileProvider);
  if (profile == null) throw const NoActiveProfileException();
  final client = ZhangApiClient(profile);
  ref.onDispose(client.close);
  return client;
});

/// Probes a not-yet-saved profile (onboarding / settings "Test connection").
class ConnectionTester {
  const ConnectionTester({this.createClient = ZhangApiClient.new});

  /// Builds the client for the probed profile (tests inject a fake adapter).
  final ZhangApiClient Function(ServerProfile profile) createClient;

  /// Calls `GET /api/info` with [profile]'s URL and credentials and applies
  /// the version gate ([ApiServerTooOld] for zhang < 0.2). When the
  /// credentials are refused, `GET /api/auth/status` tells a passkey-only
  /// server ([ApiPasskeyOnly]) from a wrong password ([ApiUnauthorized]).
  Future<ServerInfo> test(ServerProfile profile) async {
    final client = createClient(profile);
    try {
      return await client.supportedInfo();
    } on ApiUnauthorized {
      final status = await _authStatus(client);
      if (status != null && status.isPasskeyOnly) throw const ApiPasskeyOnly();
      rethrow;
    } finally {
      client.close();
    }
  }

  /// Best effort: `null` when the server cannot tell (older servers answer
  /// 401 or a text page here).
  static Future<AuthStatus?> _authStatus(ZhangApiClient client) async {
    try {
      return await client.authStatus();
    } on ZhangApiException {
      return null;
    }
  }
}

/// Overridable in widget tests.
final connectionTesterProvider = Provider<ConnectionTester>((ref) => const ConnectionTester());
