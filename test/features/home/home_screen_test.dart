import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:zhang_app/features/home/home_screen.dart';

import '../../helpers/fixtures.dart';
import '../journals/fake_server.dart';
import '../journals/journal_test_utils.dart';
import '../journals/screen_test_utils.dart';

void main() {
  testWidgets('home: summary card, recent rows, error chip, detail', (tester) async {
    final server = FakeZhangServer(
      journals: generateExpenses(30),
      errors: [
        for (final e in ((fixtureData('errors.json') as Map)['records'] as List)) e as Map<String, Object?>,
      ],
    );
    await pumpApp(tester, server);

    // Summary of the current month from /statistic/summary.
    expect(find.byKey(const Key('home.summary')), findsOneWidget);
    expect(find.text('¥796.73'), findsOneWidget);
    expect(find.text('¥436.00'), findsOneWidget);
    expect(find.text('−¥360.73'), findsOneWidget);
    // Recent transactions: page 1, size 10.
    final recent = server.requestsTo('/journals').single.uri.queryParameters;
    expect(recent['size'], '10');
    expect(find.text('Payee 0'), findsOneWidget);
    expect(find.text('Recent transactions'), findsOneWidget);

    // Ledger errors chip → sheet.
    await tester.tap(find.byKey(const Key('home.errors')));
    await tester.pumpAndSettle();
    expect(find.text('Ledger errors'), findsOneWidget);
    expect(find.text('Unbalanced transaction'), findsOneWidget);
    expect(find.textContaining('data/2023/12.zhang'), findsWidgets);
    await tester.tapAt(const Offset(10, 10));
    await tester.pumpAndSettle();

    // Tap a recent row → detail (Home tab keeps its bottom bar).
    await tester.tap(find.text('Payee 0'));
    await tester.pumpAndSettle();
    expect(find.text('Transaction'), findsOneWidget);
    expect(find.text('Payee 0 · n-id-0'), findsOneWidget);
    expect(find.byKey(const Key('shell.newTransaction')), findsOneWidget);
  });

  testWidgets('home: month switcher refetches the summary for that month', (tester) async {
    final server = FakeZhangServer(journals: generateExpenses(3));
    await pumpApp(tester, server);
    expect(server.requestsTo('/statistic/summary'), hasLength(1));
    await tester.tap(find.byKey(const Key('home.prevMonth')));
    await tester.pumpAndSettle();
    expect(server.requestsTo('/statistic/summary'), hasLength(2));
    await tester.tap(find.byKey(const Key('home.nextMonth')));
    await tester.pumpAndSettle();
    // Back to the current month: served from the cache.
    expect(server.requestsTo('/statistic/summary'), hasLength(2));
  });

  testWidgets('home: empty ledger card', (tester) async {
    await pumpApp(tester, FakeZhangServer(journals: []));
    expect(find.byKey(const Key('home.empty')), findsOneWidget);
  });

  testWidgets('home: 401 shows the credentials banner and card errors', (tester) async {
    final server = FakeZhangServer(journals: [expenseJson('a', '2023-09-01T10:00:00')])..unauthorized = true;
    await pumpApp(tester, server);
    expect(find.byKey(const Key('home.authBanner')), findsOneWidget);
    expect(find.text('Failed to load'), findsWidgets);
    await tester.tap(find.text('Update'));
    await tester.pumpAndSettle();
    expect(find.text('Edit server'), findsWidgets);
  });

  test('humanizeErrorType', () {
    expect(humanizeErrorType('UnbalancedTransaction'), 'Unbalanced transaction');
    expect(humanizeErrorType('AccountBalanceCheckError'), 'Account balance check error');
    expect(humanizeErrorType(''), '');
  });
}
