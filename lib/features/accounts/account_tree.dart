import 'package:decimal/decimal.dart';
import 'package:flutter/foundation.dart';

import '../../data/models/account.dart';
import '../../data/models/commodity.dart';

/// Order of the sections on the Accounts screen.
const accountSectionOrder = [
  AccountType.assets,
  AccountType.liabilities,
  AccountType.income,
  AccountType.expenses,
  AccountType.equity,
];

/// A node of the client-side account tree, built from colon-separated names.
///
/// Intermediate nodes may not correspond to an opened account (e.g.
/// `Assets:Bank` when only `Assets:Bank:CMB` is opened); then [account] is
/// `null`. Balances are the sums over the node and all its *visible*
/// descendants.
class AccountNode {
  AccountNode._({
    required this.path,
    required this.depth,
    required this.account,
    required this.children,
    required this.balances,
    required this.calculated,
    required this.calculatedCommodity,
  });

  /// Full name prefix, e.g. `Assets:Bank`.
  final String path;

  /// 1 for the type root (`Assets`), 2 for `Assets:Bank`, …
  final int depth;

  /// The opened account at exactly [path], if any.
  final Account? account;

  /// Sorted by segment name.
  final List<AccountNode> children;

  /// Per-commodity sums (own + descendants); zero entries are dropped.
  final Map<String, Decimal> balances;

  /// Sum of the server-converted `calculated` amounts.
  final Decimal calculated;

  /// Commodity of [calculated] (the operating currency), `null` when empty.
  final String? calculatedCommodity;

  /// Last name segment.
  String get segment => path.split(':').last;

  /// `alias` of the account when set, else [segment].
  String get displayName {
    final alias = account?.alias;
    return (alias == null || alias.isEmpty) ? segment : alias;
  }

  bool get hasChildren => children.isNotEmpty;
  bool get isAccount => account != null;
  bool get isClosed => account != null && !account!.isOpen;

  /// Non-zero balances sorted by commodity.
  List<MapEntry<String, Decimal>> get sortedBalances =>
      balances.entries.toList()..sort((a, b) => a.key.compareTo(b.key));

  /// More than one commodity with a non-zero balance.
  bool get isMultiCommodity => balances.length > 1;

  /// Depth-first iteration over this node and all descendants.
  Iterable<AccountNode> get descendantsAndSelf sync* {
    yield this;
    for (final c in children) {
      yield* c.descendantsAndSelf;
    }
  }
}

/// One top-level section (an account type) of the tree.
class AccountTreeSection {
  const AccountTreeSection(this.type, this.root);

  final AccountType type;

  /// Depth-1 node whose path is `type.wire`.
  final AccountNode root;
}

/// Result of [buildAccountTree].
class AccountTree {
  const AccountTree({required this.sections, required this.closedCount});

  /// Non-empty sections in [accountSectionOrder].
  final List<AccountTreeSection> sections;

  /// Number of closed accounts in the input (whether shown or not).
  final int closedCount;

  bool get isEmpty => sections.isEmpty;
}

/// Builds the account tree from the flat `/api/accounts` list.
///
/// * Closed accounts are dropped unless [showClosed].
/// * [query]: whitespace-separated terms, all of which must occur
///   (case-insensitively) in the account name or alias; ancestors of matching
///   accounts are kept so the hierarchy stays visible.
/// * Accounts with an invalid type prefix are ignored.
AccountTree buildAccountTree(
  List<Account> accounts, {
  bool showClosed = false,
  String query = '',
}) {
  final terms = query
      .toLowerCase()
      .split(RegExp(r'\s+'))
      .where((t) => t.isNotEmpty)
      .toList();
  bool matches(Account a) {
    if (terms.isEmpty) return true;
    final hay = '${a.name} ${a.alias ?? ''}'.toLowerCase();
    return terms.every(hay.contains);
  }

  final closedCount = accounts.where((a) => !a.isOpen).length;
  final roots = <AccountType, _Builder>{};
  for (final a in accounts) {
    final type = a.type;
    if (type == null) continue;
    if (!showClosed && !a.isOpen) continue;
    if (!matches(a)) continue;
    final segments = a.name.split(':');
    var node = roots.putIfAbsent(type, () => _Builder(type.wire, 1));
    for (var i = 1; i < segments.length; i++) {
      final path = segments.sublist(0, i + 1).join(':');
      node = node.children.putIfAbsent(segments[i], () => _Builder(path, i + 1));
    }
    node.account = a;
  }
  return AccountTree(
    sections: [
      for (final t in accountSectionOrder)
        if (roots[t] != null) AccountTreeSection(t, roots[t]!.build()),
    ],
    closedCount: closedCount,
  );
}

