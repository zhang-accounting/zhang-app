import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:zhang_app/core/utils/dates.dart';
import 'package:zhang_app/features/accounts/account_detail_screen.dart';
import 'package:zhang_app/features/stats/report_period.dart';
import 'package:zhang_app/features/stats/reports_providers.dart';

import '../../helpers/fake_adapter.dart';
import '../../helpers/fixtures.dart';
import '../accounts/ledger_app_harness.dart';

final _incomeRank = {
  'from': '2023-08-31T15:00:00',
  'to': '2023-09-30T14:59:59',
  'detail': [
    {
      'account': 'Income:Salary',
      'amount': {
        'calculated': {'number': '-200', 'commodity': 'CNY'},
        'detail': {'CNY': '-200'},
      },
    },
    {
      'account': 'Income:Publisher:A',
      'amount': {
        'calculated': {'number': '-148', 'commodity': 'CNY'},
        'detail': {'CNY': '-148'},
      },
    },
  ],
  'top_transactions': [],
};

ResponseBody _route(String path, RequestOptions o) => switch (path) {
  '/statistic/summary' => jsonResponse(fixture('statistic_summary.json')),
  '/statistic/graph' => jsonResponse(fixture('statistic_graph.json')),
  '/statistic/Expenses' => jsonResponse(fixture('statistic_rank.json')),
  '/statistic/Income' => data(_incomeRank),
  '/accounts' => data(const []),
  _ when path.endsWith('/journals') => jsonResponse(fixture('account_journals.json')),
  _ when path.endsWith('/balances') => jsonResponse(fixture('account_balances.json')),
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
    final (container, adapter) = await pumpLedgerApp(tester, _route, now: DateTime(2023, 9, 15, 10));
    await tester.tap(find.text('Reports'));
    await tester.pumpAndSettle();

    expect(_text(tester, 'reports.periodLabel'), 'September 2023');
    final summaryReq = adapter.requests.lastWhere((r) => r.path == '/statistic/summary');
    expect(summaryReq.queryParameters['from'], ZhangDates.toRfc3339(DateTime(2023, 9)));
    expect(summaryReq.queryParameters['to'], ZhangDates.toRfc3339(DateTime(2023, 9, 30, 23, 59, 59)));

    // KPIs from the summary: income flipped to positive, net = income − expense.
    expect(
      find.descendant(of: _key('reports.kpi.income'), matching: find.text('¥436.00')),
      findsOneWidget,
    );
    expect(
      find.descendant(of: _key('reports.kpi.expense'), matching: find.text('¥796.73')),
      findsOneWidget,
    );
    expect(
      find.descendant(of: _key('reports.kpi.net'), matching: find.text('-¥360.73')),
      findsOneWidget,
    );

    expect(_key('reports.cashflowChart'), findsOneWidget);

    await _show(tester, _key('reports.donut'), delta: 200);
    expect(_text(tester, 'reports.donutTotal'), '¥796.73');

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
    expect(adapter.requests.any((r) => r.path == '/statistic/Income'), isTrue);
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
    final aug = adapter.requests.lastWhere((r) => r.path == '/statistic/summary');
    expect(aug.queryParameters['from'], ZhangDates.toRfc3339(DateTime(2023, 8)));
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
    await pumpLedgerApp(tester, (path, o) {
      if (path == '/statistic/summary' && fail) return jsonResponse({'message': 'boom'}, status: 500);
      return _route(path, o);
    }, now: DateTime(2023, 9, 15));
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
