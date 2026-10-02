import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/category_icons.dart';
import '../../core/utils/money.dart';
import '../../core/widgets/error_view.dart';
import '../../data/models/account.dart';
import '../../data/models/commodity.dart';
import '../../data/repositories/ledger_data_providers.dart';
import '../../l10n/l10n.dart';
import 'account_picker_data.dart';

/// Opens the account picker (docs/design-research.md S04) and returns the
/// chosen account name, or `null` when dismissed.
///
/// * [types]: account types offered (e.g. Assets + Liabilities for a
///   funding account); closed accounts are never offered.
/// * [suggested]: extra "Recent" candidates (e.g. history frecency), shown
///   after the accounts picked recently in this picker.
/// * [selected]: highlighted current value.
Future<String?> showAccountPicker(
  BuildContext context, {
  required Set<AccountType> types,
  String? title,
  String? selected,
  List<String> suggested = const [],
}) {
  return showModalBottomSheet<String>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    showDragHandle: true,
    builder: (context) => Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(context).bottom),
      child: FractionallySizedBox(
        heightFactor: 0.9,
        child: AccountPickerSheet(types: types, title: title, selected: selected, suggested: suggested),
      ),
    ),
  );
}

/// Localised name of an account type.
String accountTypeLabel(AppLocalizations l10n, AccountType type) => switch (type) {
  AccountType.assets => l10n.addTypeAssets,
  AccountType.liabilities => l10n.addTypeLiabilities,
  AccountType.equity => l10n.addTypeEquity,
  AccountType.income => l10n.addTypeIncome,
  AccountType.expenses => l10n.addTypeExpenses,
};

/// Body of the picker sheet: search, favourites, recent, type filter and a
/// collapsible account tree. Long-press an account to star / un-star it.
class AccountPickerSheet extends ConsumerStatefulWidget {
  const AccountPickerSheet({
    super.key,
    required this.types,
    this.title,
    this.selected,
    this.suggested = const [],
  });

  final Set<AccountType> types;
  final String? title;
  final String? selected;
  final List<String> suggested;

  @override
  ConsumerState<AccountPickerSheet> createState() => _AccountPickerSheetState();
}

class _AccountPickerSheetState extends ConsumerState<AccountPickerSheet> {
  final _search = TextEditingController();
  String _query = '';
  AccountType? _typeFilter;
  final Set<String> _collapsed = {};
  List<String> _favourites = const [];
  List<String> _recent = const [];

  @override
  void initState() {
    super.initState();
    final prefs = ref.read(accountPickerPrefsProvider);
    _favourites = prefs?.favourites ?? const [];
    _recent = prefs?.recent ?? const [];
  }

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  Future<void> _pick(String account) async {
    await ref.read(accountPickerPrefsProvider)?.pushRecent(account);
    if (mounted) Navigator.of(context).pop(account);
  }

