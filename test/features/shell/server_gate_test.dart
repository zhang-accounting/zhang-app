import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../helpers/fake_adapter.dart';
import '../accounts/ledger_app_harness.dart';

void main() {
  testWidgets('a zhang < 0.2 server gets "server too old" and no other request', (tester) async {
    final (_, adapter) = await pumpLedgerApp(
      tester,
      (path, _) => jsonResponse({'message': 'no route GET /api$path'}, status: 404),
      info: const {
        'data': {'title': 'Old', 'version': '0.1.0', 'build_date': '2026-10-02'},
      },
    );
    expect(find.byKey(const Key('shell.tooOld')), findsOneWidget);
    expect(find.textContaining('zhang ≥ 0.2'), findsOneWidget);
    expect(find.textContaining('0.1.0'), findsOneWidget);
    expect(find.byKey(const Key('home.summary')), findsNothing);
    expect(find.byKey(const Key('shell.newTransaction')), findsNothing);
    expect([for (final r in adapter.requests) r.path], ['/info']);
  });

  testWidgets('a v0.2 server shows the tabs', (tester) async {
    await pumpLedgerApp(
      tester,
      (path, _) => jsonResponse({'message': 'boom'}, status: 500),
    );
    expect(find.byKey(const Key('shell.tooOld')), findsNothing);
    expect(find.byKey(const Key('shell.newTransaction')), findsOneWidget);
  });
}
