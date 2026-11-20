import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:zhang_app/router.dart';

import '../../helpers/builtin_fake.dart';
import 'fake_server.dart';
import 'journal_test_utils.dart';
import 'screen_test_utils.dart';

/// A transaction as zhang ≥ 0.2 lists it: written forms, posting metadata
/// and `edit_drops_text`.
Map<String, Object?> editableJson({
  String id = 'tx-1',
  String payee = 'Uniqlo',
  String narration = 'Shirt',
  bool dropsText = false,
  String? comment,
  String? version,
}) => {
  ...txnJson(
    id: id,
    datetime: '2023-09-30T12:00:00',
    payee: payee,
    narration: narration,
    tags: ['clothes'],
    links: ['order-7'],
    metas: [
      {'key': 'receipt_no', 'value': 'A-1'},
    ],
    postings: [('Assets:WeChat', '-99', 'CNY'), ('Expenses:Clothing', '99', 'CNY')],
    sequence: 5,
  ),
  'postings': [
    for (final (account, number) in [('Assets:WeChat', '-99'), ('Expenses:Clothing', '99')])
      {
        'account': account,
        'unit': {'number': number, 'commodity': 'CNY'},
        'cost': null,
        'inferred_unit': {'number': number, 'commodity': 'CNY'},
        'account_before': {'number': '0', 'commodity': 'CNY'},
        'account_after': {'number': number, 'commodity': 'CNY'},
        'metas': account == 'Expenses:Clothing'
            ? [
                {'key': 'size', 'value': 'M'},
              ]
            : <Object?>[],
        'written': {'cost': null, 'price': null, 'comment': account == 'Assets:WeChat' ? comment : null},
      },
  ],
  'edit_drops_text': dropsText,
  'version': ?version,
};

Future<void> openDetail(WidgetTester tester, String payee) async {
  await tester.tap(find.text('Journal'));
  await tester.pumpAndSettle();
  await tester.tap(find.text(payee));
  await tester.pumpAndSettle();
  expect(find.text('Transaction'), findsOneWidget);
}

