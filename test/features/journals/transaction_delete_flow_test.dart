import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'fake_server.dart';
import 'journal_test_utils.dart';
import 'screen_test_utils.dart';

/// A transaction as the journal lists it, with a `version` when given
/// (zhang ≥ 0.3).
Map<String, Object?> _txn(String id, String payee, {String narration = '', String? version, int sequence = 5}) => {
  ...txnJson(
    id: id,
    datetime: '2023-09-30T12:00:00',
    payee: payee,
    narration: narration,
    postings: [('Assets:WeChat', '-99', 'CNY'), ('Expenses:Clothing', '99', 'CNY')],
    sequence: sequence,
  ),
  'version': ?version,
};

Future<void> _openDetail(WidgetTester tester, String payee) async {
  await tester.tap(find.text('Journal'));
  await tester.pumpAndSettle();
  await tester.tap(find.text(payee));
  await tester.pumpAndSettle();
  expect(find.byKey(const Key('trx.body')), findsOneWidget);
}

Future<void> _chooseDelete(WidgetTester tester) async {
  await tester.tap(find.byKey(const Key('trx.more')));
  await tester.pumpAndSettle();
  await tester.tap(find.byKey(const Key('trx.delete')));
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('delete from the detail: confirmed, sent with If-Match, the detail closes and the list refreshes', (
    tester,
  ) async {
    final server = FakeZhangServer(
      journals: [
        _txn('tx-1', 'Uniqlo', narration: 'Shirt', version: 'v1'),
        _txn('tx-2', 'Bakery', version: 'v2', sequence: 4),
      ],
    );
    await pumpApp(tester, server);
    await _openDetail(tester, 'Uniqlo');

    // Asked first; cancelling sends nothing.
    await _chooseDelete(tester);
    expect(find.byKey(const Key('trx.deleteDialog')), findsOneWidget);
    expect(find.textContaining('2023-09-30 · Uniqlo · Shirt · '), findsOneWidget);
    await tester.tap(find.text('Cancel'));
    await tester.pumpAndSettle();
    expect(server.requestsTo('/api/transactions/tx-1'), isEmpty);
    expect(find.byKey(const Key('trx.body')), findsOneWidget);

    await _chooseDelete(tester);
    await tester.tap(find.byKey(const Key('trx.deleteConfirm')));
    await tester.pumpAndSettle();
    final delete = server.requestsTo('/api/transactions/tx-1').single;
    expect(delete.method, 'DELETE');
    expect(delete.headers['If-Match'], 'v1');
    expect(server.journals.map((j) => j['id']), ['tx-2']);
    expect(find.text('Transaction deleted'), findsOneWidget);
    expect(find.byKey(const Key('trx.body')), findsNothing, reason: 'the detail closed');

    // The list refreshes once the ledger reloaded (here: the write timer).
    await tester.pump(const Duration(seconds: 1));
    await tester.pumpAndSettle();
    expect(find.text('Uniqlo'), findsNothing);
    expect(find.text('Bakery'), findsOneWidget);
  });

  testWidgets('412: changed on the server – nothing deleted, refresh goes back to the list', (tester) async {
    final server = FakeZhangServer(journals: [_txn('tx-1', 'Uniqlo', version: 'v1')]);
    await pumpApp(tester, server);
    await _openDetail(tester, 'Uniqlo');
    // Edited elsewhere after the list was loaded (or another transaction
    // took the id): the version the detail has is stale.
    server.journals[0] = {...server.journals[0], 'version': 'v1-edited'};

    await _chooseDelete(tester);
    await tester.tap(find.byKey(const Key('trx.deleteConfirm')));
    await tester.pumpAndSettle();
    expect(server.requestsTo('/api/transactions/tx-1').single.headers['If-Match'], 'v1');
    expect(find.byKey(const Key('trx.deleteStale')), findsOneWidget);
    expect(find.text('Changed on the server'), findsOneWidget);
    expect(server.journals, hasLength(1), reason: 'nothing deleted');

    await tester.tap(find.byKey(const Key('trx.deleteRefresh')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('trx.body')), findsNothing);
    expect(find.text('Uniqlo'), findsOneWidget);
  });

  testWidgets('a server without versions (zhang < 0.3) offers no delete', (tester) async {
    final server = FakeZhangServer(journals: [_txn('tx-1', 'Uniqlo')]);
    await pumpApp(tester, server);
    await _openDetail(tester, 'Uniqlo');
    expect(find.byKey(const Key('trx.edit')), findsOneWidget);
    expect(find.byKey(const Key('trx.more')), findsNothing);
  });
}
