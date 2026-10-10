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

  /// Passkeys only: the app (HTTP Basic) cannot sign in.
  bool get isPasskeyOnly => enabled && !password;
}
