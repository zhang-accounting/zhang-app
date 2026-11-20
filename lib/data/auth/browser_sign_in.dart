import 'dart:convert';
import 'dart:developer' as developer;
import 'dart:math';

import 'package:crypto/crypto.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_web_auth_2/flutter_web_auth_2.dart';

import '../api/api_exception.dart';
import '../api/endpoints.dart';
import '../api/zhang_api_client.dart';
import '../models/auth_status.dart';
import '../models/json_utils.dart';
import '../profiles/profile_providers.dart';
import '../profiles/server_profile.dart';
import 'pkce_servers.dart';

/// What a successful browser sign-in yields: zhang's session token (sent as
/// `Authorization: Bearer`), when it stops working and who signed in.
///
/// [toString] never includes the token.
@immutable
class SessionGrant {
  const SessionGrant({required this.token, required this.expiresAt, required this.user});

  /// `POST /api/auth/app/exchange` → `{"token","expires_at","user"}`.
  factory SessionGrant.fromJson(Object? json) {
    final m = asMap(json, 'session');
    final token = reqString(m, 'token');
    if (token.isEmpty) throw const FormatException('empty session token');
    final expires = DateTime.parse(reqString(m, 'expires_at')).toUtc();
    return SessionGrant(token: token, expiresAt: expires, user: optString(m, 'user') ?? '');
  }

  final String token;

  /// UTC.
  final DateTime expiresAt;
  final String user;

  /// [profile] switched to [AuthType.session] with this session.
  ServerProfile applyTo(ServerProfile profile) => profile.copyWith(
    authType: AuthType.session,
    sessionToken: token,
    sessionExpiresAt: expiresAt,
    sessionUser: user,
  );

  @override
  String toString() => 'SessionGrant(user: $user, expiresAt: $expiresAt)';
}

/// The secrets of one browser sign-in: a PKCE code verifier (RFC 7636) and a
/// `state`, each 32 bytes of a CSPRNG, base64url without padding (43
/// characters). The login URL carries [codeChallenge] (`S256`) and [state];
/// the callback must echo [state] and the exchange sends [codeVerifier], so an
/// app that intercepts the `zhang-app://` callback cannot use the code.
///
/// [toString] never includes them.
@immutable
class SignInSecrets {
  const SignInSecrets({required this.codeVerifier, required this.state});

  /// Fresh secrets from [random] (default `Random.secure()`).
  factory SignInSecrets.generate([Random? random]) {
    final r = random ?? Random.secure();
    return SignInSecrets(codeVerifier: _randomToken(r), state: _randomToken(r));
  }

  final String codeVerifier;
  final String state;

  /// `BASE64URL(SHA256(code_verifier))` without padding (method `S256`).
  String get codeChallenge => _base64UrlNoPadding(sha256.convert(ascii.encode(codeVerifier)).bytes);

  static String _randomToken(Random random) => _base64UrlNoPadding(List<int>.generate(32, (_) => random.nextInt(256)));

  @override
  String toString() => 'SignInSecrets(<redacted>)';
}

/// RFC 4648 §5 base64url without the `=` padding (RFC 7636 appendix A).
String _base64UrlNoPadding(List<int> bytes) => base64Url.encode(bytes).replaceAll('=', '');

/// Why a browser sign-in did not produce a session.
enum BrowserSignInFailure {
  /// `/api/auth/status.enabled == false`: the server needs no sign-in.
  notNeeded,

  /// Sign-in is on but the server has no app handoff (zhang without PR #786,
  /// or `ZHANG_APP_RETURN_SCHEMES` without `zhang-app`).
  notSupported,

  /// The user closed the browser sheet.
  cancelled,

  /// The system browser could not be opened.
  browserFailed,

  /// The browser returned something other than
  /// `zhang-app://auth/callback?code=<one-time code>[&state=<state>]`.
  malformedCallback,

  /// The callback's `state` is not the one this sign-in sent, or is missing
  /// although the server echoes it (`app_login_pkce`): the callback answers a
  /// sign-in the app did not start, so its code is never exchanged.
  stateMismatch,