  Future<void> _toggleFavourite(String account) async {
    final prefs = ref.read(accountPickerPrefsProvider);
    if (prefs == null) return;
    HapticFeedback.mediumImpact();
    await prefs.toggleFavourite(account);
    if (mounted) setState(() => _favourites = prefs.favourites);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final theme = Theme.of(context);
    final accounts = ref.watch(pickerAccountsProvider);
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 0, 8, 4),
          child: Row(
            children: [
              Expanded(child: Text(widget.title ?? l10n.addChooseAccount, style: theme.textTheme.titleLarge)),
              IconButton(
                tooltip: l10n.addClose,
                icon: const Icon(Icons.close),
                onPressed: () => Navigator.of(context).pop(),
              ),
            ],
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
          child: TextField(
            key: const Key('picker.search'),
            controller: _search,
            onChanged: (v) => setState(() => _query = v),
            textInputAction: TextInputAction.search,
            decoration: InputDecoration(
              isDense: true,
              filled: true,
              prefixIcon: const Icon(Icons.search),
              hintText: l10n.addPickerSearch,
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(28), borderSide: BorderSide.none),
              suffixIcon: _query.isEmpty
                  ? null
                  : IconButton(
                      icon: const Icon(Icons.clear),
                      onPressed: () => setState(() {
                        _search.clear();
                        _query = '';
                      }),
                    ),
            ),
          ),
        ),
        Expanded(
          child: accounts.when(
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (e, _) => ErrorView(error: e, onRetry: () => ref.invalidate(pickerAccountsProvider)),
            data: _buildContent,
          ),
        ),
      ],
    );
  }

  Widget _buildContent(List<Account> accounts) {
    final l10n = context.l10n;
    final commodities = ref.watch(commoditiesProvider).value ?? const <String, Commodity>{};
    final byName = {
      for (final a in accounts)
        if (a.isOpen && widget.types.contains(a.type)) a.name: a,
    };
    if (_query.trim().isNotEmpty) {
      final results = searchAccounts(byName.values, _query, widget.types);
      if (results.isEmpty) {
        return Center(child: Text(l10n.addPickerEmpty));
      }
      return ListView(
        children: [
          for (final a in results)
            _AccountRow(
              key: Key('picker.account.${a.name}'),
              account: a,
              depth: 0,
              commodities: commodities,
              selected: a.name == widget.selected,
              favourite: _favourites.contains(a.name),
              onTap: () => _pick(a.name),
              onLongPress: () => _toggleFavourite(a.name),
            ),
        ],
      );
    }

    final favourites = [
      for (final f in _favourites)
        if (byName.containsKey(f)) byName[f]!,
    ];
    final recentNames = <String>{};
    for (final r in [..._recent, ...widget.suggested]) {
      if (byName.containsKey(r)) recentNames.add(r);
      if (recentNames.length >= 6) break;
    }
    final recent = [for (final r in recentNames) byName[r]!];
    final visibleTypes = _typeFilter == null ? widget.types : {_typeFilter!};
    final forest = buildAccountForest(byName.values, visibleTypes);
    final rows = <Widget>[];
    void addNode(AccountNode node) {
      final collapsed = _collapsed.contains(node.path);
      if (node.depth == 0) {
        rows.add(_TypeHeader(
          key: Key('picker.group.${node.path}'),
          label: accountTypeLabel(l10n, AccountType.tryParse(node.path)!),
          collapsed: collapsed,
          onTap: () => setState(() => collapsed ? _collapsed.remove(node.path) : _collapsed.add(node.path)),
        ));
      } else {
        rows.add(_AccountRow(
          key: Key('picker.account.${node.path}'),
          account: node.account,
          path: node.path,
          depth: node.depth - 1,
          commodities: commodities,
          selected: node.path == widget.selected,
          favourite: _favourites.contains(node.path),
          expandable: node.hasChildren,
          collapsed: collapsed,
          onToggle: node.hasChildren
              ? () => setState(() => collapsed ? _collapsed.remove(node.path) : _collapsed.add(node.path))
              : null,
          onTap: node.isSelectable
              ? () => _pick(node.path)
              : () => setState(() => collapsed ? _collapsed.remove(node.path) : _collapsed.add(node.path)),
          onLongPress: node.isSelectable ? () => _toggleFavourite(node.path) : null,
        ));
      }
      if (!collapsed) {
        for (final c in node.children) {
          addNode(c);
        }
      }
    }

    for (final root in forest) {
      addNode(root);
    }

    return ListView(
      padding: const EdgeInsets.only(bottom: 24),
      children: [
        _ChipsSection(
          icon: Icons.star_rounded,
          label: l10n.addPickerFavourites,
          emptyHint: l10n.addPickerStarHint,
          accounts: favourites,
          keyPrefix: 'picker.fav.',
          onTap: _pick,
          onLongPress: _toggleFavourite,
        ),
        if (recent.isNotEmpty)
          _ChipsSection(
            icon: Icons.history,
            label: l10n.addPickerRecent,
            accounts: recent,
            keyPrefix: 'picker.recent.',
            onTap: _pick,
            onLongPress: _toggleFavourite,
          ),
        if (widget.types.length > 1)
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
            child: Wrap(
              spacing: 8,
              children: [
                ChoiceChip(
                  key: const Key('picker.type.all'),
                  label: Text(l10n.addPickerAll),
                  selected: _typeFilter == null,
                  onSelected: (_) => setState(() => _typeFilter = null),
                ),
                for (final t in AccountType.values)
                  if (widget.types.contains(t))
                    ChoiceChip(
                      key: Key('picker.type.${t.wire}'),
                      label: Text(accountTypeLabel(l10n, t)),
                      selected: _typeFilter == t,
                      onSelected: (_) => setState(() => _typeFilter = t),
                    ),
              ],
            ),
          ),
        if (forest.isEmpty)
          Padding(
            padding: const EdgeInsets.all(32),
            child: Center(child: Text(l10n.addPickerEmpty)),
          ),
        ...rows,
      ],
    );
  }
}

/// Formatted balance of an Assets / Liabilities account (others: `null`).
String? _balanceText(Account account, Map<String, Commodity> commodities) {
  final type = account.type;
  if (type != AccountType.assets && type != AccountType.liabilities) return null;
  final amount = account.amount.calculated;
  return commodities[amount.commodity]?.format(amount.number) ?? formatMoney(amount.number, amount.commodity);
}

class _ChipsSection extends StatelessWidget {
  const _ChipsSection({
    required this.icon,
    required this.label,
    required this.accounts,
    required this.keyPrefix,
    required this.onTap,
    required this.onLongPress,
    this.emptyHint,
  });

