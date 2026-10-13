import 'dart:io';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:zhang_app/data/api/api_exception.dart';
import 'package:zhang_app/data/api/zhang_api_client.dart';
import 'package:zhang_app/data/models/auth_status.dart';
import 'package:zhang_app/data/profiles/server_profile.dart';

import '../helpers/fake_adapter.dart';
import '../helpers/fixtures.dart';

const _profile = ServerProfile(id: 'p', name: 'Test', baseUrl: 'http://127.0.0.1:18080');

/// A [ConnectionTester] whose client answers with [handler]; [paths]
/// collects the requested paths.
ConnectionTester _tester(FakeHandler handler, List<String> paths) => ConnectionTester(
  createClient: (profile) {
    final client = ZhangApiClient(profile);
    client.dio.httpClientAdapter = FakeAdapter((o) {
      paths.add(o.uri.path);
      return handler(o);
    });
    return client;
  },
);

/// `/api/info` of a zhang 0.1 server (no `format`).
const _v01Info = {
  'data': {'title': 'My Accounting', 'version': '0.1.0', 'build_date': '2026-10-02'},
};

void main() {
  test('v0.2 server passes the gate with one request', () async {
    final paths = <String>[];
    final info = await _tester((_) => jsonResponse(fixture('info.json')), paths).test(_profile);
    expect(info.isSupported, isTrue);
    expect(info.format, 'zhang');
    expect(paths, ['/api/info']);
  });

  test('server without `format` (zhang < 0.2) → ApiServerTooOld, nothing else requested', () async {
    final paths = <String>[];
    await expectLater(
      _tester((_) => jsonResponse(_v01Info), paths).test(_profile),
      throwsA(isA<ApiServerTooOld>().having((e) => e.version, 'version', '0.1.0')),
    );
    expect(paths, ['/api/info']);
  });

  test('401 on a passkey-only server → ApiPasskeyOnly', () async {
    final paths = <String>[];
    final tester = _tester((o) {
      if (o.uri.path == '/api/auth/status') {
        return jsonResponse({
          'data': {
            'enabled': true,
            'authenticated': false,
            'methods': {'password': false, 'passkey': true},
            'passkey_registered': false,
            'user': null,
            'title': 'My Accounting',
          },
        });
      }
      return rawJsonResponse(fixtureText('err_unauthorized.json'), status: 401);
    }, paths);
    await expectLater(tester.test(_profile), throwsA(isA<ApiPasskeyOnly>()));
    expect(paths, ['/api/info', '/api/auth/status']);
  });

  test('401 on a password server → ApiUnauthorized (wrong credentials)', () async {
    final paths = <String>[];
    final tester = _tester((o) {
      if (o.uri.path == '/api/auth/status') {
        // Captured from `--auth demo:secret`.
        return jsonResponse({
          'data': {
            'enabled': true,
            'authenticated': false,
            'methods': {'password': true, 'passkey': false},
            'passkey_registered': false,
            'user': null,
            'title': 'My Accounting',
          },
        });
      }
      return rawJsonResponse(fixtureText('err_unauthorized.json'), status: 401);
    }, paths);
    await expectLater(tester.test(_profile), throwsA(isA<ApiUnauthorized>()));
  });

  test('401 where /api/auth/status also fails → the original ApiUnauthorized', () async {
    final paths = <String>[];
    final tester = _tester((_) => emptyResponse(401), paths);
    await expectLater(tester.test(_profile), throwsA(isA<ApiUnauthorized>()));
    expect(paths, ['/api/info', '/api/auth/status']);
  });

  test('401 on a passkey-only server with the app handoff → ApiPasskeyOnly(appLogin)', () async {
    final tester = _tester((o) {
      if (o.uri.path == '/api/auth/status') {
        return jsonResponse({
          'data': {
            'enabled': true,
            'authenticated': false,
            'methods': {'password': false, 'passkey': true},
            'passkey_registered': true,
            'user': null,
            'title': 'My Accounting',
            'app_login': true,
            'app_return_schemes': ['zhang-app'],
          },
        });
      }
      return rawJsonResponse(fixtureText('err_unauthorized.json'), status: 401);
    }, []);
    await expectLater(
      tester.test(_profile),
      throwsA(isA<ApiPasskeyOnly>().having((e) => e.appLogin, 'appLogin', isTrue)),
    );
  });

  test('browser sign-in profile: Bearer session on /api/info; 401 is not "passkey only"', () async {
    final paths = <String>[];
    final headers = <Object?>[];
    final session = _profile.copyWith(authType: AuthType.session, sessionToken: 'tok.sig');
    final ok = ConnectionTester(
      createClient: (profile) {
        final client = ZhangApiClient(profile);
        client.dio.httpClientAdapter = FakeAdapter((o) {
          paths.add(o.uri.path);
          headers.add(o.headers['Authorization']);
          return jsonResponse(fixture('info.json'));
        });
        return client;
      },
    );
    await ok.test(session);
    expect(paths, ['/api/info']);
    expect(headers, ['Bearer tok.sig']);

    paths.clear();
    final expired = _tester((_) => rawJsonResponse(fixtureText('err_unauthorized.json'), status: 401), paths);
    await expectLater(expired.test(session), throwsA(isA<ApiUnauthorized>()));
    expect(paths, ['/api/info'], reason: 'no auth/status lookup for a session profile');
  });

  test('auth status: app_login fields (zhang PR #786) and their absence', () {
    final withHandoff = AuthStatus.fromJson({
      'enabled': true,
      'authenticated': false,
      'methods': {'password': true, 'passkey': false},
      'app_login': true,
      'app_return_schemes': ['zhang-app'],
    });
    expect(withHandoff.appLogin, isTrue);
    expect(withHandoff.appReturnSchemes, ['zhang-app']);
    expect(withHandoff.supportsAppLogin, isTrue);
    final old = AuthStatus.fromJson(fixtureData('auth_status.json'));
    expect(old.appLogin, isFalse);
    expect(old.supportsAppLogin, isFalse);
  });

  test('auth status fixture (no auth) parses', () {
    final status = AuthStatus.fromJson(fixtureData('auth_status.json'));
    expect(status.enabled, isFalse);
    expect(status.authenticated, isTrue);
    expect(status.isPasskeyOnly, isFalse);
  });

  group('probe (setup wizard step 1)', () {
    Map<String, Object?> status({bool enabled = true, bool password = true, bool appLogin = true}) => {
      'data': {
        'enabled': enabled,
        'authenticated': !enabled,
        'methods': {'password': password, 'passkey': !password},
        'passkey_registered': false,
        'user': null,
        'title': 'My Accounting',
        if (appLogin) 'app_login': true,
        if (appLogin) 'app_return_schemes': ['zhang-app'],
      },
    };

    test('open v0.2 server: info and auth status, no credentials sent', () async {
      final paths = <String>[];
      final headers = <Object?>[];
      final probe = await _tester((o) {
        headers.add(o.headers['Authorization']);
        return o.uri.path == '/api/auth/status'
            ? jsonResponse(fixture('auth_status.json'))
            : jsonResponse(fixture('info.json'));
      }, paths).probe('http://127.0.0.1:18080');
      expect(paths, ['/api/auth/status', '/api/info']);
      expect(headers, everyElement(isNull));
      expect(probe.open, isTrue);
      expect(probe.gateway, isFalse);
      expect(probe.title, 'My Accounting');
      expect(probe.auth!.enabled, isFalse);
    });

    test('sign-in enabled: /api/info refused → not open, methods from auth status', () async {
      final probe = await _tester((o) {
        if (o.uri.path == '/api/auth/status') return jsonResponse(status());
        return rawJsonResponse(fixtureText('err_unauthorized.json'), status: 401);
      }, []).probe('http://127.0.0.1:18081');
      expect(probe.open, isFalse);
      expect(probe.gateway, isFalse);
      expect(probe.auth!.supportsAppLogin, isTrue);
      expect(probe.title, 'My Accounting');
    });

    test('zhang without sign-in but 401 anyway → gateway', () async {
      final probe = await _tester((o) {
        if (o.uri.path == '/api/auth/status') return jsonResponse(status(enabled: false, password: false));
        return emptyResponse(401);
      }, []).probe('https://ledger.example.com');
      expect(probe.open, isFalse);
      expect(probe.gateway, isTrue);
    });

    test('zhang 0.1 (text page for /api/auth/status, info without format) → ApiServerTooOld', () async {
      await expectLater(
        _tester((o) {
          if (o.uri.path == '/api/auth/status') return textResponse('hello zhang');
          return jsonResponse(_v01Info);
        }, []).probe('http://127.0.0.1:18082'),
        throwsA(isA<ApiServerTooOld>().having((e) => e.version, 'version', '0.1.0')),
      );
    });

    test('not a zhang server (HTML everywhere) → ApiParseError', () async {
      await expectLater(
        _tester((_) => textResponse('<html>login</html>'), []).probe('https://example.com'),
        throwsA(isA<ApiParseError>()),
      );
    });

    test('unreachable → the network error, /api/info is not tried', () async {
      final paths = <String>[];
      await expectLater(
        _tester((o) => throw DioException(
              requestOptions: o,
              type: DioExceptionType.connectionError,
              error: const SocketException('Connection refused'),
            ), paths).probe('http://127.0.0.1:1'),
        throwsA(isA<ApiNetworkError>().having((e) => e.kind, 'kind', NetworkErrorKind.connection)),
      );
      expect(paths, ['/api/auth/status']);
    });
  });

  test('overview: operating currency and open accounts with the profile\'s credentials', () async {
    final headers = <Object?>[];
    final tester = ConnectionTester(
      createClient: (profile) => ZhangApiClient(profile)
        ..dio.httpClientAdapter = FakeAdapter((o) {
          headers.add(o.headers['Authorization']);
          return switch (o.uri.path) {
            '/api/options' => jsonResponse(fixture('options.json')),
            '/api/accounts' => jsonResponse(fixture('accounts.json')),
            _ => emptyResponse(404),
          };
        }),
    );
    final overview = await tester.overview(
      _profile.copyWith(authType: AuthType.basic, basicUsername: 'demo', basicPassword: 'secret'),
    );
    expect(overview.operatingCurrency, 'CNY');
    expect(overview.openAccounts, 22);
    expect(headers, everyElement(startsWith('Basic ')));
  });
}