  /// `401` from the exchange: the code is unknown, expired (60 s) or used.
  codeRejected,

  /// `429` from the exchange: too many failed attempts from this client.
  rateLimited,
}

class BrowserSignInException implements Exception {
  const BrowserSignInException(this.kind, {this.retryAfter, this.detail});

  final BrowserSignInFailure kind;

  /// [BrowserSignInFailure.rateLimited]: the server's `Retry-After`.
  final Duration? retryAfter;

  /// Developer-facing detail (never contains the code or a token).
  final String? detail;

  @override
  String toString() => 'BrowserSignInException(${kind.name}${detail == null ? '' : ': $detail'})';
}

/// Opens [url] in the system browser (iOS `ASWebAuthenticationSession`,
/// Android Custom Tabs / Auth Tab) and completes with the URL the page
/// redirected to once it reached [callbackScheme].
typedef WebAuthLauncher = Future<String> Function(String url, String callbackScheme);

/// The real launcher: `flutter_web_auth_2` with an ephemeral session, so no
/// cookie of an earlier sign-in is reused and every sign-in is fresh.
Future<String> systemBrowserLauncher(String url, String callbackScheme) => FlutterWebAuth2.authenticate(
  url: url,
  callbackUrlScheme: callbackScheme,
  options: const FlutterWebAuth2Options(preferEphemeral: true),
);

/// Browser sign-in handoff (docs/passkey-login.md):
///
/// 1. `GET /api/auth/status` – sign-in enabled and `app_login` supported?
///    `app_login_pkce` – does the server echo `state` and check the verifier?
///    (remembered per server in [pkceServers]: once seen, always required)
/// 2. fresh [SignInSecrets]; open
///    `<base>/login?return_to=zhang-app%3A%2F%2Fauth%2Fcallback&code_challenge=…&code_challenge_method=S256&state=…`
///    in the system browser; the user signs in with a passkey or password,
/// 3. the page redirects to `zhang-app://auth/callback?code=<one-time code>&state=<state>`
///    (60 s, single use); the `state` must be this sign-in's (a server
///    without `app_login_pkce` ignores the extra parameters and echoes none),
/// 4. `POST /api/auth/app/exchange {"code","code_verifier"}` → [SessionGrant].
///
/// Tests inject [launch] (no browser), [createClient] (fake adapter),
/// [newSecrets] and [pkceServers]. Never logs codes, verifiers, states or
/// tokens.
class BrowserSignIn {
  BrowserSignIn({
    WebAuthLauncher? launch,
    this.createClient = ZhangApiClient.new,
    this.newSecrets = SignInSecrets.generate,
    PkceServers? pkceServers,
  }) : launch = launch ?? systemBrowserLauncher,
       pkceServers = pkceServers ?? PkceServers();

  final WebAuthLauncher launch;

  /// Builds the (credential-less) client for the server being signed in to.
  final ZhangApiClient Function(ServerProfile profile) createClient;

  /// The secrets of each new sign-in.
  final SignInSecrets Function() newSecrets;

  /// The servers that reported `app_login_pkce: true` before.
  final PkceServers pkceServers;

  static const callbackScheme = 'zhang-app';
  static const callbackUrl = '$callbackScheme://auth/callback';

  /// The server's login page, told to return to the app, with the PKCE
  /// challenge and the state of [secrets].
  static String loginUrl(String baseUrl, SignInSecrets secrets) {
    final query = Uri(
      queryParameters: {
        'return_to': callbackUrl,
        'code_challenge': secrets.codeChallenge,
        'code_challenge_method': 'S256',
        'state': secrets.state,
      },
    ).query;
    return '$baseUrl/login?$query';
  }

  static final _codePattern = RegExp(r'^[A-Za-z0-9_-]{16,512}={0,2}$');