  final IconData icon;
  final String label;
  final String? emptyHint;
  final List<Account> accounts;
  final String keyPrefix;
  final ValueChanged<String> onTap;
  final ValueChanged<String> onLongPress;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final muted = theme.textTheme.labelMedium?.copyWith(color: theme.colorScheme.onSurfaceVariant);
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 4, 0, 4),
      child: Row(
        children: [
          Icon(icon, size: 18, color: theme.colorScheme.onSurfaceVariant),
          const SizedBox(width: 6),
          Text(label, style: muted),
          const SizedBox(width: 8),
          Expanded(
            child: accounts.isEmpty
                ? Text(emptyHint ?? '', style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.outline))
                : SizedBox(
                    height: 40,
                    child: ListView(
                      scrollDirection: Axis.horizontal,
                      children: [
                        for (final a in accounts)
                          Padding(
                            padding: const EdgeInsets.only(right: 8),
                            child: GestureDetector(
                              onLongPress: () => onLongPress(a.name),
                              child: ActionChip(
                                key: Key('$keyPrefix${a.name}'),
                                avatar: Icon(categoryIcon(a.name, alias: a.alias), size: 18),
                                label: Text(_label(a)),
                                tooltip: a.name,
                                onPressed: () => onTap(a.name),
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
          ),
        ],
      ),
    );
  }
}

String _label(Account a) => (a.alias != null && a.alias!.trim().isNotEmpty) ? a.alias!.trim() : a.shortName;

class _TypeHeader extends StatelessWidget {
  const _TypeHeader({super.key, required this.label, required this.collapsed, required this.onTap});

  final String label;
  final bool collapsed;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 14, 16, 6),
        child: Row(
          children: [
            Icon(collapsed ? Icons.chevron_right : Icons.expand_more, size: 20),
            const SizedBox(width: 4),
            Text(label, style: theme.textTheme.titleSmall?.copyWith(color: theme.colorScheme.primary)),
          ],
        ),
      ),
    );
  }
}

class _AccountRow extends StatelessWidget {
  const _AccountRow({
    super.key,
    required this.account,
    this.path,
    required this.depth,
    required this.commodities,
    required this.selected,
    required this.favourite,
    required this.onTap,
    this.onLongPress,
    this.onToggle,
    this.expandable = false,
    this.collapsed = false,
  });

  /// `null` for intermediate tree nodes that are not accounts.
  final Account? account;
  final String? path;
  final int depth;
  final Map<String, Commodity> commodities;
  final bool selected;
  final bool favourite;
  final bool expandable;
  final bool collapsed;
  final VoidCallback onTap;
  final VoidCallback? onLongPress;
  final VoidCallback? onToggle;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final a = account;
    final name = a?.name ?? path!;
    final label = a == null ? name.split(':').last : _label(a);
    final balance = a == null ? null : _balanceText(a, commodities);
    final muted = theme.textTheme.bodySmall?.copyWith(color: scheme.onSurfaceVariant);
    return Semantics(
      selected: selected,
      button: true,
      child: InkWell(
        onTap: onTap,
        onLongPress: onLongPress,
        child: Container(
          color: selected ? scheme.secondaryContainer.withValues(alpha: 0.6) : null,
          constraints: const BoxConstraints(minHeight: 52),
          padding: EdgeInsets.fromLTRB(16.0 + depth * 18.0, 6, 8, 6),
          child: Row(
            children: [
              Icon(
                a == null ? Icons.folder_outlined : categoryIcon(name, alias: a.alias),
                size: 22,
                color: a == null ? scheme.onSurfaceVariant : scheme.primary,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      label,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.bodyLarge?.copyWith(
                        color: a == null ? scheme.onSurfaceVariant : null,
                      ),
                    ),
                    if (a != null) Text(name, maxLines: 1, overflow: TextOverflow.ellipsis, style: muted),
                  ],
                ),
              ),
              if (favourite) Icon(Icons.star_rounded, size: 18, color: scheme.tertiary),
              if (balance != null)
                Padding(
                  padding: const EdgeInsets.only(left: 8),
                  child: Text(
                    balance,
                    style: theme.textTheme.bodyMedium?.copyWith(
                      fontFeatures: const [FontFeature.tabularFigures()],
                      color: a!.amount.calculated.isNegative ? scheme.onSurfaceVariant : null,
                    ),
                  ),
                ),
              if (expandable)
                IconButton(
                  visualDensity: VisualDensity.compact,
                  icon: Icon(collapsed ? Icons.chevron_right : Icons.expand_more),
                  onPressed: onToggle,
                )
              else
                const SizedBox(width: 8),
            ],
          ),
        ),
      ),
    );
  }
}
