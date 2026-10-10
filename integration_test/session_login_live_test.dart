// Live end-to-end check of the browser sign-in ("Browser" auth type) against
// a running zhang server with the app login handoff (zhang PR #786). NOT part
// of `flutter test` (needs a server + device):
//
//   ZHANG_SESSION_SECRET=pk-test zhang serve /tmp/zhang-pk-ledger --addr 127.0.0.1 \
//     --port 18100 --auth demo:secret --no-report
//   flutter test integration_test/session_login_live_test.dart -d <simulator-id> \
//     [--dart-define=ZHANG_URL=http://127.0.0.1:18100] \
//     [--dart-define=ZHANG_USER=demo --dart-define=ZHANG_PASS=secret] \
//     [--dart-define=ZHANG_SCREENSHOT_PAUSE=8]   # seconds to hold each state for screenshots
//
// No browser is driven: the launcher ([webAuthLauncherProvider]) is replaced
// by one that does what the login page does – `POST /api/auth/login`, then
// `POST /api/auth/app/code` with the session cookie – and returns the
// `zhang-app://auth/callback?code=…` redirect. Everything after the callback
// (code parsing, exchange, storage, Bearer requests, sign-out) is the app's
// real code path. Clears the app's saved profiles first. Never prints tokens.
import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:zhang_app/data/auth/browser_sign_in.dart';
import 'package:zhang_app/data/profiles/profile_providers.dart';
import 'package:zhang_app/data/profiles/profile_repository.dart';
import 'package:zhang_app/data/profiles/secret_store.dart';
import 'package:zhang_app/data/profiles/server_profile.dart';
import 'package:zhang_app/data/repositories/ledger_events.dart';
import 'package:zhang_app/main.dart' as app;

const _url = String.fromEnvironment('ZHANG_URL', defaultValue: 'http://127.0.0.1:18100');
const _user = String.fromEnvironment('ZHANG_USER', defaultValue: 'demo');
const _pass = String.fromEnvironment('ZHANG_PASS', defaultValue: 'secret');
const _pause = int.fromEnvironment('ZHANG_SCREENSHOT_PAUSE');

// ignore: avoid_print
void _result(String line) => print('ZHANG_RESULT $line');

Future<void> _hold(WidgetTester tester, String marker) async {
  // ignore: avoid_print
  print('ZHANG_STATE $marker');
  if (_pause > 0) {
    await tester.runAsync(() => Future<void>.delayed(const Duration(seconds: _pause)));
    await tester.pumpAndSettle();
  }
}

/// What the server's login page does after a successful sign-in: password
/// login (cookie `zhang_session`), then a one-time code for the app.
Future<String> _callbackFromServer(String loginUrl, String scheme) async {
  final login = Uri.parse(loginUrl);
  final returnTo = login.queryParameters['return_to']!;
  final http = HttpClient();
  try {
    final req = await http.postUrl(Uri.parse('$_url/api/auth/login'));
    req.headers.contentType = ContentType.json;
    req.write(jsonEncode({'username': _user, 'password': _pass}));
    final res = await req.close();
    await res.drain<void>();
    if (res.statusCode != 200) throw StateError('login failed: HTTP ${res.statusCode}');
    final cookie = res.cookies.firstWhere((c) => c.name == 'zhang_session');

    final codeReq = await http.postUrl(Uri.parse('$_url/api/auth/app/code'));
    codeReq.headers.contentType = ContentType.json;
    codeReq.cookies.add(Cookie(cookie.name, cookie.value));
    codeReq.write(jsonEncode({'return_to': returnTo}));
    final codeRes = await codeReq.close();
    final body = await codeRes.transform(utf8.decoder).join();
    if (codeRes.statusCode != 200) throw StateError('app/code failed: HTTP ${codeRes.statusCode}');
    final redirect = (jsonDecode(body) as Map)['data']['redirect'] as String;
    if (!redirect.startsWith('$scheme://')) throw StateError('unexpected redirect scheme');
    return redirect;
  } finally {
    http.close(force: true);
  }
}

/// Pumps (with real time passing) until [done] or [seconds] elapsed.
Future<void> _waitFor(WidgetTester tester, bool Function() done, {int seconds = 15}) async {
  for (var i = 0; i < seconds * 10 && !done(); i++) {
    await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 100)));
    await tester.pump();
  }
  await tester.pumpAndSettle();
}

bool _present(String key) => find.byKey(Key(key)).evaluate().isNotEmpty;

String _texts(Finder of) => find
    .descendant(of: of, matching: find.byType(Text))
    .evaluate()
    .map((e) => (e.widget as Text).data)
    .join(' | ');

