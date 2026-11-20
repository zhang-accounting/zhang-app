import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:zhang_app/core/theme/app_colors.dart';
import 'package:zhang_app/features/accounts/account_detail_screen.dart';
import 'package:zhang_app/features/budgets/budget_detail_screen.dart';
import 'package:zhang_app/features/journals/transaction_detail_screen.dart';

import '../../helpers/builtin_fake.dart';
import '../../helpers/fake_adapter.dart';
import '../../helpers/fixtures.dart';
import '../accounts/ledger_app_harness.dart';

ResponseBody _route(String path, RequestOptions o) => switch (path) {
  '/statistic/graph' => jsonResponse(fixture('statistic_graph.json')),
  '/accounts' => data(const []),
  _ when path.startsWith('/journals') => jsonResponse(fixture('journals.json')),
  _ when path.endsWith('/journals') => jsonResponse(fixture('account_journals.json')),
  _ when path.startsWith('/accounts/') => jsonResponse(fixture('account_detail.json')),
  _ => jsonResponse({'message': 'not found'}, status: 404),
};

/// A `budgets.month` result with [rows] in the captured column layout.
Map<String, Object?> _month(List<List<Object?>> rows) => {...singleResult('budgets.json'), 'rows': rows};

List<Object?> _row(String name, String? alias, String? category, String assigned, String activity, String available) =>
    [
      name,
      alias,
      category,
      'CNY',
      '2023-09-01',
      {'number': assigned, 'currency': 'CNY'},
      activity,
      {'number': available, 'currency': 'CNY'},
      false,
    ];

Finder _key(String k) => find.byKey(Key(k));

String _text(WidgetTester tester, String key) => tester.widget<Text>(_key(key)).data!;

String _richText(WidgetTester tester, String key) => tester.widget<Text>(_key(key)).textSpan!.toPlainText();

LinearProgressIndicator _bar(WidgetTester tester, String budget) => tester.widget<LinearProgressIndicator>(
  find.descendant(of: _key('budgets.row.$budget'), matching: find.byType(LinearProgressIndicator)),
);

