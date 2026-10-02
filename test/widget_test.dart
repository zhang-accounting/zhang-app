import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:zhang_app/app.dart';
import 'package:zhang_app/data/api/api_exception.dart';
import 'package:zhang_app/data/api/zhang_api_client.dart';
import 'package:zhang_app/data/models/info.dart';
import 'package:zhang_app/data/profiles/profile_providers.dart';
import 'package:zhang_app/data/profiles/profile_repository.dart';
import 'package:zhang_app/data/profiles/secret_store.dart';
import 'package:zhang_app/data/profiles/server_profile.dart';

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

Future<ProviderContainer> _pumpApp(
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
  final container = ProviderContainer(
    overrides: [
      sharedPreferencesProvider.overrideWithValue(prefs),
      secretStoreProvider.overrideWithValue(InMemorySecretStore()),
      initialProfilesStateProvider.overrideWithValue(initial),
      if (connectionTester != null) connectionTesterProvider.overrideWithValue(connectionTester),
    ],
  );
  addTearDown(container.dispose);
  await tester.pumpWidget(
    UncontrolledProviderScope(container: container, child: const ZhangApp()),
  );
  await tester.pumpAndSettle();
  return container;
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

  testWidgets('without a profile the app shows onboarding', (tester) async {
    await _pumpApp(tester);
    expect(find.text('Connect to your zhang server'), findsOneWidget);
    expect(find.byKey(const Key('profileForm.url')), findsOneWidget);
  });

  testWidgets('onboarding: test connection success, 401, then save → home', (tester) async {
    var fail = false;
    final fake = _FakeTester((p) async {
      if (fail) throw const ApiUnauthorized();
      return const ServerInfo(title: 'My Accounting', version: '0.1.0', buildDate: '2026-10-02');
    });
    final container = await _pumpApp(tester, connectionTester: fake);

    await tester.enterText(find.byKey(const Key('profileForm.name')), 'Family');
    await tester.enterText(find.byKey(const Key('profileForm.url')), '127.0.0.1:18011/api/');
    await tester.tap(find.text('Basic'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byKey(const Key('profileForm.username')), 'demo');
    await tester.enterText(find.byKey(const Key('profileForm.password')), 'secret');

    await tester.ensureVisible(find.byKey(const Key('profileForm.test')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('profileForm.test')));
    await tester.pumpAndSettle();
    expect(find.text('Connected to “My Accounting”'), findsOneWidget);
    expect(fake.tested.last.baseUrl, 'https://127.0.0.1:18011');
    expect(fake.tested.last.authHeaders()['Authorization'], startsWith('Basic '));

    fail = true;
    await tester.tap(find.byKey(const Key('profileForm.test')));
    await tester.pumpAndSettle();
    expect(find.text('Authentication failed (401). Check your credentials.'), findsOneWidget);

    await tester.ensureVisible(find.byKey(const Key('profileForm.submit')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('profileForm.submit')));
    await tester.pumpAndSettle();

    final active = container.read(activeProfileProvider);
    expect(active?.name, 'Family');
    expect(active?.basicPassword, 'secret');
    // Main shell with four tabs + the centre FAB.
    expect(find.text('Home'), findsWidgets);
    expect(find.text('Journal'), findsOneWidget);
    expect(find.text('Reports'), findsOneWidget);
    expect(find.text('Accounts'), findsOneWidget);
    expect(find.byKey(const Key('shell.newTransaction')), findsOneWidget);
  });

  testWidgets('shell: tabs switch and FAB opens /transactions/new', (tester) async {
    await _pumpApp(tester, initial: const ProfilesState(profiles: [_profile], activeId: 'p1'));
    expect(find.text('Family'), findsOneWidget); // ActiveLedgerTitle in Home app bar

    await tester.tap(find.text('Accounts'));
    await tester.pumpAndSettle();
    expect(find.text('Ledger: Family'), findsOneWidget);

    await tester.tap(find.byKey(const Key('shell.newTransaction')));
    await tester.pumpAndSettle();
    expect(find.text('New transaction'), findsWidgets);
  });

  testWidgets('settings: switch profile and delete the last one → onboarding', (tester) async {
    const second = ServerProfile(id: 'p2', name: 'Work', baseUrl: 'https://work.example.com');
    final container = await _pumpApp(
      tester,
      initial: const ProfilesState(profiles: [_profile, second], activeId: 'p1'),
      connectionTester: _FakeTester((_) async => throw const ApiNetworkError(NetworkErrorKind.connection, 'x')),
    );
    await tester.tap(find.byTooltip('Settings'));
    await tester.pumpAndSettle();
    expect(find.text('Servers'), findsOneWidget);

    await tester.tap(find.text('Work'));
    await tester.pumpAndSettle();
    expect(container.read(activeProfileProvider)?.id, 'p2');

    for (final id in ['p1', 'p2']) {
      await tester.tap(find.byKey(Key('settings.profileMenu.$id')));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Delete').last);
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(FilledButton, 'Delete'));
      await tester.pumpAndSettle();
    }
    expect(container.read(profilesProvider).profiles, isEmpty);
    expect(find.text('Connect to your zhang server'), findsOneWidget);
  });

  test('ProfilesController.save activates the first profile', () async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    final container = ProviderContainer(
      overrides: [
        sharedPreferencesProvider.overrideWithValue(prefs),
        secretStoreProvider.overrideWithValue(InMemorySecretStore()),
      ],
    );
    addTearDown(container.dispose);
    await container.read(profilesProvider.notifier).save(_profile);
    expect(container.read(activeProfileProvider), _profile);
    expect(prefs.getString(ProfileRepository.activeKey), 'p1');
  });
}
