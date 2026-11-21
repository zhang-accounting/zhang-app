import 'dart:convert';
import 'dart:math';

import 'package:dio/dio.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:zhang_app/data/api/api_exception.dart';
import 'package:zhang_app/data/api/zhang_api_client.dart';
import 'package:zhang_app/data/auth/browser_sign_in.dart';
import 'package:zhang_app/data/auth/pkce_servers.dart';
import 'package:zhang_app/data/profiles/server_profile.dart';

import '../helpers/fake_adapter.dart';

const _base = 'http://127.0.0.1:18100';
const _code = 'q3Hn0Zx4c0QyX2xJm9Yb8kq1sV7tWw5uRr6pLe-_aBc';
const _token = 'eyJ1IjoiZGVtbyJ9.sig';

/// The code verifier of RFC 7636 appendix B and its `S256` challenge.
const _verifier = 'dBjftJeZ4CVP-mB92K27uhbUJU1p1r_wW1gFWFOEjXk';
const _challenge = 'E9Melhoa2OwvFrEMTJguCHaoeK1t8URWbuGJSstw-cM';
const _state = 'c3RhdGUtb2YtdGhpcy1zaWduLWluLTAxMjM0NTY3ODk';
const _secrets = SignInSecrets(codeVerifier: _verifier, state: _state);
const _callback = 'zhang-app://auth/callback?code=$_code&state=$_state';
const _loginUrl =
    '$_base/login?return_to=zhang-app%3A%2F%2Fauth%2Fcallback'
    '&code_challenge=$_challenge&code_challenge_method=S256&state=$_state';

Map<String, Object?> _status({bool enabled = true, bool appLogin = true, bool pkce = true, List<String>? schemes}) => {
  'data': {
    'enabled': enabled,
    'authenticated': false,
    'methods': {'password': true, 'passkey': false},
    'passkey_registered': false,
    'user': null,
    'title': 'My Accounting',
    'app_login': ?(appLogin ? true : null),
    'app_login_pkce': ?(appLogin && pkce ? true : null),
    'app_return_schemes': ?(appLogin ? (schemes ?? ['zhang-app']) : null),
  },
};

const _exchangeOk = {
  'data': {'token': _token, 'expires_at': '2026-11-09T03:07:29Z', 'user': 'demo'},
};

/// A [BrowserSignIn] whose server answers with [handler] and whose "browser"
/// is [launch]; [requests] collects every request.
BrowserSignIn _signIn(
  FakeHandler handler, {
  WebAuthLauncher? launch,
  List<RequestOptions>? requests,
  PkceServers? pkceServers,
}) => BrowserSignIn(
  launch: launch ?? (url, scheme) async => throw StateError('no browser in this test'),
  newSecrets: () => _secrets,
  pkceServers: pkceServers,
  createClient: (profile) {
    final client = ZhangApiClient(profile);
    client.dio.httpClientAdapter = FakeAdapter((o) {
      requests?.add(o);
      return handler(o);
    });
    return client;
  },
);

Matcher _failure(BrowserSignInFailure kind) =>
    throwsA(isA<BrowserSignInException>().having((e) => e.kind, 'kind', kind));

