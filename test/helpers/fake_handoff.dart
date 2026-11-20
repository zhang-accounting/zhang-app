import 'package:zhang_app/data/auth/browser_sign_in.dart';

/// What zhang's login page and `POST /api/auth/app/exchange` do with the
/// browser sign-in's PKCE challenge and state, for the fake servers: the
/// callback for a login URL echoes its `state` and the exchange needs the
/// code verifier of its `code_challenge`. With [pkce] off it behaves like a
/// server without `app_login_pkce` (ignores both).
class FakeHandoff {
  FakeHandoff(this.code);

  /// The one-time code every callback carries.
  final String code;

  /// The server reports `app_login_pkce` and checks the verifier.
  bool pkce = true;

  /// The next callback leaves the state out (or carries this one instead).
  bool dropNextState = false;
  String? plantNextState;

  String? _challenge;

  /// The `zhang-app://` callback the login page redirects to for [loginUrl].
  String callbackFor(String loginUrl, String scheme) {
    final query = Uri.parse(loginUrl).queryParameters;
    final base = '$scheme://auth/callback?code=$code';
    if (!pkce) return base;
    _challenge = query['code_challenge_method'] == 'S256' ? query['code_challenge'] : null;
    final state = plantNextState ?? query['state'];
    final drop = dropNextState;
    dropNextState = false;
    plantNextState = null;
    if (drop || state == null) return base;
    return '$base&state=${Uri.encodeQueryComponent(state)}';
  }

  /// Whether the exchange request body [data] gets the session.
  bool accepts(Object? data) {
    if (data is! Map || data['code'] != code) return false;
    if (!pkce) return true;
    final verifier = data['code_verifier'];
    final challenge = _challenge;
    _challenge = null;
    return verifier is String &&
        challenge != null &&
        SignInSecrets(codeVerifier: verifier, state: '').codeChallenge == challenge;
  }
}
