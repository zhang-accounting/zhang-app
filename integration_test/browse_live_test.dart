// Live end-to-end check of the browsing screens (Home, Journal, detail)
// against a running zhang server without auth. NOT part of `flutter test`
// (needs a server + device):
//
//   zhang serve /tmp/zhang-app-lineB --addr 127.0.0.1 --port 18030 --no-report
//   flutter test integration_test/browse_live_test.dart -d <simulator-id> \
//     [--dart-define=ZHANG_URL=http://127.0.0.1:18030] \
//     [--dart-define=ZHANG_SCREENSHOT_PAUSE=6]   # seconds to hold each state for screenshots
//
// Prints `ZHANG_STATE <name>` when a state is ready (home, journal, detail).
// Replaces the app's saved profiles with one pointing at ZHANG_URL.
import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:zhang_app/data/profiles/profile_repository.dart';
import 'package:zhang_app/data/profiles/secret_store.dart';
import 'package:zhang_app/data/profiles/server_profile.dart';
import 'package:zhang_app/main.dart' as app;

const _url = String.fromEnvironment('ZHANG_URL', defaultValue: 'http://127.0.0.1:18030');
const _pause = int.fromEnvironment('ZHANG_SCREENSHOT_PAUSE');

void _log(String message) {
  // ignore: avoid_print
  print(message);
}

Future<void> _hold(WidgetTester tester, String marker) async {
  _log('ZHANG_STATE $marker');
  if (_pause > 0) {
    await tester.runAsync(() => Future<void>.delayed(const Duration(seconds: _pause)));
    await tester.pump();
  }
}

/// Pumps (with real time passing for network I/O) until [finder] matches.
Future<void> _waitFor(WidgetTester tester, Finder finder, {int seconds = 20}) async {
  for (var i = 0; i < seconds * 10; i++) {
    if (finder.evaluate().isNotEmpty) return;
    await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 100)));
    await tester.pump();
  }
  expect(finder, findsWidgets, reason: 'timed out waiting for $finder');
}

/// `GET /api/journals?page&size` straight from the server (to know what
/// page 2 holds).
Future<List<Map<String, Object?>>> _journals(int page, int size) async {
  final client = HttpClient();
  try {
    final req = await client.getUrl(Uri.parse('$_url/api/journals?page=$page&size=$size'));
    final res = await req.close();
    final body = jsonDecode(await res.transform(utf8.decoder).join()) as Map<String, Object?>;
    return [for (final r in (body['data'] as Map)['records'] as List) r as Map<String, Object?>];
  } finally {
    client.close();
  }
}

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('home, journal pagination and detail against a live server', (tester) async {
    // Fixtures from the server itself.
    final page1 = (await tester.runAsync(() => _journals(1, 50)))!;
    final page2 = (await tester.runAsync(() => _journals(2, 50)))!;
    expect(page1, hasLength(50));
    expect(page2, isNotEmpty);
    final newest = page1.first;
    final target = page2.first; // first item of the second page
    final latest = DateTime.parse(newest['datetime']! as String);

    // One active profile pointing at the server.
    final prefs = await SharedPreferences.getInstance();
    await prefs.clear();
    final repo = ProfileRepository(prefs: prefs, secrets: SecureSecretStore());
    const profile = ServerProfile(id: 'lineb', name: 'Line B ledger', baseUrl: _url);
    await repo.upsert(profile);
    await repo.setActiveId(profile.id);

    await tester.pumpWidget(await app.bootstrap());
    await tester.pump();

    // --- Home: recent rows + summary card -------------------------------
    await _waitFor(tester, find.byKey(Key('journal.row.${newest['id']}')));
    expect(find.byKey(const Key('home.summary')), findsOneWidget);
    await _waitFor(tester, find.byKey(const Key('home.summary.expense')));
    // Walk the summary back to the month of the newest transaction so the
    // card shows real figures.
    final now = DateTime.now();
    final months = (now.year - latest.year) * 12 + now.month - latest.month;
    for (var i = 0; i < months; i++) {
      await tester.tap(find.byKey(const Key('home.prevMonth')));
      await tester.pump();
    }
    await _waitFor(tester, find.byKey(const Key('home.summary.expense')));
    await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 500)));
    await tester.pumpAndSettle();
    final expense = tester.widget<Text>(find.byKey(const Key('home.summary.expense'))).data;
    final income = tester.widget<Text>(find.byKey(const Key('home.summary.income'))).data;
    _log('ZHANG_RESULT home month=${tester.widget<Text>(find.byKey(const Key('home.month'))).data} '
        'expense=$expense income=$income newest=${newest['payee']}');
    expect(find.text(newest['payee']! as String), findsWidgets);
    await _hold(tester, 'home');

    // --- Journal: scroll until an item of page 2 is visible --------------
    await tester.tap(find.text('Journal').last);
    await tester.pumpAndSettle();
    await _waitFor(tester, find.byKey(ValueKey('journal.item.${newest['id']}')));
    final list = find.descendant(
      of: find.byKey(const PageStorageKey('journal.list')),
      matching: find.byType(Scrollable),
    );
    final targetRow = find.byKey(ValueKey('journal.item.${target['id']}'));
    for (var i = 0; i < 200 && targetRow.evaluate().isEmpty; i++) {
      await tester.drag(list, const Offset(0, -500));
      await tester.pump();
      await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 50)));
      await tester.pump();
    }
    expect(targetRow, findsOneWidget);
    await tester.ensureVisible(targetRow);
    await tester.pumpAndSettle();
    // Bring the row towards the middle so the sticky month header and some
    // context are visible.
    await tester.drag(list, const Offset(0, 250));
    await tester.pumpAndSettle();
    _log('ZHANG_RESULT journal page2-first=${target['id']} payee=${target['payee']}');
    await _hold(tester, 'journal');

    // --- Detail ------------------------------------------------------------
    await tester.tap(targetRow);
    await tester.pumpAndSettle();
    expect(find.text('Transaction'), findsWidgets);
    final payee = target['payee']! as String;
    final subtitle = tester.widget<Text>(find.byKey(const Key('trx.subtitle'))).data!;
    _log('ZHANG_RESULT detail subtitle="$subtitle" amount='
        '${tester.widget<Text>(find.byKey(const Key('trx.amount'))).data}');
    expect(subtitle, startsWith(payee));
    await _hold(tester, 'detail');
  });
}
