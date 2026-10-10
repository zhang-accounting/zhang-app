import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:zhang_app/data/api/api_exception.dart';
import 'package:zhang_app/data/api/zhang_api_client.dart';
import 'package:zhang_app/data/auth/browser_sign_in.dart';
import 'package:zhang_app/data/profiles/server_profile.dart';

import '../helpers/fake_adapter.dart';

const _base = 'http://127.0.0.1:18100';
const _code = 'q3Hn0Zx4c0QyX2xJm9Yb8kq1sV7tWw5uRr6pLe-_aBc';
const _token = 'eyJ1IjoiZGVtbyJ9.sig';

Map<String, Object?> _status({bool enabled = true, bool appLogin = true, List<String>? schemes}) => {
  'data': {
    'enabled': enabled,
    'authenticated': false,
    'methods': {'password': true, 'passkey': false},
    'passkey_registered': false,
    'user': null,
    'title': 'My Accounting',
    'app_login': ?(appLogin ? true : null),
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
}) => BrowserSignIn(
  launch: launch ?? (url, scheme) async => throw StateError('no browser in this test'),
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
  test('login URL carries the encoded callback', () {
    expect(
      BrowserSignIn.loginUrl(_base),
      'http://127.0.0.1:18100/login?return_to=zhang-app%3A%2F%2Fauth%2Fcallback',
    );
    expect(
      BrowserSignIn.loginUrl('https://x.com/zhang'),
      'https://x.com/zhang/login?return_to=zhang-app%3A%2F%2Fauth%2Fcallback',
    );
  });

  group('callback parsing', () {
    test('reads only the code', () {
      expect(BrowserSignIn.codeFromCallback('zhang-app://auth/callback?code=$_code'), _code);
    });

    for (final bad in [
      '',
      'not a url',
      'zhang-app://auth/callback',
      'zhang-app://auth/callback?code=',
      'zhang-app://auth/callback?token=$_token',
      'zhang-app://auth/callback?code=$_code&code=$_code',
      'zhang-app://auth/callback?code=$_code&token=$_token',
      'zhang-app://auth/callback?code=$_code#frag',
      'zhang-app://auth/callback?code=short',
      'zhang-app://auth/callback?code=has%20space$_code',
      'zhang-app://evil/callback?code=$_code',
      'zhang-app://auth/other?code=$_code',
      'zhang-app://user@auth/callback?code=$_code',
      'other-app://auth/callback?code=$_code',
      'https://auth/callback?code=$_code',
    ]) {
      test('rejects "$bad"', () {
        expect(() => BrowserSignIn.codeFromCallback(bad), _failure(BrowserSignInFailure.malformedCallback));
      });
    }

    test('a malformed callback makes no request', () async {
      final requests = <RequestOptions>[];
      final signIn = _signIn((_) => jsonResponse(_exchangeOk), requests: requests);
      await expectLater(
        signIn.completeSignIn(_base, 'zhang-app://auth/callback?error=access_denied'),
        _failure(BrowserSignInFailure.malformedCallback),
      );
      expect(requests, isEmpty);
    });
  });

  group('exchange', () {
    test('success → token, UTC expiry, user; no credentials sent', () async {
      final requests = <RequestOptions>[];
      final grant = await _signIn((_) => jsonResponse(_exchangeOk), requests: requests)
          .completeSignIn(_base, 'zhang-app://auth/callback?code=$_code');
      expect(grant.token, _token);
      expect(grant.user, 'demo');
      expect(grant.expiresAt, DateTime.utc(2026, 11, 9, 3, 7, 29));
      expect(grant.toString(), isNot(contains(_token)));

      final req = requests.single;
      expect(req.method, 'POST');
      expect(req.uri.toString(), '$_base/api/auth/app/exchange');
      expect(req.data, {'code': _code});
      expect(req.headers.containsKey('Authorization'), isFalse);

      final profile = grant.applyTo(const ServerProfile(id: 'p', name: 'x', baseUrl: _base));
      expect(profile.authType, AuthType.session);
      expect(profile.authHeaders(), {'Authorization': 'Bearer $_token'});
      expect(profile.sessionUser, 'demo');
    });

    test('401 invalid or expired code → codeRejected', () async {
      final signIn = _signIn((_) => jsonResponse({'message': 'invalid or expired code'}, status: 401));
      await expectLater(signIn.exchange(_base, _code), _failure(BrowserSignInFailure.codeRejected));
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
        signIn.exchange(_base, _code),
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
        signIn.exchange(_base, _code),
        throwsA(isA<BrowserSignInException>().having((e) => e.retryAfter, 'retryAfter', isNull)),
      );
    });

    test('server without the route → notSupported', () async {
      final signIn = _signIn(
        (_) => jsonResponse({'message': 'no route POST /api/auth/app/exchange'}, status: 404),
      );
      await expectLater(signIn.exchange(_base, _code), _failure(BrowserSignInFailure.notSupported));
    });

    test('payload without a token → ApiParseError', () async {
      final signIn = _signIn(
        (_) => jsonResponse({
          'data': {'token': '', 'expires_at': '2026-11-09T03:07:29Z', 'user': 'demo'},
        }),
      );
      await expectLater(signIn.exchange(_base, _code), throwsA(isA<ApiParseError>()));
    });
  });

  group('signIn (status check + browser + exchange)', () {
    test('opens the login page with the zhang-app scheme, then exchanges the code', () async {
      final launched = <(String, String)>[];
      final requests = <RequestOptions>[];
      final signIn = _signIn(
        (o) => o.uri.path.endsWith('/auth/status') ? jsonResponse(_status()) : jsonResponse(_exchangeOk),
        requests: requests,
        launch: (url, scheme) async {
          launched.add((url, scheme));
          return 'zhang-app://auth/callback?code=$_code';
        },
      );
      final grant = await signIn.signIn(_base);
      expect(grant.user, 'demo');
      expect(launched, [('$_base/login?return_to=zhang-app%3A%2F%2Fauth%2Fcallback', 'zhang-app')]);
      expect(requests.map((r) => r.uri.path), ['/api/auth/status', '/api/auth/app/exchange']);
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

  test('logout posts with the Bearer session; failures are swallowed', () async {
    final requests = <RequestOptions>[];
    final profile = const ServerProfile(id: 'p', name: 'x', baseUrl: _base).copyWith(
      authType: AuthType.session,
      sessionToken: _token,
    );
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
      expect(
        ApiRateLimited.parseRetryAfter('Sat, 10 Oct 2026 12:01:00 GMT', now: now),
        const Duration(minutes: 1),
      );
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
