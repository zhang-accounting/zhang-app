import 'dart:convert';
import 'dart:io';

import 'package:decimal/decimal.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:zhang_app/data/api/api_exception.dart';
import 'package:zhang_app/data/api/zhang_api_client.dart';
import 'package:zhang_app/data/models/models.dart';
import 'package:zhang_app/data/profiles/server_profile.dart';
import 'package:zhang_app/data/repositories/repositories.dart';

import '../helpers/fake_adapter.dart';
import '../helpers/fixtures.dart';

const _base = ServerProfile(id: 'p', name: 'Test', baseUrl: 'http://127.0.0.1:18010');

(ZhangApiClient, FakeAdapter) _client(ServerProfile profile, FakeHandler handler) {
  final client = ZhangApiClient(profile);
  final adapter = FakeAdapter(handler);
  client.dio.httpClientAdapter = adapter;
  return (client, adapter);
}

void main() {
  group('auth header injection', () {
    Future<Map<String, dynamic>> headersFor(ServerProfile profile) async {
      final (client, adapter) = _client(profile, (_) => jsonResponse(fixture('info.json')));
      await client.info();
      return adapter.last.headers;
    }

    test('none sends no Authorization', () async {
      final h = await headersFor(_base);
      expect(h.containsKey('Authorization'), isFalse);
    });

    test('basic', () async {
      final h = await headersFor(
        _base.copyWith(authType: AuthType.basic, basicUsername: 'demo', basicPassword: 'secret'),
      );
      expect(h['Authorization'], 'Basic ${base64Encode(utf8.encode('demo:secret'))}');
    });

    test('bearer', () async {
      final h = await headersFor(_base.copyWith(authType: AuthType.bearer, bearerToken: 't0k'));
      expect(h['Authorization'], 'Bearer t0k');
    });

    test('custom headers', () async {
      final h = await headersFor(
        _base.copyWith(
          authType: AuthType.headers,
          customHeaders: {'CF-Access-Client-Id': 'a', 'CF-Access-Client-Secret': 'b'},
        ),
      );
      expect(h['CF-Access-Client-Id'], 'a');
      expect(h['CF-Access-Client-Secret'], 'b');
      expect(h.containsKey('Authorization'), isFalse);
    });

    test('requests go to <baseUrl>/api/<path>', () async {
      final (client, adapter) = _client(_base, (_) => jsonResponse(fixture('info.json')));
      await client.info();
      expect(adapter.last.uri.toString(), 'http://127.0.0.1:18010/api/info');
    });
  });

  group('envelope and error mapping', () {
    test('unwraps {"data": …}', () async {
      final (client, _) = _client(_base, (_) => jsonResponse(fixture('info.json')));
      final info = await client.info();
      expect(info.title, 'My Accounting');
      expect(info.version, '0.1.0');
      expect(info.buildDate, '2026-10-02');
    });

    test('401 with empty body → ApiUnauthorized', () async {
      final (client, _) = _client(
        _base,
        (_) => emptyResponse(401, headers: {
          'www-authenticate': ['Basic'],
        }),
      );
      await expectLater(client.info(), throwsA(isA<ApiUnauthorized>()));
    });

    test('404 JSON → ApiNotFound', () async {
      final (client, _) = _client(
        _base,
        (_) => jsonResponse({'message': 'not found', 'origin': 'with_rejection'}, status: 404),
      );
      await expectLater(
        client.get('/accounts/Assets:Nope', decode: (d) => d),
        throwsA(isA<ApiNotFound>().having((e) => e.message, 'message', 'not found')),
      );
    });

    test('500 JSON message → ApiServerError(status, message)', () async {
      final (client, _) = _client(
        _base,
        (_) => jsonResponse({'message': 'core error: account is invalid', 'origin': 'with_rejection'}, status: 500),
      );
      await expectLater(
        client.get('/accounts/Foo', decode: (d) => d),
        throwsA(
          isA<ApiServerError>()
              .having((e) => e.status, 'status', 500)
              .having((e) => e.message, 'message', 'core error: account is invalid'),
        ),
      );
    });

    test('422 plain text → ApiServerError with the text', () async {
      final (client, _) = _client(
        _base,
        (_) => textResponse('Failed to deserialize the JSON body: missing field `metas`', status: 422),
      );
      await expectLater(
        client.post('/transactions', body: const {}, decode: (d) => d),
        throwsA(isA<ApiServerError>().having((e) => e.message, 'message', contains('missing field'))),
      );
    });

    test('400 empty body → ApiServerError("HTTP 400")', () async {
      final (client, _) = _client(_base, (_) => emptyResponse(400));
      await expectLater(
        client.get('/journals?page=abc', decode: (d) => d),
        throwsA(isA<ApiServerError>().having((e) => e.message, 'message', 'HTTP 400')),
      );
    });

    test('200 text/plain fallback (unknown path / not zhang) → ApiParseError', () async {
      final (client, _) = _client(
        _base,
        (_) => textResponse('hello zhang,\nseems you are trying to access the frontend UI'),
      );
      await expectLater(client.info(), throwsA(isA<ApiParseError>()));
      await expectLater(client.send('POST', '/nope'), throwsA(isA<ApiParseError>()));
    });

    test('JSON without envelope → ApiParseError', () async {
      final (client, _) = _client(_base, (_) => jsonResponse({'title': 'x'}));
      await expectLater(client.info(), throwsA(isA<ApiParseError>()));
    });

    test('malformed payload → ApiParseError', () async {
      final (client, _) = _client(_base, (_) => jsonResponse({'data': {'title': 1}}));
      await expectLater(client.info(), throwsA(isA<ApiParseError>()));
    });

    test('socket failure (connection closed / refused) → ApiNetworkError', () async {
      final (client, _) = _client(_base, (_) => throw const SocketException('Connection refused'));
      await expectLater(
        client.info(),
        throwsA(isA<ApiNetworkError>().having((e) => e.kind, 'kind', NetworkErrorKind.connection)),
      );
    });

    test('send(): 201 empty body and 200 {"data":"Ok"} both succeed', () async {
      final (client, adapter) = _client(_base, (_) => emptyResponse(201));
      await client.send('POST', '/accounts/Assets:Cash/balances', body: const {'type': 'Check'});
      adapter.handler = (_) => jsonResponse({'data': 'Ok'});
      await client.send('POST', '/transactions', body: const {});
      expect(adapter.requests, hasLength(2));
    });
  });

  group('repositories', () {
    test('journal list sends literal-bracket query and post-filters tags', () async {
      final (client, adapter) = _client(_base, (_) => jsonResponse(fixture('journals.json')));
      final repo = JournalRepository(client);
      final page = await repo.list(const JournalQuery(page: 2, size: 5, keyword: '隆江 x', tags: ['weekly']));
      // The path handed to dio carries literal brackets (dart:io may still
      // percent-encode them on the wire – see JournalRepository.list docs).
      expect(adapter.last.path, contains('tags[0]=weekly'));
      expect(adapter.last.path, contains('keyword=${Uri.encodeComponent('隆江 x')}'));
      expect(adapter.last.path, contains('page=2&size=5'));
      expect(page.records, hasLength(1));
      expect((page.records.single as JournalTransaction).tags, ['weekly']);
    });

    test('create posts strings and bumps revision callback', () async {
      var mutated = 0;
      final (client, adapter) = _client(_base, (_) => jsonResponse({'data': 'Ok'}));
      final repo = JournalRepository(client, onMutated: () => mutated++);
      await repo.create(
        CreateTransactionRequest(
          datetime: DateTime.utc(2026, 10, 2, 9, 30),
          payee: 'Cafe',
          postings: [
            PostingRequest(account: 'Assets:WeChat', unit: Amount(Decimal.parse('-32.50'), 'CNY')),
            const PostingRequest(account: 'Expenses:Food'),
          ],
        ),
      );
      final body = adapter.last.data as Map<String, Object?>;
      expect(adapter.last.method, 'POST');
      expect(body['datetime'], '2026-10-02T09:30:00Z');
      expect(body['narration'], '');
      expect((body['postings'] as List).first, {
        'account': 'Assets:WeChat',
        'unit': {'number': '-32.5', 'commodity': 'CNY'},
      });
      expect(mutated, 1);
    });

    test('statistic range is sent as RFC 3339 UTC', () async {
      final (client, adapter) = _client(_base, (_) => jsonResponse(fixture('statistic_summary.json')));
      await StatisticRepository(client).summary(
        DateTime.utc(2023, 8, 31, 15),
        DateTime.utc(2023, 9, 30, 14, 59, 59),
      );
      expect(adapter.last.queryParameters, {
        'from': '2023-08-31T15:00:00Z',
        'to': '2023-09-30T14:59:59Z',
      });
    });

    test('budget interval rejects invalid months before calling the server', () {
      final (client, adapter) = _client(_base, (_) => jsonResponse({'data': []}));
      expect(() => BudgetRepository(client).interval('food', 2023, 13), throwsArgumentError);
      expect(adapter.requests, isEmpty);
    });
  });
}
