/// Errors thrown by `ZhangApiClient` and every repository.
///
/// UI code should switch over the sealed hierarchy (or use
/// `describeApiError` / `ErrorView` from `lib/core/widgets/error_view.dart`):
///
/// ```dart
/// switch (error) {
///   ApiUnauthorized() => ...,  // 401/403: wrong credentials
///   ApiNotFound() => ...,      // 404
///   ApiServerError(:final statusCode, :final message) => ...,
///   ApiNetworkError(:final kind) => ...,   // offline, timeout, TLS, crash
///   ApiParseError() => ...,    // not a zhang server / unexpected payload
///   ApiServerTooOld() => ...,  // zhang < 0.2 (no built-in query API)
///   ApiPasskeyOnly() => ...,   // the server only allows passkey sign-in
/// }
/// ```
///
/// zhang ≥ 0.2 always answers errors as JSON `{"message": …}`. A request to a
/// route the server does not have answers `404 no route GET /api/x` (or `405
/// … the path takes another method`); see [ZhangApiException.isMissingRoute].
sealed class ZhangApiException implements Exception {
  const ZhangApiException(this.message);

  /// Developer-facing description (not localised; never contains secrets).
  final String message;

  /// HTTP status when the server answered, else `null`.
  int? get statusCode => null;

  /// The server has no such route (`404`/`405` `no route …`): the app and
  /// the server speak different API versions.
  bool get isMissingRoute =>
      (statusCode == 404 || statusCode == 405) && message.startsWith('no route ');

  @override
  String toString() => '$runtimeType: $message';
}

/// 401 (or 403): credentials missing or wrong. zhang answers
/// `401 {"message":"unauthorized"}` (no `WWW-Authenticate` header).
final class ApiUnauthorized extends ZhangApiException {
  const ApiUnauthorized({this.status = 401, String message = 'unauthorized'})
    : super(message);

  final int status;

  @override
  int get statusCode => status;
}

/// 404: `{"message":"not found"}`, `there is no built-in query x`, or
/// `no route GET /api/x` (see [ZhangApiException.isMissingRoute]).
final class ApiNotFound extends ZhangApiException {
  const ApiNotFound([super.message = 'not found']);

  @override
  int get statusCode => 404;
}

/// Any other non-2xx answer (400 bad parameter, 405 wrong method, 409 reload
/// failed, 415, 422, 500…). [message] is the server's JSON `message`, else
/// the plain-text body, else `HTTP <status>`.
final class ApiServerError extends ZhangApiException {
  const ApiServerError(this.status, super.message);

  final int status;

  @override
  int get statusCode => status;
}

enum NetworkErrorKind {
  /// DNS failure, connection refused, connection reset/closed (zhang closes
  /// the connection without a response when a handler panics).
  connection,
  timeout,

  /// TLS handshake / certificate problem (see `allowSelfSigned`).
  certificate,
  cancelled,
  unknown,
}

/// No (complete) HTTP response was received.
final class ApiNetworkError extends ZhangApiException {
  const ApiNetworkError(this.kind, super.message, {this.cause});

  final NetworkErrorKind kind;
  final Object? cause;
}

/// A response arrived but was not what we expected: not JSON (a URL that is
/// not a zhang server, or the `200 text/plain` frontend fallback of servers
/// older than 0.2), missing the `{"data": …}` envelope, or a payload that
/// failed to decode into a model.
final class ApiParseError extends ZhangApiException {
  const ApiParseError(super.message, {this.cause});

  final Object? cause;
}

/// The server is a zhang older than 0.2: `GET /api/info` has no `format`
/// key, so the built-in query API the app reads every figure from is
/// missing. Nothing else is requested from such a server.
final class ApiServerTooOld extends ZhangApiException {
  const ApiServerTooOld(this.version)
    : super('zhang $version has no built-in query API (zhang >= 0.2 is required)');

  /// `version` reported by `/api/info`.
  final String version;
}

/// The server only allows passkey sign-in (`ZHANG_PASSKEY` without
/// `ZHANG_AUTH`): it refuses HTTP Basic, and the app cannot do WebAuthn.
final class ApiPasskeyOnly extends ZhangApiException {
  const ApiPasskeyOnly() : super('the server only allows passkey sign-in');

  @override
  int get statusCode => 401;
}

/// Thrown by `zhangApiClientProvider` when read without an active profile.
/// The router keeps the app on onboarding in that case, so feature screens
/// should never see this.
final class NoActiveProfileException implements Exception {
  const NoActiveProfileException();

  @override
  String toString() => 'NoActiveProfileException: no server profile is active';
}
