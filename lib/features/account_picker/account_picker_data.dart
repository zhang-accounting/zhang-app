import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../data/models/account.dart';
import '../../data/profiles/profile_providers.dart';
import '../../data/repositories/account_repository.dart';
import '../../data/repositories/ledger_revision.dart';

/// `GET /api/accounts` (all accounts incl. closed ones, sorted by name) for
/// the record flow and the account picker.
final pickerAccountsProvider = FutureProvider<List<Account>>((ref) {
  ref.watch(ledgerRevisionProvider);
  return ref.watch(accountRepositoryProvider).list();
});

/// Per-profile picker memory in shared_preferences: starred accounts and the
/// most-recently picked ones.
class AccountPickerPrefs {
  AccountPickerPrefs(this._prefs, this.profileId);

  final SharedPreferences _prefs;
  final String profileId;

  static const maxRecent = 12;

  static String favouritesKey(String profileId) => 'zhang.accountPicker.$profileId.favourites.v1';
  static String recentKey(String profileId) => 'zhang.accountPicker.$profileId.recent.v1';

  /// Starred accounts in the order they were starred.
  List<String> get favourites => _prefs.getStringList(favouritesKey(profileId)) ?? const [];

  bool isFavourite(String account) => favourites.contains(account);

  /// Stars / un-stars [account]; returns whether it is now a favourite.
  Future<bool> toggleFavourite(String account) async {
    final list = [...favourites];
    final starred = !list.remove(account);
    if (starred) list.add(account);
    await _prefs.setStringList(favouritesKey(profileId), list);
    return starred;
  }

  /// Most recently picked first.
  List<String> get recent => _prefs.getStringList(recentKey(profileId)) ?? const [];

  Future<void> pushRecent(String account) async {
    final list = [account, ...recent.where((a) => a != account)].take(maxRecent).toList();
    await _prefs.setStringList(recentKey(profileId), list);
  }
}

/// [AccountPickerPrefs] of the active profile (`null` without one).
final accountPickerPrefsProvider = Provider<AccountPickerPrefs?>((ref) {
  final profile = ref.watch(activeProfileProvider);
  if (profile == null) return null;
  return AccountPickerPrefs(ref.watch(sharedPreferencesProvider), profile.id);
});

/// A node of the picker's account tree. Intermediate nodes that are not
/// accounts themselves (e.g. `Assets:Bank` when only `Assets:Bank:Checking`
/// is opened) have [account] `null` and cannot be picked.
@immutable
class AccountNode {
  const AccountNode({required this.path, required this.depth, this.account, this.children = const []});

  /// Full name up to this node (`Assets:Bank`).
  final String path;

  /// 0 for the type roots (`Assets`).
  final int depth;
  final Account? account;
  final List<AccountNode> children;

  String get segment => path.split(':').last;
  bool get isSelectable => account != null;
  bool get hasChildren => children.isNotEmpty;

  /// This node and all descendants, depth first.
  Iterable<AccountNode> get descendantsAndSelf sync* {
    yield this;
    for (final c in children) {
      yield* c.descendantsAndSelf;
    }
  }
}

/// Builds one tree per type in [types] (in [AccountType] order) from the open
/// accounts of [accounts]. Closed accounts are hidden; children are sorted
/// by name (case-insensitive).
List<AccountNode> buildAccountForest(Iterable<Account> accounts, Set<AccountType> types) {
  final byName = <String, Account>{};
  for (final a in accounts) {
    if (a.isOpen && types.contains(a.type)) byName[a.name] = a;
  }
  final paths = <String>{};
  for (final name in byName.keys) {
    final segments = name.split(':');
    for (var i = 1; i <= segments.length; i++) {
      paths.add(segments.take(i).join(':'));
    }
  }
  AccountNode build(String path, int depth) {
    final prefix = '$path:';
    final childPaths = paths
        .where((p) => p.startsWith(prefix) && !p.substring(prefix.length).contains(':'))
        .toList()
      ..sort((a, b) {
        final c = a.toLowerCase().compareTo(b.toLowerCase());
        return c != 0 ? c : a.compareTo(b);
      });
    return AccountNode(
      path: path,
      depth: depth,
      account: byName[path],
      children: [for (final c in childPaths) build(c, depth + 1)],
    );
  }

  return [
    for (final type in AccountType.values)
      if (types.contains(type) && paths.contains(type.wire)) build(type.wire, 0),
  ];
}

/// Open accounts of [types] matching [query] (case-insensitive) in the full
/// name, any segment or the alias; prefix-of-segment matches first.
List<Account> searchAccounts(Iterable<Account> accounts, String query, Set<AccountType> types) {
  final q = query.trim().toLowerCase();
  final candidates = [
    for (final a in accounts)
      if (a.isOpen && types.contains(a.type)) a,
  ];
  if (q.isEmpty) return candidates;
  final strong = <Account>[];
  final weak = <Account>[];
  for (final a in candidates) {
    final name = a.name.toLowerCase();
    final alias = (a.alias ?? '').toLowerCase();
    final segmentPrefix = name.split(':').any((s) => s.startsWith(q)) || alias.startsWith(q);
    if (segmentPrefix) {
      strong.add(a);
    } else if (name.contains(q) || alias.contains(q)) {
      weak.add(a);
    }
  }
  return [...strong, ...weak];
}
