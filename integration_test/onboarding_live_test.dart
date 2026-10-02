// Live end-to-end check of onboarding against a running zhang server with
// Basic auth. NOT part of `flutter test` (needs a server + device):
//
//   zhang serve /tmp/zhang-app-dev-ledger-auth --addr 127.0.0.1 --port 18011 \
//     --auth demo:secret --no-report
//   flutter test integration_test/onboarding_live_test.dart -d <simulator-id> \
//     [--dart-define=ZHANG_URL=http://127.0.0.1:18011] \
//     [--dart-define=ZHANG_SCREENSHOT_PAUSE=8]   # seconds to hold each state for screenshots
//
// Clears the app's saved profiles first.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:zhang_app/main.dart' as app;

const _url = String.fromEnvironment('ZHANG_URL', defaultValue: 'http://127.0.0.1:18011');
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
    await tester.enterText(find.byKey(const Key('profileForm.url')), _url);
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
    await _hold(tester, 'shell-home');
  });
}
