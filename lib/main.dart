import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:shared_preferences/shared_preferences.dart';

import 'app.dart';
import 'core/utils/shared_files.dart';
import 'data/api/api_exception.dart';
import 'data/profiles/profile_providers.dart';
import 'data/profiles/profile_repository.dart';
import 'data/profiles/secret_store.dart';
import 'data/repositories/ledger_events.dart';
import 'ledger_session.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  // Documents shared during an earlier run (the app was killed meanwhile).
  unawaited(clearSharedDocuments());
  runApp(await bootstrap());
}

/// Loads persisted profiles before the first frame (so the router can decide
/// synchronously between onboarding and the main shell) and returns the root
/// widget: the app in a [LedgerSessionHost] (one provider container per
/// active profile). Also used by integration tests, which may add
/// [overrides] (e.g. `webAuthLauncherProvider` instead of a browser).
Future<Widget> bootstrap({List<Override> overrides = const []}) async {
  final prefs = await SharedPreferences.getInstance();
  final secrets = SecureSecretStore();
  final initial = await ProfileRepository(prefs: prefs, secrets: secrets).load();
  return LedgerSessionHost(
    initialProfiles: initial,
    overrides: [
      sharedPreferencesProvider.overrideWithValue(prefs),
      secretStoreProvider.overrideWithValue(secrets),
      // Refresh on the server's SSE `Reload` events.
      ledgerEventsEnabledProvider.overrideWithValue(true),
      ...overrides,
    ],
    retry: zhangRetryPolicy,
    child: const ZhangApp(),
  );
}

/// Riverpod retries failing providers by default. Only retry transient
/// network failures (max 2×); auth/parse/server errors are shown at once.
Duration? zhangRetryPolicy(int retryCount, Object error) {
  if (retryCount >= 2) return null;
  if (error is ApiNetworkError && error.kind != NetworkErrorKind.cancelled) {
    return Duration(milliseconds: 500 * (retryCount + 1));
  }
  return null;
}
