import 'package:decimal/decimal.dart';
import 'package:flutter/material.dart';

import '../../../core/theme/app_colors.dart';
import '../../../data/models/account.dart';
import '../../../data/models/commodity.dart';
import '../../../l10n/l10n.dart';
import '../account_tree.dart';
import 'amount_format.dart';

/// Width of one indentation level of the tree.
const double kTreeIndent = 16;

/// Indentation stops growing after this many levels (deeper rows show their
/// full path instead).
const int kMaxTreeIndentLevels = 4;

const double _kLeadingPad = 8;
const double _kToggleWidth = 40;

/// Localised name of an account type.
String accountTypeLabel(AppLocalizations l10n, AccountType type) => switch (type) {
  AccountType.assets => l10n.accountsAssets,
  AccountType.liabilities => l10n.accountsLiabilities,
  AccountType.income => l10n.accountsIncome,
  AccountType.expenses => l10n.accountsExpenses,
  AccountType.equity => l10n.accountsEquity,
};

/// Icon of an account type (docs/design-research.md §2.7).
IconData accountTypeIcon(AccountType type) => switch (type) {
  AccountType.assets => Icons.account_balance_outlined,
  AccountType.liabilities => Icons.credit_card_outlined,
  AccountType.income => Icons.trending_up,
  AccountType.expenses => Icons.shopping_bag_outlined,
  AccountType.equity => Icons.balance_outlined,
};

/// Container/on-container colours for an account type's icon.
(Color, Color) accountTypeColors(BuildContext context, AccountType type) {
  final scheme = Theme.of(context).colorScheme;
  final z = context.zhangColors;
  return switch (type) {
    AccountType.assets => (scheme.primaryContainer, scheme.onPrimaryContainer),
    AccountType.liabilities => (scheme.tertiaryContainer, scheme.onTertiaryContainer),
    AccountType.income => (z.incomeContainer, z.onIncomeContainer),
    AccountType.expenses => (z.expenseContainer, z.onExpenseContainer),
    AccountType.equity => (scheme.surfaceContainerHighest, scheme.onSurfaceVariant),
  };
}

/// One row of the account tree: indent guides, expand toggle, name and the
/// summed balance (multi-currency balances expand into one line each).
class AccountTreeTile extends StatelessWidget {
  const AccountTreeTile({
    super.key,
    required this.row,
    required this.type,
    required this.commodities,
    required this.operatingCurrency,
    required this.showCommodities,
    required this.onToggle,
    required this.onToggleCommodities,
    required this.onOpen,
  });

  final AccountTreeRow row;
  final AccountType type;
  final Map<String, Commodity> commodities;
  final String operatingCurrency;

  /// Whether the per-commodity lines of a multi-currency row are shown.
  final bool showCommodities;
  final VoidCallback onToggle;
  final VoidCallback onToggleCommodities;

  /// Opens the account detail (only called for nodes that are accounts).
  final VoidCallback onOpen;

  AccountNode get node => row.node;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final isSection = node.depth == 1;
    final level = (node.depth - 1).clamp(0, kMaxTreeIndentLevels);
    final indent = _kLeadingPad + level * kTreeIndent;
    final dim = node.isClosed;
    final nameColor = dim ? scheme.onSurface.withValues(alpha: 0.5) : scheme.onSurface;

    final toggle = node.hasChildren
        ? IconButton(
            key: Key('accounts.toggle.${node.path}'),
            tooltip: row.expanded ? l10n.accountsCollapse : l10n.accountsExpand,
            visualDensity: VisualDensity.compact,
            icon: AnimatedRotation(
              turns: row.expanded ? 0.25 : 0,
              duration: const Duration(milliseconds: 150),
              child: const Icon(Icons.chevron_right),
            ),
            onPressed: onToggle,
          )
        : null;

    Widget name;
    if (isSection) {
      final (bg, fg) = accountTypeColors(context, type);
      name = Row(
        children: [
          Container(
            width: 32,
            height: 32,
            decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(10)),
            child: Icon(accountTypeIcon(type), size: 18, color: fg),
          ),
          const SizedBox(width: 12),
          Flexible(
            child: Text(
              accountTypeLabel(l10n, type),
              style: theme.textTheme.titleMedium,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      );
    } else {
      final showPath =
          (node.account?.alias?.isNotEmpty ?? false) || node.depth - 1 > kMaxTreeIndentLevels;
      name = Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              Flexible(
                child: Text(
                  node.displayName,
                  style: theme.textTheme.bodyLarge?.copyWith(color: nameColor),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              if (node.isClosed) ...[
                const SizedBox(width: 6),
                _Badge(text: l10n.accountsClosedBadge),
              ],
            ],
          ),
          if (showPath)
            Text(
              node.path,
              style: accountPathStyle(context),
              overflow: TextOverflow.ellipsis,
            ),
        ],
      );
    }

