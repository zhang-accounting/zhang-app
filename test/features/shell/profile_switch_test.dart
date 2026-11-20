import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:zhang_app/data/api/api_exception.dart';
import 'package:zhang_app/data/api/zhang_api_client.dart';
import 'package:zhang_app/data/profiles/profile_providers.dart';
import 'package:zhang_app/data/profiles/profile_repository.dart';
import 'package:zhang_app/data/profiles/secret_store.dart';
import 'package:zhang_app/data/profiles/server_profile.dart';
import 'package:zhang_app/data/repositories/repositories.dart';
import 'package:zhang_app/features/account_picker/account_picker_data.dart';
import 'package:zhang_app/ledger_session.dart';

import '../../helpers/app_host.dart';
import '../../helpers/builtin_fake.dart';
import '../../helpers/fake_adapter.dart';
import '../../helpers/fixtures.dart';
import '../accounts/ledger_app_harness.dart' show accountJson, data;
import '../journals/journal_test_utils.dart';

const _family = ServerProfile(id: 'p1', name: 'Family', baseUrl: 'http://127.0.0.1:18101');
const _work = ServerProfile(id: 'p2', name: 'Work', baseUrl: 'http://127.0.0.1:18102');
const _old = ServerProfile(id: 'p3', name: 'Attic', baseUrl: 'http://127.0.0.1:18103');

/// The version probes, the only requests a server may get before it passed
/// the version gate.
const _probes = {'/api/info', '/api/auth/status'};

/// One fake zhang server per profile: its own accounts and payee, a request
/// log, a hold on `/api/accounts` and an SSE stream.
class _Server {
  _Server({required this.accounts, required this.payee, this.supported = true});

  final List<String> accounts;
  final String payee;
  final bool supported;
  final builtins = FakeBuiltins();

  /// While set, `/api/accounts` answers only once it completes.
  Completer<void>? holdAccounts;

  final sse = <StreamController<Uint8List>>[];

  late final adapter = FakeAdapter(_handle);

  List<String> get paths => [for (final r in adapter.requests) r.uri.path];

  Future<ResponseBody> _handle(RequestOptions o) async {
    final path = Uri.decodeComponent(o.uri.path);
    if (path == '/api/info') {
      return supported
          ? jsonResponse(fixture('info.json'))
          : data({'title': 'Attic', 'version': '0.1.0', 'build_date': '2026-10-02'});
    }
    if (!supported) return jsonResponse({'message': 'no route ${o.method} $path'}, status: 404);
    if (path == '/api/sse') {
      final controller = StreamController<Uint8List>();
      sse.add(controller);
      controller.add(Uint8List.fromList(utf8.encode('data: {"type":"Connected"}\n\n')));
      return ResponseBody(
        controller.stream,
        200,
        headers: {
          Headers.contentTypeHeader: ['text/event-stream'],
        },
      );
    }
    if (path == '/api/accounts') {
      await holdAccounts?.future;
      return data([for (final a in accounts) accountJson(a, {'CNY': '0'})]);
    }
    if (path == '/api/journals') {
      return jsonResponse(pageJson([expenseJson('${payee}1', '2023-09-01T10:00:00', payee: payee)], page: 1, size: 10, total: 1));
    }
    if (path == '/api/options') return jsonResponse(fixture('options.json'));
    if (path == '/api/commodities') return jsonResponse(fixture('commodities.json'));
    if (path == '/api/transactions/preview') return jsonResponse(fixture('transaction_preview.json'));
    if (path == '/api/transactions') return emptyResponse(201);
    return builtins.handle(o) ?? jsonResponse({'message': 'not found'}, status: 404);
  }
}

late Map<String, _Server> _servers;

/// The app as `bootstrap()` builds it – in a `LedgerSessionHost` – with
/// [active] active and each profile's real, gated client answered by its
/// fake server.
Future<AppHost> _pumpHost(
  WidgetTester tester, {
  String active = 'p1',
  bool events = false,
  SecretStore? secrets,
}) async {
  tester.view.physicalSize = const Size(1170, 2532);
  tester.view.devicePixelRatio = 3;
  addTearDown(tester.view.reset);
  SharedPreferences.setMockInitialValues({});
  final prefs = await SharedPreferences.getInstance();
  _servers = {
    'p1': _Server(accounts: ['Assets:Cash', 'Expenses:Food', 'Expenses:Fun'], payee: 'Family bakery'),
    'p2': _Server(accounts: ['Assets:Bank', 'Expenses:Office', 'Expenses:Travel'], payee: 'Work taxi'),
    'p3': _Server(accounts: const [], payee: '', supported: false),
  };
  return pumpAppHost(
    tester,
    initial: ProfilesState(profiles: const [_family, _work, _old], activeId: active),
    overrides: [
      sharedPreferencesProvider.overrideWithValue(prefs),
      secretStoreProvider.overrideWithValue(secrets ?? InMemorySecretStore()),
      if (events) ledgerEventsEnabledProvider.overrideWithValue(true),
      zhangApiClientProvider.overrideWith((ref) {
        final profile = ref.watch(activeProfileProvider)!;
        final client = ZhangApiClient(profile)..dio.httpClientAdapter = _servers[profile.id]!.adapter;
        return gatedClient(ref, client);
      }),
    ],
    retry: (_, _) => null,
  );
}

