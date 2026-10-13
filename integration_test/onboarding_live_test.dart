// Live end-to-end check of the setup wizard against running zhang servers.
// NOT part of `flutter test` (needs servers + a device):
//
//   ZHANG_SESSION_SECRET=ob-test zhang serve /tmp/zhang-ob-ledger --addr 127.0.0.1 --port 18121 \
//     --auth demo:secret --no-report
//   flutter test integration_test/onboarding_live_test.dart -d <simulator-id> \
//     [--dart-define=ZHANG_URL=http://127.0.0.1:18121] \
//     [--dart-define=ZHANG_OLD_URL=http://127.0.0.1:18122] \  # a zhang 0.1 server: expect "needs an update"
//     [--dart-define=ZHANG_SCREENSHOT_PAUSE=4]   # seconds to hold each state for screenshots
//     [--dart-define=ZHANG_DEMO=true]            # also "Try the demo" (public demo server, internet)
//
// Walks: welcome → step 1 (address hint, an unreachable host, the too-old
// server) → step 2 (browser sign-in offered first; username and password:
// wrong, then right; one dark / Chinese frame) → step 3 (ledger facts) →
// Start → Home → Settings → Edit server. Clears the app's saved profiles first.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:zhang_app/main.dart' as app;

const _url = String.fromEnvironment('ZHANG_URL', defaultValue: 'http://127.0.0.1:18121');
const _oldUrl = String.fromEnvironment('ZHANG_OLD_URL');
const _user = String.fromEnvironment('ZHANG_USER', defaultValue: 'demo');
const _pass = String.fromEnvironment('ZHANG_PASS', defaultValue: 'secret');
const _pause = int.fromEnvironment('ZHANG_SCREENSHOT_PAUSE');

/// Also try "Try the demo" (the public demo server; needs internet).
const _demo = bool.fromEnvironment('ZHANG_DEMO');

/// `.invalid` never resolves (RFC 2606): an unreachable server without
/// touching the network.
const _unreachable = 'ledger.invalid';

// ignore: avoid_print
void _result(String line) => print('ZHANG_RESULT $line');

Future<void> _hold(WidgetTester tester, String marker) async {
  await tester.pumpAndSettle();
  // ignore: avoid_print
  print('ZHANG_STATE $marker');
  if (_pause > 0) {
    await tester.runAsync(() => Future<void>.delayed(const Duration(seconds: _pause)));
    await tester.pumpAndSettle();
  }
}

bool _present(String key) => find.byKey(Key(key)).evaluate().isNotEmpty;

String _texts(Finder of) => find
    .descendant(of: of, matching: find.byType(Text))
    .evaluate()
    .map((e) => (e.widget as Text).data)
    .whereType<String>()
    .join(' | ');

/// Pumps (with real time passing) until [done] or [seconds] elapsed.
Future<void> _waitFor(WidgetTester tester, bool Function() done, {int seconds = 15}) async {
  for (var i = 0; i < seconds * 10 && !done(); i++) {
    await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 100)));
    await tester.pump();
  }
  await tester.pumpAndSettle();
}

Future<void> _tapKey(WidgetTester tester, String key) async {
  FocusManager.instance.primaryFocus?.unfocus();
  await tester.pumpAndSettle();
  final finder = find.byKey(Key(key));
  await tester.ensureVisible(finder);
  await tester.pumpAndSettle();
  await tester.tap(finder);
  await tester.pump();
}

/// Taps the field first (re-opens the input connection), then types.
Future<void> _type(WidgetTester tester, String key, String text) async {
  final field = find.byKey(Key(key));
  await tester.ensureVisible(field);
  await tester.pumpAndSettle();
  await tester.tap(field);
  await tester.pumpAndSettle();
  await tester.enterText(field, text);
  await tester.pumpAndSettle();
}

