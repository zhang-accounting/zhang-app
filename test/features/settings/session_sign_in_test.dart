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
import 'package:zhang_app/data/profiles/profile_repository.dart';
import 'package:zhang_app/data/profiles/secret_store.dart';
import 'package:zhang_app/data/profiles/server_profile.dart';

import '../../helpers/fake_adapter.dart';
import '../journals/fake_server.dart';
import '../journals/journal_test_utils.dart';

const _base = 'http://127.0.0.1:18100';
const _code = 'q3Hn0Zx4c0QyX2xJm9Yb8kq1sV7tWw5uRr6pLe-_aBc';

/// The fake zhang server's sign-in side: `/api/auth/status`, the code
/// exchange (a new token per exchange) and logout.
class _FakeAuthServer {
  bool appLogin = true;
  bool enabled = true;
  int exchanges = 0;
  final launched = <String>[];
  final logouts = <String?>[];

  /// Tokens the ledger accepts (see [_ledgerAdapter]).
  final valid = <String>{};

  ResponseBody handle(RequestOptions o) {
    final path = o.uri.path;
    if (path.endsWith('/auth/status')) {
      return jsonResponse({
        'data': {
          'enabled': enabled,
          'authenticated': false,
          'methods': {'password': true, 'passkey': true},
          'passkey_registered': true,
          'user': null,
          'title': 'My Accounting',
          if (appLogin) 'app_login': true,
          if (appLogin) 'app_return_schemes': ['zhang-app'],
        },
      });
    }
    if (path.endsWith('/auth/app/exchange')) {
      exchanges++;
      final token = 'tok$exchanges.sig';
      valid.add(token);
      return jsonResponse({
        'data': {'token': token, 'expires_at': '2026-11-09T03:07:29Z', 'user': 'demo'},
      });
    }
    if (path.endsWith('/auth/logout')) {
      logouts.add(o.headers['Authorization'] as String?);
      return jsonResponse({'data': null});
    }
    return jsonResponse({'message': 'no route ${o.method} $path'}, status: 404);
  }

  BrowserSignIn signIn() => BrowserSignIn(
    launch: (url, scheme) async {
      launched.add(url);
      return '$scheme://auth/callback?code=$_code';
    },
    createClient: (profile) => ZhangApiClient(profile)..dio.httpClientAdapter = FakeAdapter(handle),
  );
}

Future<ProviderContainer> _pump(
  WidgetTester tester, {
  required _FakeAuthServer auth,
  FakeZhangServer? ledger,
  ProfilesState initial = const ProfilesState(),
}) async {
  tester.view.physicalSize = const Size(1170, 2532);
  tester.view.devicePixelRatio = 3;
  addTearDown(tester.view.reset);
  SharedPreferences.setMockInitialValues({});
  final prefs = await SharedPreferences.getInstance();
  final container = ProviderContainer(
    overrides: [
      sharedPreferencesProvider.overrideWithValue(prefs),
      secretStoreProvider.overrideWithValue(InMemorySecretStore()),
      initialProfilesStateProvider.overrideWithValue(initial),
      browserSignInProvider.overrideWithValue(auth.signIn()),
      if (ledger != null)
        // The real client for the active profile (auth interceptor included),
        // answered by the fake ledger only with a valid session token.
        zhangApiClientProvider.overrideWith((ref) {
          final profile = ref.watch(activeProfileProvider)!;
          final inner = ledger.adapter.handler;
          final client = ZhangApiClient(profile)
            ..dio.httpClientAdapter = FakeAdapter((o) {
              final header = o.headers['Authorization'];
              final ok = header is String && auth.valid.contains(header.replaceFirst('Bearer ', ''));
              return ok ? inner(o) : jsonResponse({'message': 'unauthorized'}, status: 401);
            });
          ref.onDispose(client.close);
          return client;
        }),
    ],
    retry: (_, _) => null,
  );
  addTearDown(container.dispose);
  await tester.pumpWidget(UncontrolledProviderScope(container: container, child: const ZhangApp()));
  await tester.pumpAndSettle();
  return container;
}

