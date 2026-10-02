// Live end-to-end check of the "记一笔" flow against a running zhang server
// (no auth). NOT part of `flutter test` (needs a server + simulator):
//
//   zhang serve /tmp/zhang-app-lineA --addr 127.0.0.1 --port 18020 --no-report
//   flutter test integration_test/add_transaction_live_test.dart -d <simulator-id> \
//     [--dart-define=ZHANG_URL=http://127.0.0.1:18020] \
//     [--dart-define=ZHANG_LEDGER_DIR=/tmp/zhang-app-lineA] \
//     [--dart-define=ZHANG_SCREENSHOT_PAUSE=6]   # seconds to hold states for screenshots
//
// Prints `ZHANG_STATE <name>` when a state worth a screenshot is on screen.
// Clears the app's saved profiles first.
import 'dart:io';

import 'package:decimal/decimal.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:zhang_app/data/api/zhang_api_client.dart';
import 'package:zhang_app/data/models/journal.dart';
import 'package:zhang_app/data/profiles/profile_repository.dart';
import 'package:zhang_app/data/profiles/secret_store.dart';
import 'package:zhang_app/data/profiles/server_profile.dart';
import 'package:zhang_app/data/repositories/journal_repository.dart';
import 'package:zhang_app/main.dart' as app;

const _url = String.fromEnvironment('ZHANG_URL', defaultValue: 'http://127.0.0.1:18020');
const _ledgerDir = String.fromEnvironment('ZHANG_LEDGER_DIR', defaultValue: '/tmp/zhang-app-lineA');
const _pause = int.fromEnvironment('ZHANG_SCREENSHOT_PAUSE');

void _log(String line) {
  // ignore: avoid_print
  print(line);
}

Future<void> _hold(WidgetTester tester, String marker) async {
  _log('ZHANG_STATE $marker');
  if (_pause > 0) {
    await tester.runAsync(() => Future<void>.delayed(const Duration(seconds: _pause)));
    await tester.pumpAndSettle();
  }
}

/// Pumps (with real time passing for network I/O) until [finder] matches.
Future<void> _waitFor(WidgetTester tester, Finder finder, {int seconds = 20}) async {
  for (var i = 0; i < seconds * 10; i++) {
    if (finder.evaluate().isNotEmpty) break;
    await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 100)));
    await tester.pump();
  }
  expect(finder, findsWidgets);
  await tester.pumpAndSettle();
}

Future<void> _tapKey(WidgetTester tester, String key) async {
  final finder = find.byKey(Key(key));
  await tester.ensureVisible(finder);
  await tester.tap(finder);
  await tester.pumpAndSettle();
}

Future<void> _keypad(WidgetTester tester, String keys) async {
  for (final k in keys.split('')) {
    final name = switch (k) {
      '+' => 'plus',
      '-' => 'minus',
      '.' => 'dot',
      _ => k,
    };
    await _tapKey(tester, 'add.key.$name');
  }
}

Future<void> _type(WidgetTester tester, String key, String text) async {
  final field = find.byKey(Key(key));
  await tester.ensureVisible(field);
  await tester.tap(field);
  await tester.pumpAndSettle();
  await tester.enterText(field, text);
  await tester.pumpAndSettle();
}

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('record an expense with the keypad against a live server', (tester) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.clear();
    final profile = ServerProfile(id: ProfileRepository.newId(), name: 'Line A', baseUrl: _url);
    final repo = ProfileRepository(prefs: prefs, secrets: SecureSecretStore());
    await repo.upsert(profile);
    await repo.setActiveId(profile.id);

    final payee = 'LineA ${DateTime.now().millisecondsSinceEpoch}';

    await tester.pumpWidget(await app.bootstrap());
    await _waitFor(tester, find.byKey(const Key('shell.newTransaction')));
    await tester.tap(find.byKey(const Key('shell.newTransaction')));
    await tester.pumpAndSettle();

    // Category grid from /api/accounts: PersonalDiet is not an open account
    // itself, so a sub-category is required.
    await _waitFor(tester, find.byKey(const Key('add.category.Expenses:PersonalDiet')));
    await _tapKey(tester, 'add.category.Expenses:PersonalDiet');
    await _tapKey(tester, 'add.sub.Expenses:PersonalDiet:Lunch');

    // Funding account via the picker sheet.
    await _tapKey(tester, 'add.funding');
    await _waitFor(tester, find.byKey(const Key('picker.account.Assets:WeChat')));
    await _hold(tester, 'picker');
    await _tapKey(tester, 'picker.account.Assets:WeChat');
    expect(find.text('Paid from: WeChat'), findsOneWidget);

    await _type(tester, 'add.payee', payee);
    await _type(tester, 'add.narration', 'integration test');
    FocusManager.instance.primaryFocus?.unfocus();
    await tester.pumpAndSettle();

    await _keypad(tester, '12+3.5');
    expect(tester.widget<Text>(find.byKey(const Key('add.expression'))).data, '12 + 3.5');
    expect(tester.widget<Text>(find.byKey(const Key('add.amount'))).data, '¥15.50');
    await _hold(tester, 'add-filled');

    await _tapKey(tester, 'add.key.save'); // "="
    expect(tester.widget<Text>(find.byKey(const Key('add.amount'))).data, '¥15.5');
    await tester.tap(find.byKey(const Key('add.key.save'))); // save
    await _waitFor(tester, find.byKey(const Key('shell.newTransaction')));
    expect(find.byKey(const Key('add.payee')), findsNothing, reason: 'screen closed after saving');
    expect(find.textContaining(payee), findsOneWidget, reason: 'snackbar');
    await _hold(tester, 'saved');

    // The server has the transaction (it reloads asynchronously → poll).
    final journals = JournalRepository(ZhangApiClient(profile));
    JournalTransaction? saved;
    for (var i = 0; i < 50 && saved == null; i++) {
      final page = await tester.runAsync(() => journals.list(JournalQuery(keyword: payee, size: 5)));
      saved = page?.records.whereType<JournalTransaction>().where((t) => t.payee == payee).firstOrNull;
      if (saved == null) await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 200)));
    }
    expect(saved, isNotNull, reason: 'transaction with payee "$payee" in /api/journals');
    final postings = {for (final p in saved!.postings) p.account: p.unit};
    _log('ZHANG_RESULT journal ${saved.datetime} "${saved.payee}" "${saved.narration}" '
        '${saved.postings.map((p) => '${p.account} ${p.unit}').join(' | ')}');
    expect(saved.narration, 'integration test');
    expect(postings['Assets:WeChat']?.number, Decimal.parse('-15.5'));
    expect(postings['Assets:WeChat']?.commodity, 'CNY');
    expect(postings['Expenses:PersonalDiet:Lunch']?.number, Decimal.parse('15.5'));
    expect(saved.isBalanced, isTrue);

    // The ledger text gained the entry (the simulator can read host /tmp).
    final hits = await tester.runAsync(() async {
      final dir = Directory(_ledgerDir);
      if (!dir.existsSync()) return const <String>[];
      return [
        for (final f in dir.listSync(recursive: true).whereType<File>())
          if (f.path.endsWith('.zhang') && f.readAsStringSync().contains('"$payee"')) f.path,
      ];
    });
    _log('ZHANG_RESULT ledger files with payee: $hits');
    expect(hits, isNotEmpty, reason: 'a .zhang file under $_ledgerDir contains the new entry');
  });
}
