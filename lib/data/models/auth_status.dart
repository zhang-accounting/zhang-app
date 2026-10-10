import 'json_utils.dart';

/// `GET /api/auth/status` (no credentials needed): which sign-in methods the
/// server accepts and whether this request is authenticated.
class AuthStatus {
  const AuthStatus({
    required this.enabled,
    required this.authenticated,
    required this.password,
    required this.passkey,
    this.user,
    this.title,
    this.appLogin = false,
    this.appReturnSchemes = const [],
  });

  factory AuthStatus.fromJson(Object? json) {
    final m = asMap(json, 'auth status');
    final methods = m['methods'] == null ? const <String, Object?>{} : asMap(m['methods'], 'methods');
    return AuthStatus(
      enabled: optBool(m, 'enabled'),
      authenticated: optBool(m, 'authenticated'),
      password: optBool(methods, 'password'),
      passkey: optBool(methods, 'passkey'),
      user: optString(m, 'user'),
      title: optString(m, 'title'),
      appLogin: optBool(m, 'app_login'),
      appReturnSchemes: stringList(m['app_return_schemes']),
    );
  }

  /// Whether any sign-in method is on (every other `/api` route then needs
  /// credentials).
  final bool enabled;
  final bool authenticated;

  /// Password sign-in (`ZHANG_AUTH`); HTTP Basic is accepted only then.
  final bool password;

  /// Passkey sign-in (`ZHANG_PASSKEY`).
  final bool passkey;
  final String? user;
  final String? title;

  /// The server supports the browser sign-in handoff: its login page accepts
  /// `?return_to=` and `POST /api/auth/app/exchange` trades the returned
  /// one-time code for a session token (zhang PR #786).
  final bool appLogin;

  /// URL schemes the login page may return to (`["zhang-app"]` by default,
  /// `ZHANG_APP_RETURN_SCHEMES`).
  final List<String> appReturnSchemes;

  /// Passkeys only: HTTP Basic cannot sign in.
  bool get isPasskeyOnly => enabled && !password;

  /// The app can sign in through the browser: the handoff is on and accepts
  /// the app's `zhang-app` scheme (an empty list is taken as the default).
  bool get supportsAppLogin =>
      appLogin && (appReturnSchemes.isEmpty || appReturnSchemes.contains('zhang-app'));
}
