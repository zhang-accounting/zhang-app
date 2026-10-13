import 'dart:async';
import 'dart:io';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:zhang_app/app.dart';
import 'package:zhang_app/data/api/zhang_api_client.dart';
import 'package:zhang_app/data/auth/browser_sign_in.dart';
import 'package:zhang_app/data/profiles/profile_providers.dart';
import 'package:zhang_app/data/profiles/secret_store.dart';
import 'package:zhang_app/data/profiles/server_profile.dart';
import 'package:zhang_app/features/onboarding/setup_links.dart';
import 'package:zhang_app/main.dart' show zhangRetryPolicy;

import '../../helpers/fake_setup_server.dart';

Future<ProviderContainer> _pump(WidgetTester tester, FakeSetupServer server) async {
  tester.view.physicalSize = const Size(1170, 2532);
  tester.view.devicePixelRatio = 3;
  addTearDown(tester.view.reset);
  SharedPreferences.setMockInitialValues({});
  final prefs = await SharedPreferences.getInstance();
  final container = ProviderContainer(
    overrides: [
      sharedPreferencesProvider.overrideWithValue(prefs),
      secretStoreProvider.overrideWithValue(InMemorySecretStore()),
      connectionTesterProvider.overrideWithValue(server.tester),
      browserSignInProvider.overrideWithValue(server.signIn),
    ],
    retry: zhangRetryPolicy,
  );
  addTearDown(container.dispose);
  await tester.pumpWidget(UncontrolledProviderScope(container: container, child: const ZhangApp()));
  await tester.pumpAndSettle();
  return container;
}

Future<void> _tap(WidgetTester tester, String key) async {
  final finder = find.byKey(Key(key));
  await tester.ensureVisible(finder);
  await tester.pumpAndSettle();
  await tester.tap(finder);
  await tester.pumpAndSettle();
}

/// Welcome → step 1, enters [url] and taps Continue.
Future<void> _toServer(WidgetTester tester, String url) async {
  if (find.byKey(const Key('welcome.connect')).evaluate().isNotEmpty) await _tap(tester, 'welcome.connect');
  await tester.enterText(find.byKey(const Key('setup.url')), url);
  await tester.pumpAndSettle();
  await _tap(tester, 'setup.submitUrl');
}

String _text(WidgetTester tester, String key) => tester.widget<Text>(find.byKey(Key(key))).data!;

DioException Function(RequestOptions) _error(DioExceptionType type, [Object? error]) =>
    (o) => DioException(requestOptions: o, type: type, error: error);

