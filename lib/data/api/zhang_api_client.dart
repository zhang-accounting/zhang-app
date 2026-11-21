import 'dart:convert';
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
import 'endpoints.dart';
import 'server_gate.dart';

export 'connection_tester.dart';
export 'server_gate.dart' show gatedClient;

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
  ///
  /// Redirects are not followed: dart:io copies custom headers (a gateway's
  /// `CF-Access-Client-Secret`…) to any redirect target, other hosts and
  /// plain http included, and zhang's API never redirects. A 3xx is an
  /// [ApiRedirect].
  static Dio createDio(ServerProfile profile) {
    final dio = Dio(
      BaseOptions(
        baseUrl: profile.apiBaseUrl,
        connectTimeout: connectTimeout,
        receiveTimeout: receiveTimeout,
        sendTimeout: receiveTimeout,
        responseType: ResponseType.json,
        headers: {'Accept': 'application/json'},
        followRedirects: false,
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
  Future<ServerInfo> info() => get(ZhangEndpoints.info, decode: ServerInfo.fromJson);

  /// `GET /api/auth/status` – sign-in methods of the server; needs no
  /// credentials (zhang ≥ 0.2).
  Future<AuthStatus> authStatus() => get(ZhangEndpoints.authStatus, decode: AuthStatus.fromJson);

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

  /// [headers] are added to this request (e.g. `If-Match`).
  Future<T> post<T>(String path, {Object? body, Map<String, String>? headers, required DataDecoder<T> decode}) =>
      _json('POST', path, body: body, headers: headers, decode: decode);

  Future<T> put<T>(String path, {Object? body, required DataDecoder<T> decode}) =>
      _json('PUT', path, body: body, decode: decode);

  /// [method] [path] for a write whose answer only adds to it (the id a
  /// create wrote): the envelope's `data` with the response headers (e.g.
  /// `Idempotency-Replayed`). A 2xx whose body is empty or no JSON envelope
  /// (a proxy in front of zhang) is still a success, with `null` data;
  /// errors are thrown as usual.
  Future<({Object? data, Headers headers})> write(
    String method,
    String path, {
    Object? body,
    Map<String, String>? headers,
  }) async {
    // Bytes, decoded here: dio JSON-decodes any other response type of a
    // typed request, and fails on a body that is not JSON.
    final res = await _send(method, path, body: body, headers: headers, responseType: ResponseType.bytes);
    return (data: _lenientData(res.data), headers: res.headers);
  }

  /// The `data` of a JSON envelope in [body] (bytes), `null` when there is
  /// none.
  static Object? _lenientData(Object? body) {
    final text = body is List<int> ? utf8.decode(body, allowMalformed: true) : '';
    if (text.trim().isEmpty) return null;
    try {
      final json = jsonDecode(text);
      return json is Map && json.containsKey('data') ? json['data'] : null;
    } on FormatException {
      return null;
    }
  }

  /// For endpoints whose result is irrelevant: `201` with empty body, or
  /// `200 {"data":"Ok"}` / `{"data":null}`. A non-JSON `200` (the server's
  /// text fallback for unknown paths) is still an [ApiParseError].
  Future<void> send(
    String method,
    String path, {
    Object? body,
    Map<String, Object?>? query,
    Map<String, String>? headers,
  }) async {
    final res = await _send(method, path, body: body, query: query, headers: headers);
    final data = res.data;
    if (data == null || (data is String && data.isEmpty) || data is Map) return;
    if (res.statusCode == 201 || res.statusCode == 204) return;
    throw ApiParseError(_notJsonMessage(res));
  }

  /// GET raw bytes (document downloads). With [maxBytes] the download is
  /// cancelled as soon as the announced or received size exceeds it and
  /// [ResponseTooLarge] is thrown.
  Future<Uint8List> getBytes(String path, {int? maxBytes}) async {
    final cancel = maxBytes == null ? null : CancelToken();
    var tooLarge = false;
    final Response<Object?> res;
    try {
      res = await _send(
        'GET',
        path,
        responseType: ResponseType.bytes,
        cancelToken: cancel,
        onReceiveProgress: maxBytes == null
            ? null
            : (received, total) {
                if (tooLarge || (received <= maxBytes && total <= maxBytes)) return;
                tooLarge = true;
                cancel!.cancel('larger than $maxBytes bytes');
              },
      );
    } on ApiNetworkError {
      if (tooLarge) throw ResponseTooLarge(maxBytes!);
      rethrow;
    }
    final data = res.data;
    final bytes = data is Uint8List
        ? data
        : data is List<int>
        ? Uint8List.fromList(data)
        : Uint8List(0);
    // The body may have arrived in one chunk before the cancel took effect.
    if (tooLarge || (maxBytes != null && bytes.length > maxBytes)) throw ResponseTooLarge(maxBytes!);
    return bytes;
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
    Map<String, String>? headers,
    required DataDecoder<T> decode,
  }) async {
    final res = await _send(method, path, body: body, query: query, headers: headers);
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
    CancelToken? cancelToken,
    ProgressCallback? onReceiveProgress,
    Map<String, String>? headers,
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
          headers: headers,
          responseType: responseType,
          contentType: body == null ? null : Headers.jsonContentType,
        ),
        cancelToken: cancelToken,
        onReceiveProgress: onReceiveProgress,
      );
    } on DioException catch (e) {
      throw mapDioException(e);
    }
  }

  /// Returns the `data` member of a JSON envelope or throws [ApiParseError]
  /// (non-JSON body – the URL is not a zhang API – or no envelope).
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
        if (status >= 300 && status < 400) {
          return ApiRedirect(status, e.response?.headers.value('location'), from: e.requestOptions.uri);
        }
        if (status == 429) {
          return ApiRateLimited(
            message: message,
            retryAfter: ApiRateLimited.parseRetryAfter(e.response?.headers.value('retry-after')),
          );
        }
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

  /// Error text: zhang's JSON `message`, else a plain-text body (e.g. from
  /// a reverse proxy), else `HTTP <status>`.
  static String errorMessageOf(Object? body, int status) {
    if (body is Map && body['message'] is String) return body['message'] as String;
    final text = switch (body) {
      String() => body.trim(),
      List<int>() => utf8.decode(body.length > 4096 ? body.sublist(0, 4096) : body, allowMalformed: true).trim(),
      _ => '',
    };
    if (text.isEmpty) return 'HTTP $status';
    // zhang's JSON error read as bytes ([write], [getBytes]).
    if (text.startsWith('{')) {
      try {
        final json = jsonDecode(text);
        if (json is Map && json['message'] is String) return json['message'] as String;
      } on FormatException {
        // not JSON after all
      }
    }
    return text.length > 300 ? '${text.substring(0, 300)}…' : text;
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

/// The client for the **active** profile, behind its version gate
/// ([gatedClient]): until `/api/info` has shown a zhang ≥ 0.2 server only the
/// probes (`/api/info`, `/api/auth/status`) are sent; on an older server
/// every other request fails with [ApiServerTooOld] without being sent.
///
/// In the app it lives in a ledger session (`LedgerSessionHost`): one client
/// per session, closed with it when the active profile is switched or
/// edited, together with everything that watched it.
///
/// Throws [NoActiveProfileException] when no profile is active; the router
/// never shows feature screens in that state.
final zhangApiClientProvider = Provider<ZhangApiClient>((ref) {
  final profile = ref.watch(activeProfileProvider);
  if (profile == null) throw const NoActiveProfileException();
  return gatedClient(ref, ZhangApiClient(profile));
});
