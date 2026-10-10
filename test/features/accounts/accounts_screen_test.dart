import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:zhang_app/router.dart';
import 'package:zhang_app/features/accounts/account_detail_screen.dart';
import 'package:zhang_app/features/journals/transaction_detail_screen.dart';

import '../../helpers/builtin_fake.dart';
import '../../helpers/fake_adapter.dart';
import '../../helpers/fixtures.dart';
import 'ledger_app_harness.dart';

final _accounts = [
  accountJson('Assets:Bank:CMB', {'CNY': '2754.06'}, alias: 'CMB Savings'),
  accountJson('Assets:Bank:ICBC', {'CNY': '1000'}),
  accountJson('Assets:Paypal', {'CNY': '134614', 'USD': '-260'}, calculated: '132768.0'),
  accountJson('Assets:Old', {'CNY': '0'}, closed: true),
  accountJson('Liabilities:CreditCard:Apple', {'CNY': '-382', 'USD': '-12.99'}, calculated: '-474.229'),
  accountJson('Expenses:Food', {'CNY': '100'}),
  accountJson('Income:Salary', {'CNY': '-9000'}),
  accountJson('Equity:Opening', {'CNY': '-1000'}),
];

ResponseBody _route(String path, RequestOptions o) {
  if (path == '/accounts') return data(_accounts);
  if (path.startsWith('/journals')) return jsonResponse(fixture('journals.json'));
  if (path.endsWith('/journals')) return jsonResponse(fixture('account_journals.json'));
  if (path.startsWith('/accounts/')) return jsonResponse(fixture('account_detail.json'));
  return jsonResponse({'message': 'not found'}, status: 404);
}

Finder _key(String k) => find.byKey(Key(k));

Finder _scrollable(String listKey) =>
    find.descendant(of: _key(listKey), matching: find.byType(Scrollable)).first;

