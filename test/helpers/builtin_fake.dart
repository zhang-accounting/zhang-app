import 'package:dio/dio.dart';
import 'package:zhang_app/core/utils/dates.dart';
import 'package:zhang_app/core/utils/device_clock.dart';

import 'fake_adapter.dart';
import 'fixtures.dart';

/// Answer of one built-in query in a fake server: the `{columns, rows}`
/// JSON of a `QueryResult` for the given `params`.
typedef BuiltinAnswer = Map<String, Object?> Function(Map<String, Object?> params);

/// One built-in query call seen by [FakeBuiltins].
class BuiltinCall {
  const BuiltinCall(this.name, this.params);

  final String name;
  final Map<String, Object?> params;

  @override
  String toString() => 'BuiltinCall($name, $params)';
}

/// `results[index]` of a captured batch fixture.
Map<String, Object?> batchResult(String fixtureName, int index) =>
    ((fixtureData(fixtureName)! as List)[index] as Map).cast<String, Object?>();

/// The `data` of a captured single-query fixture.
Map<String, Object?> singleResult(String fixtureName) => (fixtureData(fixtureName)! as Map).cast<String, Object?>();

/// `ledger.now` answering [now] (default: the device clock, `deviceNow()`)
/// as the ledger's wall clock.
BuiltinAnswer ledgerNowAnswer([DateTime Function() now = deviceNow]) => (_) {
  final t = now();
  return {
    ...singleResult('ledger_now.json'),
    'rows': [
      [ZhangDates.toIsoDate(t), ZhangDates.toNaiveIso(t).substring(11)],
    ],
  };
};

/// `ledger.now` as captured from the test ledger (`2026-10-10 12:07:59`), for
/// tests that compare against the captured row.
Map<String, Object?> capturedLedgerNow(Map<String, Object?> _) => singleResult('ledger_now.json');

/// An empty result with [columns] (all typed `str`).
Map<String, Object?> emptyResult(List<String> columns) => {
  'columns': [
    for (final c in columns) {'name': c, 'type': 'str'},
  ],
  'rows': <Object?>[],
};

/// Fake for `POST /api/query/builtins[/{name}]`, answering from the zhang
/// v0.2 captures in `test/fixtures` (override single queries with
/// [answers]) and logging every call in [calls].
///
/// Except `ledger.now`: it answers the device clock ([ledgerNowAnswer]), so
/// "today" / "this month" in the app is the day the test runs on – as with
/// a real server – and no test depends on the date the captures were taken.
/// Use [capturedLedgerNow] to get the captured row.
class FakeBuiltins {
  FakeBuiltins([Map<String, BuiltinAnswer> answers = const {}]) : answers = {...defaults(), ...answers};

  final Map<String, BuiltinAnswer> answers;
  final List<BuiltinCall> calls = [];

  /// When it returns a response for a call, the whole request (batch)
  /// answers with it (e.g. a 500 to test error states).
  ResponseBody? Function(BuiltinCall call)? intercept;

  List<BuiltinCall> callsTo(String name) => [for (final c in calls) if (c.name == name) c];

  /// Answers captured from the v0.2 test ledger (`ledger.now`: the device
  /// clock).
  static Map<String, BuiltinAnswer> defaults() => {
    'report.net_worth': (_) => batchResult('statistic_summary.json', 0),
    'report.liabilities': (_) => batchResult('statistic_summary.json', 1),
    'report.flows': (_) => batchResult('statistic_summary.json', 2),
    'report.transaction_count': (_) => batchResult('statistic_summary.json', 3),
    'report.account_totals': (_) => batchResult('statistic_rank.json', 0),
    'report.top_postings': (_) => batchResult('statistic_rank.json', 1),
    'accounts.balance_history': (_) => singleResult('account_balances.json'),
    'accounts.documents': (_) => singleResult('account_documents.json'),
    'journals.documents': (_) => singleResult('documents.json'),
    'journals.errors': (_) => singleResult('errors.json'),
    'journals.payees': (_) => batchResult('for_new_transaction.json', 0),
    'journals.accounts': (_) => batchResult('for_new_transaction.json', 1),
    'ledger.now': ledgerNowAnswer(),
    'budgets.month': (_) => singleResult('budgets.json'),
    'budgets.budget': (_) => batchResult('budget_detail.json', 0),
    'budgets.budget_month': (_) => batchResult('budget_detail.json', 1),
    'budgets.events': (_) => batchResult('budget_interval.json', 0),
    'budgets.postings': (_) => batchResult('budget_interval.json', 1),
  };

  /// The response for [o] when it is a built-in query call, else `null`.
  /// Unknown names answer 404 like the server.
  ResponseBody? handle(RequestOptions o) {
    final path = Uri.decodeComponent(o.uri.path);
    final at = path.indexOf('/query/builtins');
    if (at < 0 || o.method != 'POST') return null;
    final rest = path.substring(at + '/query/builtins'.length);
    if (rest.isEmpty || rest == '/') {
      final out = <Object?>[];
      for (final item in o.data as List) {
        final m = (item as Map).cast<String, Object?>();
        final failure = intercept?.call(BuiltinCall(m['name']! as String, _params(m['params'])));
        if (failure != null) return failure;
        final answer = _answer(m['name']! as String, _params(m['params']));
        if (answer == null) return _unknown(m['name']! as String);
        out.add(answer);
      }
      return jsonResponse({'data': out});
    }
    final name = rest.substring(1);
    final failure = intercept?.call(BuiltinCall(name, _params((o.data as Map)['params'])));
    if (failure != null) return failure;
    final answer = _answer(name, _params((o.data as Map)['params']));
    return answer == null ? _unknown(name) : jsonResponse({'data': answer});
  }

  Map<String, Object?>? _answer(String name, Map<String, Object?> params) {
    final answer = answers[name];
    if (answer == null) return null;
    calls.add(BuiltinCall(name, params));
    return answer(params);
  }

  static Map<String, Object?> _params(Object? p) => p == null ? const {} : (p as Map).cast<String, Object?>();

  static ResponseBody _unknown(String name) =>
      jsonResponse({'message': 'there is no built-in query $name'}, status: 404);
}
