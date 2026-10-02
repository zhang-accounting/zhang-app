import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../data/profiles/profile_providers.dart';

/// Per-profile local memory of the record flow (shared_preferences):
/// category → last funding account (MOZE's `lastFundingByCategory`, P-07).
class RecordPrefs {
  RecordPrefs(this._prefs, this.profileId);

  final SharedPreferences _prefs;
  final String profileId;

  /// Bounded so the JSON blob cannot grow forever.
  static const maxEntries = 300;

  static String fundingKey(String profileId) => 'zhang.record.$profileId.lastFunding.v1';

  Map<String, String> _read() {
    final raw = _prefs.getString(fundingKey(profileId));
    if (raw == null || raw.isEmpty) return {};
    try {
      final decoded = jsonDecode(raw);
      if (decoded is! Map) return {};
      return {
        for (final e in decoded.entries)
          if (e.key is String && e.value is String) e.key as String: e.value as String,
      };
    } on FormatException {
      return {};
    }
  }

  /// Funding account last used with [category] (a tile or a leaf account).
  String? lastFunding(String category) => _read()[category];

  /// Remembers [funding] for every key in [categories] (the leaf posting
  /// account and its second-level tile). Most recent entries are kept last.
  Future<void> rememberFunding(Iterable<String> categories, String funding) async {
    final map = _read();
    for (final c in categories) {
      map.remove(c);
      map[c] = funding;
    }
    while (map.length > maxEntries) {
      map.remove(map.keys.first);
    }
    await _prefs.setString(fundingKey(profileId), jsonEncode(map));
  }
}

/// [RecordPrefs] of the active profile (`null` without one).
final recordPrefsProvider = Provider<RecordPrefs?>((ref) {
  final profile = ref.watch(activeProfileProvider);
  if (profile == null) return null;
  return RecordPrefs(ref.watch(sharedPreferencesProvider), profile.id);
});
