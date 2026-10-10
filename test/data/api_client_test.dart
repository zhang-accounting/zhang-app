import 'dart:convert';
import 'dart:io';

import 'package:decimal/decimal.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:zhang_app/core/utils/dates.dart';
import 'package:zhang_app/data/api/api_exception.dart';
import 'package:zhang_app/data/api/zhang_api_client.dart';
import 'package:zhang_app/data/models/models.dart';
import 'package:zhang_app/data/profiles/server_profile.dart';
import 'package:zhang_app/data/repositories/repositories.dart';

import '../helpers/builtin_fake.dart';
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
      expect(info.buildDate, '2026-10-10');
      expect(info.format, 'zhang');
      expect(info.isSupported, isTrue);
    });

    test('401 {"message":"unauthorized"} → ApiUnauthorized', () async {
      final (client, _) = _client(
        _base,
        (_) => rawJsonResponse(fixtureText('err_unauthorized.json'), status: 401),
      );
      await expectLater(
        client.info(),
        throwsA(isA<ApiUnauthorized>().having((e) => e.message, 'message', 'unauthorized')),
      );
    });

    test('401 with empty body → ApiUnauthorized', () async {
      final (client, _) = _client(_base, (_) => emptyResponse(401));
      await expectLater(client.info(), throwsA(isA<ApiUnauthorized>()));
    });

    test('404 JSON → ApiNotFound', () async {
      final (client, _) = _client(_base, (_) => jsonResponse({'message': 'not found'}, status: 404));
      await expectLater(
        client.get('/accounts/Assets:Nope', decode: (d) => d),
        throwsA(
          isA<ApiNotFound>()
              .having((e) => e.message, 'message', 'not found')
              .having((e) => e.isMissingRoute, 'isMissingRoute', isFalse),
        ),
      );
    });

    test('404 / 405 "no route" → isMissingRoute (API version mismatch)', () async {
      final (client, _) = _client(_base, (o) {
        final name = o.path.endsWith('/balances') ? 'err_wrong_method.json' : 'err_no_route.json';
        return rawJsonResponse(fixtureText(name), status: o.path.endsWith('/balances') ? 405 : 404);
      });
      await expectLater(
        client.get('/statistic/summary', decode: (d) => d),
        throwsA(isA<ApiNotFound>().having((e) => e.isMissingRoute, 'isMissingRoute', isTrue)),
      );
      await expectLater(
        client.get('/accounts/Assets:Paypal/balances', decode: (d) => d),
        throwsA(
          isA<ApiServerError>()
              .having((e) => e.status, 'status', 405)
              .having((e) => e.isMissingRoute, 'isMissingRoute', isTrue),
        ),
      );
    });

    test('400 JSON message → ApiServerError(status, message)', () async {
      final (client, _) = _client(
        _base,
        (_) => jsonResponse({'message': 'invalid account "Foo:Bar": it is `Assets`, …'}, status: 400),
      );
      await expectLater(
        client.get('/accounts/Foo:Bar', decode: (d) => d),
        throwsA(
          isA<ApiServerError>()
              .having((e) => e.status, 'status', 400)
              .having((e) => e.message, 'message', startsWith('invalid account "Foo:Bar"')),
        ),
      );
    });

    test('422 JSON (body rejected) → ApiServerError with the message', () async {
      final (client, _) = _client(
        _base,
        (_) => jsonResponse({
          'message': 'Failed to deserialize the JSON body into the target type: missing field `metas` at line 1 column 96',
        }, status: 422),
      );
      await expectLater(
        client.post('/transactions', body: const {}, decode: (d) => d),
        throwsA(isA<ApiServerError>().having((e) => e.message, 'message', contains('missing field'))),
      );
    });

    test('plain-text error (e.g. from a reverse proxy) → ApiServerError with the text', () async {
      final (client, _) = _client(_base, (_) => textResponse('Bad Gateway', status: 502));
      await expectLater(
        client.get('/info', decode: (d) => d),
        throwsA(isA<ApiServerError>().having((e) => e.message, 'message', 'Bad Gateway')),
      );
    });

    test('400 empty body → ApiServerError("HTTP 400")', () async {
      final (client, _) = _client(_base, (_) => emptyResponse(400));
      await expectLater(
        client.get('/journals?page=abc', decode: (d) => d),
        throwsA(isA<ApiServerError>().having((e) => e.message, 'message', 'HTTP 400')),
      );
    });

    test('200 text/plain (not a zhang API URL, or the frontend fallback) → ApiParseError', () async {
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
          datetime: DateTime(2026, 10, 2, 9, 30),
          payee: 'Cafe',
          postings: [
            PostingRequest(account: 'Assets:WeChat', unit: Amount(Decimal.parse('-32.50'), 'CNY')),
            const PostingRequest(account: 'Expenses:Food'),
          ],
        ),
      );
      final body = adapter.last.data as Map<String, Object?>;
      expect(adapter.last.method, 'POST');
      expect(body['datetime'], '2026-10-02T09:30:00', reason: 'ledger wall clock, no offset');
      expect(body['narration'], '');
      expect((body['postings'] as List).first, {
        'account': 'Assets:WeChat',
        'unit': {'number': '-32.5', 'commodity': 'CNY'},
      });
      expect(mutated, 1);
    });

    test('summary: one batch of report.* queries with ledger dates', () async {
      final builtins = FakeBuiltins();
      final (client, adapter) = _client(_base, (o) => builtins.handle(o)!);
      final summary = await StatisticRepository(client).summary(
        DateTime(2023, 9),
        DateTime(2023, 9, 30, 23, 59, 59),
        currency: 'CNY',
      );
      expect(adapter.requests, hasLength(1));
      expect(adapter.last.uri.path, '/api/query/builtins');
      expect([for (final c in builtins.calls) c.name], [
        'report.net_worth',
        'report.liabilities',
        'report.flows',
        'report.transaction_count',
      ]);
      expect(builtins.calls[2].params, {'from': '2023-09-01', 'to': '2023-09-30', 'currency': 'CNY'});
      expect(summary.expense.calculated, Amount(Decimal.parse('798.6775'), 'CNY'));
      expect(summary.to, DateTime(2023, 9, 30));
    });

    test('graph sends ledger dates', () async {
      final (client, adapter) = _client(_base, (_) => jsonResponse(fixture('statistic_graph.json')));
      await StatisticRepository(client).graph(DateTime(2023, 9), DateTime(2023, 9, 5, 23, 59, 59));
      expect(adapter.last.queryParameters, {'from': '2023-09-01', 'to': '2023-09-05', 'interval': 'Day'});
    });

    test('rank: report.account_totals + report.top_postings for the type', () async {
      final builtins = FakeBuiltins();
      final (client, _) = _client(_base, (o) => builtins.handle(o)!);
      final rank = await StatisticRepository(client).rank(
        AccountType.expenses,
        DateTime(2023, 9),
        DateTime(2023, 9, 30),
        currency: 'CNY',
      );
      expect([for (final c in builtins.calls) c.name], ['report.account_totals', 'report.top_postings']);
      expect(builtins.calls.first.params, {
        'type': 'Expenses',
        'from': '2023-09-01',
        'to': '2023-09-30',
        'currency': 'CNY',
      });
      expect(rank.detail, hasLength(6));
      expect(rank.topTransactions.first.payee, 'UNIQLO');
    });

    test('ledger errors: journals.errors with count_total, paged by offset', () async {
      final builtins = FakeBuiltins();
      final (client, adapter) = _client(_base, (o) => builtins.handle(o)!);
      final page = await LedgerRepository(client).errors(page: 2, size: 5000);
      expect(adapter.last.uri.path, '/api/query/builtins/journals.errors');
      expect(jsonDecode(jsonEncode(adapter.last.data)), {
        'params': {'size': 1000, 'offset': 1000},
        'count_total': true,
      });
      expect(page.totalCount, 2);
      expect(page.records.first.type, LedgerErrorType.unbalancedTransaction);
    });

    test('ledger clock: ledger.now as a naive wall-clock DateTime', () async {
      final builtins = FakeBuiltins();
      final (client, _) = _client(_base, (o) => builtins.handle(o)!);
      final now = await LedgerRepository(client).now();
      final row = (singleResult('ledger_now.json')['rows']! as List).single as List;
      expect(now.isUtc, isFalse);
      expect(ZhangDates.toIsoDate(now), row[0]);
      expect(ZhangDates.toNaiveIso(now), '${row[0]}T${row[1]}');
    });

    test('account balance history: accounts.balance_history', () async {
      final builtins = FakeBuiltins();
      final (client, _) = _client(_base, (o) => builtins.handle(o)!);
      final h = await AccountRepository(client).balances('Assets:Paypal');
      expect(builtins.calls.single.params, {'account': 'Assets:Paypal'});
      expect(h.commodities, ['CNY', 'USD']);
    });

    test('account journals: 404 (no own open directive) reads as no postings', () async {
      final (client, _) = _client(_base, (_) => jsonResponse({'message': 'not found'}, status: 404));
      expect(await AccountRepository(client).journals('Assets:CitiBank'), isEmpty);
    });

    test('form data: ledger.now first, then payees + accounts open at that instant', () async {
      final builtins = FakeBuiltins();
      final (client, adapter) = _client(_base, (o) => builtins.handle(o)!);
      final f = await JournalRepository(client).forNewTransaction();
      expect(adapter.requests.map((r) => r.uri.path), [
        '/api/query/builtins/ledger.now',
        '/api/query/builtins',
      ]);
      final row = (singleResult('ledger_now.json')['rows']! as List).single as List;
      expect(builtins.callsTo('journals.accounts').single.params, {'date': row[0], 'time': row[1]});
      expect(f.payees.first, 'Adidas');
      expect(f.accountNames.first, 'Assets:CitiBank:9999');
    });

    test('preview posts the transaction body to /api/transactions/preview', () async {
      final (client, adapter) = _client(_base, (_) => jsonResponse(fixture('transaction_preview.json')));
      final preview = await JournalRepository(client).preview(
        CreateTransactionRequest(
          datetime: DateTime(2026, 10, 10, 9, 30),
          payee: 'Cafe',
          narration: 'Latte',
          postings: [
            PostingRequest(account: 'Assets:WeChat', unit: Amount(Decimal.parse('-32.50'), 'CNY')),
            const PostingRequest(account: 'Expenses:PersonalDiet:Lunch'),
          ],
        ),
      );
      expect(adapter.last.method, 'POST');
      expect(adapter.last.uri.path, '/api/transactions/preview');
      expect((adapter.last.data as Map)['datetime'], '2026-10-10T09:30:00');
      expect(preview.isClean, isTrue);
      expect(preview.text, startsWith('2026-10-10 09:30:00 * "Cafe" "Latte"'));
    });

    test('budgets: month list, detail, unknown name, merged history', () async {
      final builtins = FakeBuiltins({
        'budgets.budget': (p) => p['name'] == 'food'
            ? batchResult('budget_detail.json', 0)
            : {...batchResult('budget_detail.json', 0), 'rows': const <Object?>[]},
      });
      final (client, _) = _client(_base, (o) => builtins.handle(o)!);
      final repo = BudgetRepository(client);
      final list = await repo.list(year: 2023, month: 9);
      expect(builtins.callsTo('budgets.month').single.params, {'month': '2023-09-01'});
      expect(list.single.name, 'food');
      await repo.list();
      expect(builtins.callsTo('ledger.now'), hasLength(1), reason: 'current month by the ledger clock');
      final detail = await repo.get('food', year: 2023, month: 9);
      expect(detail.relatedAccounts, ['Expenses:Groceries']);
      await expectLater(repo.get('nope', year: 2023, month: 9), throwsA(isA<ApiNotFound>()));
      final items = await repo.interval('food', 2023, 9);
      expect(items.first, isA<BudgetPosting>());
      expect(items.last, isA<BudgetEvent>());
      await repo.interval('food', 2023, 13);
      expect(builtins.callsTo('budgets.events').last.params, {'name': 'food', 'month': '2024-01-01'});
    });

    test('documents: journals.documents; download by base64 path', () async {
      final builtins = FakeBuiltins();
      final (client, adapter) = _client(_base, (o) => builtins.handle(o) ?? textResponse('hello receipt'));
      final docs = await DocumentRepository(client).list();
      expect(docs, hasLength(3));
      await DocumentRepository(client).download(docs.last);
      expect(adapter.last.uri.path, '/api/documents/YXR0YWNobWVudHMvcmVjZWlwdC50eHQ=');
    });
  });
}