  /// The one-time code of a callback URL. Accepts exactly
  /// `zhang-app://auth/callback?code=<base64url>[&state=<state>]`: any other
  /// scheme, host or path, a fragment, a missing / repeated / malformed
  /// `code`, a repeated `state` or any other query parameter throws
  /// [BrowserSignInFailure.malformedCallback].
  ///
  /// The `state` must be [state] (constant-time comparison); without one the
  /// callback is accepted only when ![stateRequired] (a server without
  /// `app_login_pkce` ignores the state it was sent). Otherwise throws
  /// [BrowserSignInFailure.stateMismatch].
  static String codeFromCallback(String callback, {required String state, required bool stateRequired}) {
    const malformed = BrowserSignInException(BrowserSignInFailure.malformedCallback);
    final uri = Uri.tryParse(callback.trim());
    if (uri == null ||
        uri.scheme != callbackScheme ||
        uri.host != 'auth' ||
        uri.path != '/callback' ||
        uri.hasFragment ||
        uri.userInfo.isNotEmpty ||
        uri.hasPort) {
      throw malformed;
    }
    final params = uri.queryParametersAll;
    if (params.keys.any((name) => name != 'code' && name != 'state')) throw malformed;
    final codes = params['code'];
    if (codes == null || codes.length != 1 || !_codePattern.hasMatch(codes.single)) throw malformed;
    final states = params['state'];
    if (states != null && states.length != 1) throw malformed;
    final returned = states?.single;
    if (returned == null ? stateRequired : !_sameSecret(returned, state)) {
      throw const BrowserSignInException(
        BrowserSignInFailure.stateMismatch,
        detail: 'the callback does not carry the state of this sign-in',
      );
    }
    return codes.single;
  }

  /// Compares two strings without stopping at the first difference.
  static bool _sameSecret(String a, String b) {
    final x = utf8.encode(a);
    final y = utf8.encode(b);
    var diff = x.length ^ y.length;
    for (var i = 0; i < x.length && i < y.length; i++) {
      diff |= x[i] ^ y[i];
    }
    return diff == 0;
  }

  /// `GET /api/auth/status` of [baseUrl] (no credentials); remembers
  /// `app_login_pkce: true` in [pkceServers].
  Future<AuthStatus> status(String baseUrl, {bool allowSelfSigned = false}) async {
    final status = await _withClient(baseUrl, allowSelfSigned, (client) => client.authStatus());
    if (status.appLoginPkce) await pkceServers.remember(baseUrl);
    return status;
  }

  /// The whole flow: checks `/api/auth/status` first (throws
  /// [BrowserSignInFailure.notNeeded] / [BrowserSignInFailure.notSupported]),
  /// then [startBrowserSignIn].
  Future<SessionGrant> signIn(String baseUrl, {bool allowSelfSigned = false}) async {
    final status = await this.status(baseUrl, allowSelfSigned: allowSelfSigned);
    if (!status.enabled) throw const BrowserSignInException(BrowserSignInFailure.notNeeded);
    if (!status.supportsAppLogin) throw const BrowserSignInException(BrowserSignInFailure.notSupported);
    return startBrowserSignIn(baseUrl, pkce: status.appLoginPkce, allowSelfSigned: allowSelfSigned);
  }

  /// Opens the login page in the system browser and exchanges the returned
  /// code (steps 2–4, no status check). [pkce] is the server's
  /// `app_login_pkce` (`AuthStatus.appLoginPkce`): then, and whenever
  /// [pkceServers] saw it before for [baseUrl], the callback must echo the
  /// state.
  Future<SessionGrant> startBrowserSignIn(String baseUrl, {required bool pkce, bool allowSelfSigned = false}) async {
    if (pkce) await pkceServers.remember(baseUrl);
    final stateRequired = pkce || pkceServers.contains(baseUrl);
    final secrets = newSecrets();
    final String callback;
    try {
      callback = await launch(loginUrl(baseUrl, secrets), callbackScheme);
    } on PlatformException catch (e) {
      if (e.code == 'CANCELED') throw const BrowserSignInException(BrowserSignInFailure.cancelled);
      throw BrowserSignInException(BrowserSignInFailure.browserFailed, detail: '${e.code}: ${e.message}');
    } on BrowserSignInException {
      rethrow;
    } catch (e) {
      throw BrowserSignInException(BrowserSignInFailure.browserFailed, detail: '${e.runtimeType}');
    }
    return completeSignIn(baseUrl, callback, secrets, pkce: stateRequired, allowSelfSigned: allowSelfSigned);
  }

