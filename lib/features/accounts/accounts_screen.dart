import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/widgets/error_view.dart';
import '../../data/models/account.dart';
import '../../data/repositories/ledger_data_providers.dart';
import '../../l10n/l10n.dart';
import 'account_detail_screen.dart';
import 'account_tree.dart';
import 'accounts_providers.dart';
import 'widgets/account_tree_tile.dart';
import 'widgets/net_worth_card.dart';

/// Accounts tab (S12): net-worth card and the collapsible account tree per
/// type, with search and a "show closed accounts" toggle.
class AccountsScreen extends ConsumerStatefulWidget {
  const AccountsScreen({super.key});

  @override
  ConsumerState<AccountsScreen> createState() => _AccountsScreenState();
}

class _AccountsScreenState extends ConsumerState<AccountsScreen> {
  final _searchController = TextEditingController();
  bool _searching = false;
  bool _showClosed = false;
  String _query = '';

  /// Paths whose expansion differs from [defaultExpanded].
  final _toggled = <String>{};

  /// Multi-currency rows showing one line per commodity.
  final _commoditiesShown = <String>{};

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  void _closeSearch() => setState(() {
    _searching = false;
    _query = '';
    _searchController.clear();
  });

  void _toggle(String path) => setState(() {
    if (!_toggled.remove(path)) _toggled.add(path);
  });

  void _toggleCommodities(String path) => setState(() {
    if (!_commoditiesShown.remove(path)) _commoditiesShown.add(path);
  });

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final accounts = ref.watch(accountsListProvider);
    return Scaffold(
      appBar: AppBar(
        title: _searching
            ? TextField(
                key: const Key('accounts.searchField'),
                controller: _searchController,
                autofocus: true,
                decoration: InputDecoration(
                  hintText: l10n.accountsSearchHint,
                  border: InputBorder.none,
                  filled: false,
                ),
                onChanged: (v) => setState(() => _query = v),
              )
            : Text(l10n.tabAccounts),
        actions: [
          if (_searching)
            IconButton(
              tooltip: l10n.accountsCloseSearch,
              icon: const Icon(Icons.close),
              onPressed: _closeSearch,
            )
          else
            IconButton(
              key: const Key('accounts.search'),
              tooltip: l10n.accountsSearch,
              icon: const Icon(Icons.search),
              onPressed: () => setState(() => _searching = true),
            ),
          PopupMenuButton<String>(
            key: const Key('accounts.menu'),
            onSelected: (v) {
              if (v == 'closed') setState(() => _showClosed = !_showClosed);
            },
            itemBuilder: (context) => [
              CheckedPopupMenuItem(
                key: const Key('accounts.showClosed'),
                value: 'closed',
                checked: _showClosed,
                child: Text(l10n.accountsShowClosed),
              ),
            ],
          ),
        ],
      ),
      body: accounts.when(
        data: (list) => RefreshIndicator(
          onRefresh: () => ref.refresh(accountsListProvider.future),
          child: _buildList(context, list),
        ),
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => ErrorView(error: e, onRetry: () => ref.invalidate(accountsListProvider)),
      ),
    );
  }

  Widget _buildList(BuildContext context, List<Account> accounts) {
    final l10n = context.l10n;
    final theme = Theme.of(context);
    final commodities = ref.watch(commoditiesProvider).value ?? const {};
    final operatingCurrency = ref.watch(ledgerOptionsProvider).value?.operatingCurrency ??
        (accounts.isEmpty ? 'CNY' : accounts.first.amount.calculated.commodity);
    final netWorth = computeNetWorth(
      accounts,
      operatingCurrency: operatingCurrency,
      commodities: commodities,
    );
    final tree = buildAccountTree(accounts, showClosed: _showClosed, query: _query);
    final searching = _query.trim().isNotEmpty;

    final rows = <(AccountType, AccountTreeRow)>[
      for (final s in tree.sections)
        for (final r in flattenTree(s.root, toggled: _toggled, expandAll: searching)) (s.type, r),
    ];

    Widget message(String text) => Padding(
      padding: const EdgeInsets.fromLTRB(32, 48, 32, 48),
      child: Text(
        text,
        textAlign: TextAlign.center,
        style: theme.textTheme.bodyLarge?.copyWith(color: theme.colorScheme.onSurfaceVariant),
      ),
    );

    final hiddenClosed = _showClosed ? 0 : tree.closedCount;
    return CustomScrollView(
      key: const Key('accounts.list'),
      physics: const AlwaysScrollableScrollPhysics(),
      slivers: [
        if (accounts.isNotEmpty)
          SliverToBoxAdapter(
            child: NetWorthCard(netWorth: netWorth, commodities: commodities),
          ),
        if (accounts.isEmpty)
          SliverToBoxAdapter(child: message(l10n.accountsEmpty))
        else if (rows.isEmpty && searching)
          SliverToBoxAdapter(child: message(l10n.accountsNoMatches(_query.trim())))
        else
          SliverList.builder(
            itemCount: rows.length,
            itemBuilder: (context, i) {
              final (type, row) = rows[i];
              final node = row.node;
              return AccountTreeTile(
                row: row,
                type: type,
                commodities: commodities,
                operatingCurrency: operatingCurrency,
                showCommodities: _commoditiesShown.contains(node.path),
                onToggle: () => _toggle(node.path),
                onToggleCommodities: () => _toggleCommodities(node.path),
                onOpen: () => context.push(accountDetailLocation(node.path)),
              );
            },
          ),
        if (hiddenClosed > 0)
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
              child: Center(
                child: TextButton(
                  onPressed: () => setState(() => _showClosed = true),
                  child: Text(l10n.accountsClosedHidden(hiddenClosed)),
                ),
              ),
            ),
          ),
        // Room for the docked FAB.
        const SliverToBoxAdapter(child: SizedBox(height: 96)),
      ],
    );
  }
}
