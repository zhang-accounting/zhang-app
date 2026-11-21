import 'package:dio/dio.dart';

import '../profiles/server_profile.dart';

/// Adds the profile's auth headers (see [ServerProfile.authHeaders]) to
/// every request: the sign-in method's `Authorization` and the custom
/// headers. The request's own headers win (decisions.md §7): a custom
/// `Accept`, `Content-Type`, `If-Match`… only fills a header the client or
/// the request did not set, so it cannot replace SSE's `Accept` or an edit's
/// `If-Match`. Header names compare case-insensitively (dio's header map).
class AuthInterceptor extends Interceptor {
  AuthInterceptor(this.profile);

  final ServerProfile profile;

  @override
  void onRequest(RequestOptions options, RequestInterceptorHandler handler) {
    for (final e in profile.authHeaders().entries) {
      options.headers.putIfAbsent(e.key, () => e.value);
    }
    handler.next(options);
  }
}
