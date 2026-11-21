import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../journals/fake_server.dart';
import '../journals/journal_test_utils.dart';
import '../journals/screen_test_utils.dart';

/// Records ¥9 at "Corner Shop" from the Home tab's "Record" button.
Future<void> _record(WidgetTester tester) async {
  await tester.tap(find.byKey(const Key('shell.newTransaction')));
  await tester.pumpAndSettle();
  await tester.tap(find.byKey(const Key('add.category.Expenses:Clothing')));
  await tester.pumpAndSettle();
  await tester.tap(find.byKey(const Key('add.key.9')));
  await tester.pump();
  await tester.enterText(find.byKey(const Key('add.payee')), 'Corner Shop');
  FocusManager.instance.primaryFocus?.unfocus();
  await tester.pumpAndSettle();
  await tester.tap(find.byKey(const Key('add.key.save')));
  await tester.pumpAndSettle();
}

List<Map<String, Object?>> _journal() => [
  txnJson(
    id: 'old-1',
    datetime: '2023-09-30T12:00:00',
    payee: 'Bakery',
    postings: [('Assets:WeChat', '-18', 'CNY'), ('Expenses:Food', '18', 'CNY')],
  ),
];

void main() {
  testWidgets('a create that answers its id offers "View", which opens it in the Home tab (zhang ≥ 0.3)', (
    tester,
  ) async {
    final server = FakeZhangServer(journals: _journal())..writesAnswerIds = true;
    await pumpApp(tester, server);
    await _record(tester);

    final create = server.requestsTo('/api/transactions').single;
    expect(create.method, 'POST');
    expect(create.headers['Idempotency-Key'], isNotNull);
    expect(find.text('Recorded −¥9.00 · Corner Shop'), findsOneWidget);
    expect(find.byKey(const Key('add.viewSaved')), findsOneWidget);

    await tester.tap(find.byKey(const Key('add.viewSaved')));
    await tester.pumpAndSettle();
    expect(find.text('Transaction'), findsOneWidget);
    expect(find.byKey(const Key('trx.subtitle')), findsOneWidget);
    expect(find.text('Corner Shop'), findsWidgets);
    expect(find.byKey(const Key('trx.message')), findsNothing, reason: 'found under the id, same version');
    // Opened in the Home tab, which it was recorded from.
    expect(tester.widget<NavigationBar>(find.byType(NavigationBar)).selectedIndex, 0);
    await tester.pageBack();
    await tester.pumpAndSettle();
    expect(find.text('Transaction'), findsNothing);
    expect(tester.widget<NavigationBar>(find.byType(NavigationBar)).selectedIndex, 0);
  });

  testWidgets('an older server answers "Ok": the snackbar has no "View"', (tester) async {
    final server = FakeZhangServer(journals: _journal());
    await pumpApp(tester, server);
    await _record(tester);

    expect(server.requestsTo('/api/transactions').single.headers['Idempotency-Key'], isNotNull);
    expect(find.text('Recorded −¥9.00 · Corner Shop'), findsOneWidget);
    expect(find.byKey(const Key('add.viewSaved')), findsNothing);
  });
}