/// Pumps frames for [ms] (no pumpAndSettle while a spinner runs).
Future<void> _frames(WidgetTester tester, [int ms = 600]) async {
  for (var i = 0; i < ms ~/ 100; i++) {
    await tester.pump(const Duration(milliseconds: 100));
  }
}

/// Settings → tap [name] (switch), then back to the shell.
Future<void> _switchTo(WidgetTester tester, String name, {bool settle = true}) async {
  await tester.tap(find.byTooltip('Settings'));
  await tester.pumpAndSettle();
  await tester.tap(find.text(name));
  await _frames(tester);
  expect(find.text('Switched to $name'), findsOneWidget, reason: 'the Settings screen stays (snackbar)');
  await tester.pageBack();
  // Let the snackbar go (it would cover the keypad).
  await tester.pump(const Duration(seconds: 5));
  if (settle) {
    await tester.pumpAndSettle();
  } else {
    await _frames(tester);
  }
}

/// The error [future] fails with (fake time: pump until it is done).
Future<Object?> _errorOf(WidgetTester tester, Future<Object?> future) async {
  Object? error;
  var done = false;
  future.then<void>(
    (_) => done = true,
    onError: (Object e) {
      error = e;
      done = true;
    },
  );
  for (var i = 0; i < 20 && !done; i++) {
    await tester.pump(const Duration(milliseconds: 50));
  }
  expect(done, isTrue);
  return error;
}

/// Holds `delete` until [hold] completes.
class _SlowSecrets extends InMemorySecretStore {
  Completer<void>? hold;

  @override
  Future<void> delete(String key) async {
    await hold?.future;
    return super.delete(key);
  }
}

/// Bumps the ledger revision while it builds when [bump] is set – what
/// flutter_riverpod's debug check must report.
class _BumpWhileBuilding extends ConsumerWidget {
  const _BumpWhileBuilding();

  static var bump = false;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    ref.watch(ledgerRevisionProvider);
    if (bump) ref.read(ledgerRevisionProvider.notifier).bump();
    return const SizedBox();
  }
}

bool _enabled(WidgetTester tester, String key) =>
    tester.widget<InkWell>(find.descendant(of: find.byKey(Key(key)), matching: find.byType(InkWell))).onTap != null;

