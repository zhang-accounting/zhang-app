import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'profile_repository.dart';
import 'secret_store.dart';
import 'server_profile.dart';

/// The app's [SharedPreferences]. Overridden in `main()` (and in tests).
final sharedPreferencesProvider = Provider<SharedPreferences>(
  (ref) => throw UnimplementedError('sharedPreferencesProvider must be overridden'),
);

/// Secret storage (Keychain / Keystore). Override with [InMemorySecretStore]
/// in tests.
final secretStoreProvider = Provider<SecretStore>((ref) => SecureSecretStore());

final profileRepositoryProvider = Provider<ProfileRepository>(
  (ref) => ProfileRepository(
    prefs: ref.watch(sharedPreferencesProvider),
    secrets: ref.watch(secretStoreProvider),
  ),
);

/// Profiles loaded before `runApp` (so routing can decide synchronously
/// whether onboarding is needed). Overridden in `main()` / tests.
final initialProfilesStateProvider = Provider<ProfilesState>(
  (ref) => const ProfilesState(),
);

/// All profiles + the active id. Mutate through the notifier:
/// `ref.read(profilesProvider.notifier).save(...)`.
final profilesProvider = NotifierProvider<ProfilesController, ProfilesState>(
  ProfilesController.new,
);

/// The active server profile, or `null` (→ the router shows onboarding).
///
/// Everything server-related (`zhangApiClientProvider`, repositories, data
/// providers) depends on this, so switching profile refreshes all data.
final activeProfileProvider = Provider<ServerProfile?>(
  (ref) => ref.watch(profilesProvider.select((s) => s.active)),
);

class ProfilesController extends Notifier<ProfilesState> {
  ProfileRepository get _repo => ref.read(profileRepositoryProvider);

  @override
  ProfilesState build() => ref.watch(initialProfilesStateProvider);

  /// Creates or updates [profile]. A new profile becomes active when
  /// [activate] is true or when it is the first one.
  Future<void> save(ServerProfile profile, {bool activate = false}) async {
    await _repo.upsert(profile);
    final list = [...state.profiles];
    final index = list.indexWhere((p) => p.id == profile.id);
    if (index >= 0) {
      list[index] = profile;
    } else {
      list.add(profile);
    }
    final makeActive = activate || state.activeId == null;
    if (makeActive) await _repo.setActiveId(profile.id);
    state = state.copyWith(
      profiles: list,
      activeId: makeActive ? profile.id : state.activeId,
    );
  }

  /// Switches the active profile.
  Future<void> activate(String id) async {
    if (state.byId(id) == null || state.activeId == id) return;
    await _repo.setActiveId(id);
    state = state.copyWith(activeId: id);
  }

  /// Deletes a profile. If it was active, the first remaining profile becomes
  /// active; when none remain the app returns to onboarding.
  Future<void> delete(String id) async {
    await _repo.delete(id);
    final list = state.profiles.where((p) => p.id != id).toList();
    String? activeId = state.activeId;
    if (activeId == id) {
      activeId = list.isEmpty ? null : list.first.id;
      await _repo.setActiveId(activeId);
    }
    state = ProfilesState(profiles: list, activeId: activeId);
  }
}
