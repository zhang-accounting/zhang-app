import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:zhang_app/app.dart';
import 'package:zhang_app/data/api/zhang_api_client.dart';
import 'package:zhang_app/data/profiles/profile_providers.dart';
import 'package:zhang_app/data/profiles/profile_repository.dart';
import 'package:zhang_app/data/profiles/secret_store.dart';
import 'package:zhang_app/data/profiles/server_profile.dart';
import 'package:zhang_app/features/stats/reports_providers.dart';

import '../../helpers/fake_adapter.dart';
import '../../helpers/fixtures.dart';

const testProfile = ServerProfile(id: 'p1', name: 'Family', baseUrl: 'http://127.0.0.1:18040');

/// `{"data": …}` envelope.
ResponseBody data(Object? json) => jsonResponse({'data': json});

/// An `/api/accounts` item.
Map<String, Object?> accountJson(
  String name,
  Map<String, String> detail, {
  String? calculated,
  bool closed = false,
  String? alias,
}) => {
  'name': name,
  'status': closed ? 'Close' : 'Open',
  'alias': alias,
  'amount': {
    'calculated': {'number': calculated ?? detail['CNY'] ?? '0', 'commodity': 'CNY'},
    'detail': detail,
  },
};

/// Default routes for the shared ledger endpoints (options, commodities).
ResponseBody? commonRoute(String path) => switch (path) {
  '/options' => jsonResponse(fixture('options.json')),
  '/commodities' => jsonResponse(fixture('commodities.json')),
  '/info' => jsonResponse(fixture('info.json')),
  _ => null,
};

/// Pumps the whole app with an active profile whose API calls are answered
/// by [handler] (called with the decoded request path, relative to `/api`).
Future<(ProviderContainer, FakeAdapter)> pumpLedgerApp(
  WidgetTester tester,
  ResponseBody Function(String path, RequestOptions options) handler, {
  DateTime? now,
  Map<String, Object?>? info,
}) async {
  tester.view.physicalSize = const Size(1170, 2532); // 390 x 844 logical
  tester.view.devicePixelRatio = 3;
  addTearDown(tester.view.reset);
  SharedPreferences.setMockInitialValues({});
  final prefs = await SharedPreferences.getInstance();
  final client = ZhangApiClient(testProfile);
  final adapter = FakeAdapter((o) {
    final path = Uri.decodeComponent(o.path);
    if (info != null && path == '/info') return jsonResponse(info);
    return commonRoute(path) ?? handler(path, o);
  });
  client.dio.httpClientAdapter = adapter;
  final container = ProviderContainer(
    overrides: [
      sharedPreferencesProvider.overrideWithValue(prefs),
      secretStoreProvider.overrideWithValue(InMemorySecretStore()),
      initialProfilesStateProvider.overrideWithValue(
        const ProfilesState(profiles: [testProfile], activeId: 'p1'),
      ),
      zhangApiClientProvider.overrideWithValue(client),
      if (now != null) reportsClockProvider.overrideWithValue(() => now),
    ],
    retry: (_, _) => null,
  );
  addTearDown(container.dispose);
  await tester.pumpWidget(UncontrolledProviderScope(container: container, child: const ZhangApp()));
  await tester.pumpAndSettle();
  return (container, adapter);
}