void main() {
  group('sign-in secrets (PKCE, RFC 7636)', () {
    test('the S256 challenge of the RFC 7636 example verifier', () {
      expect(_secrets.codeChallenge, _challenge);
    });

    test('verifier and state: 32 random bytes each, base64url without padding', () {
      final a = SignInSecrets.generate();
      final b = SignInSecrets.generate();
      final base64url = RegExp(r'^[A-Za-z0-9_-]{43}$');
      for (final value in [a.codeVerifier, a.state, a.codeChallenge, b.codeVerifier, b.state]) {
        expect(value, matches(base64url));
      }
      expect(base64Url.decode('${a.codeVerifier}='), hasLength(32));
      expect({a.codeVerifier, a.state, b.codeVerifier, b.state}, hasLength(4));
      // Drawn from the given generator (Random.secure() by default).
      final seeded = SignInSecrets.generate(Random(7));
      expect(SignInSecrets.generate(Random(7)).codeVerifier, seeded.codeVerifier);
      expect(seeded.toString(), isNot(contains(seeded.codeVerifier)));
      expect(seeded.toString(), isNot(contains(seeded.state)));
    });
  });

  test('login URL carries the encoded callback, the S256 challenge and the state', () {
    expect(BrowserSignIn.loginUrl(_base, _secrets), _loginUrl);
    expect(
      BrowserSignIn.loginUrl('https://x.com/zhang', _secrets),
      'https://x.com/zhang/login?return_to=zhang-app%3A%2F%2Fauth%2Fcallback'
      '&code_challenge=$_challenge&code_challenge_method=S256&state=$_state',
    );
    expect(Uri.parse(_loginUrl).queryParameters['return_to'], 'zhang-app://auth/callback');
  });

  group('callback parsing', () {
    String parse(String callback, {bool stateRequired = true}) =>
        BrowserSignIn.codeFromCallback(callback, state: _state, stateRequired: stateRequired);

    test('reads the code of a callback with this sign-in\'s state', () {
      expect(parse(_callback), _code);
      expect(parse('zhang-app://auth/callback?state=$_state&code=$_code'), _code);
      expect(parse(_callback, stateRequired: false), _code);
    });

    test('without state: accepted only from a server without app_login_pkce', () {
      expect(parse('zhang-app://auth/callback?code=$_code', stateRequired: false), _code);
      expect(() => parse('zhang-app://auth/callback?code=$_code'), _failure(BrowserSignInFailure.stateMismatch));
    });

    for (final other in ['', 'other-state', '${_state}x', _state.substring(1), _state.toUpperCase()]) {
      test('another state ("$other") → stateMismatch, whatever the server', () {
        for (final required in [true, false]) {
          expect(
            () => parse(
              'zhang-app://auth/callback?code=$_code&state=${Uri.encodeQueryComponent(other)}',
              stateRequired: required,
            ),
            _failure(BrowserSignInFailure.stateMismatch),
          );
        }
      });
    }

    for (final bad in [
      '',
      'not a url',
      'zhang-app://auth/callback',
      'zhang-app://auth/callback?state=$_state',
      'zhang-app://auth/callback?code=&state=$_state',
      'zhang-app://auth/callback?token=$_token',
      'zhang-app://auth/callback?code=$_code&code=$_code&state=$_state',
      'zhang-app://auth/callback?code=$_code&state=$_state&state=$_state',
      'zhang-app://auth/callback?code=$_code&state=$_state&token=$_token',
      'zhang-app://auth/callback?code=$_code&token=$_token',
      'zhang-app://auth/callback?code=$_code&state=$_state#frag',
      'zhang-app://auth/callback?code=short&state=$_state',
      'zhang-app://auth/callback?code=has%20space$_code&state=$_state',
      'zhang-app://evil/callback?code=$_code&state=$_state',
      'zhang-app://auth/other?code=$_code&state=$_state',
      'zhang-app://user@auth/callback?code=$_code&state=$_state',
      'other-app://auth/callback?code=$_code&state=$_state',
      'https://auth/callback?code=$_code&state=$_state',
    ]) {
      test('rejects "$bad"', () {
        for (final required in [true, false]) {
          expect(() => parse(bad, stateRequired: required), _failure(BrowserSignInFailure.malformedCallback));
        }
      });
    }

    test('a malformed callback makes no request', () async {
      final requests = <RequestOptions>[];
      final signIn = _signIn((_) => jsonResponse(_exchangeOk), requests: requests);
      await expectLater(
        signIn.completeSignIn(_base, 'zhang-app://auth/callback?error=access_denied', _secrets, pkce: true),
        _failure(BrowserSignInFailure.malformedCallback),
      );
      expect(requests, isEmpty);
    });

    test('a callback of another sign-in is never exchanged', () async {
      final requests = <RequestOptions>[];
      final signIn = _signIn((_) => jsonResponse(_exchangeOk), requests: requests);
      for (final (callback, pkce) in [
        ('zhang-app://auth/callback?code=$_code&state=planted', true),
        ('zhang-app://auth/callback?code=$_code&state=planted', false),
        ('zhang-app://auth/callback?code=$_code', true),
      ]) {
        await expectLater(
          signIn.completeSignIn(_base, callback, _secrets, pkce: pkce),
          _failure(BrowserSignInFailure.stateMismatch),
        );
      }
      expect(requests, isEmpty);
    });
  });

  group('exchange', () {
    test('success → token, UTC expiry, user; the verifier, no credentials sent', () async {
      final requests = <RequestOptions>[];
      final grant = await _signIn(
        (_) => jsonResponse(_exchangeOk),
        requests: requests,
      ).completeSignIn(_base, _callback, _secrets, pkce: true);
      expect(grant.token, _token);
      expect(grant.user, 'demo');
      expect(grant.expiresAt, DateTime.utc(2026, 11, 9, 3, 7, 29));
      expect(grant.toString(), isNot(contains(_token)));

      final req = requests.single;
      expect(req.method, 'POST');
      expect(req.uri.toString(), '$_base/api/auth/app/exchange');
      expect(req.data, {'code': _code, 'code_verifier': _verifier});
      expect(req.headers.containsKey('Authorization'), isFalse);

      final profile = grant.applyTo(const ServerProfile(id: 'p', name: 'x', baseUrl: _base));
      expect(profile.authType, AuthType.session);
      expect(profile.authHeaders(), {'Authorization': 'Bearer $_token'});
      expect(profile.sessionUser, 'demo');
    });

    test('a code without a verifier sends none', () async {
      final requests = <RequestOptions>[];
      await _signIn((_) => jsonResponse(_exchangeOk), requests: requests).exchange(_base, _code, codeVerifier: null);
      expect(requests.single.data, {'code': _code});
    });

    test('401 invalid or expired code (or a wrong verifier) → codeRejected', () async {
      final signIn = _signIn((_) => jsonResponse({'message': 'invalid or expired code'}, status: 401));
      await expectLater(
        signIn.exchange(_base, _code, codeVerifier: _verifier),
        _failure(BrowserSignInFailure.codeRejected),
      );
    });

    test('429 with Retry-After → rateLimited with the wait', () async {
      final signIn = _signIn(
        (_) => ResponseBody.fromString(
          jsonEncode({'message': 'too many failed attempts'}),
          429,
          headers: {
            Headers.contentTypeHeader: [Headers.jsonContentType],
            'retry-after': ['42'],
          },
        ),
      );
      await expectLater(
        signIn.exchange(_base, _code, codeVerifier: _verifier),
        throwsA(
          isA<BrowserSignInException>()
              .having((e) => e.kind, 'kind', BrowserSignInFailure.rateLimited)
              .having((e) => e.retryAfter, 'retryAfter', const Duration(seconds: 42)),
        ),
      );
    });

    test('429 without Retry-After → rateLimited, no wait known', () async {
      final signIn = _signIn((_) => jsonResponse({'message': 'slow down'}, status: 429));
      await expectLater(
        signIn.exchange(_base, _code, codeVerifier: _verifier),
        throwsA(isA<BrowserSignInException>().having((e) => e.retryAfter, 'retryAfter', isNull)),
      );
    });

    test('server without the route → notSupported', () async {
      final signIn = _signIn((_) => jsonResponse({'message': 'no route POST /api/auth/app/exchange'}, status: 404));
      await expectLater(
        signIn.exchange(_base, _code, codeVerifier: _verifier),
        _failure(BrowserSignInFailure.notSupported),
      );
    });

    test('payload without a token → ApiParseError', () async {
      final signIn = _signIn(
        (_) => jsonResponse({
          'data': {'token': '', 'expires_at': '2026-11-09T03:07:29Z', 'user': 'demo'},
        }),
      );
      await expectLater(signIn.exchange(_base, _code, codeVerifier: _verifier), throwsA(isA<ApiParseError>()));
    });
  });

  group('signIn (status check + browser + exchange)', () {
    test('opens the login page with the zhang-app scheme and PKCE, then exchanges the code', () async {
      final launched = <(String, String)>[];
      final requests = <RequestOptions>[];
      final signIn = _signIn(
        (o) => o.uri.path.endsWith('/auth/status') ? jsonResponse(_status()) : jsonResponse(_exchangeOk),
        requests: requests,
        launch: (url, scheme) async {
          launched.add((url, scheme));
          return _callback;
        },
      );
      final grant = await signIn.signIn(_base);
      expect(grant.user, 'demo');
      expect(launched, [(_loginUrl, 'zhang-app')]);
      expect(requests.map((r) => r.uri.path), ['/api/auth/status', '/api/auth/app/exchange']);
      expect(requests.last.data, {'code': _code, 'code_verifier': _verifier});
    });

    test('gateway headers go with the status check and the exchange, an Authorization never', () async {
      final requests = <RequestOptions>[];
      final signIn = _signIn(
        (o) => o.uri.path.endsWith('/auth/status') ? jsonResponse(_status()) : jsonResponse(_exchangeOk),
        requests: requests,
        launch: (url, scheme) async => _callback,
      );
      final grant = await signIn.signIn(
        _base,
        headers: {'CF-Access-Client-Id': 'cf-id', 'authorization': 'Basic stale'},
      );
      expect(grant.token, _token);
      expect(requests.map((r) => r.uri.path), ['/api/auth/status', '/api/auth/app/exchange']);
      for (final r in requests) {
        expect(r.headers['CF-Access-Client-Id'], 'cf-id');
        expect(r.headers.containsKey('Authorization'), isFalse);
      }
      final profile = grant.applyTo(
        const ServerProfile(id: 'p', name: 'x', baseUrl: _base, customHeaders: {'CF-Access-Client-Id': 'cf-id'}),
      );
      expect(profile.authHeaders(), {'CF-Access-Client-Id': 'cf-id', 'Authorization': 'Bearer $_token'});
    });

    test('every sign-in has fresh secrets', () async {
      final launched = <Uri>[];
      final signIn = BrowserSignIn(
        launch: (url, scheme) async {
          launched.add(Uri.parse(url));
          return 'zhang-app://auth/callback?code=$_code&state=${Uri.parse(url).queryParameters['state']}';
        },
        createClient: (profile) => ZhangApiClient(profile)
          ..dio.httpClientAdapter = FakeAdapter(
            (o) => o.uri.path.endsWith('/auth/status') ? jsonResponse(_status()) : jsonResponse(_exchangeOk),
          ),
      );
      await signIn.signIn(_base);
      await signIn.signIn(_base);
      final [first, second] = launched;
      expect(first.queryParameters['code_challenge_method'], 'S256');
      expect(first.queryParameters['code_challenge'], isNot(second.queryParameters['code_challenge']));
      expect(first.queryParameters['state'], isNot(second.queryParameters['state']));
    });

    test('app_login_pkce: a callback without the state fails before the exchange', () async {
      final requests = <RequestOptions>[];
      final signIn = _signIn(
        (o) => o.uri.path.endsWith('/auth/status') ? jsonResponse(_status()) : jsonResponse(_exchangeOk),
        requests: requests,
        launch: (url, scheme) async => 'zhang-app://auth/callback?code=$_code',
      );
      await expectLater(signIn.signIn(_base), _failure(BrowserSignInFailure.stateMismatch));
      expect(requests.map((r) => r.uri.path), ['/api/auth/status']);
    });

    test('a server without app_login_pkce: no state echoed, still signs in', () async {
      final requests = <RequestOptions>[];
      final launched = <String>[];
      final signIn = _signIn(
        (o) => o.uri.path.endsWith('/auth/status') ? jsonResponse(_status(pkce: false)) : jsonResponse(_exchangeOk),
        requests: requests,
        launch: (url, scheme) async {
          launched.add(url);
          return 'zhang-app://auth/callback?code=$_code';
        },
      );
      expect((await signIn.signIn(_base)).user, 'demo');
      // The extra parameters are sent all the same; that server ignores them.
      expect(launched, [_loginUrl]);
      expect(requests.last.data, {'code': _code, 'code_verifier': _verifier});
    });

    test('a server without app_login_pkce: a wrong state still fails', () async {
      final signIn = _signIn(
        (o) => jsonResponse(_status(pkce: false)),
        launch: (url, scheme) async => 'zhang-app://auth/callback?code=$_code&state=planted',
      );
      await expectLater(signIn.signIn(_base), _failure(BrowserSignInFailure.stateMismatch));
    });

    test('sign-in disabled → notNeeded, no browser', () async {
      var launched = false;
      final signIn = _signIn(
        (_) => jsonResponse(_status(enabled: false)),
        launch: (_, _) async {
          launched = true;
          return '';
        },
      );
      await expectLater(signIn.signIn(_base), _failure(BrowserSignInFailure.notNeeded));
      expect(launched, isFalse);
    });

    test('enabled without app_login (zhang before PR #786) → notSupported', () async {
      final signIn = _signIn((_) => jsonResponse(_status(appLogin: false)));
      await expectLater(signIn.signIn(_base), _failure(BrowserSignInFailure.notSupported));
    });

    test('app_login but zhang-app not an allowed scheme → notSupported', () async {
      final signIn = _signIn((_) => jsonResponse(_status(schemes: ['other-app'])));
      await expectLater(signIn.signIn(_base), _failure(BrowserSignInFailure.notSupported));
    });

    test('user closes the browser → cancelled; other platform errors → browserFailed', () async {
      for (final (code, kind) in [
        ('CANCELED', BrowserSignInFailure.cancelled),
        ('EUNKNOWN', BrowserSignInFailure.browserFailed),
      ]) {
        final signIn = _signIn(
          (_) => jsonResponse(_status()),
          launch: (_, _) async => throw PlatformException(code: code, message: 'x'),
        );
        await expectLater(signIn.signIn(_base), _failure(kind));
      }
    });
  });

  group('app_login_pkce, once seen, is required from then on', () {
    test('a later status without the flag still needs the state', () async {
      final servers = PkceServers();
      var pkce = true;
      final requests = <RequestOptions>[];
      final callbacks = [_callback, 'zhang-app://auth/callback?code=$_code'];
      final signIn = _signIn(
        (o) => o.uri.path.endsWith('/auth/status') ? jsonResponse(_status(pkce: pkce)) : jsonResponse(_exchangeOk),
        requests: requests,
        pkceServers: servers,
        launch: (url, scheme) async => callbacks.removeAt(0),
      );
      expect((await signIn.signIn(_base)).user, 'demo');
      expect(servers.contains(_base), isTrue);

      pkce = false;
      requests.clear();
      await expectLater(signIn.signIn(_base), _failure(BrowserSignInFailure.stateMismatch));
      expect(requests.map((r) => r.uri.path), ['/api/auth/status'], reason: 'never exchanged');
    });

    test('also for a sign-in started without a status check (setup wizard)', () async {
      final servers = PkceServers();
      await servers.remember('$_base/');
      final signIn = _signIn(
        (_) => jsonResponse(_exchangeOk),
        pkceServers: servers,
        launch: (url, scheme) async => 'zhang-app://auth/callback?code=$_code',
      );
      await expectLater(signIn.startBrowserSignIn(_base, pkce: false), _failure(BrowserSignInFailure.stateMismatch));
      // Another server is not affected.
      expect((await signIn.startBrowserSignIn('http://127.0.0.1:18101', pkce: false)).user, 'demo');
      expect(servers.contains('http://127.0.0.1:18101'), isFalse);
      // A sign-in told about the flag remembers it.
      await expectLater(
        signIn.startBrowserSignIn('http://127.0.0.1:18102', pkce: true),
        _failure(BrowserSignInFailure.stateMismatch),
      );
      expect(servers.contains('http://127.0.0.1:18102'), isTrue);
    });

    test('kept in SharedPreferences, by base URL', () async {
      TestWidgetsFlutterBinding.ensureInitialized();
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();
      await PkceServers(prefs).remember('https://x.com/zhang/');
      await PkceServers(prefs).remember('https://x.com/zhang');
      final reloaded = PkceServers(prefs);
      expect(reloaded.contains('https://x.com/zhang'), isTrue);
      expect(reloaded.contains('https://x.com/zhang/'), isTrue);
      expect(reloaded.contains('https://x.com'), isFalse);
      expect(prefs.getStringList(PkceServers.key), ['https://x.com/zhang']);
    });

    test('one server, however its base URL is spelled', () async {
      for (final (spelled, id) in [
        ('HTTPS://Example.COM:443/zhang/', 'https://example.com/zhang'),
        ('https://example.com', 'https://example.com'),
        ('http://Example.com:80//', 'http://example.com'),
        ('http://example.com:8080/', 'http://example.com:8080'),
        ('https://example.com:80', 'https://example.com:80'),
        ('http://example.com:443', 'http://example.com:443'),
        ('https://example.com/Zhang', 'https://example.com/Zhang'),
        ('http://[::1]:18580/', 'http://[::1]:18580'),
        ('  http://127.0.0.1:18100  ', 'http://127.0.0.1:18100'),
      ]) {
        expect(PkceServers.serverId(spelled), id, reason: spelled);
      }
      final servers = PkceServers();
      await servers.remember('HTTPS://Example.COM:443/zhang/');
      expect(servers.contains('https://example.com/zhang'), isTrue);
      expect(servers.contains('https://example.com:8443/zhang'), isFalse);
      expect(servers.contains('http://example.com/zhang'), isFalse);
      expect(servers.contains('https://example.com/Zhang'), isFalse, reason: 'the path keeps its case');
    });
  });

  test('logout posts with the Bearer session; failures are swallowed', () async {
    final requests = <RequestOptions>[];
    final profile = const ServerProfile(
      id: 'p',
      name: 'x',
      baseUrl: _base,
    ).copyWith(authType: AuthType.session, sessionToken: _token);
    await _signIn((_) => jsonResponse({'data': null}), requests: requests).logout(profile);
    expect(requests.single.uri.path, '/api/auth/logout');
    expect(requests.single.headers['Authorization'], 'Bearer $_token');

    await _signIn((_) => jsonResponse({'message': 'boom'}, status: 500)).logout(profile);
    // Signed-out profiles make no request.
    requests.clear();
    await _signIn((_) => jsonResponse({'data': null}), requests: requests).logout(profile.withoutSession());
    expect(requests, isEmpty);
  });

  group('ApiRateLimited', () {
    test('Retry-After: seconds, HTTP date, junk', () {
      final now = DateTime.utc(2026, 10, 10, 12);
      expect(ApiRateLimited.parseRetryAfter('120'), const Duration(seconds: 120));
      expect(ApiRateLimited.parseRetryAfter('Sat, 10 Oct 2026 12:01:00 GMT', now: now), const Duration(minutes: 1));
      expect(ApiRateLimited.parseRetryAfter('soon'), isNull);
      expect(ApiRateLimited.parseRetryAfter(null), isNull);
      expect(ApiRateLimited.parseRetryAfter('-5'), isNull);
    });

    test('a 429 from any route is an ApiServerError(429) too', () async {
      final client = ZhangApiClient(const ServerProfile(id: 'p', name: 'x', baseUrl: _base));
      client.dio.httpClientAdapter = FakeAdapter(
        (_) => ResponseBody.fromString(
          '{"message":"too many failed attempts"}',
          429,
          headers: {
            Headers.contentTypeHeader: [Headers.jsonContentType],
            'retry-after': ['7'],
          },
        ),
      );
      await expectLater(
        client.info(),
        throwsA(
          isA<ApiServerError>()
              .having((e) => e.status, 'status', 429)
              .having((e) => (e as ApiRateLimited).retryAfter, 'retryAfter', const Duration(seconds: 7)),
        ),
      );
    });
  });
}
