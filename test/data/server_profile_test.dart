import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:zhang_app/data/profiles/profile_repository.dart';
import 'package:zhang_app/data/profiles/secret_store.dart';
import 'package:zhang_app/data/profiles/server_profile.dart';

const _full = ServerProfile(
  id: 'p1',
  name: 'Home',
  baseUrl: 'https://ledger.example.com',
  authType: AuthType.headers,
  basicUsername: 'alice',
  basicPassword: 's3cret',
  bearerToken: 'tok',
  customHeaders: {'CF-Access-Client-Id': 'id-1', 'CF-Access-Client-Secret': 'sec-2'},
  allowSelfSigned: true,
  color: 0xFF3949AB,
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
    };
    cases.forEach((input, expected) {
      test('"$input" -> "$expected"', () {
        expect(ServerProfile.normalizeBaseUrl(input), expected);
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
      expect(_full.toString(), isNot(contains('s3cret')));
    });

    test('round-trips through public + secret JSON', () {
      final public = jsonDecode(jsonEncode(_full.toPublicJson())) as Map<String, Object?>;
      final secret = jsonDecode(jsonEncode(_full.toSecretJson())) as Map<String, Object?>;
      expect(ServerProfile.fromJson(public, secret), _full);
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

    test('custom headers (blank names dropped)', () {
      final p = base.copyWith(authType: AuthType.headers, customHeaders: {'X-A': '1', ' ': 'no'});
      expect(p.authHeaders(), {'X-A': '1'});
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
      await repo.delete('p1');
      state = await repo.load();
      expect(state.profiles.map((p) => p.id), ['p2']);
      expect(secrets.values.containsKey(ProfileRepository.secretKey('p1')), isFalse);
      // Active id pointed at the deleted profile → falls back to the first one.
      expect(state.activeId, 'p2');
    });

    test('corrupt prefs do not crash loading', () async {
      await prefs.setString(ProfileRepository.profilesKey, '{not json');
      final state = await repo.load();
      expect(state.profiles, isEmpty);
      expect(state.active, isNull);
    });
  });
}