Future<void> _tapKey(WidgetTester tester, String key) async {
  FocusManager.instance.primaryFocus?.unfocus();
  await tester.pumpAndSettle();
  final finder = find.byKey(Key(key));
  await tester.ensureVisible(finder);
  await tester.pumpAndSettle();
  await tester.tap(finder);
  await tester.pump();
}

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('browser sign-in (session token) against a live server', (tester) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.clear();

    final launched = <String>[];
    Future<String> launcher(String url, String scheme) async {
      launched.add(url);
      return _callbackFromServer(url, scheme);
    }

    await tester.pumpWidget(
      await app.bootstrap(overrides: [webAuthLauncherProvider.overrideWithValue(launcher)]),
    );
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('profileForm.url')), findsOneWidget);

    await tester.enterText(find.byKey(const Key('profileForm.name')), 'Passkey ledger');
    final url = find.byKey(const Key('profileForm.url'));
    await tester.tap(url);
    await tester.pumpAndSettle();
    await tester.enterText(url, _url);
    await tester.pumpAndSettle();
    FocusManager.instance.primaryFocus?.unfocus();
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.text('Browser'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Browser'));
    await tester.pumpAndSettle();
    expect(tester.widget<FilledButton>(find.byKey(const Key('profileForm.submit'))).onPressed, isNull);
    await _hold(tester, 'form-browser');

    // 1. "Sign in with browser": /api/auth/status, launcher, callback, exchange.
    await _tapKey(tester, 'profileForm.signIn');
    await _waitFor(tester, () => _present('profileForm.signedIn') || _present('profileForm.signInError'));
    _result('launched ${launched.single}');
    expect(launched.single, '$_url/login?return_to=zhang-app%3A%2F%2Fauth%2Fcallback');
    for (final key in ['profileForm.signedIn', 'profileForm.signInError']) {
      if (_present(key)) _result('$key: ${_texts(find.byKey(Key(key)))}');
    }
    expect(find.byKey(const Key('profileForm.signedIn')), findsOneWidget);
    expect(find.textContaining('Signed in as $_user, valid until'), findsOneWidget);
    await _hold(tester, 'form-signed-in');

    // 2. "Test connection" with the session token → /api/info.
    await _tapKey(tester, 'profileForm.test');
    await _waitFor(tester, () => _present('profileForm.testOk') || _present('profileForm.testError'));
    for (final key in ['profileForm.testOk', 'profileForm.testError']) {
      if (_present(key)) _result('$key: ${_texts(find.byKey(Key(key)))}');
    }
    expect(find.byKey(const Key('profileForm.testOk')), findsOneWidget);

    // 3. Save → profile with a Bearer session (secure storage) → Home loads.
    await _tapKey(tester, 'profileForm.submit');
    await _waitFor(tester, () => _present('home.summary.expense') || _present('home.authBanner'), seconds: 20);
    final container = ProviderScope.containerOf(tester.element(find.byKey(const Key('home.list'))));
    final profile = container.read(activeProfileProvider)!;
    final auth = profile.authHeaders()['Authorization'] ?? '';
    _result(
      'saved authType=${profile.authType.name} user=${profile.sessionUser} '
      'expires=${profile.sessionExpiresAt?.toIso8601String()} '
      'header=${auth.startsWith('Bearer ') ? 'Bearer <${auth.length - 7} chars>' : 'missing'}',
    );
    expect(profile.authType, AuthType.session);
    expect(auth, startsWith('Bearer '));
    final stored = await SecureSecretStore().read(ProfileRepository.secretKey(profile.id));
    final secret = jsonDecode(stored!) as Map<String, Object?>;
    _result('secure storage keys=${secret.keys.toList()}');
    expect(secret['sessionToken'], isA<String>());
    expect(prefs.getString(ProfileRepository.profilesKey), isNot(contains(secret['sessionToken']! as String)));

    expect(find.byKey(const Key('home.authBanner')), findsNothing);
    expect(find.byKey(const Key('home.sessionExpiringBanner')), findsNothing);
    final expense = tester.widget<Text>(find.byKey(const Key('home.summary.expense'))).data;
    _result('home expense=$expense recentRows=${find.byKey(const Key('home.list')).evaluate().isNotEmpty}');
    // The SSE stream authenticates with the same Bearer header.
    await _waitFor(tester, () => container.read(ledgerEventsProvider).connected, seconds: 10);
    _result('sse connected=${container.read(ledgerEventsProvider).connected}');
    expect(container.read(ledgerEventsProvider).connected, isTrue);
    await _hold(tester, 'shell-home');

    // 4. Settings → "Sign out" clears the session → Home shows the 401 banner.
    await tester.tap(find.byTooltip('Settings'));
    await tester.pumpAndSettle();
    final subtitle = find.byKey(Key('settings.profileSubtitle.${profile.id}'));
    _result('settings subtitle=${tester.widget<Text>(subtitle).data!.replaceAll('\n', ' / ')}');
    await _hold(tester, 'settings-signed-in');
    await tester.tap(find.byKey(Key('settings.profileMenu.${profile.id}')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(Key('settings.signOut.${profile.id}')));
    await tester.pumpAndSettle();
    final signedOut = container.read(activeProfileProvider)!;
    expect(signedOut.hasSession, isFalse);
    expect(await SecureSecretStore().read(ProfileRepository.secretKey(profile.id)), isNull);
    _result('after sign-out hasSession=${signedOut.hasSession} '
        'header=${signedOut.authHeaders().containsKey('Authorization')} '
        'subtitle=${tester.widget<Text>(subtitle).data!.replaceAll('\n', ' / ')}');
    await tester.tap(find.byType(BackButton));
    await tester.pumpAndSettle();
    await _waitFor(tester, () => _present('home.authBanner'));
    expect(find.byKey(const Key('home.authBanner')), findsOneWidget);
    expect(find.byKey(const Key('home.signInAgain')), findsOneWidget);
    _result('home after sign-out: ${_texts(find.byKey(const Key('home.authBanner')))}');
    await _hold(tester, 'home-signed-out');

    // 5. "Sign in again" → a new session → Home loads again.
    await tester.tap(find.byKey(const Key('home.signInAgain')));
    await tester.pump();
    await _waitFor(
      tester,
      () => !_present('home.authBanner') && _present('home.summary.expense'),
      seconds: 20,
    );
    expect(launched, hasLength(2));
    expect(container.read(activeProfileProvider)!.hasSession, isTrue);
    expect(find.byKey(const Key('home.authBanner')), findsNothing);
    _result('signed in again: hasSession=${container.read(activeProfileProvider)!.hasSession} '
        'expense=${tester.widget<Text>(find.byKey(const Key('home.summary.expense'))).data}');
    await _hold(tester, 'home-signed-in-again');
  });
}
