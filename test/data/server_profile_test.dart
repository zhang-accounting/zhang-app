import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:zhang_app/data/profiles/profile_repository.dart';
import 'package:zhang_app/data/profiles/secret_store.dart';
import 'package:zhang_app/data/profiles/server_profile.dart';

/// zhang's Basic behind Cloudflare Access (decisions.md §7).
const _full = ServerProfile(
  id: 'p1',
  name: 'Home',
  baseUrl: 'https://ledger.example.com',
  authType: AuthType.basic,
  basicUsername: 'alice',
  basicPassword: 's3cret',
  bearerToken: 'tok',
  customHeaders: {'CF-Access-Client-Id': 'id-1', 'CF-Access-Client-Secret': 'sec-2'},
  allowSelfSigned: true,
  color: 0xFF3949AB,
);

/// A browser sign-in profile (session token from `POST /api/auth/app/exchange`).
final _session = ServerProfile(
  id: 'p3',
  name: 'Passkey',
  baseUrl: 'https://pk.example.com',
  authType: AuthType.session,
  sessionToken: 'eyJ1c2VyIjoiZGVtbyJ9.c2lnbmF0dXJl',
  sessionExpiresAt: DateTime.utc(2026, 11, 9, 3, 7, 29),
  sessionUser: 'demo',
);

