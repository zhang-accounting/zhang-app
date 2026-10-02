import 'package:flutter/foundation.dart';

import '../../data/models/account.dart';

/// Display name of an account: its `alias` meta when set, else the last
/// name segment (docs/design-research.md §2.7).
String accountLabel(String name, {String? alias}) =>
    (alias != null && alias.trim().isNotEmpty) ? alias.trim() : name.split(':').last;

/// Case-insensitive, then exact, ordering of account names (stable grid order).
int compareAccountNames(String a, String b) {
  final c = a.toLowerCase().compareTo(b.toLowerCase());
  return c != 0 ? c : a.compareTo(b);
}

/// A sub-category chip: an open account below a [CategoryNode].
@immutable
class SubCategory {
  const SubCategory({required this.name, required this.label});

  /// Full account name, e.g. `Expenses:Food:Dining`.
  final String name;

  /// Alias, else the path below the category (`Dining`, `Dining:Lunch`).
  final String label;

  @override
  bool operator ==(Object other) => other is SubCategory && other.name == name && other.label == label;

  @override
  int get hashCode => Object.hash(name, label);

  @override
  String toString() => 'SubCategory($name)';
}

/// A tile of the category grid: a second-level `Expenses:*` / `Income:*`
/// account (docs/design-research.md §2.3).
@immutable
class CategoryNode {
  const CategoryNode({
    required this.name,
    required this.label,
    required this.isOpen,
    this.alias,
    this.children = const [],
  });

  /// Second-level account name, e.g. `Expenses:Food`.
  final String name;

  /// Alias of [name] when it is an account with an alias, else the segment.
  final String label;

  /// `alias` meta of the account itself (used for icon matching).
  final String? alias;

  /// Whether [name] itself is an open account. When it is not (only deeper
  /// accounts were opened), a sub-category must be chosen.
  final bool isOpen;

  /// All open accounts below [name] (any depth), sorted by name.
  final List<SubCategory> children;

  bool get requiresSubcategory => !isOpen;

  @override
  String toString() => 'CategoryNode($name, open: $isOpen, children: ${children.length})';
}

/// Where an account sits in a [CategoryTree].
typedef CategoryLocation = ({CategoryNode category, SubCategory? subcategory});

/// The category grid of one root type, derived from `GET /api/accounts`.
///
/// * Closed accounts are ignored; a second-level node only exists when it or
///   one of its descendants is open.
/// * Tiles are in a fixed, stable order (by account name), never re-ranked
///   (docs/design-research.md §2.1 rule 5).
class CategoryTree {
  const CategoryTree({required this.root, required this.categories});

  factory CategoryTree.fromAccounts(Iterable<Account> accounts, AccountType root) {
    final own = <String, Account>{};
    final descendants = <String, List<Account>>{};
    for (final account in accounts) {
      if (!account.isOpen || account.type != root) continue;
      final segments = account.name.split(':');
      if (segments.length < 2) continue;
      final key = '${segments[0]}:${segments[1]}';
      if (segments.length == 2) {
        own[key] = account;
      } else {
        descendants.putIfAbsent(key, () => []).add(account);
      }
    }
    final keys = {...own.keys, ...descendants.keys}.toList()..sort(compareAccountNames);
    return CategoryTree(
      root: root,
      categories: [
        for (final key in keys)
          CategoryNode(
            name: key,
            label: accountLabel(key, alias: own[key]?.alias),
            alias: own[key]?.alias,
            isOpen: own.containsKey(key),
            children: [
              for (final a in [...?descendants[key]]..sort((x, y) => compareAccountNames(x.name, y.name)))
                SubCategory(
                  name: a.name,
                  label: (a.alias != null && a.alias!.trim().isNotEmpty)
                      ? a.alias!.trim()
                      : a.name.substring(key.length + 1),
                ),
            ],
          ),
      ],
    );
  }

  final AccountType root;
  final List<CategoryNode> categories;

  bool get isEmpty => categories.isEmpty;

  CategoryNode? byName(String name) {
    for (final c in categories) {
      if (c.name == name) return c;
    }
    return null;
  }

  /// Finds the tile (and chip) for a posting account such as
  /// `Expenses:Food:Dining`; `null` when it is not an open category account.
  CategoryLocation? locate(String account) {
    final segments = account.split(':');
    if (segments.length < 2) return null;
    final category = byName('${segments[0]}:${segments[1]}');
    if (category == null) return null;
    if (segments.length == 2) {
      return category.isOpen ? (category: category, subcategory: null) : null;
    }
    for (final sub in category.children) {
      if (sub.name == account) return (category: category, subcategory: sub);
    }
    return null;
  }
}
