import 'dart:convert';

import 'package:decimal/decimal.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:zhang_app/data/api/api_exception.dart';
import 'package:zhang_app/data/api/builtin_query_client.dart';
import 'package:zhang_app/data/api/zhang_api_client.dart';
import 'package:zhang_app/data/models/models.dart';
import 'package:zhang_app/data/profiles/server_profile.dart';

import '../helpers/fake_adapter.dart';
import '../helpers/fixtures.dart';

const _profile = ServerProfile(id: 'p', name: 'Test', baseUrl: 'http://127.0.0.1:18080');

Decimal d(String v) => Decimal.parse(v);

(BuiltinQueryClient, FakeAdapter) _client(FakeHandler handler) {
  final client = ZhangApiClient(_profile);
  final adapter = FakeAdapter(handler);
  client.dio.httpClientAdapter = adapter;
  return (client.builtins, adapter);
}

/// Results of `test/fixtures/builtin_batch.json` (captured from zhang 0.2):
/// report.net_worth, journals.errors (count_total), budgets.budget,
/// budgets.month, ledger.now.
List<QueryResult> _batch() => [for (final r in fixtureData('builtin_batch.json')! as List) QueryResult.fromJson(r)];

void main() {
  group('requests', () {
    test('run posts {params, count_total} to /api/query/builtins/{name}', () async {
      final (q, adapter) = _client((_) => jsonResponse(fixture('ledger_now.json')));
      await q.run(const BuiltinQuery('journals.errors', {'size': 100, 'offset': 0}, true));
      expect(adapter.last.method, 'POST');
      expect(adapter.last.uri.path, '/api/query/builtins/journals.errors');
      expect(adapter.last.headers['content-type'], contains('application/json'));
      expect(jsonDecode(jsonEncode(adapter.last.data)), {
        'params': {'size': 100, 'offset': 0},
        'count_total': true,
      });
    });

    test('run sends empty params as {} and omits count_total', () async {
      final (q, adapter) = _client((_) => jsonResponse(fixture('ledger_now.json')));
      final now = await q.run(const BuiltinQuery('ledger.now'));
      expect(jsonDecode(jsonEncode(adapter.last.data)), {'params': <String, Object?>{}});
      expect(now.firstOrNull!.date('date'), DateTime(2026, 10, 10));
      expect(now.firstOrNull!.dateTime('date', 'time'), DateTime(2026, 10, 10, 11, 58, 15));
    });

    test('runBatch posts [{name, params}] and returns results in order', () async {
      final (q, adapter) = _client((_) => jsonResponse(fixture('builtin_batch.json')));
      final results = await q.runBatch([
        BuiltinQuery('report.net_worth', {'to': BuiltinQuery.date(DateTime(2023, 9, 30, 23, 59)), 'currency': 'CNY'}),
        const BuiltinQuery('journals.errors', {'size': 1, 'offset': 0}, true),
        const BuiltinQuery('budgets.budget', {'name': 'food'}),
        const BuiltinQuery('budgets.month', {'month': '2023-09-01'}),
        const BuiltinQuery('ledger.now'),
      ]);
      expect(adapter.last.uri.path, '/api/query/builtins');
      final body = jsonDecode(jsonEncode(adapter.last.data)) as List;
      expect(body.first, {
        'name': 'report.net_worth',
        'params': {'to': '2023-09-30', 'currency': 'CNY'},
      });
      expect(body[1], {
        'name': 'journals.errors',
        'params': {'size': 1, 'offset': 0},
        'count_total': true,
      });
      expect(results, hasLength(5));
      expect(results[1].total, 2);
      expect(results.first.total, isNull);
    });

    test('a batch with the wrong number of results is a parse error', () async {
      final (q, _) = _client((_) => jsonResponse(fixture('ledger_now.json')));
      await expectLater(
        q.runBatch(const [BuiltinQuery('ledger.now'), BuiltinQuery('journals.payees')]),
        throwsA(isA<ApiParseError>()),
      );
    });
  });

  group('error bodies', () {
    test('unknown query → ApiNotFound with the server message', () async {
      final (q, _) = _client((_) => rawJsonResponse(fixtureText('err_unknown_query.json'), status: 404));
      await expectLater(
        q.run(const BuiltinQuery('nope.nope')),
        throwsA(
          isA<ApiNotFound>()
              .having((e) => e.message, 'message', 'there is no built-in query nope.nope')
              .having((e) => e.isMissingRoute, 'isMissingRoute', isFalse),
        ),
      );
    });

    test('missing parameter → ApiServerError(400, message)', () async {
      final (q, _) = _client((_) => rawJsonResponse(fixtureText('err_missing_param.json'), status: 400));
      await expectLater(
        q.run(const BuiltinQuery('report.flows', {'from': '2023-09-01'})),
        throwsA(
          isA<ApiServerError>()
              .having((e) => e.status, 'status', 400)
              .having((e) => e.message, 'message', 'parameter :to of report.flows is missing'),
        ),
      );
    });

    test('401 → ApiUnauthorized', () async {
      final (q, _) = _client((_) => rawJsonResponse(fixtureText('err_unauthorized.json'), status: 401));
      await expectLater(q.run(const BuiltinQuery('ledger.now')), throwsA(isA<ApiUnauthorized>()));
    });

    test('a route the server lacks (zhang < 0.2) → isMissingRoute', () async {
      final (q, _) = _client(
        (_) => jsonResponse({'message': 'no route POST /api/query/builtins'}, status: 404),
      );
      await expectLater(
        q.run(const BuiltinQuery('ledger.now')),
        throwsA(isA<ApiNotFound>().having((e) => e.isMissingRoute, 'isMissingRoute', isTrue)),
      );
    });

    test('a cell of the wrong type or a missing column → FormatException', () async {
      final (q, _) = _client((_) => jsonResponse(fixture('ledger_now.json')));
      final now = await q.run(const BuiltinQuery('ledger.now'));
      expect(() => now.rows.first.integer('date'), throwsFormatException);
      expect(() => now.rows.first.string('nope'), throwsFormatException);
    });
  });

  group('cells', () {
    test('inventory with cost lots; value converted to the operating currency', () {
      final row = _batch()[0].rows.single;
      final balance = row.inventory('balance');
      expect(balance.positions, hasLength(3));
      final btc = balance.positions.first;
      expect(btc.units, Amount(d('0.01'), 'BTC'));
      expect(btc.cost!.amount, Amount(d('26000'), 'USD'));
      expect(btc.cost!.date, DateTime(2023, 9, 6));
      expect(btc.cost!.label, isNull);
      expect(row.inventory('units').unitsByCurrency, {'BTC': d('0.01'), 'CNY': d('444553.50'), 'USD': d('-262.99')});
      expect(row.inventory('value').sumIn('CNY'), d('444531.8225'));
      expect(row.inventory('value').sumIn('USD'), Decimal.zero);

      final calc = calculatedFromInventories(
        units: row.inventory('units'),
        value: row.inventory('value'),
        currency: 'CNY',
      );
      expect(calc.calculated, Amount(d('444531.8225'), 'CNY'));
      expect(calc.nonZeroDetail.map((a) => a.commodity), ['BTC', 'CNY', 'USD']);
    });

    test('str, int and metas cells; total with count_total', () {
      final errors = _batch()[1];
      expect(errors.total, 2);
      final row = errors.rows.single;
      expect(row.string('kind'), 'UnbalancedTransaction');
      expect(row.integer('line'), 38);
      expect(row.integer('span_start'), 956);
      expect(row.metas('metas'), [Meta('txn_id', row.string('id'))]);
    });

    test('set cells and null dates', () {
      final row = _batch()[2].rows.single;
      expect(row.stringSet('accounts'), ['Expenses:Groceries']);
      expect(row.dateOrNull('close'), isNull);
      expect(row.stringOrNull('close_time'), isNull);
      expect(() => row.date('close'), throwsFormatException);
    });

    test('amount, decimal string, date and bool cells', () {
      final row = _batch()[3].rows.single;
      expect(row.amount('assigned'), Amount(d('1000'), 'CNY'));
      expect(row.decimal('activity'), d('88.50'));
      expect(row.amount('available'), Amount(d('911.50'), 'CNY'));
      expect(row.date('last_month'), DateTime(2023, 9));
      expect(row.boolean('closed'), isFalse);
    });

    test('columns are looked up by name, not position', () {
      final r = QueryResult.fromJson({
        'columns': [
          {'name': 'b', 'type': 'int'},
          {'name': 'a', 'type': 'str'},
        ],
        'rows': [
          [1, 'x'],
        ],
      });
      expect(r.rows.single.string('a'), 'x');
      expect(r.rows.single.integer('b'), 1);
      expect(r.hasColumn('c'), isFalse);
    });
  });
}
