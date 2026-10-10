// Live end-to-end check of onboarding against a running zhang ≥ 0.2 server
// with Basic auth. NOT part of `flutter test` (needs a server + device):
//
//   zhang serve /tmp/zhang-v3-ledger-auth --addr 127.0.0.1 --port 18081 \
//     --auth demo:secret --no-report
//   flutter test integration_test/onboarding_live_test.dart -d <simulator-id> \
//     [--dart-define=ZHANG_URL=http://127.0.0.1:18081] \
//     [--dart-define=ZHANG_OLD_URL=http://127.0.0.1:18082] \  # a zhang 0.1 server: expect "too old"
//     [--dart-define=ZHANG_SCREENSHOT_PAUSE=8]   # seconds to hold each state for screenshots
//
// Clears the app's saved profiles first.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:zhang_app/main.dart' as app;

const _url = String.fromEnvironment('ZHANG_URL', defaultValue: 'http://127.0.0.1:18081');
const _oldUrl = String.fromEnvironment('ZHANG_OLD_URL');
const _user = String.fromEnvironment('ZHANG_USER', defaultValue: 'demo');
const _pass = String.fromEnvironment('ZHANG_PASS', defaultValue: 'secret');
const _pause = int.fromEnvironment('ZHANG_SCREENSHOT_PAUSE');

Future<void> _hold(WidgetTester tester, String marker) async {
  // ignore: avoid_print
  print('ZHANG_STATE $marker');
  if (_pause > 0) {
    await tester.runAsync(() => Future<void>.delayed(const Duration(seconds: _pause)));
    await tester.pumpAndSettle();
  }
}

Future<void> _tapTest(WidgetTester tester) async {
  // Close the keyboard / text toolbars first: they can cover the button.
  FocusManager.instance.primaryFocus?.unfocus();
  await tester.pumpAndSettle();
  final button = find.byKey(const Key('profileForm.test'));
  await tester.ensureVisible(button);
  await tester.pumpAndSettle();
  await tester.tap(button);
  await tester.pump();
  // Real network: poll until the test finished (button enabled again) and a
  // result card is shown.
  for (var i = 0; i < 100; i++) {
    await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 100)));
    await tester.pump();
    final enabled = tester.widget<OutlinedButton>(button).onPressed != null;
    final hasCard = find.byKey(const Key('profileForm.testOk')).evaluate().isNotEmpty ||
        find.byKey(const Key('profileForm.testError')).evaluate().isNotEmpty;
    if (enabled && hasCard) break;
  }
  await tester.pumpAndSettle();
  for (final key in ['profileForm.testOk', 'profileForm.testError']) {
    final card = find.byKey(Key(key));
    if (card.evaluate().isEmpty) continue;
    final texts = find.descendant(of: card, matching: find.byType(Text)).evaluate()
        .map((e) => (e.widget as Text).data)
        .join(' | ');
    // ignore: avoid_print
    print('ZHANG_RESULT $key: $texts');
  }
}

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('onboarding with Basic auth against a live server', (tester) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.clear();

    await tester.pumpWidget(await app.bootstrap());
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('profileForm.url')), findsOneWidget);

    await tester.enterText(find.byKey(const Key('profileForm.name')), 'Demo ledger');

    // 0. Optional: a zhang 0.1 server (no auth) is rejected as too old.
    if (_oldUrl.isNotEmpty) {
      await tester.enterText(find.byKey(const Key('profileForm.url')), _oldUrl);
      await tester.pumpAndSettle();
      await _tapTest(tester);
      expect(find.byKey(const Key('profileForm.testError')), findsOneWidget);
      expect(find.textContaining('too old'), findsOneWidget);
      expect(find.textContaining('zhang ≥ 0.2'), findsOneWidget);
      await _hold(tester, 'onboarding-too-old');
    }

    // Tap the field first (the test unfocused the form; see step 2).
    final url = find.byKey(const Key('profileForm.url'));
    await tester.ensureVisible(url);
    await tester.pumpAndSettle();
    await tester.tap(url);
    await tester.pumpAndSettle();
    await tester.enterText(url, _url);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Basic'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byKey(const Key('profileForm.username')), _user);

    // 1. Wrong password → 401 message.
    await tester.enterText(find.byKey(const Key('profileForm.password')), '$_pass-wrong');
    await _tapTest(tester);
    expect(find.byKey(const Key('profileForm.testError')), findsOneWidget);
    expect(find.textContaining('401'), findsOneWidget);
    await _hold(tester, 'onboarding-401');

    // 2. Correct password → server title + version. Tap the field first: the
    // form unfocused it, and enterText alone would not reopen the input
    // connection (flutter_test keeps a stale focusedEditable).
    final password = find.byKey(const Key('profileForm.password'));
    await tester.ensureVisible(password);
    await tester.pumpAndSettle();
    await tester.tap(password);
    await tester.pumpAndSettle();
    await tester.enterText(password, _pass);
    await tester.pumpAndSettle();
    await _tapTest(tester);
    expect(find.byKey(const Key('profileForm.testOk')), findsOneWidget);
    expect(find.textContaining('My Accounting'), findsOneWidget);
    await _hold(tester, 'onboarding-ok');

    // 3. Save → main shell.
    final submit = find.byKey(const Key('profileForm.submit'));
    await tester.ensureVisible(submit);
    await tester.pumpAndSettle();
    await tester.tap(submit);
    for (var i = 0; i < 50; i++) {
      await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 100)));
      await tester.pump();
      if (find.byKey(const Key('shell.newTransaction')).evaluate().isNotEmpty) break;
    }
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('shell.newTransaction')), findsOneWidget);
    expect(find.text('Demo ledger'), findsWidgets);
    expect(find.byKey(const Key('shell.tooOld')), findsNothing);
    // The v0.2 data (built-in queries) loads with Basic auth.
    for (var i = 0; i < 100 && find.byKey(const Key('home.summary.expense')).evaluate().isEmpty; i++) {
      await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 100)));
      await tester.pump();
    }
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('home.authBanner')), findsNothing);
    // ignore: avoid_print
    print('ZHANG_RESULT home expense=${tester.widget<Text>(find.byKey(const Key('home.summary.expense'))).data}');
    await _hold(tester, 'shell-home');
  });
}
