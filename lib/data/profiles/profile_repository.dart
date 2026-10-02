import 'dart:convert';
import 'dart:developer' as developer;
import 'dart:math';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'secret_store.dart';
import 'server_profile.dart';

/// Snapshot of all configured profiles plus the active one.
@immutable
class ProfilesState {
  const ProfilesState({this.profiles = const [], this.activeId});

  final List<ServerProfile> profiles;
  final String? activeId;

  /// The active profile, or `null` when none is configured (→ onboarding).
  ServerProfile? get active {
    for (final p in profiles) {
      if (p.id == activeId) return p;
    }
    return null;
  }

  ServerProfile? byId(String id) {
    for (final p in profiles) {
      if (p.id == id) return p;
    }
    return null;
  }

  ProfilesState copyWith({
    List<ServerProfile>? profiles,
    String? activeId,
    bool clearActive = false,
  }) => ProfilesState(
    profiles: profiles ?? this.profiles,
    activeId: clearActive ? null : (activeId ?? this.activeId),
  );

  @override
  bool operator ==(Object other) =>
      other is ProfilesState &&
      other.activeId == activeId &&
      listEquals(other.profiles, profiles);

  @override
  int get hashCode => Object.hash(activeId, Object.hashAll(profiles));
}

/// Persists [ServerProfile]s.
///
/// * shared_preferences key [profilesKey]: JSON list of
///   `ServerProfile.toPublicJson()` (no secrets).
/// * shared_preferences key [activeKey]: active profile id.
/// * secure storage key `zhang.profile.<id>.secrets`: JSON of
///   `ServerProfile.toSecretJson()` (password, token, header values).
class ProfileRepository {
  ProfileRepository({required this._prefs, required this._secrets});

  static const profilesKey = 'zhang.profiles.v1';
  static const activeKey = 'zhang.activeProfileId';
  static String secretKey(String id) => 'zhang.profile.$id.secrets';

  final SharedPreferences _prefs;
  final SecretStore _secrets;

  /// Loads every profile including its secrets. Never throws for corrupt
  /// data: unreadable entries are skipped / loaded without secrets.
  Future<ProfilesState> load() async {
    final publics = _readPublicList();
    final profiles = <ServerProfile>[];
    for (final public in publics) {
      Map<String, Object?>? secret;
      try {
        final raw = await _secrets.read(secretKey(public['id'] as String));
        if (raw != null && raw.isNotEmpty) {
          secret = (jsonDecode(raw) as Map).cast<String, Object?>();
        }
      } catch (e) {
        developer.log(
          'Could not read secrets for profile ${public['id']}: ${e.runtimeType}',
          name: 'zhang.profiles',
        );
      }
      try {
        profiles.add(ServerProfile.fromJson(public, secret));
      } catch (e) {
        developer.log('Skipping corrupt profile entry', name: 'zhang.profiles');
      }
    }
    var activeId = _prefs.getString(activeKey);
    if (activeId == null || !profiles.any((p) => p.id == activeId)) {
      activeId = profiles.isEmpty ? null : profiles.first.id;
    }
    return ProfilesState(profiles: profiles, activeId: activeId);
  }

  /// Inserts or replaces [profile] (matched by id), keeping list order.
  Future<void> upsert(ServerProfile profile) async {
    final publics = _readPublicList();
    final index = publics.indexWhere((p) => p['id'] == profile.id);
    final json = profile.toPublicJson();
    if (index >= 0) {
      publics[index] = json;
    } else {
      publics.add(json);
    }
    final secret = profile.toSecretJson();
    if (secret.isEmpty) {
      await _secrets.delete(secretKey(profile.id));
    } else {
      await _secrets.write(secretKey(profile.id), jsonEncode(secret));
    }
    await _prefs.setString(profilesKey, jsonEncode(publics));
  }

  /// Removes a profile, its secrets and its per-profile preferences
  /// (`zhang.<feature>.<id>.…`: account-picker favourites / recents, record
  /// memory – they hold the ledger's account names). Clears the active id if
  /// it pointed to it.
  Future<void> delete(String id) async {
    final publics = _readPublicList()..removeWhere((p) => p['id'] == id);
    await _prefs.setString(profilesKey, jsonEncode(publics));
    await _secrets.delete(secretKey(id));
    if (_prefs.getString(activeKey) == id) await _prefs.remove(activeKey);
    for (final key in _prefs.getKeys().where((k) => k.startsWith('zhang.') && k.contains('.$id.')).toList()) {
      await _prefs.remove(key);
    }
  }

  Future<void> setActiveId(String? id) async {
    if (id == null) {
      await _prefs.remove(activeKey);
    } else {
      await _prefs.setString(activeKey, id);
    }
  }

  /// A new random profile id (128-bit hex).
  static String newId() {
    final rnd = Random.secure();
    return List.generate(16, (_) => rnd.nextInt(256).toRadixString(16).padLeft(2, '0')).join();
  }

  List<Map<String, Object?>> _readPublicList() {
    final raw = _prefs.getString(profilesKey);
    if (raw == null || raw.isEmpty) return [];
    try {
      final list = jsonDecode(raw);
      if (list is! List) return [];
      return [
        for (final e in list)
          if (e is Map && e['id'] is String) e.cast<String, Object?>(),
      ];
    } on FormatException {
      return [];
    }
  }
}
