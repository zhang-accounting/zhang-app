import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:zhang_app/features/accounts/account_detail_screen.dart';
import 'package:zhang_app/features/stats/report_period.dart';
import 'package:zhang_app/features/stats/reports_providers.dart';

import '../../helpers/builtin_fake.dart';
import '../../helpers/fake_adapter.dart';
import '../../helpers/fixtures.dart';
import '../accounts/ledger_app_harness.dart';

/// `report.account_totals` for Income (two accounts), in the captured
/// column layout.
Map<String, Object?> _incomeTotals() {
  Map<String, Object?> inv(String n) => {
    'positions': [
      {
        'units': {'number': n, 'currency': 'CNY'},
        'cost': null,
      },
    ],
  };
  return {
    ...batchResult('statistic_rank.json', 0),
    'rows': [
      ['Income:Salary', inv('-200'), inv('-200')],
      ['Income:Publisher:A', inv('-148'), inv('-148')],
    ],
  };
}

FakeBuiltins _builtins() => FakeBuiltins({
  'report.account_totals': (p) =>
      p['type'] == 'Income' ? _incomeTotals() : batchResult('statistic_rank.json', 0),
});

ResponseBody _route(String path, RequestOptions o) => switch (path) {
  '/statistic/graph' => jsonResponse(fixture('statistic_graph.json')),
  '/accounts' => data(const []),
  _ when path.endsWith('/journals') => jsonResponse(fixture('account_journals.json')),
  _ when path.startsWith('/accounts/') => jsonResponse(fixture('account_detail.json')),
  _ => jsonResponse({'message': 'not found'}, status: 404),
};

Finder _key(String k) => find.byKey(Key(k));

String _text(WidgetTester tester, String key) => tester.widget<Text>(_key(key)).data!;

