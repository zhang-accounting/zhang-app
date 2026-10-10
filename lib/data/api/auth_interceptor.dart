import 'package:dio/dio.dart';

import '../profiles/server_profile.dart';

/// Adds the profile's auth header(s) (see [ServerProfile.authHeaders]) to
/// every request: Basic / Bearer `Authorization`, or the custom headers.
class AuthInterceptor extends Interceptor {
  AuthInterceptor(this.profile);

  final ServerProfile profile;

  @override
  void onRequest(RequestOptions options, RequestInterceptorHandler handler) {
    options.headers.addAll(profile.authHeaders());
    handler.next(options);
  }
}
