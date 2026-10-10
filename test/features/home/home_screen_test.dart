import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:zhang_app/data/repositories/ledger_revision.dart';
import 'package:zhang_app/features/home/home_screen.dart';

import '../journals/fake_server.dart';
import '../journals/journal_test_utils.dart';
import '../journals/screen_test_utils.dart';

void main() {
  testWidgets('home: summary card, recent rows, error chip, detail', (tester) async {
    final server = FakeZhangServer(journals: generateExpenses(30), withErrors: true);
    await pumpApp(tester, server);

    // Summary of the current month from the report.* built-in queries.
    expect(find.byKey(const Key('home.summary')), findsOneWidget);
    expect(find.text('¥798.68'), findsOneWidget);
    expect(find.text('¥436.00'), findsOneWidget);
    expect(find.text('−¥362.68'), findsOneWidget);
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
    expect(server.builtins.callsTo('report.flows'), hasLength(1));
    await tester.tap(find.byKey(const Key('home.prevMonth')));
    await tester.pumpAndSettle();
    expect(server.builtins.callsTo('report.flows'), hasLength(2));
    await tester.tap(find.byKey(const Key('home.nextMonth')));
    await tester.pumpAndSettle();
    // Back to the current month: served from the cache.
    expect(server.builtins.callsTo('report.flows'), hasLength(2));
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

  testWidgets('home: a failing refetch shows the error, not the previous (other ledger) data', (tester) async {
    // Same state shape as a profile switch to an unreachable / 401 ledger:
    // AsyncError that still carries the previous value.
    final server = FakeZhangServer(journals: generateExpenses(3));
    final container = await pumpApp(tester, server);
    expect(find.text('Payee 0'), findsOneWidget);
    expect(find.text('¥798.68'), findsOneWidget);
    server.unauthorized = true;
    container.read(ledgerRevisionProvider.notifier).bump();
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('home.authBanner')), findsOneWidget);
    expect(find.text('Payee 0'), findsNothing);
    expect(find.text('¥798.68'), findsNothing);
    expect(find.text('Failed to load'), findsNWidgets(2));
  });

  testWidgets('home: a failed reload shows a banner; retry reloads', (tester) async {
    final server = FakeZhangServer(journals: generateExpenses(3))
      ..reloadFailure = {
        'file': 'data/2023/12.zhang',
        'message': 'cannot parse data/2023/12.zhang: unexpected input at line 44, column 1',
      };
    await pumpApp(tester, server);
    expect(find.byKey(const Key('home.reloadFailedBanner')), findsOneWidget);
    expect(find.textContaining('unexpected input at line 44'), findsOneWidget);
    // Still failing: the 409 message is shown.
    await tester.tap(find.byKey(const Key('home.reloadRetry')));
    await tester.pumpAndSettle();
    expect(find.textContaining('Server error 409'), findsOneWidget);
    // Fixed: the banner goes away after the reload.
    server.reloadFailure = null;
    await tester.tap(find.byKey(const Key('home.reloadRetry')));
    await tester.pump(const Duration(seconds: 1));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('home.reloadFailedBanner')), findsNothing);
    expect(server.adapter.requests.where((r) => r.uri.path == '/api/reload'), hasLength(2));
  });

  test('humanizeErrorType', () {
    expect(humanizeErrorType('UnbalancedTransaction'), 'Unbalanced transaction');
    expect(humanizeErrorType('AccountBalanceCheckError'), 'Account balance check error');
    expect(humanizeErrorType(''), '');
  });
}