  /// Steps 3–4 for a callback URL the browser returned to the sign-in of
  /// [secrets]: checks the state ([codeFromCallback], `stateRequired` =
  /// [pkce]), then exchanges the code with the verifier. Also the entry
  /// point for tests that obtain the callback without a browser.
  Future<SessionGrant> completeSignIn(
    String baseUrl,
    String callback,
    SignInSecrets secrets, {
    required bool pkce,
    bool allowSelfSigned = false,
  }) async => exchange(
    baseUrl,
    codeFromCallback(callback, state: secrets.state, stateRequired: pkce),
    codeVerifier: secrets.codeVerifier,
    allowSelfSigned: allowSelfSigned,
  );

  /// `POST /api/auth/app/exchange {"code","code_verifier"}` (no credentials:
  /// the code and the verifier are). A server without `app_login_pkce`
  /// ignores the verifier. `401` → [BrowserSignInFailure.codeRejected]
  /// (also a wrong verifier, which uses the code up), `429` →
  /// [BrowserSignInFailure.rateLimited]; anything else is a
  /// [ZhangApiException].
  Future<SessionGrant> exchange(
    String baseUrl,
    String code, {
    required String? codeVerifier,
    bool allowSelfSigned = false,
  }) async {
    try {
      final grant = await _withClient(
        baseUrl,
        allowSelfSigned,
        (client) => client.post(
          ZhangEndpoints.authAppExchange,
          body: {'code': code, 'code_verifier': ?codeVerifier},
          decode: SessionGrant.fromJson,
        ),
      );
      developer.log('browser sign-in: session for "${grant.user}" until ${grant.expiresAt}', name: 'zhang.auth');
      return grant;
    } on ApiUnauthorized {
      throw const BrowserSignInException(BrowserSignInFailure.codeRejected);
    } on ApiRateLimited catch (e) {
      throw BrowserSignInException(BrowserSignInFailure.rateLimited, retryAfter: e.retryAfter);
    } on ZhangApiException catch (e) {
      // A server without the handoff has no such route.
      if (e.isMissingRoute) throw const BrowserSignInException(BrowserSignInFailure.notSupported);
      rethrow;
    }
  }

  /// Best effort `POST /api/auth/logout` with [profile]'s session. zhang's
  /// tokens are stateless (the call only clears a cookie), so this does not
  /// revoke the token; callers forget it locally. Never throws.
  Future<void> logout(ServerProfile profile) async {
    if (!profile.hasSession) return;
    final client = createClient(profile);
    try {
      await client.send('POST', ZhangEndpoints.authLogout).timeout(const Duration(seconds: 5));
    } catch (e) {
      developer.log('logout failed (ignored): ${e.runtimeType}', name: 'zhang.auth');
    } finally {
      client.close();
    }
  }

  Future<T> _withClient<T>(String baseUrl, bool allowSelfSigned, Future<T> Function(ZhangApiClient) run) async {
    final client = createClient(
      ServerProfile(id: 'browser-sign-in', name: '', baseUrl: baseUrl, allowSelfSigned: allowSelfSigned),
    );
    try {
      return await run(client);
    } finally {
      client.close();
    }
  }
}

/// The launcher used by [browserSignInProvider]. Integration tests override
/// it to hand back a callback obtained over HTTP instead of a browser.
final webAuthLauncherProvider = Provider<WebAuthLauncher>((ref) => systemBrowserLauncher);

/// [PkceServers] in the app's [SharedPreferences].
final pkceServersProvider = Provider<PkceServers>((ref) => PkceServers(ref.watch(sharedPreferencesProvider)));

final browserSignInProvider = Provider<BrowserSignIn>(
  (ref) => BrowserSignIn(launch: ref.watch(webAuthLauncherProvider), pkceServers: ref.watch(pkceServersProvider)),
);