/// Scrolls the reports list until [finder] is built, then fully on screen.
Future<void> _show(WidgetTester tester, Finder finder, {double delta = 200}) async {
  final list = find.descendant(of: _key('reports.list'), matching: find.byType(Scrollable)).first;
  await tester.scrollUntilVisible(finder, delta, scrollable: list);
  await tester.ensureVisible(finder);
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('reports: KPIs, bars, donut, drill-down, open account, step period', (tester) async {
    final builtins = _builtins();
    final (container, adapter) = await pumpLedgerApp(
      tester,
      _route,
      now: DateTime(2023, 9, 15, 10),
      builtins: builtins,
    );
    await tester.tap(find.text('Reports'));
    await tester.pumpAndSettle();

    expect(_text(tester, 'reports.periodLabel'), 'September 2023');
    expect(builtins.callsTo('report.flows').last.params, {
      'from': '2023-09-01',
      'to': '2023-09-30',
      'currency': 'CNY',
    });
    expect(builtins.callsTo('report.account_totals').last.params['type'], 'Expenses');
    final graphReq = adapter.requests.lastWhere((r) => r.path == '/statistic/graph');
    expect(graphReq.queryParameters, {'from': '2023-09-01', 'to': '2023-09-30', 'interval': 'Day'});

    // KPIs from the summary: income flipped to positive, net = income − expense.
    expect(
      find.descendant(of: _key('reports.kpi.income'), matching: find.text('¥436.00')),
      findsOneWidget,
    );
    expect(
      find.descendant(of: _key('reports.kpi.expense'), matching: find.text('¥798.68')),
      findsOneWidget,
    );
    expect(
      find.descendant(of: _key('reports.kpi.net'), matching: find.text('−¥362.68')),
      findsOneWidget,
    );

    expect(_key('reports.cashflowChart'), findsOneWidget);

    await _show(tester, _key('reports.donut'), delta: 200);
    expect(_text(tester, 'reports.donutTotal'), '¥798.68');

    // Top level aggregates to the 2nd segment; PersonalDiet drills down.
    await _show(tester, _key('reports.rank.Expenses:PersonalDiet'), delta: 200);
    await tester.tap(_key('reports.rank.Expenses:PersonalDiet'));
    await tester.pumpAndSettle();
    expect(_key('reports.crumb.Expenses'), findsOneWidget);
    expect(_key('reports.rank.Expenses:PersonalDiet:Lunch'), findsOneWidget);
    expect(_key('reports.rank.Expenses:Clothing'), findsNothing);

    // Leaf → account detail inside the Reports tab.
    await tester.tap(_key('reports.rank.Expenses:PersonalDiet:Lunch'));
    await tester.pumpAndSettle();
    expect(find.byType(AccountDetailScreen), findsOneWidget);
    expect(
      adapter.requests.any((r) => r.path == '/accounts/Expenses%3APersonalDiet%3ALunch/journals'),
      isTrue,
    );
    await tester.pageBack();
    await tester.pumpAndSettle();

    // Breadcrumb back to the top.
    await _show(tester, _key('reports.rankUp'), delta: -200);
    await tester.tap(_key('reports.rankUp'));
    await tester.pumpAndSettle();
    expect(_key('reports.crumb.Expenses'), findsNothing);
    await _show(tester, _key('reports.rank.Expenses:Clothing'), delta: 200);

    // Income segment.
    await _show(tester, _key('reports.rankType'), delta: -200);
    await tester.tap(find.descendant(of: _key('reports.rankType'), matching: find.text('Income')));
    await tester.pumpAndSettle();
    expect(builtins.callsTo('report.account_totals').last.params['type'], 'Income');
    await _show(tester, _key('reports.rank.Income:Salary'), delta: 200);
    expect(
      find.descendant(of: _key('reports.rank.Income:Salary'), matching: find.text('¥200.00')),
      findsOneWidget,
    );

    // Step to the previous month.
    await _show(tester, _key('reports.prevPeriod'), delta: -300);
    await tester.tap(_key('reports.prevPeriod'));
    await tester.pumpAndSettle();
    expect(_text(tester, 'reports.periodLabel'), 'August 2023');
    expect(container.read(reportPeriodProvider), ReportPeriod.month(DateTime(2023, 8)));
    expect(builtins.callsTo('report.flows').last.params['from'], '2023-08-01');
    expect(builtins.callsTo('report.flows').last.params['to'], '2023-08-31');
    // The fixture graph has no August postings → empty state instead of axes.
    expect(_key('reports.cashflowEmpty'), findsOneWidget);

    // Next is allowed back to September but not into the future.
    await tester.tap(_key('reports.nextPeriod'));
    await tester.pumpAndSettle();
    expect(_text(tester, 'reports.periodLabel'), 'September 2023');
    expect(tester.widget<IconButton>(_key('reports.nextPeriod')).onPressed, isNull);

    // Year view.
    final year = find.descendant(of: _key('reports.periodKind'), matching: find.text('Year'));
    await _show(tester, year, delta: -300);
    await tester.tap(year);
    await tester.pumpAndSettle();
    expect(_text(tester, 'reports.periodLabel'), '2023');
    expect(_key('reports.cashflowChart'), findsOneWidget);
  });

  testWidgets('reports: card-level error with retry', (tester) async {
    var fail = true;
    final builtins = _builtins()
      ..intercept = (call) =>
          fail && call.name == 'report.flows' ? jsonResponse({'message': 'boom'}, status: 500) : null;
    await pumpLedgerApp(tester, _route, now: DateTime(2023, 9, 15), builtins: builtins);
    await tester.tap(find.text('Reports'));
    await tester.pumpAndSettle();
    expect(find.textContaining('Server error 500'), findsOneWidget);
    expect(_key('reports.cashflowChart'), findsOneWidget); // other cards still render
    fail = false;
    await tester.tap(find.text('Retry'));
    await tester.pumpAndSettle();
    expect(_key('reports.kpi.income'), findsOneWidget);
  });
}