Future<void> _openBudgets(WidgetTester tester) async {
  await tester.tap(find.text('Reports'));
  await tester.pumpAndSettle();
  await tester.tap(find.descendant(of: _key('reports.segment'), matching: find.text('Budgets')));
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('budgets: month list with totals, detail, posting → transaction, linked account', (tester) async {
    // The captured assignment plus one side of a `budget-transfer`.
    final events = batchResult('budget_interval.json', 0);
    final builtins = FakeBuiltins({
      'budgets.events': (_) => {
        ...events,
        'rows': [
          [
            '2023-09-02',
            '09:00:00',
            1693612800,
            'transfer_out',
            {'number': '-200', 'currency': 'CNY'},
          ],
          ...(events['rows']! as List),
        ],
      },
    });
    final (_, adapter) = await pumpLedgerApp(tester, _route, now: DateTime(2023, 9, 15, 10), builtins: builtins);
    await _openBudgets(tester);

    // The month of the shared period, month stepper only.
    expect(builtins.callsTo('budgets.month').last.params, {'month': '2023-09-01'});
    expect(_text(tester, 'reports.periodLabel'), 'September 2023');
    expect(_key('reports.periodKind'), findsNothing);

    // Totals of the month and the days left (15 → 30 September).
    final totals = _key('budgets.totals');
    expect(find.descendant(of: totals, matching: find.text('¥1,000.00')), findsOneWidget);
    expect(find.descendant(of: totals, matching: find.text('¥88.50')), findsOneWidget);
    expect(find.descendant(of: _key('budgets.totals.available.CNY'), matching: find.text('¥911.50')), findsOneWidget);
    expect(find.text('16 days left this month'), findsOneWidget);
    expect(_key('budgets.overCount'), findsNothing);

    // Grouped by category; alias first, name under it.
    expect(find.text('Living'), findsOneWidget);
    final row = _key('budgets.row.food');
    expect(find.descendant(of: row, matching: find.text('Eating')), findsOneWidget);
    expect(find.descendant(of: row, matching: find.text('food')), findsOneWidget);
    expect(_text(tester, 'budgets.available.food'), '¥911.50');
    expect(_richText(tester, 'budgets.status.food'), 'Spent ¥88.50 of ¥1,000.00 · ≈ ¥56.97 a day');
    expect(_bar(tester, 'food').value, closeTo(0.0885, 1e-9));
    expect(_key('budgets.over.food'), findsNothing);

    // Detail of the month.
    await tester.tap(row);
    await tester.pumpAndSettle();
    expect(find.byType(BudgetDetailScreen), findsOneWidget);
    expect(builtins.callsTo('budgets.budget').last.params, {'name': 'food'});
    expect(builtins.callsTo('budgets.budget_month').last.params, {'name': 'food', 'month': '2023-09-01'});
    expect(builtins.callsTo('budgets.postings').last.params, {'name': 'food', 'month': '2023-09-01'});
    expect(_text(tester, 'budgetDetail.month'), 'September 2023');
    expect(_text(tester, 'budgetDetail.available'), '¥911.50');
    expect(find.descendant(of: _key('budgetDetail.assigned'), matching: find.text('¥1,000.00')), findsOneWidget);
    expect(find.descendant(of: _key('budgetDetail.activity'), matching: find.text('¥88.50')), findsOneWidget);
    expect(_key('budgetDetail.over'), findsNothing);
    expect(find.text('Living'), findsOneWidget); // category chip

    // History, newest first: the posting (spending, an outflow), then the assignment.
    final posting = _key('budgetDetail.posting.0');
    expect(find.descendant(of: posting, matching: find.text('Supermarket')), findsOneWidget);
    expect(find.descendant(of: posting, matching: find.text('−¥88.50')), findsOneWidget);
    expect(find.text('+¥1,000.00'), findsOneWidget);
    expect(find.text('2023-09-01 00:00'), findsOneWidget);
    expect(find.text('Moved to another budget'), findsOneWidget);
    expect(find.text('−¥200.00'), findsOneWidget);

    // A posting opens its transaction inside the Reports tab.
    await tester.tap(posting);
    await tester.pumpAndSettle();
    expect(find.byType(TransactionDetailScreen), findsOneWidget);
    expect(find.text('Supermarket · Weekly groceries'), findsOneWidget);
    final lookup = adapter.requests.lastWhere((r) => r.path.startsWith('/journals'));
    expect(lookup.uri.queryParameters['keyword'], 'Supermarket');
    await tester.pageBack();
    await tester.pumpAndSettle();
    expect(find.byType(BudgetDetailScreen), findsOneWidget);

    // A linked account opens its detail.
    await tester.tap(_key('budgetDetail.account.Expenses:Groceries'));
    await tester.pumpAndSettle();
    expect(find.byType(AccountDetailScreen), findsOneWidget);
    expect(adapter.requests.any((r) => r.path == '/accounts/Expenses%3AGroceries/journals'), isTrue);
  });

  testWidgets('budgets: over budget, running low, empty month, month shared with income/expense', (tester) async {
    final builtins = FakeBuiltins({
      'budgets.month': (p) => p['month'] == '2023-09-01'
          ? _month([
              _row('food', 'Eating', 'Living', '1000', '88.50', '911.50'),
              _row('fun', null, null, '300', '250', '50'),
              _row('dining', 'Dining out', 'Living', '1200', '1320', '-120'),
            ])
          : _month([]),
    });
    await pumpLedgerApp(tester, _route, now: DateTime(2023, 9, 15, 10), builtins: builtins);
    await tester.tap(find.text('Reports'));
    await tester.pumpAndSettle();

    // A year in the income / expense segment becomes its month for budgets.
    await tester.tap(find.descendant(of: _key('reports.periodKind'), matching: find.text('Year')));
    await tester.pumpAndSettle();
    expect(_text(tester, 'reports.periodLabel'), '2023');
    await tester.tap(find.descendant(of: _key('reports.segment'), matching: find.text('Budgets')));
    await tester.pumpAndSettle();
    expect(_text(tester, 'reports.periodLabel'), 'September 2023');

    final context = tester.element(_key('budgets.list'));
    final scheme = Theme.of(context).colorScheme;

    // Over budget: first in its group, ⚠ icon + text, error colours, full bar.
    expect(tester.getTopLeft(_key('budgets.row.dining')).dy, lessThan(tester.getTopLeft(_key('budgets.row.food')).dy));
    expect(_key('budgets.over.dining'), findsOneWidget);
    expect(_text(tester, 'budgets.available.dining'), '−¥120.00');
    expect(tester.widget<Text>(_key('budgets.available.dining')).style?.color, scheme.error);
    expect(_richText(tester, 'budgets.status.dining'), 'Over budget by ¥120.00');
    expect(_bar(tester, 'dining').value, 1);
    expect(_bar(tester, 'dining').color, scheme.error);
    expect(find.descendant(of: _key('budgets.overCount'), matching: find.text('1 budget over')), findsOneWidget);
    expect(find.descendant(of: _key('budgets.totals.available.CNY'), matching: find.text('¥841.50')), findsOneWidget);

    // Running low (under 20 % left): warning colour, no ⚠; uncategorized last.
    expect(_key('budgets.over.fun'), findsNothing);
    expect(tester.widget<Text>(_key('budgets.available.fun')).style?.color, ZhangColors.light.warning);
    expect(_bar(tester, 'fun').color, ZhangColors.light.warning);
    expect(_key('budgets.group.'), findsOneWidget);
    expect(find.text('Uncategorized'), findsOneWidget);
    expect(tester.getTopLeft(_key('budgets.row.food')).dy, lessThan(tester.getTopLeft(_key('budgets.row.fun')).dy));

    // A month without budgets explains the directives.
    await tester.tap(_key('reports.prevPeriod'));
    await tester.pumpAndSettle();
    expect(builtins.callsTo('budgets.month').last.params, {'month': '2023-08-01'});
    expect(_key('budgets.empty'), findsOneWidget);
    expect(find.text('No budgets this month'), findsOneWidget);
    expect(find.textContaining('budget-add Food 2000 CNY'), findsOneWidget);
    expect(_key('budgets.totals'), findsNothing);

    // The month is shared with the income / expense segment.
    await tester.tap(find.descendant(of: _key('reports.segment'), matching: find.text('Income & expense')));
    await tester.pumpAndSettle();
    expect(_text(tester, 'reports.periodLabel'), 'August 2023');
    expect(_key('reports.periodKind'), findsOneWidget);
    expect(builtins.callsTo('report.flows').last.params['from'], '2023-08-01');
  });

  testWidgets('budgets: card-level error with retry', (tester) async {
    var fail = true;
    final builtins = FakeBuiltins()
      ..intercept = (call) =>
          fail && call.name == 'budgets.month' ? jsonResponse({'message': 'boom'}, status: 500) : null;
    await pumpLedgerApp(tester, _route, now: DateTime(2023, 9, 15), builtins: builtins);
    await _openBudgets(tester);
    expect(find.textContaining('Server error 500'), findsOneWidget);
    fail = false;
    await tester.tap(find.text('Retry'));
    await tester.pumpAndSettle();
    expect(_key('budgets.row.food'), findsOneWidget);
  });
}