void main() {
  testWidgets('accounts: net worth, tree, multi-currency, closed toggle, search, detail', (tester) async {
    final (_, adapter) = await pumpLedgerApp(tester, _route);
    await tester.tap(find.text('Accounts'));
    await tester.pumpAndSettle();

    // Net worth = Σ Assets + Σ Liabilities (calculated, CNY).
    expect(tester.widget<Text>(_key('accounts.netWorth')).data, '¥136,047.83');
    expect(tester.widget<Text>(_key('accounts.netWorth.liabilities')).data, '−¥474.23');
    expect(find.text('Sum of account balances in CNY'), findsOneWidget);

    // Assets/Liabilities open to level 2; deeper parents and other types collapsed.
    expect(_key('accounts.row.Assets:Bank'), findsOneWidget);
    expect(_key('accounts.row.Assets:Paypal'), findsOneWidget);
    expect(_key('accounts.row.Assets:Bank:CMB'), findsNothing);
    expect(_key('accounts.row.Expenses'), findsOneWidget);
    expect(_key('accounts.row.Expenses:Food'), findsNothing);
    // Parent sum of like commodities.
    expect(
      find.descendant(of: _key('accounts.row.Assets:Bank'), matching: find.text('¥3,754.06')),
      findsOneWidget,
    );

    await tester.tap(_key('accounts.toggle.Assets:Bank'));
    await tester.pumpAndSettle();
    expect(_key('accounts.row.Assets:Bank:CMB'), findsOneWidget);
    expect(find.text('CMB Savings'), findsOneWidget);

    // Multi-currency row: converted total, expands into one line per commodity.
    final paypal = _key('accounts.row.Assets:Paypal');
    expect(find.descendant(of: paypal, matching: find.text('≈ ¥132,768.00')), findsOneWidget);
    expect(find.text('−\$260.00'), findsNothing);
    await tester.tap(_key('accounts.commodities.Assets:Paypal'));
    await tester.pumpAndSettle();
    expect(find.descendant(of: paypal, matching: find.text('−\$260.00')), findsOneWidget);
    expect(find.descendant(of: paypal, matching: find.text('¥134,614.00')), findsOneWidget);

    // Closed accounts are behind the toggle.
    expect(_key('accounts.row.Assets:Old'), findsNothing);
    await tester.scrollUntilVisible(find.text('1 closed account hidden'), 200);
    await tester.tap(_key('accounts.menu'));
    await tester.pumpAndSettle();
    await tester.tap(_key('accounts.showClosed'));
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(_key('accounts.row.Assets:Old'), -200);
    expect(find.descendant(of: _key('accounts.row.Assets:Old'), matching: find.text('Closed')), findsOneWidget);

    // Search filters the tree and expands matches.
    await tester.tap(_key('accounts.search'));
    await tester.pumpAndSettle();
    await tester.enterText(_key('accounts.searchField'), 'apple');
    await tester.pumpAndSettle();
    expect(_key('accounts.row.Liabilities:CreditCard:Apple'), findsOneWidget);
    expect(_key('accounts.row.Assets:Paypal'), findsNothing);
    await tester.enterText(_key('accounts.searchField'), 'zzz');
    await tester.pumpAndSettle();
    expect(find.text('No accounts match “zzz”'), findsOneWidget);
    await tester.tap(find.byTooltip('Close search'));
    await tester.pumpAndSettle();

    // Leaf tap → detail with balances, chart and journal rows.
    await tester.scrollUntilVisible(_key('accounts.row.Assets:Paypal'), -200);
    await tester.ensureVisible(_key('accounts.row.Assets:Paypal'));
    await tester.pumpAndSettle();
    // Tap the name: the amount column of an expanded multi-currency row
    // toggles its currency lines instead.
    await tester.tap(find.descendant(of: _key('accounts.row.Assets:Paypal'), matching: find.text('Paypal')));
    await tester.pumpAndSettle();
    expect(find.byType(AccountDetailScreen), findsOneWidget);
    expect(adapter.requests.any((r) => r.path == '/accounts/Assets%3APaypal/journals'), isTrue);
    expect(find.text('Paypal'), findsOneWidget); // app bar
    expect(_key('accountDetail.balance'), findsOneWidget);
    expect(_key('accountDetail.balanceChart'), findsOneWidget);
    await tester.scrollUntilVisible(_key('accountDetail.firstRow'), 200, scrollable: _scrollable('accountDetail.list'));
    final first = _key('accountDetail.firstRow');
    expect(find.descendant(of: first, matching: find.text('Pending Shop')), findsOneWidget);
    expect(find.descendant(of: first, matching: find.text('−¥9.90')), findsOneWidget);
    expect(find.descendant(of: first, matching: find.text('¥146,039.60')), findsOneWidget); // running balance
    // Check rows show the asserted amount (their own entry is zero).
    await tester.scrollUntilVisible(
      find.text('Balance check failed'),
      200,
      scrollable: _scrollable('accountDetail.list'),
    );
    expect(find.text('¥100.00'), findsOneWidget);
    await tester.scrollUntilVisible(
      find.text('Balance check'),
      200,
      scrollable: _scrollable('accountDetail.list'),
    );

    // A posting opens its transaction (trx_id is the transaction id).
    await tester.scrollUntilVisible(first, -400, scrollable: _scrollable('accountDetail.list'));
    await tester.tap(first);
    await tester.pumpAndSettle();
    expect(find.byType(TransactionDetailScreen), findsOneWidget);
    expect(find.text('Pending Shop · Awaiting refund'), findsOneWidget);
    final lookup = adapter.requests.lastWhere((r) => r.path.startsWith('/journals'));
    expect(lookup.uri.queryParameters['keyword'], 'Pending Shop');
    await tester.pageBack();
    await tester.pumpAndSettle();

    // Back to the tree.
    await tester.pageBack();
    await tester.pumpAndSettle();
    expect(find.byType(AccountDetailScreen), findsNothing);
    expect(_key('accounts.list'), findsOneWidget);
  });

  testWidgets('accounts: empty ledger and server error states', (tester) async {
    var fail = true;
    await pumpLedgerApp(tester, (path, o) {
      if (path == '/accounts') {
        return fail ? jsonResponse({'message': 'boom'}, status: 500) : data(const []);
      }
      return jsonResponse({'message': 'not found'}, status: 404);
    });
    await tester.tap(find.text('Accounts'));
    await tester.pumpAndSettle();
    expect(find.textContaining('Server error 500'), findsOneWidget);
    fail = false;
    await tester.tap(find.text('Retry'));
    await tester.pumpAndSettle();
    expect(find.textContaining('No accounts yet'), findsOneWidget);
  });

  testWidgets('account detail: empty journals', (tester) async {
    final noHistory = FakeBuiltins({
      'accounts.balance_history': (_) => {...singleResult('account_balances.json'), 'rows': const <Object?>[]},
    });
    final (container, _) = await pumpLedgerApp(tester, builtins: noHistory, (path, o) {
      if (path == '/accounts') return data([accountJson('Assets:Cash', {'CNY': '0'})]);
      if (path.endsWith('/journals')) return data(const []);
      return data({
        'date': '2023-01-01T00:00:00',
        'type': 'Assets',
        'name': 'Assets:Cash',
        'status': 'Open',
        'alias': null,
        'amount': {
          'calculated': {'number': '0', 'commodity': 'CNY'},
          'detail': {'CNY': '0'},
        },
      });
    });
    await tester.tap(find.text('Accounts'));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('accounts.row.Assets:Cash')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('accountDetail.empty')), findsOneWidget);
    expect(find.text('No balance history yet'), findsOneWidget);
    expect(tester.widget<Text>(find.byKey(const Key('accountDetail.balance'))).data, '¥0.00');
    expect(container, isNotNull);
  });

  testWidgets('account detail: postings of sub-accounts name their account', (tester) async {
    final (container, _) = await pumpLedgerApp(tester, (path, o) {
      if (path == '/accounts') {
        return data([accountJson('Assets:Bank', {'CNY': '0'}), accountJson('Assets:Bank:CMB', {'CNY': '25'})]);
      }
      if (path.endsWith('/journals')) {
        return data([
          {
            'datetime': '2023-09-13T14:25:00',
            'timestamp': 1694582700,
            'account': 'Assets:Bank:CMB',
            'trx_id': 'a236abdf-1855-c7fa-2c8a-9cc8a22f2c49',
            'payee': 'Github Restaurant',
            'narration': 'Fried Chicken',
            'inferred_unit': {'number': '25', 'commodity': 'CNY'},
            'account_after': {'number': '25', 'commodity': 'CNY'},
            'asserted': null,
            'checked_balance': null,
            'difference': null,
            'tolerance': null,
            'passed': null,
          },
        ]);
      }
      return jsonResponse(fixture('account_detail.json'));
    });
    container.read(routerProvider).go('/accounts/${Uri.encodeComponent('Assets:Bank')}');
    await tester.pumpAndSettle();
    final row = find.byKey(const Key('accountDetail.firstRow'));
    await tester.scrollUntilVisible(row, 200, scrollable: _scrollable('accountDetail.list'));
    expect(find.descendant(of: row, matching: find.textContaining('in CMB')), findsOneWidget);
  });
}