Future<void> _submitUrl(WidgetTester tester, String url, bool Function() done) async {
  await _type(tester, 'setup.url', url);
  await _tapKey(tester, 'setup.submitUrl');
  await _waitFor(tester, done, seconds: 20);
}

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('setup wizard against live servers', (tester) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.clear();

    await tester.pumpWidget(await app.bootstrap());
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('welcome.connect')), findsOneWidget);
    await _hold(tester, 'welcome');

    if (_demo) {
      await _tapKey(tester, 'welcome.demo');
      await _waitFor(tester, () => _present('setup.fact.accounts') || _present('welcome.demoError'), seconds: 120);
      for (final key in ['setup.ledgerCard', 'welcome.demoError']) {
        if (_present(key)) _result('demo $key: ${_texts(find.byKey(Key(key)))}');
      }
      expect(find.byKey(const Key('setup.demoNote')), findsOneWidget);
      await _hold(tester, 'demo-ready');
      await _tapKey(tester, 'setup.back');
      await tester.pumpAndSettle();
    }

    // Step 1: the address and its normalisation hint.
    await _tapKey(tester, 'welcome.connect');
    await tester.pumpAndSettle();
    expect(find.text('Step 1 of 3'), findsOneWidget);
    await _type(tester, 'setup.url', '${Uri.parse(_url).host}:${Uri.parse(_url).port}/api/');
    _result('hint: ${find.textContaining('Connects to').evaluate().map((e) => (e.widget as Text).data).join()}');
    await _hold(tester, 'step1-url');

    // An unreachable host: hints + "Use http://…".
    await _submitUrl(tester, _unreachable, () => _present('setup.probeError'));
    expect(find.byKey(const Key('setup.probeError')), findsOneWidget);
    _result('unreachable: ${_texts(find.byKey(const Key('setup.probeError')))}');
    await _hold(tester, 'step1-error');

    // Optional: a zhang 0.1 server.
    if (_oldUrl.isNotEmpty) {
      await _submitUrl(tester, _oldUrl, () => _present('setup.tooOld') || _present('setup.probeError'));
      expect(find.byKey(const Key('setup.tooOld')), findsOneWidget);
      _result('too old: ${_texts(find.byKey(const Key('setup.tooOld')))}');
      await _hold(tester, 'step1-too-old');
    }

    // Step 2: a server with the app login handoff offers the browser sign-in
    // first (older servers: username and password right away).
    await _submitUrl(tester, _url, () => _present('setup.signInBrowser') || _present('setup.signIn'));
    expect(find.text('Step 2 of 3'), findsOneWidget);
    final browser = _present('setup.signInBrowser');
    _result('step 2 offers: browser=$browser password=${_present('setup.usePassword') || _present('setup.signIn')}');
    if (browser) {
      expect(find.byKey(const Key('setup.usePassword')), findsOneWidget);
      await _hold(tester, 'step2-browser');
    }

    // One frame in dark mode and Chinese.
    tester.platformDispatcher.platformBrightnessTestValue = Brightness.dark;
    tester.platformDispatcher.localesTestValue = const [Locale('zh', 'CN')];
    await tester.pumpAndSettle();
    _result('zh: ${find.text('第 2 步，共 3 步').evaluate().length} step label');
    await _hold(tester, 'step2-dark-zh');
    tester.platformDispatcher.clearPlatformBrightnessTestValue();
    tester.platformDispatcher.clearLocalesTestValue();
    await tester.pumpAndSettle();

    // Username and password: wrong, then right.
    if (browser) {
      await _tapKey(tester, 'setup.usePassword');
      await tester.pumpAndSettle();
    }
    await _type(tester, 'setup.username', _user);
    await _type(tester, 'setup.password', '$_pass-wrong');
    FocusManager.instance.primaryFocus?.unfocus();
    await _hold(tester, 'step2-password');
    await _tapKey(tester, 'setup.signIn');
    await _waitFor(tester, () => _present('setup.result.error') || _present('setup.result.ok'));
    expect(find.byKey(const Key('setup.result.error')), findsOneWidget);
    _result('wrong password: ${_texts(find.byKey(const Key('setup.result.error')))}');

    await _type(tester, 'setup.password', _pass);
    await _tapKey(tester, 'setup.signIn');
    await _waitFor(tester, () => _present('setup.result.ok') || _present('setup.result.error'));
    expect(find.byKey(const Key('setup.result.ok')), findsOneWidget);
    _result('signed in: ${_texts(find.byKey(const Key('setup.result.ok')))}');
    await _hold(tester, 'step2-signed-in');

    // Step 3: what the app read from the ledger.
    await _tapKey(tester, 'setup.continue');
    await _waitFor(tester, () => _present('setup.fact.accounts') || _present('setup.overviewError'));
    expect(find.byKey(const Key('setup.fact.accounts')), findsOneWidget);
    _result('ready: ${_texts(find.byKey(const Key('setup.ledgerCard')))}');
    await tester.tap(find.byKey(const Key('colorPicker.ff00897b')));
    await tester.pumpAndSettle();
    await _hold(tester, 'step3-ready');

    // Start → Home with the v0.2 data.
    await _tapKey(tester, 'setup.start');
    await _waitFor(tester, () => _present('home.summary.expense') || _present('home.authBanner'), seconds: 20);
    expect(find.byKey(const Key('shell.newTransaction')), findsOneWidget);
    expect(find.byKey(const Key('home.authBanner')), findsNothing);
    _result('home expense=${tester.widget<Text>(find.byKey(const Key('home.summary.expense'))).data}');
    await _hold(tester, 'home');

    // Settings → Edit server.
    await tester.tap(find.byTooltip('Settings'));
    await tester.pumpAndSettle();
    final menu = find.byWidgetPredicate((w) => w.key is ValueKey<String> &&
        (w.key! as ValueKey<String>).value.startsWith('settings.profileMenu.'));
    await tester.tap(menu.first);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Edit'));
    await tester.pumpAndSettle();
    expect(find.text('Edit server'), findsOneWidget);
    _result('edit form: method=${find.text('Username and password').evaluate().isNotEmpty}');
    await _hold(tester, 'settings-edit');
    await tester.tap(find.byKey(const Key('profileForm.authType')));
    await tester.pumpAndSettle();
    await _hold(tester, 'settings-edit-menu');
  });
}