void main() {
  setUp(() {
    PackageInfo.setMockInitialValues(
      appName: 'zhang_app',
      packageName: 'com.zhangaccounting.app',
      version: '1.0.0',
      buildNumber: '1',
      buildSignature: '',
    );
  });

  testWidgets('welcome, then step 1: validation and the live normalisation hint', (tester) async {
    await _pump(tester, FakeSetupServer());
    expect(find.text('Your plain-text books, in your pocket.'), findsOneWidget);
    expect(find.byKey(const Key('welcome.demo')), findsOneWidget);
    expect(find.byKey(const Key('setup.progress')), findsNothing);

    await _tap(tester, 'welcome.about');
    expect(find.text('Read the docs'), findsOneWidget);
    await tester.tap(find.text('Close'));
    await tester.pumpAndSettle();

    await _tap(tester, 'welcome.connect');
    expect(find.text('Step 1 of 3'), findsOneWidget);
    expect(find.text('Where is your server?'), findsOneWidget);

    await _tap(tester, 'setup.submitUrl');
    expect(find.text('Enter the server URL'), findsOneWidget);

    await tester.enterText(find.byKey(const Key('setup.url')), '127.0.0.1:18011/api/');
    await tester.pumpAndSettle();
    expect(find.text('Enter the server URL'), findsNothing);
    expect(find.text('Connects to https://127.0.0.1:18011'), findsOneWidget);

    await tester.enterText(find.byKey(const Key('setup.url')), 'http://');
    await tester.pumpAndSettle();
    expect(find.textContaining('Connects to'), findsNothing);
    await _tap(tester, 'setup.submitUrl');
    expect(find.text('Enter a valid http(s) URL'), findsOneWidget);

    // Back returns to the welcome page.
    await _tap(tester, 'setup.back');
    expect(find.byKey(const Key('welcome.connect')), findsOneWidget);
  });

  testWidgets('open server: straight to step 3; Start saves, activates and lands on Home', (tester) async {
    final server = FakeSetupServer()..enabled = false;
    final container = await _pump(tester, server);
    await _toServer(tester, 'http://127.0.0.1:18120/');

    expect(find.text('Step 3 of 3'), findsOneWidget);
    expect(find.text("You're connected"), findsOneWidget);
    expect(_text(tester, 'setup.fact.currency'), 'CNY');
    expect(_text(tester, 'setup.fact.accounts'), '22 open');
    expect(_text(tester, 'setup.fact.server'), 'zhang 0.1.0');
    expect(find.text('Not needed'), findsOneWidget);
    expect(_text(tester, 'setup.ledgerCard.name'), 'My Accounting');
    // No credentials were sent anywhere.
    expect(server.requests.map((o) => o.headers['Authorization']), everyElement(isNull));

    await tester.enterText(find.byKey(const Key('setup.name')), 'Family');
    await tester.pumpAndSettle();
    expect(_text(tester, 'setup.ledgerCard.name'), 'Family');
    await _tap(tester, 'colorPicker.ff2e7d32');
    await _tap(tester, 'setup.start');

    final active = container.read(activeProfileProvider)!;
    expect(active.name, 'Family');
    expect(active.baseUrl, 'http://127.0.0.1:18120');
    expect(active.authType, AuthType.none);
    expect(active.color, 0xFF2E7D32);
    expect(find.byKey(const Key('shell.newTransaction')), findsOneWidget);
  });

  testWidgets('unreachable: hints, "Use http://…" retries with http', (tester) async {
    final server = FakeSetupServer()
      ..enabled = false
      ..fail = _error(DioExceptionType.connectionError, const SocketException('Connection refused'));
    await _pump(tester, server);
    await _toServer(tester, '127.0.0.1:18120');

    expect(find.byKey(const Key('setup.probeError')), findsOneWidget);
    expect(find.text('Cannot reach the server'), findsOneWidget);
    expect(find.textContaining('same Wi-Fi or VPN'), findsOneWidget);
    expect(find.textContaining('No scheme was entered'), findsOneWidget);
    expect(find.byKey(const Key('setup.allowSelfSigned')), findsNothing);
    expect(find.text('Try again'), findsOneWidget);

    server.fail = null;
    await _tap(tester, 'setup.tryHttp');
    expect(find.text('Step 3 of 3'), findsOneWidget);
    expect(find.text('127.0.0.1:18120'), findsOneWidget); // host line of the ledger card
  });

  testWidgets('TLS: a certificate error offers the self-signed switch; a plain-http port suggests http', (
    tester,
  ) async {
    final server = FakeSetupServer()
      ..enabled = false
      ..fail = _error(
        DioExceptionType.unknown,
        const HandshakeException('Handshake error in client (OS Error: CERTIFICATE_VERIFY_FAILED: self signed certificate)'),
      );
    final container = await _pump(tester, server);
    await _toServer(tester, 'https://ledger.example.com');
    expect(find.textContaining('TLS certificate was rejected'), findsOneWidget);
    expect(find.byKey(const Key('setup.allowSelfSigned')), findsOneWidget);
    expect(find.byKey(const Key('setup.tryHttp')), findsNothing); // a scheme was typed

    await _tap(tester, 'setup.allowSelfSigned');
    server.fail = null;
    await _tap(tester, 'setup.submitUrl');
    await _tap(tester, 'setup.start');
    expect(container.read(activeProfileProvider)!.allowSelfSigned, isTrue);
  });

  testWidgets('TLS handshake with a plain-http port: no self-signed switch, "Use http://…"', (tester) async {
    final server = FakeSetupServer()
      ..fail = _error(
        DioExceptionType.unknown,
        const HandshakeException('Handshake error in client (OS Error: WRONG_VERSION_NUMBER)'),
      );
    await _pump(tester, server);
    await _toServer(tester, '192.168.1.10:8000');
    expect(find.byKey(const Key('setup.allowSelfSigned')), findsNothing);
    expect(find.text('Use http://192.168.1.10:8000'), findsOneWidget);
  });

  testWidgets('zhang 0.1: "needs an update" and the wizard stays on step 1', (tester) async {
    final server = FakeSetupServer()
      ..enabled = false
      ..v02 = false;
    await _pump(tester, server);
    await _toServer(tester, 'http://127.0.0.1:18122');
    expect(find.byKey(const Key('setup.tooOld')), findsOneWidget);
    expect(find.text('This server needs an update'), findsOneWidget);
    expect(find.textContaining('It runs zhang 0.1.0'), findsOneWidget);
    expect(find.text('Step 1 of 3'), findsOneWidget);
  });

  testWidgets('browser sign-in first (app_login): cancel is silent, then sign-in is verified inline', (
    tester,
  ) async {
    final server = FakeSetupServer()..cancelNextSignIn = true;
    final container = await _pump(tester, server);
    await _toServer(tester, 'http://127.0.0.1:18121');

    expect(find.text('Step 2 of 3'), findsOneWidget);
    expect(find.text('Sign in to My Accounting'), findsOneWidget);
    expect(find.text('127.0.0.1:18121 asks you to sign in.'), findsOneWidget);
    expect(find.byKey(const Key('setup.browserExplainer')), findsOneWidget);
    expect(find.byKey(const Key('setup.usePassword')), findsOneWidget);
    expect(find.byKey(const Key('setup.username')), findsNothing);

    await _tap(tester, 'setup.signInBrowser');
    expect(server.launched, ['http://127.0.0.1:18121/login?return_to=zhang-app%3A%2F%2Fauth%2Fcallback']);
    expect(find.byKey(const Key('setup.result.error')), findsNothing);
    expect(find.byKey(const Key('setup.continue')), findsNothing);

    await _tap(tester, 'setup.signInBrowser');
    expect(server.launched, hasLength(2));
    expect(find.byKey(const Key('setup.result.ok')), findsOneWidget);
    expect(find.text('Signed in as demo'), findsOneWidget);
    expect(find.textContaining('Connected to “My Accounting”'), findsOneWidget);

    await _tap(tester, 'setup.continue');
    expect(_text(tester, 'setup.fact.user'), 'demo');
    expect(_text(tester, 'setup.fact.accounts'), '22 open');
    await _tap(tester, 'setup.start');

    final active = container.read(activeProfileProvider)!;
    expect(active.authType, AuthType.session);
    expect(active.sessionUser, 'demo');
    expect(active.sessionExpiresAt, DateTime.utc(2026, 11, 9, 3, 7, 29));
    expect(active.authHeaders(), {'Authorization': 'Bearer tok1.sig'});
  });

  testWidgets('username and password: from the browser page, wrong password inline, then right', (tester) async {
    final server = FakeSetupServer();
    final container = await _pump(tester, server);
    await _toServer(tester, 'http://127.0.0.1:18121');
    await _tap(tester, 'setup.usePassword');
    expect(find.byKey(const Key('setup.useBrowser')), findsOneWidget);

    await tester.enterText(find.byKey(const Key('setup.username')), 'demo');
    await tester.enterText(find.byKey(const Key('setup.password')), 'wrong');
    await _tap(tester, 'setup.signIn');
    expect(find.text('Authentication failed (401). Check your credentials.'), findsOneWidget);

    await tester.enterText(find.byKey(const Key('setup.password')), 'secret');
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('setup.result.error')), findsNothing);
    await _tap(tester, 'setup.signIn');
    expect(find.text('Signed in as demo'), findsOneWidget);
    await _tap(tester, 'setup.continue');

    // Back to step 2 keeps the result; back again keeps the address.
    await _tap(tester, 'setup.back');
    expect(find.byKey(const Key('setup.result.ok')), findsOneWidget);
    await _tap(tester, 'setup.back');
    expect(find.text('Connects to http://127.0.0.1:18121'), findsOneWidget);
    await _tap(tester, 'setup.submitUrl');
    expect(find.byKey(const Key('setup.result.ok')), findsOneWidget);
    await _tap(tester, 'setup.continue');
    await _tap(tester, 'setup.start');

    final active = container.read(activeProfileProvider)!;
    expect(active.authType, AuthType.basic);
    expect(active.basicUsername, 'demo');
    expect(active.basicPassword, 'secret');
  });

  testWidgets('password only (no app handoff): fields directly, no browser option', (tester) async {
    final server = FakeSetupServer()
      ..appLogin = false
      ..passkey = false;
    await _pump(tester, server);
    await _toServer(tester, 'http://127.0.0.1:18121');
    expect(find.byKey(const Key('setup.username')), findsOneWidget);
    expect(find.byKey(const Key('setup.signInBrowser')), findsNothing);
    expect(find.byKey(const Key('setup.useBrowser')), findsNothing);
  });

  testWidgets('passkey only without the app handoff: explanation, "Check again" after the upgrade', (
    tester,
  ) async {
    final server = FakeSetupServer()
      ..password = false
      ..appLogin = false;
    await _pump(tester, server);
    await _toServer(tester, 'http://127.0.0.1:18121');
    expect(find.byKey(const Key('setup.passkeyUnsupported')), findsOneWidget);
    expect(find.text('This server only accepts passkeys'), findsOneWidget);
    expect(find.byKey(const Key('setup.signInBrowser')), findsNothing);
    expect(find.byKey(const Key('setup.username')), findsNothing);

    server.appLogin = true;
    await _tap(tester, 'setup.checkAgain');
    expect(find.byKey(const Key('setup.signInBrowser')), findsOneWidget);
    expect(find.byKey(const Key('setup.usePassword')), findsNothing);
  });

  testWidgets('gateway in front: bearer token, then custom headers', (tester) async {
    final server = FakeSetupServer()..gateway = true;
    final container = await _pump(tester, server);
    await _toServer(tester, 'https://ledger.example.com');
    expect(find.text('Step 2 of 3'), findsOneWidget);
    expect(find.text('The server asks for credentials.'), findsOneWidget);
    expect(find.byKey(const Key('setup.advanced')), findsNothing);

    await tester.enterText(find.byKey(const Key('setup.token')), 'nope');
    await _tap(tester, 'setup.connect');
    expect(find.byKey(const Key('setup.result.error')), findsOneWidget);

    await tester.tap(find.text('Custom headers'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byKey(const Key('setup.headerName.0')), 'X-Gate');
    await tester.enterText(find.byKey(const Key('setup.headerValue.0')), 'open');
    await _tap(tester, 'setup.connect');
    expect(find.text('Connected'), findsOneWidget);
    await _tap(tester, 'setup.continue');
    await _tap(tester, 'setup.start');
    final active = container.read(activeProfileProvider)!;
    expect(active.authType, AuthType.headers);
    expect(active.customHeaders, {'X-Gate': 'open'});
  });

  testWidgets('"Reverse proxy or gateway" section on a zhang sign-in page: bearer token', (tester) async {
    final server = FakeSetupServer();
    final container = await _pump(tester, server);
    await _toServer(tester, 'http://127.0.0.1:18121');
    await _tap(tester, 'setup.advanced');
    // zhang itself accepts no proxy token: the error stays in the section.
    await tester.enterText(find.byKey(const Key('setup.token')), 'proxy-token');
    await _tap(tester, 'setup.connectAdvanced');
    expect(find.byKey(const Key('setup.proxyError')), findsOneWidget);
    expect(find.byKey(const Key('setup.result.error')), findsNothing);

    server.gateway = true;
    await _tap(tester, 'setup.connectAdvanced');
    expect(find.text('Connected'), findsOneWidget);
    await _tap(tester, 'setup.continue');
    await _tap(tester, 'setup.start');
    final active = container.read(activeProfileProvider)!;
    expect(active.authType, AuthType.bearer);
    expect(active.bearerToken, 'proxy-token');
  });

  testWidgets('"Try the demo": retries a timeout while the demo wakes up, then the summary', (tester) async {
    final server = FakeSetupServer()..enabled = false;
    final container = await _pump(tester, server);
    final wake = Completer<void>();
    var timeouts = 0;
    server
      ..gate = wake.future
      ..fail = (o) {
        // The first request times out; the retry is answered.
        timeouts++;
        server.fail = null;
        return DioException(requestOptions: o, type: DioExceptionType.receiveTimeout);
      };
    await tester.tap(find.byKey(const Key('welcome.demo')));
    await tester.pump();
    expect(find.text('Waking up the demo server. This can take up to a minute.'), findsOneWidget);
    expect(tester.widget<FilledButton>(find.byKey(const Key('welcome.connect'))).onPressed, isNull);

    wake.complete();
    server.gate = null;
    await tester.pumpAndSettle();
    expect(timeouts, 1);
    expect(find.byKey(const Key('setup.demoNote')), findsOneWidget);
    expect(find.byKey(const Key('setup.progress')), findsNothing);
    expect(server.requests.first.uri.toString(), startsWith(kDemoServerUrl));

    // Back leaves the demo; "Connect" starts with an empty address.
    await _tap(tester, 'setup.back');
    await _tap(tester, 'welcome.connect');
    expect(tester.widget<TextField>(find.byKey(const Key('setup.url'))).controller!.text, isEmpty);
    await _tap(tester, 'setup.back');

    await _tap(tester, 'welcome.demo');
    await _tap(tester, 'setup.start');
    final active = container.read(activeProfileProvider)!;
    expect(active.baseUrl, kDemoServerUrl);
    expect(active.name, 'My Accounting');
  });
}
