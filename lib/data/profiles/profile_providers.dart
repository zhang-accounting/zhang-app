import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../core/utils/shared_files.dart';
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

/// The profiles + active id, shared by every ledger session:
/// `LedgerSessionHost` keeps one store for the app's lifetime (and opens a
/// new session when its active profile changes), so a change that completes
/// after its session ended still lands. Without the host, one per container.
/// Read and change it through [profilesProvider].
final profilesStoreProvider = Provider<ValueNotifier<ProfilesState>>((ref) {
  final store = ValueNotifier(ref.watch(initialProfilesStateProvider));
  ref.onDispose(store.dispose);
  return store;
});

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

/// Changes go to the repository, then to [profilesStoreProvider]; each
/// method reads the store again after its awaits (another change, or a
/// profile switch, may have happened meanwhile).
class ProfilesController extends Notifier<ProfilesState> {
  @override
  ProfilesState build() {
    final store = ref.watch(profilesStoreProvider);
    void sync() => state = store.value;
    store.addListener(sync);
    ref.onDispose(() => store.removeListener(sync));
    return store.value;
  }

  /// Creates or updates [profile]. A new profile becomes active when
  /// [activate] is true or when it is the first one.
  Future<void> save(ServerProfile profile, {bool activate = false}) async {
    final repo = ref.read(profileRepositoryProvider);
    final store = ref.read(profilesStoreProvider);
    await repo.upsert(profile);
    final makeActive = activate || store.value.activeId == null;
    if (makeActive) await repo.setActiveId(profile.id);
    final current = store.value;
    final list = [...current.profiles];
    final index = list.indexWhere((p) => p.id == profile.id);
    if (index >= 0) {
      list[index] = profile;
    } else {
      list.add(profile);
    }
    store.value = current.copyWith(
      profiles: list,
      activeId: makeActive ? profile.id : current.activeId,
    );
  }

  /// Switches the active profile.
  Future<void> activate(String id) async {
    final repo = ref.read(profileRepositoryProvider);
    final store = ref.read(profilesStoreProvider);
    if (store.value.byId(id) == null || store.value.activeId == id) return;
    await repo.setActiveId(id);
    if (store.value.byId(id) == null) return; // deleted meanwhile
    store.value = store.value.copyWith(activeId: id);
  }

  /// Deletes a profile. If it was active, the first remaining profile becomes
  /// active; when none remain the app returns to onboarding. Copies of
  /// shared documents are wiped too (they may belong to that ledger).
  Future<void> delete(String id) async {
    final repo = ref.read(profileRepositoryProvider);
    final store = ref.read(profilesStoreProvider);
    await repo.delete(id);
    unawaited(clearSharedDocuments());
    final list = store.value.profiles.where((p) => p.id != id).toList();
    String? activeId = store.value.activeId;
    if (activeId == id) {
      activeId = list.isEmpty ? null : list.first.id;
      await repo.setActiveId(activeId);
    }
    final current = store.value;
    store.value = ProfilesState(
      profiles: current.profiles.where((p) => p.id != id).toList(),
      activeId: current.activeId == id ? activeId : current.activeId,
    );
  }
}