void main() {
  testWidgets('edit from the detail: id preview, PUT on the id, detail shows the saved version', (tester) async {
    final server = FakeZhangServer(journals: [editableJson(comment: 'wallet')]);
    await pumpApp(tester, server);
    await openDetail(tester, 'Uniqlo');

    await tester.tap(find.byKey(const Key('trx.edit')));
    await tester.pumpAndSettle();
    // Checked on the server first: the update preview of the unchanged transaction.
    final check = server.transactionRequests.single;
    expect((check.$1, check.$2), ('POST', '/api/transactions/tx-1/preview'));
    // Two opposite postings, open accounts: the simple form.
    expect(find.text('Edit transaction'), findsOneWidget);
    expect(find.text('Paid from: WeChat'), findsOneWidget);

    await tester.enterText(find.byKey(const Key('add.narration')), 'Blue shirt');
    FocusManager.instance.primaryFocus?.unfocus();
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('add.key.save')));
    await tester.pumpAndSettle();

    final writes = server.transactionRequests.skip(1).toList();
    expect([for (final w in writes) '${w.$1} ${w.$2}'], [
      'POST /api/transactions/tx-1/preview',
      'PUT /api/transactions/tx-1',
    ]);
    final body = writes.last.$3;
    expect(body['narration'], 'Blue shirt');
    // What the form does not show is sent back as read.
    expect(body['links'], ['order-7']);
    expect(body['metas'], [
      {'key': 'receipt_no', 'value': 'A-1'},
    ]);
    expect(body['postings'], [
      {
        'account': 'Assets:WeChat',
        'unit': {'number': '-99', 'commodity': 'CNY'},
        'cost': null,
        'price': null,
        'comment': 'wallet',
      },
      {
        'account': 'Expenses:Clothing',
        'unit': {'number': '99', 'commodity': 'CNY'},
        'cost': null,
        'price': null,
        'comment': null,
        'metas': [
          {'key': 'size', 'value': 'M'},
        ],
      },
    ]);

    // Back on the detail, read again after the ledger reloaded.
    expect(find.text('Transaction'), findsOneWidget);
    expect(find.text('Uniqlo · Blue shirt'), findsOneWidget);
    expect(find.byKey(const Key('trx.refreshing')), findsNothing);
  });

  testWidgets('edit is blocked with an explanation when it would lose something', (tester) async {
    final server = FakeZhangServer(
      journals: [
        editableJson(id: 'c1', payee: 'Commented', dropsText: true),
        // An older server: no written forms, no posting metadata.
        txnJson(
          id: 'o1',
          datetime: '2023-09-29T12:00:00',
          payee: 'Old',
          postings: [('Assets:WeChat', '-1', 'CNY'), ('Expenses:Clothing', '1', 'CNY')],
        ),
      ],
    );
    await pumpApp(tester, server);
    await openDetail(tester, 'Commented');
    await tester.tap(find.byKey(const Key('trx.edit')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('trx.editBlocked')), findsOneWidget);
    expect(find.textContaining('saving through the server would delete'), findsOneWidget);
    expect(find.textContaining('copy it as a new transaction'), findsOneWidget);
    expect(server.transactionRequests, isEmpty, reason: 'known without asking the server');
    await tester.tap(find.text('Close'));
    await tester.pumpAndSettle();

    await tester.pageBack();
    await tester.pumpAndSettle();
    await tester.tap(find.text('Old'));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('trx.edit')));
    await tester.pumpAndSettle();
    expect(find.textContaining('Update zhang'), findsOneWidget);
  });

  testWidgets('a posting flag in the server text blocks the edit; a stale id is explained', (tester) async {
    final server = FakeZhangServer(journals: [editableJson()]);
    server.previewAnswer = {
      'text': '2023-09-30 12:00:00 * "Uniqlo" "Shirt"\n  ! Assets:WeChat -99 CNY\n  Expenses:Clothing 99 CNY',
      'field_errors': <Object?>[],
      'unbalanced': <Object?>[],
      'errors': <Object?>[],
    };
    await pumpApp(tester, server);
    await openDetail(tester, 'Uniqlo');
    await tester.tap(find.byKey(const Key('trx.edit')));
    await tester.pumpAndSettle();
    expect(find.textContaining('has its own flag'), findsOneWidget);
    await tester.tap(find.text('Close'));
    await tester.pumpAndSettle();

    server.journals.clear(); // changed on the server: the id is gone
    await tester.tap(find.byKey(const Key('trx.edit')));
    await tester.pumpAndSettle();
    expect(find.textContaining('its id is out of date'), findsOneWidget);
    expect(find.text('Edit transaction'), findsNothing);
  });

  testWidgets('copy opens the editor dated now and creates a new transaction', (tester) async {
    // The captured ledger clock (2026-10-10 12:07), whatever the device date.
    final server = FakeZhangServer(journals: [editableJson()]);
    server.builtins.answers['ledger.now'] = capturedLedgerNow;
    await pumpApp(tester, server);
    await openDetail(tester, 'Uniqlo');
    await tester.tap(find.byKey(const Key('trx.duplicate')));
    await tester.pumpAndSettle();
    expect(find.text('New transaction'), findsOneWidget);
    expect(find.textContaining('Today'), findsOneWidget);
    await tester.tap(find.byKey(const Key('add.key.save')));
    await tester.pumpAndSettle();
    expect([for (final w in server.transactionRequests) '${w.$1} ${w.$2}'], [
      'POST /api/transactions/preview',
      'POST /api/transactions',
    ]);
    final body = server.transactionRequests.last.$3;
    expect(body['payee'], 'Uniqlo');
    expect(body['metas'], isEmpty, reason: 'metadata belongs to the original');
    expect(body['links'], isEmpty, reason: 'links tie related entries; a copy is a new one');
    // Dated now by the ledger clock (the captured `ledger.now`: 2026-10-10 12:07).
    expect(body['datetime'], startsWith('2026-10-10T'));
    expect(find.text('Transaction'), findsOneWidget, reason: 'back on the original');
  });

  testWidgets('a version is sent as If-Match on the edit preview and the PUT', (tester) async {
    final server = FakeZhangServer(journals: [editableJson(version: 'v1')]);
    await pumpApp(tester, server);
    await openDetail(tester, 'Uniqlo');
    await tester.tap(find.byKey(const Key('trx.edit')));
    await tester.pumpAndSettle();
    await tester.enterText(find.byKey(const Key('add.narration')), 'Blue shirt');
    FocusManager.instance.primaryFocus?.unfocus();
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('add.key.save')));
    await tester.pumpAndSettle();
    final ifMatch = [
      for (final r in server.adapter.requests)
        if (r.uri.path.contains('/transactions/')) '${r.method} ${r.uri.path} ${r.headers['If-Match']}',
    ];
    expect(ifMatch, [
      'POST /api/transactions/tx-1/preview v1',
      'POST /api/transactions/tx-1/preview v1',
      'PUT /api/transactions/tx-1 v1',
    ]);
    expect(find.text('Uniqlo · Blue shirt'), findsOneWidget);
  });

  testWidgets('a write the journal never shows: refreshing, then a clear message', (tester) async {
    final server = FakeZhangServer(journals: [editableJson()])..ignoreWrites = true;
    await pumpApp(tester, server);
    await openDetail(tester, 'Uniqlo');
    await tester.tap(find.byKey(const Key('trx.edit')));
    await tester.pumpAndSettle();
    await tester.enterText(find.byKey(const Key('add.narration')), 'Blue shirt');
    FocusManager.instance.primaryFocus?.unfocus();
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('add.key.save')));
    for (var i = 0; i < 30; i++) {
      await tester.pump(const Duration(milliseconds: 100)); // past the write's reload (600 ms)
    }
    expect(find.byKey(const Key('trx.refreshing')), findsOneWidget, reason: 'a reload alone is not the edit');
    expect(find.text('Uniqlo · Shirt'), findsOneWidget);
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('trx.editedPending')), findsOneWidget);
  });

  testWidgets('opened with a version that no longer matches (an account row): changed, not shown', (tester) async {
    final server = FakeZhangServer(journals: [editableJson(version: 'v2')]);
    final container = await pumpApp(tester, server);
    container.read(routerProvider).push('/journals/tx-1?q=Uniqlo&v=v1');
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('trx.changed')), findsOneWidget);
    expect(find.byKey(const Key('trx.edit')), findsNothing);

    container.read(routerProvider).pop();
    await tester.pumpAndSettle();
    container.read(routerProvider).push('/journals/tx-1?q=Uniqlo&v=v2');
    await tester.pumpAndSettle();
    expect(find.text('Uniqlo · Shirt'), findsOneWidget);
  });
}
