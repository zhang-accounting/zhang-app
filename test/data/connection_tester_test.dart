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

  test('auth status fixture (no auth) parses', () {
    final status = AuthStatus.fromJson(fixtureData('auth_status.json'));
    expect(status.enabled, isFalse);
    expect(status.authenticated, isTrue);
    expect(status.isPasskeyOnly, isFalse);
  });
}