ServerProfile _session(String token, {DateTime? expires}) => ServerProfile(
  id: 'p1',
  name: 'Passkey ledger',
  baseUrl: _base,
  authType: AuthType.session,
  sessionToken: token,
  sessionExpiresAt: expires ?? DateTime.now().toUtc().add(const Duration(days: 30)),
  sessionUser: 'demo',
);

Future<void> _tapVisible(WidgetTester tester, Finder finder) async {
  await tester.ensureVisible(finder);
  await tester.pumpAndSettle();
  await tester.tap(finder);
  await tester.pumpAndSettle();
}

void main() {
  setUp(() {
    PackageInfo.setMockInitialValues(
      appName: 'zhang_app',
      packageName: 'me.kilerd.zhang_app',
      version: '1.0.0',
      buildNumber: '1',
      buildSignature: '',
    );
  });

  testWidgets('edit server → "Browser sign-in": status check, sign-in, then save with a Bearer session', (
    tester,
  ) async {
    final auth = _FakeAuthServer()..appLogin = false;
    const basic = ServerProfile(
      id: 'p1',
      name: 'Passkey ledger',
      baseUrl: _base,
      authType: AuthType.basic,
      basicUsername: 'demo',
      basicPassword: 'secret',
    );
    final container = await _pump(tester, auth: auth, initial: const ProfilesState(profiles: [basic], activeId: 'p1'));
    await tester.tap(find.byTooltip('Settings'));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('settings.profileMenu.p1')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Edit'));
    await tester.pumpAndSettle();

    await _tapVisible(tester, find.byKey(const Key('profileForm.authType')));
    await tester.tap(find.text('Browser sign-in (passkey or password)').last);
    await tester.pumpAndSettle();
    expect(find.text('Sign in with a passkey or password in the browser'), findsOneWidget);
    expect(find.byKey(const Key('profileForm.username')), findsNothing);
    expect(find.byKey(const Key('profileForm.signInFirst')), findsOneWidget);
    // Save and Test need a session first.
    expect(tester.widget<FilledButton>(find.byKey(const Key('profileForm.submit'))).onPressed, isNull);
    expect(tester.widget<OutlinedButton>(find.byKey(const Key('profileForm.test'))).onPressed, isNull);

    // (b) sign-in on, but no app handoff (zhang before PR #786).
    await _tapVisible(tester, find.byKey(const Key('profileForm.signIn')));
    expect(find.byKey(const Key('profileForm.signInError')), findsOneWidget);
    expect(
      find.text('This server does not support app sign-in yet; upgrade zhang (PR #786).'),
      findsOneWidget,
    );
    expect(auth.launched, isEmpty);

    // (c) no sign-in on the server at all.
    auth
      ..appLogin = true
      ..enabled = false;
    await _tapVisible(tester, find.byKey(const Key('profileForm.signIn')));
    expect(find.text('This server does not require sign-in. Choose “No sign-in” instead.'), findsOneWidget);
    expect(auth.launched, isEmpty);

    // (a) handoff supported: browser → callback → exchange.
    auth.enabled = true;
    await _tapVisible(tester, find.byKey(const Key('profileForm.signIn')));
    expect(auth.launched, ['$_base/login?return_to=zhang-app%3A%2F%2Fauth%2Fcallback']);
    expect(find.byKey(const Key('profileForm.signedIn')), findsOneWidget);
    expect(find.text('Signed in as demo, valid until Nov 9, 2026'), findsOneWidget);
    expect(tester.widget<FilledButton>(find.byKey(const Key('profileForm.submit'))).onPressed, isNotNull);

    // Changing the URL drops the session (it belongs to that server).
    await tester.enterText(find.byKey(const Key('profileForm.url')), 'http://127.0.0.1:18101');
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('profileForm.signedIn')), findsNothing);
    expect(tester.widget<FilledButton>(find.byKey(const Key('profileForm.submit'))).onPressed, isNull);
    await tester.enterText(find.byKey(const Key('profileForm.url')), _base);
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('profileForm.signedIn')), findsOneWidget);

    await _tapVisible(tester, find.byKey(const Key('profileForm.submit')));
    final active = container.read(activeProfileProvider)!;
    expect(active.authType, AuthType.session);
    expect(active.sessionUser, 'demo');
    expect(active.sessionExpiresAt, DateTime.utc(2026, 11, 9, 3, 7, 29));
    expect(active.authHeaders(), {'Authorization': 'Bearer tok1.sig'});
    expect(active.basicPassword, isNull);
  });

  testWidgets('home: 401 on a session profile → "Sign in again" stores a new session and reloads', (tester) async {
    final auth = _FakeAuthServer();
    final ledger = FakeZhangServer(journals: [expenseJson('a', '2023-09-01T10:00:00', payee: 'Bakery')]);
    final container = await _pump(
      tester,
      auth: auth,
      ledger: ledger,
      initial: ProfilesState(profiles: [_session('expired.sig')], activeId: 'p1'),
    );
    expect(find.byKey(const Key('home.authBanner')), findsOneWidget);
    expect(find.text('Your sign-in has ended. Sign in again in the browser.'), findsOneWidget);
    expect(find.text('Bakery'), findsNothing);

    await tester.tap(find.byKey(const Key('home.signInAgain')));
    await tester.pumpAndSettle();
    expect(auth.launched, hasLength(1));
    expect(container.read(activeProfileProvider)!.sessionToken, 'tok1.sig');
    expect(find.text('Signed in as demo'), findsOneWidget);
    expect(find.byKey(const Key('home.authBanner')), findsNothing);
    expect(find.text('Bakery'), findsOneWidget);
  });

  testWidgets('home: warns when the session ends within 3 days', (tester) async {
    final auth = _FakeAuthServer()..valid.add('ok.sig');
    final ledger = FakeZhangServer(journals: []);
    await _pump(
      tester,
      auth: auth,
      ledger: ledger,
      initial: ProfilesState(
        profiles: [_session('ok.sig', expires: DateTime.now().toUtc().add(const Duration(days: 2)))],
        activeId: 'p1',
      ),
    );
    expect(find.byKey(const Key('home.authBanner')), findsNothing);
    expect(find.byKey(const Key('home.sessionExpiringBanner')), findsOneWidget);
    expect(find.textContaining('Your sign-in expires on'), findsOneWidget);
    expect(find.byKey(const Key('home.signInAgain')), findsOneWidget);
  });

  testWidgets('settings: session details, then "Sign out" clears the token and Home asks to sign in', (tester) async {
    final auth = _FakeAuthServer()..valid.add('ok.sig');
    final ledger = FakeZhangServer(journals: []);
    final container = await _pump(
      tester,
      auth: auth,
      ledger: ledger,
      initial: ProfilesState(
        profiles: [_session('ok.sig', expires: DateTime.utc(2026, 11, 9, 3, 7, 29))],
        activeId: 'p1',
      ),
    );
    expect(find.byKey(const Key('home.authBanner')), findsNothing);
    await tester.tap(find.byTooltip('Settings'));
    await tester.pumpAndSettle();
    expect(find.text('$_base · Browser\ndemo · until Nov 9, 2026'), findsOneWidget);

    await tester.tap(find.byKey(const Key('settings.profileMenu.p1')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('settings.signOut.p1')));
    await tester.pumpAndSettle();
    final profile = container.read(activeProfileProvider)!;
    expect(profile.hasSession, isFalse);
    expect(profile.authType, AuthType.session);
    expect(auth.logouts, ['Bearer ok.sig']);
    expect(find.text('Signed out of Passkey ledger'), findsOneWidget);
    expect(find.text('$_base · Browser\nNot signed in'), findsOneWidget);

    await tester.tap(find.byType(BackButton));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('home.authBanner')), findsOneWidget);
    expect(find.byKey(const Key('home.signInAgain')), findsOneWidget);
  });
}