void main() {
  group('normalizeBaseUrl', () {
    final cases = {
      'ledger.example.com': 'https://ledger.example.com',
      '  ledger.example.com/  ': 'https://ledger.example.com',
      'ledger.example.com/api': 'https://ledger.example.com',
      'ledger.example.com/api/': 'https://ledger.example.com',
      'http://192.168.1.2:8000/': 'http://192.168.1.2:8000',
      'HTTP://Host:8000/API': 'http://Host:8000',
      'https://x.com/zhang/api//': 'https://x.com/zhang',
      'https://x.com/rapi': 'https://x.com/rapi',
      'http://127.0.0.1:18010': 'http://127.0.0.1:18010',
      // No scheme: http for local addresses, https for everything else.
      '127.0.0.1:18011/api/': 'http://127.0.0.1:18011',
      'localhost:8000': 'http://localhost:8000',
      '[::1]:8000': 'http://[::1]:8000',
      '192.168.1.2:8000': 'http://192.168.1.2:8000',
      'nas.local': 'http://nas.local',
      'https://192.168.1.2/': 'https://192.168.1.2', // a typed scheme wins
      'HTTPS://nas.lan:8443': 'https://nas.lan:8443',
      '8.8.8.8': 'https://8.8.8.8',
      'ledger.example.com:8000/zhang': 'https://ledger.example.com:8000/zhang',
    };
    cases.forEach((input, expected) {
      test('"$input" -> "$expected"', () {
        expect(ServerProfile.normalizeBaseUrl(input), expected);
      });
    });

    group('default scheme without a typed one', () {
      const local = [
        'localhost', 'app.localhost', '127.0.0.1', '127.1.2.3', '::1', '10.0.0.8', '172.16.0.1',
        '172.31.255.254', '192.168.1.10', 'nas.local', 'router.lan', 'nas', 'raspberrypi', 'NAS.LOCAL.',
      ];
      const public = [
        'ledger.example.com', 'zhang-demo.onrender.com', '8.8.8.8', '172.15.0.1', '172.32.0.1',
        '192.169.1.1', '11.0.0.1', '2001:db8::1', 'local.example.com', 'lan.example.com', '999.1.1.1',
      ];
      for (final host in local) {
        test('$host is local → http', () => expect(ServerProfile.isLocalHost(host), isTrue));
      }
      for (final host in public) {
        test('$host is not local → https', () => expect(ServerProfile.isLocalHost(host), isFalse));
      }
      test('host is taken without user info, port, path and brackets', () {
        expect(ServerProfile.defaultSchemeFor('me@192.168.1.2:8000/api'), 'http');
        expect(ServerProfile.defaultSchemeFor('[::1]:8000'), 'http');
        expect(ServerProfile.defaultSchemeFor('[2001:db8::1]:443'), 'https');
        expect(ServerProfile.defaultSchemeFor('ledger.example.com/nas'), 'https');
        expect(ServerProfile.defaultSchemeFor('nas:8000/x?y#z'), 'http');
      });
    });

    test('validity check', () {
      expect(ServerProfile.isValidBaseUrl('https://a.b'), isTrue);
      expect(ServerProfile.isValidBaseUrl(ServerProfile.normalizeBaseUrl('ftp://a.b')), isFalse);
      expect(ServerProfile.isValidBaseUrl(ServerProfile.normalizeBaseUrl('')), isFalse);
    });

    test('apiBaseUrl appends /api', () {
      expect(_full.apiBaseUrl, 'https://ledger.example.com/api');
    });
  });

  group('JSON', () {
    test('public JSON contains no secrets', () {
      final public = jsonEncode(_full.toPublicJson());
      expect(public, isNot(contains('s3cret')));
      expect(public, isNot(contains('tok')));
      expect(public, isNot(contains('id-1')));
      expect(public, isNot(contains('sec-2')));
      expect(public, contains('CF-Access-Client-Id')); // header names are public
      expect(public, contains('"v":2'));
      expect(_full.toString(), isNot(contains('s3cret')));
    });

    test('round-trips through public + secret JSON', () {
      final public = jsonDecode(jsonEncode(_full.toPublicJson())) as Map<String, Object?>;
      final secret = jsonDecode(jsonEncode(_full.toSecretJson())) as Map<String, Object?>;
      expect(ServerProfile.fromJson(public, secret), _full);
    });

    test('session: token, expiry and user only in the secret JSON; round-trips', () {
      final public = jsonEncode(_session.toPublicJson());
      expect(public, isNot(contains('eyJ1c2VyIjoiZGVtbyJ9')));
      expect(public, isNot(contains('2026-11-09')));
      expect(public, isNot(contains('demo')));
      expect(public, contains('"authType":"session"'));
      expect(_session.toString(), isNot(contains('eyJ1c2VyIjoiZGVtbyJ9')));

      final secret = jsonDecode(jsonEncode(_session.toSecretJson())) as Map<String, Object?>;
      expect(secret, {
        'sessionToken': 'eyJ1c2VyIjoiZGVtbyJ9.c2lnbmF0dXJl',
        'sessionExpiresAt': '2026-11-09T03:07:29.000Z',
        'sessionUser': 'demo',
      });
      final back = ServerProfile.fromJson(jsonDecode(public) as Map<String, Object?>, secret);
      expect(back, _session);
      expect(back.sessionExpiresAt!.isUtc, isTrue);
    });

    test('session without secrets loads signed out', () {
      final p = ServerProfile.fromJson(_session.toPublicJson());
      expect(p.authType, AuthType.session);
      expect(p.hasSession, isFalse);
      expect(p.authHeaders(), isEmpty);
    });

    test('withoutSession clears the session, keeps the rest', () {
      final out = _session.withoutSession();
      expect(out.sessionToken, isNull);
      expect(out.sessionExpiresAt, isNull);
      expect(out.sessionUser, isNull);
      expect(out.authType, AuthType.session);
      expect(out.baseUrl, _session.baseUrl);
      expect(out.toSecretJson(), isEmpty);
      expect(out == _session, isFalse);
    });

    test('unknown authType falls back to none', () {
      final p = ServerProfile.fromJson({..._session.toPublicJson(), 'authType': 'kerberos'});
      expect(p.authType, AuthType.none);
    });

    test('without secrets header values are empty, passwords null', () {
      final p = ServerProfile.fromJson(_full.toPublicJson());
      expect(p.basicPassword, isNull);
      expect(p.customHeaders, {'CF-Access-Client-Id': '', 'CF-Access-Client-Secret': ''});
    });
  });

  group('authHeaders', () {
    const base = ServerProfile(id: 'x', name: 'x', baseUrl: 'http://h');

    test('none', () => expect(base.authHeaders(), isEmpty));

    test('basic uses exact "Basic" scheme and utf8 base64', () {
      final p = base.copyWith(authType: AuthType.basic, basicUsername: 'alice', basicPassword: 'pw:with:colon');
      expect(p.authHeaders(), {
        'Authorization': 'Basic ${base64Encode(utf8.encode('alice:pw:with:colon'))}',
      });
    });

    test('bearer', () {
      final p = base.copyWith(authType: AuthType.bearer, bearerToken: 'abc');
      expect(p.authHeaders(), {'Authorization': 'Bearer abc'});
    });

    test('session sends the token as Bearer; nothing when signed out', () {
      expect(_session.authHeaders(), {'Authorization': 'Bearer eyJ1c2VyIjoiZGVtbyJ9.c2lnbmF0dXJl'});
      expect(_session.withoutSession().authHeaders(), isEmpty);
      expect(_session.copyWith(sessionToken: '').authHeaders(), isEmpty);
    });

    test('session expiry window', () {
      final now = DateTime.utc(2026, 11, 1);
      expect(_session.sessionExpiresWithin(const Duration(days: 3), now: now), isFalse);
      expect(_session.sessionExpiresWithin(const Duration(days: 9), now: now), isTrue);
      expect(
        _session.sessionExpiresWithin(const Duration(days: 3), now: DateTime.utc(2026, 12)),
        isTrue,
        reason: 'already expired',
      );
      expect(_session.withoutSession().sessionExpiresWithin(const Duration(days: 365), now: now), isFalse);
    });

    test('custom headers alone (blank names dropped)', () {
      final p = base.copyWith(customHeaders: {'X-A': '1', ' ': 'no'});
      expect(p.authHeaders(), {'X-A': '1'});
    });

    const cf = {'CF-Access-Client-Id': 'id-1', 'CF-Access-Client-Secret': 'sec-2'};

    test('custom headers stack with every sign-in method', () {
      expect(_full.authHeaders(), {
        ...cf,
        'Authorization': 'Basic ${base64Encode(utf8.encode('alice:s3cret'))}',
      });
      expect(base.copyWith(authType: AuthType.bearer, bearerToken: 'abc', customHeaders: cf).authHeaders(), {
        ...cf,
        'Authorization': 'Bearer abc',
      });
      final session = _session.copyWith(customHeaders: cf);
      expect(session.authHeaders(), {...cf, 'Authorization': 'Bearer eyJ1c2VyIjoiZGVtbyJ9.c2lnbmF0dXJl'});
      expect(session.withoutSession().authHeaders(), cf, reason: 'signed out: the gateway headers still go');
    });

    test('a custom Authorization never replaces the sign-in method\'s', () {
      const own = {'authorization': 'Token mine', 'X-A': '1'};
      expect(base.copyWith(customHeaders: own).authHeaders(), own, reason: 'allowed without a sign-in method');
      expect(base.copyWith(customHeaders: own).allowsCustomAuthorization, isTrue);
      final basic = base.copyWith(authType: AuthType.basic, basicUsername: 'a', basicPassword: 'b', customHeaders: own);
      expect(basic.allowsCustomAuthorization, isFalse);
      expect(basic.authHeaders(), {'X-A': '1', 'Authorization': 'Basic ${base64Encode(utf8.encode('a:b'))}'});
      final signedOut = _session.withoutSession().copyWith(customHeaders: {' AUTHORIZATION ': 'x'});
      expect(signedOut.authHeaders(), isEmpty, reason: 'not even while signed out');
      expect(ServerProfile.isAuthorizationHeader(' Authorization'), isTrue);
      expect(ServerProfile.isAuthorizationHeader('Proxy-Authorization'), isFalse);
    });
  });

  group('migration of version 1 profiles', () {
    // What app versions before 2026-11-21 stored: no "v", authType could be
    // "headers", custom headers were only sent with that type.
    Map<String, Object?> v1(String authType, {List<String> headerNames = const ['CF-Access-Client-Id']}) => {
      'id': 'old-$authType',
      'name': 'Old',
      'baseUrl': 'https://ledger.example.com',
      'authType': authType,
      if (authType == 'basic') 'basicUsername': 'alice',
      'customHeaderNames': headerNames,
      'allowSelfSigned': false,
    };
    const headerSecret = {
      'customHeaders': {'CF-Access-Client-Id': 'id-1'},
    };

    test('"headers" becomes no sign-in method with the same headers', () {
      final p = ServerProfile.fromJson(v1('headers'), headerSecret);
      expect(p.authType, AuthType.none);
      expect(p.customHeaders, {'CF-Access-Client-Id': 'id-1'});
      expect(p.authHeaders(), {'CF-Access-Client-Id': 'id-1'});
    });

    test('a custom Authorization of a "headers" profile keeps working', () {
      final p = ServerProfile.fromJson(v1('headers', headerNames: ['Authorization']), {
        'customHeaders': {'Authorization': 'Token abc'},
      });
      expect(p.authHeaders(), {'Authorization': 'Token abc'});
    });

    test('other types send exactly what they sent before (leftover headers dropped)', () {
      final basic = ServerProfile.fromJson(v1('basic'), {...headerSecret, 'basicPassword': 'pw'});
      expect(basic.authType, AuthType.basic);
      expect(basic.customHeaders, isEmpty);
      expect(basic.authHeaders(), {'Authorization': 'Basic ${base64Encode(utf8.encode('alice:pw'))}'});
      final bearer = ServerProfile.fromJson(v1('bearer'), {...headerSecret, 'bearerToken': 't'});
      expect(bearer.authHeaders(), {'Authorization': 'Bearer t'});
      final session = ServerProfile.fromJson(v1('session'), {...headerSecret, 'sessionToken': 'tok.sig'});
      expect(session.authHeaders(), {'Authorization': 'Bearer tok.sig'});
      expect(ServerProfile.fromJson(v1('none'), headerSecret).authHeaders(), isEmpty);
    });

    test('only an integer v >= 2 is version 2', () {
      for (final v in ['2', 1, 2.5, true]) {
        final p = ServerProfile.fromJson({...v1('basic'), 'v': v}, {...headerSecret, 'basicPassword': 'pw'});
        expect(p.customHeaders, isEmpty, reason: 'v: $v is read as version 1');
      }
      final future = ServerProfile.fromJson({...v1('basic'), 'v': 3}, {...headerSecret, 'basicPassword': 'pw'});
      expect(future.customHeaders, {'CF-Access-Client-Id': 'id-1'});
    });

    test('an unknown authType fails closed: no Authorization, not even a custom one', () {
      final p = ServerProfile.fromJson(
        {...v1('kerberos', headerNames: ['Authorization', 'X-Gate']), 'v': 2},
        {
          'customHeaders': {'Authorization': 'Negotiate abc', 'X-Gate': 'open'},
        },
      );
      expect(p.authType, AuthType.none);
      expect(p.authHeaders(), {'X-Gate': 'open'});
    });

    test('version 2 keeps the headers of every type', () {
      final v2 = {...v1('basic'), 'v': 2};
      final p = ServerProfile.fromJson(v2, {...headerSecret, 'basicPassword': 'pw'});
      expect(p.customHeaders, {'CF-Access-Client-Id': 'id-1'});
      expect(p.authHeaders().keys, ['CF-Access-Client-Id', 'Authorization']);
    });
  });

  group('plain http', () {
    const lan = ServerProfile(
      id: 'h',
      name: 'NAS',
      baseUrl: 'http://192.168.1.2:8000',
      authType: AuthType.basic,
      basicUsername: 'demo',
      basicPassword: 'secret',
    );

    test('credentials to a non-loopback http host are sent in clear', () {
      expect(lan.usesPlainHttp, isTrue);
      expect(lan.sendsCredentialsInClear, isTrue);
      expect(lan.copyWith(baseUrl: 'https://192.168.1.2:8000').sendsCredentialsInClear, isFalse);
      expect(lan.copyWith(authType: AuthType.none).sendsCredentialsInClear, isFalse, reason: 'nothing secret');
      expect(lan.copyWith(authType: AuthType.session).sendsCredentialsInClear, isTrue, reason: 'even signed out');
      for (final url in [
        'http://nas.local',
        'http://10.0.0.8',
        'http://ledger.example.com',
        'http://[fe80::1]:8000',
        'http://app.localhost', // resolvers on phones need not map *.localhost to loopback
      ]) {
        expect(lan.copyWith(baseUrl: url).sendsCredentialsInClear, isTrue, reason: url);
      }
    });

    test('loopback hosts are exempt', () {
      for (final url in [
        'http://localhost:8000',
        'http://LOCALHOST.',
        'http://127.0.0.1:18011',
        'http://127.1.2.3',
        'http://[::1]:8000',
      ]) {
        expect(ServerProfile.plainHttpRiskFor(url), isFalse, reason: url);
        expect(lan.copyWith(baseUrl: url).sendsCredentialsInClear, isFalse, reason: url);
      }
      expect(ServerProfile.isLoopbackHost('127.0.0.256'), isFalse);
      expect(ServerProfile.isLoopbackHost('128.0.0.1'), isFalse);
      expect(ServerProfile.isLoopbackHost('localhost.example.com'), isFalse);
      expect(ServerProfile.isLoopbackHost('app.localhost'), isFalse);
    });

    test('the acknowledgement is stored per profile (public JSON), absent = not given', () {
      final acked = lan.copyWith(plainHttpAcknowledged: true);
      final public = jsonDecode(jsonEncode(acked.toPublicJson())) as Map<String, Object?>;
      expect(public['plainHttpAcknowledged'], isTrue);
      expect(ServerProfile.fromJson(public, acked.toSecretJson()), acked);
      expect(lan.toPublicJson().containsKey('plainHttpAcknowledged'), isFalse);
      expect(ServerProfile.fromJson(lan.toPublicJson()).plainHttpAcknowledged, isFalse);
      expect(acked == lan, isFalse);
    });
  });

  group('ProfileRepository', () {
    late SharedPreferences prefs;
    late InMemorySecretStore secrets;
    late ProfileRepository repo;

    setUp(() async {
      SharedPreferences.setMockInitialValues({});
      prefs = await SharedPreferences.getInstance();
      secrets = InMemorySecretStore();
      repo = ProfileRepository(prefs: prefs, secrets: secrets);
    });

    test('stores secrets only in the secret store', () async {
      await repo.upsert(_full);
      await repo.setActiveId(_full.id);
      final stored = prefs.getString(ProfileRepository.profilesKey)!;
      expect(stored, isNot(contains('s3cret')));
      expect(stored, isNot(contains('sec-2')));
      expect(secrets.values[ProfileRepository.secretKey('p1')], contains('s3cret'));

      final state = await repo.load();
      expect(state.profiles, [_full]);
      expect(state.active, _full);
    });

    test('upsert replaces in place; delete removes secrets and active id', () async {
      await repo.upsert(_full);
      await repo.upsert(_full.copyWith(id: 'p2', name: 'Work'));
      await repo.upsert(_full.copyWith(name: 'Home 2'));
      var state = await repo.load();
      expect(state.profiles.map((p) => p.name), ['Home 2', 'Work']);

      await repo.setActiveId('p1');
      await prefs.setStringList('zhang.accountPicker.p1.recent.v1', ['Assets:Bank']);
      await prefs.setString('zhang.record.p1.lastFunding.v1', '{}');
      await prefs.setStringList('zhang.accountPicker.p2.recent.v1', ['Assets:Cash']);
      await repo.delete('p1');
      state = await repo.load();
      expect(state.profiles.map((p) => p.id), ['p2']);
      expect(secrets.values.containsKey(ProfileRepository.secretKey('p1')), isFalse);
      expect(prefs.getKeys().where((k) => k.contains('.p1.')), isEmpty, reason: 'per-profile prefs removed');
      expect(prefs.getStringList('zhang.accountPicker.p2.recent.v1'), ['Assets:Cash']);
      // Active id pointed at the deleted profile → falls back to the first one.
      expect(state.activeId, 'p2');
    });

    test('session secrets stay out of shared_preferences', () async {
      await repo.upsert(_session);
      final stored = prefs.getString(ProfileRepository.profilesKey)!;
      expect(stored, isNot(contains('eyJ1c2VyIjoiZGVtbyJ9')));
      expect(secrets.values[ProfileRepository.secretKey('p3')], contains('eyJ1c2VyIjoiZGVtbyJ9'));
      expect((await repo.load()).profiles, [_session]);

      // Signing out deletes the secret entry altogether.
      await repo.upsert(_session.withoutSession());
      expect(secrets.values.containsKey(ProfileRepository.secretKey('p3')), isFalse);
      expect((await repo.load()).profiles.single.hasSession, isFalse);
    });

    test('migrates stored version 1 profiles without loss; saving writes version 2', () async {
      await prefs.setString(
        ProfileRepository.profilesKey,
        jsonEncode([
          {
            'id': 'gw',
            'name': 'Gateway',
            'baseUrl': 'https://gw.example.com',
            'authType': 'headers',
            'customHeaderNames': ['CF-Access-Client-Id', 'CF-Access-Client-Secret'],
            'allowSelfSigned': true,
            'color': 0xFF3949AB,
          },
          {
            'id': 'pw',
            'name': 'Password',
            'baseUrl': 'http://127.0.0.1:18011',
            'authType': 'basic',
            'basicUsername': 'demo',
            'customHeaderNames': <String>[],
            'allowSelfSigned': false,
          },
        ]),
      );
      await prefs.setString(ProfileRepository.activeKey, 'pw');
      secrets.values[ProfileRepository.secretKey('gw')] = jsonEncode({
        'customHeaders': {'CF-Access-Client-Id': 'id-1', 'CF-Access-Client-Secret': 'sec-2'},
      });
      secrets.values[ProfileRepository.secretKey('pw')] = jsonEncode({'basicPassword': 'secret'});

      final state = await repo.load();
      expect(state.activeId, 'pw');
      final [gw, pw] = state.profiles;
      expect(gw, const ServerProfile(
        id: 'gw',
        name: 'Gateway',
        baseUrl: 'https://gw.example.com',
        customHeaders: {'CF-Access-Client-Id': 'id-1', 'CF-Access-Client-Secret': 'sec-2'},
        allowSelfSigned: true,
        color: 0xFF3949AB,
      ));
      expect(gw.authHeaders(), {'CF-Access-Client-Id': 'id-1', 'CF-Access-Client-Secret': 'sec-2'});
      expect(pw, const ServerProfile(
        id: 'pw',
        name: 'Password',
        baseUrl: 'http://127.0.0.1:18011',
        authType: AuthType.basic,
        basicUsername: 'demo',
        basicPassword: 'secret',
      ));

      // Stacking Basic on the migrated gateway profile and saving: version 2.
      final stacked = gw.copyWith(authType: AuthType.basic, basicUsername: 'demo', basicPassword: 'secret');
      await repo.upsert(stacked);
      final stored = (jsonDecode(prefs.getString(ProfileRepository.profilesKey)!) as List).first as Map;
      expect(stored['v'], 2);
      expect(stored['authType'], 'basic');
      expect((await repo.load()).profiles.first, stacked);
    });

    test('corrupt prefs do not crash loading', () async {
      await prefs.setString(ProfileRepository.profilesKey, '{not json');
      final state = await repo.load();
      expect(state.profiles, isEmpty);
      expect(state.active, isNull);
    });
  });
}