    final amountTextStyle = amountStyle(
      (isSection ? theme.textTheme.titleSmall : theme.textTheme.bodyMedium)?.copyWith(
        color: dim ? scheme.onSurface.withValues(alpha: 0.5) : scheme.onSurface,
        fontWeight: isSection || node.hasChildren ? FontWeight.w600 : null,
      ),
    );
    final amount = _AmountColumn(
      node: node,
      commodities: commodities,
      operatingCurrency: operatingCurrency,
      showCommodities: showCommodities,
      style: amountTextStyle,
      onToggleCommodities: onToggleCommodities,
    );

    final content = Padding(
      padding: EdgeInsets.only(left: indent, right: 16),
      child: ConstrainedBox(
        constraints: BoxConstraints(minHeight: isSection ? 56 : 48),
        child: Row(
          children: [
            SizedBox(width: _kToggleWidth, child: toggle),
            Expanded(child: name),
            const SizedBox(width: 8),
            amount,
          ],
        ),
      ),
    );

    return Padding(
      padding: EdgeInsets.only(top: isSection ? 8 : 0),
      child: InkWell(
        key: Key('accounts.row.${node.path}'),
        onTap: node.isAccount ? onOpen : (node.hasChildren ? onToggle : null),
        child: CustomPaint(
          painter: _IndentGuidePainter(levels: level, color: scheme.outlineVariant),
          child: content,
        ),
      ),
    );
  }
}

/// Right-aligned balance: single amount, or "≈ converted" with an expander
/// listing each commodity.
class _AmountColumn extends StatelessWidget {
  const _AmountColumn({
    required this.node,
    required this.commodities,
    required this.operatingCurrency,
    required this.showCommodities,
    required this.style,
    required this.onToggleCommodities,
  });

  final AccountNode node;
  final Map<String, Commodity> commodities;
  final String operatingCurrency;
  final bool showCommodities;
  final TextStyle style;
  final VoidCallback onToggleCommodities;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final balances = node.sortedBalances;
    if (balances.isEmpty) {
      return Text(
        formatAmount(commodities, Decimal.zero, node.calculatedCommodity ?? operatingCurrency),
        style: style,
      );
    }
    if (balances.length == 1) {
      final b = balances.single;
      return Text(formatAmount(commodities, b.value, b.key), style: style);
    }
    final muted = style.copyWith(
      color: Theme.of(context).colorScheme.onSurfaceVariant,
      fontWeight: FontWeight.w400,
    );
    return InkWell(
      key: Key('accounts.commodities.${node.path}'),
      borderRadius: BorderRadius.circular(8),
      onTap: onToggleCommodities,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 4),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.end,
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  '≈ ${formatAmount(commodities, node.calculated, node.calculatedCommodity ?? operatingCurrency)}',
                  style: style,
                ),
                Icon(
                  showCommodities ? Icons.expand_less : Icons.expand_more,
                  size: 18,
                  semanticLabel: showCommodities
                      ? l10n.accountsHideCommodities
                      : l10n.accountsShowCommodities,
                ),
              ],
            ),
            if (showCommodities)
              for (final b in balances)
                Padding(
                  padding: const EdgeInsets.only(right: 18),
                  child: Text(formatAmount(commodities, b.value, b.key), style: muted),
                ),
          ],
        ),
      ),
    );
  }
}

class _Badge extends StatelessWidget {
  const _Badge({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(
        text,
        style: theme.textTheme.labelSmall?.copyWith(color: theme.colorScheme.onSurfaceVariant),
      ),
    );
  }
}

/// Vertical guide lines, one per ancestor level, aligned with the ancestors'
/// expand toggles.
class _IndentGuidePainter extends CustomPainter {
  const _IndentGuidePainter({required this.levels, required this.color});

  final int levels;
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    if (levels <= 0) return;
    final paint = Paint()
      ..color = color
      ..strokeWidth = 1;
    for (var i = 1; i <= levels; i++) {
      // Centre of the toggle of the ancestor at level i - 1.
      final x = _kLeadingPad + (i - 1) * kTreeIndent + _kToggleWidth / 2;
      canvas.drawLine(Offset(x, 0), Offset(x, size.height), paint);
    }
  }

  @override
  bool shouldRepaint(_IndentGuidePainter old) => old.levels != levels || old.color != color;
}