void main() {
  testWidgets('switch while the new ledger loads: no old accounts shown, nothing can be saved', (tester) async {
    final app = await _pumpHost(tester);
    expect(find.text('Family bakery'), findsOneWidget);
    // The record flow has the Family accounts cached.
    await tester.tap(find.byKey(const Key('shell.newTransaction')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('add.category.Expenses:Food')), findsOneWidget);
    await tester.tap(find.byKey(const Key('add.close')));
    await tester.pumpAndSettle();
    final family = _servers['p1']!;
    final familyRequests = family.adapter.requests.length;

    final work = _servers['p2']!..holdAccounts = Completer<void>();
    await _switchTo(tester, 'Work');
    expect(find.text('Work taxi'), findsOneWidget);
    expect(find.text('Family bakery'), findsNothing);

    // The Work accounts are still loading: the Family ones must not show
    // up, and nothing can be saved.
    await tester.tap(find.byKey(const Key('shell.newTransaction')));
    await _frames(tester);
    expect(work.paths, contains('/api/accounts'));
    expect(app.container.read(pickerAccountsProvider).value, isNull, reason: 'no previous value');
    for (final name in ['Expenses:Food', 'Expenses:Fun', 'Expenses:Office']) {
      expect(find.byKey(Key('add.category.$name')), findsNothing);
    }
    expect(find.text('Food'), findsNothing);
    for (final k in ['1', '2']) {
      await tester.tap(find.byKey(Key('add.key.$k')));
      await tester.pump();
    }
    expect(_enabled(tester, 'add.key.save'), isFalse);
    await tester.tap(find.byKey(const Key('add.key.save')));
    await _frames(tester);

    work.holdAccounts!.complete();
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('add.category.Expenses:Office')), findsOneWidget);
    expect(find.byKey(const Key('add.category.Expenses:Food')), findsNothing);
    for (final s in _servers.values) {
      expect(s.paths.where((p) => p.startsWith('/api/transactions')), isEmpty);
    }
    expect(family.adapter.requests, hasLength(familyRequests), reason: 'nothing more to the previous server');
  });

  testWidgets('switch to a zhang < 0.2 server: only the version probes, then "server too old"; back works', (
    tester,
  ) async {
    final app = await _pumpHost(tester, events: true);
    final family = _servers['p1']!;
    final attic = _servers['p3']!;
    expect(find.text('Family bakery'), findsOneWidget);
    expect(family.paths, contains('/api/sse'));
    final familyRequests = family.adapter.requests.length;

    await _switchTo(tester, 'Attic');
    expect(find.byKey(const Key('shell.tooOld')), findsOneWidget);
    expect(find.byKey(const Key('shell.newTransaction')), findsNothing);
    expect(attic.paths, isNotEmpty);
    expect(attic.paths.toSet().difference(_probes), isEmpty, reason: '${attic.paths}');

    // Whatever asks next (a screen or provider added later) gets
    // ApiServerTooOld without a request.
    final container = app.container;
    for (final request in <Future<Object?> Function()>[
      () => container.read(pickerAccountsProvider.future),
      () => container.read(journalRepositoryProvider).list(const JournalQuery()),
      () => container.read(ledgerRepositoryProvider).errors(),
    ]) {
      expect(await _errorOf(tester, request()), isA<ApiServerTooOld>());
    }
    expect(attic.paths.toSet().difference(_probes), isEmpty, reason: '${attic.paths}');

    // The previous server's event stream is closed and never reopened.
    await tester.pump(const Duration(seconds: 5));
    expect(family.adapter.requests, hasLength(familyRequests));
    expect(family.sse.single.hasListener, isFalse);

    // Back to the v0.2 server: its data again, fresh session.
    final atticRequests = attic.adapter.requests.length;
    await _switchTo(tester, 'Family');
    expect(find.byKey(const Key('shell.tooOld')), findsNothing);
    expect(find.text('Family bakery'), findsOneWidget);
    expect(find.byKey(const Key('shell.newTransaction')), findsOneWidget);
    expect(family.adapter.requests.length, greaterThan(familyRequests));
    expect(family.sse, hasLength(2), reason: 'a new event stream for the new session');
    expect(attic.adapter.requests, hasLength(atticRequests));
    expect(app.container.read(activeProfileProvider), _family);
  });

  testWidgets('a session ends with its profile: editing the active profile starts a new one', (tester) async {
    final app = await _pumpHost(tester);
    final first = app.container;
    final edited = _family.copyWith(name: 'Home');
    await first.read(profilesProvider.notifier).save(edited);
    await tester.pumpAndSettle();
    final second = app.container;
    expect(identical(first, second), isFalse);
    expect(second.read(activeProfileProvider), edited);
    expect(second.read(profilesProvider).profiles.map((p) => p.name), ['Home', 'Work', 'Attic']);
    expect(find.text('Home'), findsWidgets);
    expect(find.text('Family bakery'), findsOneWidget);

    // Profiles that are not active stay in the session.
    await second.read(profilesProvider.notifier).save(_work.copyWith(name: 'Office'));
    await tester.pumpAndSettle();
    expect(identical(app.container, second), isTrue);
  });

  testWidgets('the "provider modified while building" check survives session switches', (tester) async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    await tester.pumpWidget(
      LedgerSessionHost(
        initialProfiles: const ProfilesState(profiles: [_family, _work], activeId: 'p1'),
        overrides: [
          sharedPreferencesProvider.overrideWithValue(prefs),
          secretStoreProvider.overrideWithValue(InMemorySecretStore()),
        ],
        child: const _BumpWhileBuilding(),
      ),
    );
    addTearDown(() => _BumpWhileBuilding.bump = false);
    for (var i = 0; i < 4; i++) {
      final probe = find.byType(_BumpWhileBuilding);
      final container = ProviderScope.containerOf(tester.element(probe));
      expect(container.read(activeProfileProvider), i.isEven ? _family : _work);
      _BumpWhileBuilding.bump = true;
      tester.element(probe).markNeedsBuild();
      await tester.pump();
      _BumpWhileBuilding.bump = false;
      expect(
        '${tester.takeException()}',
        contains('Tried to modify a provider while the widget tree was building'),
        reason: 'session ${i + 1}',
      );
      await container.read(profilesProvider.notifier).activate(i.isEven ? 'p2' : 'p1');
      await tester.pump();
    }
  });

  testWidgets('a profile change still running when its session ends lands in the next one', (tester) async {
    final secrets = _SlowSecrets();
    final app = await _pumpHost(tester, secrets: secrets);
    final first = app.container;
    secrets.hold = Completer<void>();
    final deleting = first.read(profilesProvider.notifier).delete('p3');
    await tester.pump();
    await first.read(profilesProvider.notifier).activate('p2');
    await tester.pumpAndSettle();
    expect(app.container.read(activeProfileProvider), _work);
    expect(identical(app.container, first), isFalse, reason: 'the first session has ended');

    secrets.hold!.complete();
    await tester.pumpAndSettle();
    await deleting;
    expect(app.container.read(profilesProvider).profiles, [_family, _work]);
    expect(app.container.read(profilesProvider).activeId, 'p2');
    expect(app.container.read(activeProfileProvider), _work);
  });
}
