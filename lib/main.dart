import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'app.dart';
import 'data/api/api_exception.dart';
import 'data/profiles/profile_providers.dart';
import 'data/profiles/profile_repository.dart';
import 'data/profiles/secret_store.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(await bootstrap());
}

/// Loads persisted profiles before the first frame (so the router can decide
/// synchronously between onboarding and the main shell) and returns the root
/// widget wrapped in a [ProviderScope]. Also used by integration tests.
Future<Widget> bootstrap() async {
  final prefs = await SharedPreferences.getInstance();
  final secrets = SecureSecretStore();
  final initial = await ProfileRepository(prefs: prefs, secrets: secrets).load();
  return ProviderScope(
    overrides: [
      sharedPreferencesProvider.overrideWithValue(prefs),
      secretStoreProvider.overrideWithValue(secrets),
      initialProfilesStateProvider.overrideWithValue(initial),
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