class _Builder {
  _Builder(this.path, this.depth);

  final String path;
  final int depth;
  Account? account;
  final children = <String, _Builder>{};

  AccountNode build() {
    final keys = children.keys.toList()..sort();
    final built = [for (final k in keys) children[k]!.build()];
    final balances = <String, Decimal>{};
    var calculated = Decimal.zero;
    String? calcCommodity;
    void add(Map<String, Decimal> detail) {
      for (final e in detail.entries) {
        balances[e.key] = (balances[e.key] ?? Decimal.zero) + e.value;
      }
    }

    final own = account;
    if (own != null) {
      add(own.amount.detail);
      calculated += own.amount.calculated.number;
      calcCommodity = own.amount.calculated.commodity;
    }
    for (final c in built) {
      add(c.balances);
      calculated += c.calculated;
      calcCommodity ??= c.calculatedCommodity;
    }
    balances.removeWhere((_, v) => v == Decimal.zero);
    return AccountNode._(
      path: path,
      depth: depth,
      account: own,
      children: List.unmodifiable(built),
      balances: Map.unmodifiable(balances),
      calculated: calculated,
      calculatedCommodity: calcCommodity,
    );
  }
}

/// A visible row of the flattened tree.
@immutable
class AccountTreeRow {
  const AccountTreeRow(this.node, {required this.expanded});

  final AccountNode node;

  /// Whether the node's children are shown (always `false` for leaves).
  final bool expanded;
}

/// Default expansion: the Assets and Liabilities sections are open, the
/// other sections are collapsed; deeper parents are collapsed (the screen is
/// "expanded to level 2", docs/design-research.md §2.7).
bool defaultExpanded(AccountNode node) {
  if (node.depth != 1) return false;
  final type = AccountType.tryParse(node.path);
  return type == AccountType.assets || type == AccountType.liabilities;
}

/// Flattens [root] into visible rows.
///
/// [toggled] holds the paths whose expansion differs from [defaultExpanded].
/// With [expandAll] (used while searching) every parent is expanded.
List<AccountTreeRow> flattenTree(
  AccountNode root, {
  Set<String> toggled = const {},
  bool expandAll = false,
}) {
  final rows = <AccountTreeRow>[];
  void visit(AccountNode n) {
    final expanded =
        n.hasChildren && (expandAll || (defaultExpanded(n) != toggled.contains(n.path)));
    rows.add(AccountTreeRow(n, expanded: expanded));
    if (expanded) n.children.forEach(visit);
  }

  visit(root);
  return rows;
}

/// Net worth computed by summing account balances.
@immutable
class NetWorth {
  const NetWorth({
    required this.assets,
    required this.liabilities,
    required this.commodity,
    this.unconverted = const [],
  });

  /// Sum of `calculated` over all Assets accounts.
  final Decimal assets;

  /// Sum of `calculated` over all Liabilities accounts (negative = owed).
  final Decimal liabilities;

  /// Operating currency.
  final String commodity;

  /// Commodities held in Assets/Liabilities that the server cannot convert to
  /// the operating currency (no direct price), so they are not in the total.
  final List<String> unconverted;

  /// Assets minus what is owed (liabilities are negative, so it is a sum).
  Decimal get net => assets + liabilities;
}

/// Net worth = Σ Assets `calculated` + Σ Liabilities `calculated` over all
/// accounts (closed ones included – their balance is normally zero).
///
/// A commodity counts as [NetWorth.unconverted] when it has a non-zero
/// balance, is not the operating currency and [commodities] reports no
/// price to the operating currency (`latest_price_commodity == null`).
NetWorth computeNetWorth(
  List<Account> accounts, {
  required String operatingCurrency,
  Map<String, Commodity> commodities = const {},
}) {
  var assets = Decimal.zero;
  var liabilities = Decimal.zero;
  final unconverted = <String>{};
  for (final a in accounts) {
    final type = a.type;
    if (type != AccountType.assets && type != AccountType.liabilities) continue;
    if (type == AccountType.assets) {
      assets += a.amount.calculated.number;
    } else {
      liabilities += a.amount.calculated.number;
    }
    for (final e in a.amount.detail.entries) {
      if (e.value == Decimal.zero || e.key == operatingCurrency) continue;
      final c = commodities[e.key];
      if (c != null && c.latestPriceCommodity == null) unconverted.add(e.key);
    }
  }
  return NetWorth(
    assets: assets,
    liabilities: liabilities,
    commodity: operatingCurrency,
    unconverted: unconverted.toList()..sort(),
  );
}
