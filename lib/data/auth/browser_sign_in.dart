import 'dart:developer' as developer;

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_web_auth_2/flutter_web_auth_2.dart';

import '../api/api_exception.dart';
import '../api/endpoints.dart';
import '../api/zhang_api_client.dart';
import '../models/auth_status.dart';
import '../models/json_utils.dart';
import '../profiles/server_profile.dart';

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
  /// `zhang-app://auth/callback?code=<one-time code>`.
  malformedCallback,

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
/// 2. open `<base>/login?return_to=zhang-app%3A%2F%2Fauth%2Fcallback` in the
///    system browser; the user signs in with a passkey or password there,
/// 3. the page redirects to `zhang-app://auth/callback?code=<one-time code>`
///    (60 s, single use); only that `code` is read from the callback,
/// 4. `POST /api/auth/app/exchange {"code"}` → [SessionGrant].
///
/// Tests inject [launch] (no browser) and [createClient] (fake adapter).
/// Never logs codes or tokens.
class BrowserSignIn {
  BrowserSignIn({WebAuthLauncher? launch, this.createClient = ZhangApiClient.new})
    : launch = launch ?? systemBrowserLauncher;

  final WebAuthLauncher launch;

  /// Builds the (credential-less) client for the server being signed in to.
  final ZhangApiClient Function(ServerProfile profile) createClient;

  static const callbackScheme = 'zhang-app';
  static const callbackUrl = '$callbackScheme://auth/callback';

  /// The server's login page, told to return to the app.
  static String loginUrl(String baseUrl) =>
      '$baseUrl/login?return_to=${Uri.encodeQueryComponent(callbackUrl)}';

  static final _codePattern = RegExp(r'^[A-Za-z0-9_-]{16,512}={0,2}$');

  /// The one-time code of a callback URL. Accepts exactly
  /// `zhang-app://auth/callback?code=<base64url>`: any other scheme, host or
  /// path, a fragment, a missing / repeated / malformed `code` or any other
  /// query parameter throws [BrowserSignInFailure.malformedCallback].
  static String codeFromCallback(String callback) {
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
    if (params.length != 1) throw malformed;
    final codes = params['code'];
    if (codes == null || codes.length != 1 || !_codePattern.hasMatch(codes.single)) throw malformed;
    return codes.single;
  }

  /// `GET /api/auth/status` of [baseUrl] (no credentials).
  Future<AuthStatus> status(String baseUrl, {bool allowSelfSigned = false}) =>
      _withClient(baseUrl, allowSelfSigned, (client) => client.authStatus());

  /// The whole flow: checks `/api/auth/status` first (throws
  /// [BrowserSignInFailure.notNeeded] / [BrowserSignInFailure.notSupported]),
  /// then [startBrowserSignIn].
  Future<SessionGrant> signIn(String baseUrl, {bool allowSelfSigned = false}) async {
    final status = await this.status(baseUrl, allowSelfSigned: allowSelfSigned);
    if (!status.enabled) throw const BrowserSignInException(BrowserSignInFailure.notNeeded);
    if (!status.supportsAppLogin) throw const BrowserSignInException(BrowserSignInFailure.notSupported);
    return startBrowserSignIn(baseUrl, allowSelfSigned: allowSelfSigned);
  }

  /// Opens the login page in the system browser and exchanges the returned
  /// code (steps 2–4, no status check).
  Future<SessionGrant> startBrowserSignIn(String baseUrl, {bool allowSelfSigned = false}) async {
    final String callback;
    try {
      callback = await launch(loginUrl(baseUrl), callbackScheme);
    } on PlatformException catch (e) {
      if (e.code == 'CANCELED') throw const BrowserSignInException(BrowserSignInFailure.cancelled);
      throw BrowserSignInException(BrowserSignInFailure.browserFailed, detail: '${e.code}: ${e.message}');
    } on BrowserSignInException {
      rethrow;
    } catch (e) {
      throw BrowserSignInException(BrowserSignInFailure.browserFailed, detail: '${e.runtimeType}');
    }
    return completeSignIn(baseUrl, callback, allowSelfSigned: allowSelfSigned);
  }

  /// Steps 3–4 for a callback URL the browser returned. Also the entry point
  /// for tests that obtain the callback without a browser.
  Future<SessionGrant> completeSignIn(String baseUrl, String callback, {bool allowSelfSigned = false}) async =>
      exchange(baseUrl, codeFromCallback(callback), allowSelfSigned: allowSelfSigned);

  /// `POST /api/auth/app/exchange {"code"}` (no credentials: the code is
  /// one). `401` → [BrowserSignInFailure.codeRejected], `429` →
  /// [BrowserSignInFailure.rateLimited]; anything else is a
  /// [ZhangApiException].
  Future<SessionGrant> exchange(String baseUrl, String code, {bool allowSelfSigned = false}) async {
    try {
      final grant = await _withClient(
        baseUrl,
        allowSelfSigned,
        (client) => client.post(
          ZhangEndpoints.authAppExchange,
          body: {'code': code},
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

final browserSignInProvider = Provider<BrowserSignIn>(
  (ref) => BrowserSignIn(launch: ref.watch(webAuthLauncherProvider)),
);
