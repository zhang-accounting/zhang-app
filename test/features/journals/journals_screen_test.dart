import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

import 'fake_server.dart';
import 'journal_test_utils.dart';
import 'screen_test_utils.dart';

/// `/journals` requests of the Journal tab (Home asks for size=10).
List<RequestOptions> journalTabRequests(FakeZhangServer server) =>
    server.requestsTo('/journals').where((r) => r.uri.queryParameters['size'] == '50').toList();

Future<void> openJournalTab(WidgetTester tester) async {
  await tester.tap(find.text('Journal'));
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('journal: month headers, day groups, infinite scroll loads page 2', (tester) async {
    final server = FakeZhangServer(journals: generateExpenses(80));
    await pumpApp(tester, server);
    await openJournalTab(tester);

    expect(find.byKey(const ValueKey('journal.item.id-0')), findsOneWidget);
    expect(find.text('September 2023'), findsOneWidget);
    // Month header totals come from the summary endpoint.
    expect(find.text('Exp ¥796.73'), findsWidgets);
    expect(find.text('Inc ¥436.00'), findsWidgets);
    // Day header with the day's net (two expenses of 1 and 2 on 2023-09-30).
    expect(
      find.descendant(of: find.byKey(const ValueKey('journal.day.2023-09-30')), matching: find.text('−¥3.00')),
      findsOneWidget,
    );
    expect(journalTabRequests(server), hasLength(1));

    // Scroll to the end: the footer loads page 2.
    await tester.scrollUntilVisible(
      find.byKey(const ValueKey('journal.item.id-79')),
      600,
      scrollable: find.descendant(of: find.byKey(const PageStorageKey('journal.list')), matching: find.byType(Scrollable)),
      maxScrolls: 100,
    );
    await tester.pumpAndSettle();
    final journalRequests = journalTabRequests(server);
    expect(journalRequests, hasLength(2));
    expect(journalRequests.last.uri.queryParameters['page'], '2');
    expect(find.text('August 2023'), findsWidgets);
  });

  testWidgets('journal: type chips filter client-side, tapping a row opens the detail', (tester) async {
    final server = FakeZhangServer(
      journals: [
        expenseJson('e1', '2023-09-30T12:00:00', payee: 'Cafe'),
        txnJson(
          id: 'i1',
          datetime: '2023-09-29T09:00:00',
          payee: 'Boss',
          narration: 'Salary',
          tags: ['work'],
          links: ['payslip-9'],
          metas: [
            {'key': 'source', 'value': 'zhang-app'},
          ],
          postings: [('Income:Salary', '-1000', 'CNY'), ('Assets:Bank', '1000', 'CNY')],
          implicit: {1},
        ),
        balanceCheckJson(id: 'b1', datetime: '2023-09-28T23:00:00'),
      ],
    );
    await pumpApp(tester, server);
    await openJournalTab(tester);
    expect(find.text('Cafe'), findsOneWidget);
    expect(find.text('Boss'), findsOneWidget);
    expect(find.text('Balance check'), findsOneWidget);

    await tester.tap(find.byKey(const Key('journal.type.income')));
    await tester.pumpAndSettle();
    expect(find.text('Cafe'), findsNothing);
    expect(find.text('Balance check'), findsNothing);
    expect(find.text('Boss'), findsOneWidget);
    expect(find.text('+¥1,000.00'), findsWidgets);
    expect(journalTabRequests(server), hasLength(1));

    await tester.tap(find.text('Boss'));
    await tester.pumpAndSettle();
    expect(find.text('Transaction'), findsOneWidget);
    expect(find.byKey(const Key('trx.subtitle')), findsOneWidget);
    expect(find.text('Boss · Salary'), findsOneWidget);
    expect(find.text('Income:Salary'), findsOneWidget);
    expect(find.text('#work'), findsOneWidget);
    expect(find.text('^payslip-9'), findsOneWidget);
    expect(find.text('auto'), findsOneWidget);

    // Copy as text.
    String? copied;
    tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(SystemChannels.platform, (call) async {
      if (call.method == 'Clipboard.setData') copied = (call.arguments as Map)['text'] as String;
      return null;
    });
    addTearDown(() => tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(SystemChannels.platform, null));
    await tester.tap(find.byKey(const Key('trx.copy')));
    await tester.pumpAndSettle();
    expect(copied, startsWith('2023-09-29 09:00:00 * "Boss" "Salary" #work ^payslip-9\n  source: "zhang-app"'));
    expect(find.text('Copied to clipboard'), findsOneWidget);
  });

  testWidgets('journal: keyword search goes to the server; no match offers clearing', (tester) async {
    final server = FakeZhangServer(journals: generateExpenses(5));
    await pumpApp(tester, server);
    await openJournalTab(tester);

    await tester.tap(find.byKey(const Key('journal.searchToggle')));
    await tester.pumpAndSettle();
    await tester.enterText(find.byKey(const Key('journal.search')), 'nothing-matches');
    await tester.pump(const Duration(milliseconds: 500));
    await tester.pumpAndSettle();
    expect(journalTabRequests(server).last.uri.queryParameters['keyword'], 'nothing-matches');
    expect(find.text('No matching transactions'), findsOneWidget);

    await tester.tap(find.byKey(const Key('journal.clearFilters')));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('journal.item.id-0')), findsOneWidget);
  });

  testWidgets('journal: empty ledger', (tester) async {
    final server = FakeZhangServer(journals: []);
    await pumpApp(tester, server);
    await openJournalTab(tester);
    expect(find.text('No transactions yet'), findsOneWidget);
  });

  testWidgets('journal: a failing next page shows retry in the footer', (tester) async {
    final server = FakeZhangServer(journals: generateExpenses(60))..failingPages = {2};
    await pumpApp(tester, server);
    await openJournalTab(tester);
    final list = find.descendant(
      of: find.byKey(const PageStorageKey('journal.list')),
      matching: find.byType(Scrollable),
    );
    await tester.scrollUntilVisible(find.byKey(const Key('journal.loadMoreRetry')), 600, scrollable: list);
    await tester.pumpAndSettle();
    expect(find.text('Failed to load more'), findsOneWidget);

    server.failingPages = {};
    await tester.tap(find.byKey(const Key('journal.loadMoreRetry')));
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(find.byKey(const ValueKey('journal.item.id-59')), 600, scrollable: list);
    expect(find.text('Failed to load more'), findsNothing);
  });
}
