import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:zhang_app/data/api/api_exception.dart';
import 'package:zhang_app/data/api/zhang_api_client.dart';
import 'package:zhang_app/data/models/info.dart';
import 'package:zhang_app/data/profiles/profile_providers.dart';
import 'package:zhang_app/data/profiles/profile_repository.dart';
import 'package:zhang_app/data/profiles/secret_store.dart';
import 'package:zhang_app/data/profiles/server_profile.dart';
import 'package:zhang_app/main.dart' show zhangRetryPolicy;

import 'helpers/app_host.dart';

class _FakeTester extends ConnectionTester {
  _FakeTester(this.handler);

  final Future<ServerInfo> Function(ServerProfile profile) handler;
  final tested = <ServerProfile>[];

  @override
  Future<ServerInfo> test(ServerProfile profile) {
    tested.add(profile);
    return handler(profile);
  }
}

/// The app as `bootstrap()` builds it (ledger sessions included).
Future<AppHost> _pumpApp(
  WidgetTester tester, {
  ProfilesState initial = const ProfilesState(),
  _FakeTester? connectionTester,
}) async {
  // Phone-sized logical screen (390 x 844).
  tester.view.physicalSize = const Size(1170, 2532);
  tester.view.devicePixelRatio = 3;
  addTearDown(tester.view.reset);
  SharedPreferences.setMockInitialValues({});
  final prefs = await SharedPreferences.getInstance();
  return pumpAppHost(
    tester,
    initial: initial,
    overrides: [
      sharedPreferencesProvider.overrideWithValue(prefs),
      secretStoreProvider.overrideWithValue(InMemorySecretStore()),
      if (connectionTester != null) connectionTesterProvider.overrideWithValue(connectionTester),
    ],
    // Same policy as bootstrap(): no Riverpod default retries (and their
    // pending timers) for failing requests.
    retry: zhangRetryPolicy,
  );
}

