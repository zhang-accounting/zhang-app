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
/// }
/// ```
sealed class ZhangApiException implements Exception {
  const ZhangApiException(this.message);

  /// Developer-facing description (not localised; never contains secrets).
  final String message;

  /// HTTP status when the server answered, else `null`.
  int? get statusCode => null;

  @override
  String toString() => '$runtimeType: $message';
}

/// 401 (or 403): credentials missing or wrong. zhang returns an empty body
/// with `www-authenticate: Basic`.
final class ApiUnauthorized extends ZhangApiException {
  const ApiUnauthorized({this.status = 401, String message = 'unauthorized'})
    : super(message);

  final int status;

  @override
  int get statusCode => status;
}

/// 404 `{"message":"not found"}`.
final class ApiNotFound extends ZhangApiException {
  const ApiNotFound([super.message = 'not found']);

  @override
  int get statusCode => 404;
}

/// Any other non-2xx answer (400, 405, 415, 422, 500…). [message] is the
/// server's JSON `message`, else the plain-text body, else `HTTP <status>`.
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

/// A response arrived but was not what we expected: not JSON (e.g. the
/// `200 text/plain` fallback for unknown paths, or a URL that is not a zhang
/// server), missing the `{"data": …}` envelope, or a payload that failed
/// to decode into a model.
final class ApiParseError extends ZhangApiException {
  const ApiParseError(super.message, {this.cause});

  final Object? cause;
}

/// Thrown by `zhangApiClientProvider` when read without an active profile.
/// The router keeps the app on onboarding in that case, so feature screens
/// should never see this.
final class NoActiveProfileException implements Exception {
  const NoActiveProfileException();

  @override
  String toString() => 'NoActiveProfileException: no server profile is active';
}