const _profile = ServerProfile(
  id: 'p1',
  name: 'Family',
  baseUrl: 'http://127.0.0.1:18011',
  authType: AuthType.basic,
  basicUsername: 'demo',
  basicPassword: 'secret',
);

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

  testWidgets('without a profile the app shows the welcome page of the setup wizard', (tester) async {
    await _pumpApp(tester);
    expect(find.byKey(const Key('welcome.connect')), findsOneWidget);
    expect(find.byKey(const Key('welcome.demo')), findsOneWidget);
  });

  testWidgets('settings: "Add server" opens the wizard at step 1 (no welcome); back returns', (tester) async {
    await _pumpApp(tester, initial: const ProfilesState(profiles: [_profile], activeId: 'p1'));
    await tester.tap(find.byTooltip('Settings'));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('settings.addServer')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('welcome.connect')), findsNothing);
    expect(find.text('Step 1 of 3'), findsOneWidget);
    expect(find.byKey(const Key('setup.url')), findsOneWidget);
    await tester.tap(find.byKey(const Key('setup.back')));
    await tester.pumpAndSettle();
    expect(find.text('Servers'), findsOneWidget);
  });

  testWidgets('edit server: sections, sign-in method menu, test connection (ok, 401), save', (tester) async {
    var fail = false;
    final fake = _FakeTester((p) async {
      if (fail) throw const ApiUnauthorized();
      return const ServerInfo(title: 'My Accounting', version: '0.1.0', buildDate: '2026-10-02', format: 'zhang');
    });
    const open = ServerProfile(id: 'p1', name: 'Family', baseUrl: 'http://127.0.0.1:18011');
    final app = await _pumpApp(
      tester,
      initial: const ProfilesState(profiles: [open], activeId: 'p1'),
      connectionTester: fake,
    );
    await tester.tap(find.byTooltip('Settings'));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('settings.profileMenu.p1')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Edit'));
    await tester.pumpAndSettle();
    expect(find.text('Edit server'), findsOneWidget);
    for (final section in ['Server', 'Sign-in', 'Appearance']) {
      expect(find.text(section), findsWidgets);
    }
    expect(find.text('No sign-in'), findsWidgets);

    // The sign-in method menu (replaces the five segments that overflowed).
    await tester.tap(find.byKey(const Key('profileForm.authType')));
    await tester.pumpAndSettle();
    for (final label in [
      'Username and password',
      'Browser sign-in (passkey or password)',
      'Bearer token (reverse proxy)',
    ]) {
      expect(find.text(label), findsWidgets);
    }
    expect(find.text('Custom headers (reverse proxy)'), findsNothing, reason: 'headers are not a method any more');
    await tester.tap(find.text('Username and password').last);
    await tester.pumpAndSettle();
    await tester.enterText(find.byKey(const Key('profileForm.username')), 'demo');
    await tester.enterText(find.byKey(const Key('profileForm.password')), 'secret');

    await tester.ensureVisible(find.byKey(const Key('profileForm.test')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('profileForm.test')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('profileForm.testOk')), findsOneWidget);
    expect(find.text('Connected to “My Accounting”'), findsOneWidget);
    expect(fake.tested.last.authHeaders()['Authorization'], startsWith('Basic '));

    fail = true;
    await tester.tap(find.byKey(const Key('profileForm.test')));
    await tester.pumpAndSettle();
    expect(find.text('Authentication failed (401). Check your credentials.'), findsOneWidget);

    await tester.ensureVisible(find.byKey(const Key('profileForm.submit')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('profileForm.submit')));
    await tester.pumpAndSettle();
    final active = app.container.read(activeProfileProvider)!;
    expect(active.authType, AuthType.basic);
    expect(active.basicPassword, 'secret');
    expect(active.plainHttpAcknowledged, isFalse, reason: 'loopback: not asked');
    expect(find.text('Servers'), findsOneWidget);
  });

  testWidgets('edit server: Basic + custom headers are saved and tested together', (tester) async {
    final fake = _FakeTester(
      (p) async => const ServerInfo(title: 'My Accounting', version: '0.2.0', buildDate: '2026-11-21', format: 'zhang'),
    );
    const open = ServerProfile(id: 'p1', name: 'Family', baseUrl: 'https://ledger.example.com');
    final app = await _pumpApp(
      tester,
      initial: const ProfilesState(profiles: [open], activeId: 'p1'),
      connectionTester: fake,
    );
    await tester.tap(find.byTooltip('Settings'));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('settings.profileMenu.p1')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Edit'));
    await tester.pumpAndSettle();
    expect(find.text('Custom headers'), findsOneWidget, reason: 'shown for every sign-in method');
    expect(find.byKey(const Key('profileForm.headerName.0')), findsNothing, reason: 'no empty row by default');

    await tester.tap(find.byKey(const Key('profileForm.authType')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Username and password').last);
    await tester.pumpAndSettle();
    await tester.enterText(find.byKey(const Key('profileForm.username')), 'demo');
    await tester.enterText(find.byKey(const Key('profileForm.password')), 'secret');
    for (final (i, name, value) in [(0, 'CF-Access-Client-Id', 'cf-id'), (1, 'Authorization', 'Token mine')]) {
      await tester.ensureVisible(find.byKey(const Key('profileForm.addHeader')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('profileForm.addHeader')));
      await tester.pumpAndSettle();
      await tester.enterText(find.byKey(Key('profileForm.headerName.$i')), name);
      await tester.enterText(find.byKey(Key('profileForm.headerValue.$i')), value);
    }

    // A custom Authorization would compete with Basic: refused, nothing sent.
    await tester.ensureVisible(find.byKey(const Key('profileForm.test')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('profileForm.test')));
    await tester.pumpAndSettle();
    expect(find.text('The sign-in method sets Authorization. To send your own, choose “No sign-in”.'), findsOneWidget);
    expect(fake.tested, isEmpty);
    await tester.ensureVisible(find.byKey(const Key('profileForm.submit')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('profileForm.submit')));
    await tester.pumpAndSettle();
    expect(app.container.read(activeProfileProvider)!.authType, AuthType.none, reason: 'not saved');

    await tester.ensureVisible(find.byKey(const Key('profileForm.removeHeader.1')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('profileForm.removeHeader.1')));
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.byKey(const Key('profileForm.test')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('profileForm.test')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('profileForm.testOk')), findsOneWidget);
    expect(fake.tested.single.authHeaders(), {
      'CF-Access-Client-Id': 'cf-id',
      'Authorization': 'Basic ${base64Encode(utf8.encode('demo:secret'))}',
    });

    await tester.ensureVisible(find.byKey(const Key('profileForm.submit')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('profileForm.submit')));
    await tester.pumpAndSettle();
    final active = app.container.read(activeProfileProvider)!;
    expect(active.authType, AuthType.basic);
    expect(active.customHeaders, {'CF-Access-Client-Id': 'cf-id'});
    expect(find.text('https://ledger.example.com · Basic + Headers'), findsOneWidget);
  });

  testWidgets('edit server: credentials over plain http need an acknowledgement, stored per profile', (tester) async {
    const open = ServerProfile(id: 'p1', name: 'NAS', baseUrl: 'http://192.168.1.2:8000');
    final app = await _pumpApp(tester, initial: const ProfilesState(profiles: [open], activeId: 'p1'));
    expect(find.byKey(const Key('ledger.plainHttp')), findsNothing, reason: 'no credentials yet');
    Future<void> openEdit() async {
      await tester.tap(find.byKey(const Key('settings.profileMenu.p1')));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Edit'));
      await tester.pumpAndSettle();
    }

    VoidCallback? onSubmit() => tester.widget<FilledButton>(find.byKey(const Key('profileForm.submit'))).onPressed;
    VoidCallback? onTest() => tester.widget<OutlinedButton>(find.byKey(const Key('profileForm.test'))).onPressed;
    bool? acked() => tester.widget<CheckboxListTile>(find.byKey(const Key('profileForm.plainHttpAck'))).value;

    await tester.tap(find.byTooltip('Settings'));
    await tester.pumpAndSettle();
    await openEdit();
    expect(find.byKey(const Key('profileForm.plainHttp')), findsNothing);

    await tester.tap(find.byKey(const Key('profileForm.authType')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Username and password').last);
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('profileForm.plainHttp')), findsOneWidget);
    expect(find.text('Not encrypted: this server uses http://'), findsOneWidget);
    expect(onSubmit(), isNull);
    expect(onTest(), isNull, reason: 'testing sends the credentials too');

    await tester.enterText(find.byKey(const Key('profileForm.username')), 'demo');
    await tester.enterText(find.byKey(const Key('profileForm.password')), 'secret');
    await tester.ensureVisible(find.byKey(const Key('profileForm.plainHttpAck')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('profileForm.plainHttpAck')));
    await tester.pumpAndSettle();
    expect(onSubmit(), isNotNull);
    expect(onTest(), isNotNull);
    await tester.ensureVisible(find.byKey(const Key('profileForm.submit')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('profileForm.submit')));
    await tester.pumpAndSettle();
    final active = app.container.read(activeProfileProvider)!;
    expect(active.authType, AuthType.basic);
    expect(active.plainHttpAcknowledged, isTrue);
    expect(find.text('http://192.168.1.2:8000 · Basic · Not encrypted (http)'), findsOneWidget);

    // Kept when editing again; another address asks again; https needs nothing.
    await openEdit();
    expect(acked(), isTrue);
    await tester.enterText(find.byKey(const Key('profileForm.url')), 'http://192.168.1.3:8000');
    await tester.pumpAndSettle();
    expect(acked(), isFalse);
    expect(onSubmit(), isNull);
    await tester.enterText(find.byKey(const Key('profileForm.url')), 'https://192.168.1.3:8000');
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('profileForm.plainHttp')), findsNothing);
    expect(onSubmit(), isNotNull);
    await tester.enterText(find.byKey(const Key('profileForm.url')), 'http://localhost:8000');
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('profileForm.plainHttp')), findsNothing, reason: 'loopback is exempt');
    await tester.enterText(find.byKey(const Key('profileForm.url')), 'http://192.168.1.2:8000');
    await tester.pumpAndSettle();
    expect(acked(), isTrue, reason: 'back to the acknowledged address');
  });

  testWidgets('edit server: custom headers alone over plain http need the acknowledgement too', (tester) async {
    const open = ServerProfile(id: 'p1', name: 'NAS', baseUrl: 'http://192.168.1.2:8000');
    final app = await _pumpApp(tester, initial: const ProfilesState(profiles: [open], activeId: 'p1'));
    await tester.tap(find.byTooltip('Settings'));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('settings.profileMenu.p1')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Edit'));
    await tester.pumpAndSettle();
    VoidCallback? onSubmit() => tester.widget<FilledButton>(find.byKey(const Key('profileForm.submit'))).onPressed;

    await tester.ensureVisible(find.byKey(const Key('profileForm.addHeader')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('profileForm.addHeader')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('profileForm.plainHttp')), findsNothing, reason: 'an empty row sends nothing');
    await tester.enterText(find.byKey(const Key('profileForm.headerName.0')), 'CF-Access-Client-Secret');
    await tester.enterText(find.byKey(const Key('profileForm.headerValue.0')), 'cf-secret');
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('profileForm.plainHttp')), findsOneWidget);
    expect(onSubmit(), isNull);

    await tester.ensureVisible(find.byKey(const Key('profileForm.plainHttpAck')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('profileForm.plainHttpAck')));
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.byKey(const Key('profileForm.submit')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('profileForm.submit')));
    await tester.pumpAndSettle();
    final active = app.container.read(activeProfileProvider)!;
    expect(active.authType, AuthType.none);
    expect(active.customHeaders, {'CF-Access-Client-Secret': 'cf-secret'});
    expect(active.plainHttpAcknowledged, isTrue);
    expect(find.text('http://192.168.1.2:8000 · Headers · Not encrypted (http)'), findsOneWidget);
  });

  testWidgets('the ledger title marks a profile whose credentials go over plain http', (tester) async {
    const lan = ServerProfile(
      id: 'p1',
      name: 'NAS',
      baseUrl: 'http://192.168.1.2:8000',
      authType: AuthType.basic,
      basicUsername: 'demo',
      basicPassword: 'secret',
      plainHttpAcknowledged: true,
    );
    await _pumpApp(tester, initial: const ProfilesState(profiles: [lan], activeId: 'p1'));
    expect(find.byKey(const Key('ledger.plainHttp')), findsOneWidget);
    expect(find.byTooltip('Not encrypted (http)'), findsOneWidget);
  });

  testWidgets('shell: tabs switch and FAB opens /transactions/new', (tester) async {
    await _pumpApp(tester, initial: const ProfilesState(profiles: [_profile], activeId: 'p1'));
    expect(find.text('Family'), findsOneWidget); // ActiveLedgerTitle in Home app bar
    expect(find.byKey(const Key('ledger.plainHttp')), findsNothing, reason: 'http to 127.0.0.1 stays on the device');

    await tester.tap(find.text('Accounts'));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('accounts.search')), findsOneWidget); // real Accounts screen

    await tester.tap(find.byKey(const Key('shell.newTransaction')));
    await tester.pumpAndSettle();
    expect(find.text('New transaction'), findsWidgets);
  });

  testWidgets('settings: switch profile and delete the last one → onboarding', (tester) async {
    const second = ServerProfile(id: 'p2', name: 'Work', baseUrl: 'https://work.example.com');
    final app = await _pumpApp(
      tester,
      initial: const ProfilesState(profiles: [_profile, second], activeId: 'p1'),
      connectionTester: _FakeTester((_) async => throw const ApiNetworkError(NetworkErrorKind.connection, 'x')),
    );
    await tester.tap(find.byTooltip('Settings'));
    await tester.pumpAndSettle();
    expect(find.text('Servers'), findsOneWidget);

    await tester.tap(find.text('Work'));
    await tester.pumpAndSettle();
    expect(app.container.read(activeProfileProvider)?.id, 'p2');

    for (final id in ['p1', 'p2']) {
      await tester.tap(find.byKey(Key('settings.profileMenu.$id')));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Delete').last);
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(FilledButton, 'Delete'));
      await tester.pumpAndSettle();
    }
    expect(app.container.read(profilesProvider).profiles, isEmpty);
    expect(find.byKey(const Key('welcome.connect')), findsOneWidget);
  });

  test('ProfilesController.save activates the first profile', () async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    final container = ProviderContainer(
      overrides: [
        sharedPreferencesProvider.overrideWithValue(prefs),
        secretStoreProvider.overrideWithValue(InMemorySecretStore()),
      ],
      retry: zhangRetryPolicy,
    );
    addTearDown(container.dispose);
    await container.read(profilesProvider.notifier).save(_profile);
    expect(container.read(activeProfileProvider), _profile);
    expect(prefs.getString(ProfileRepository.activeKey), 'p1');
  });
}
