import 'package:decimal/decimal.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';

import '../../../data/models/account.dart';
import '../../../data/models/commodity.dart';
import '../../../data/models/statistic.dart';
import '../../../l10n/l10n.dart';
import '../../accounts/widgets/amount_format.dart';
import '../report_aggregation.dart';
import 'category_palette.dart';

/// Expenses / Income breakdown: donut (top 6 + Other) and a ranked list of
/// horizontal bars at the current drill-down level, with a breadcrumb.
class CategoryBreakdownCard extends StatelessWidget {
  const CategoryBreakdownCard({
    super.key,
    required this.type,
    required this.parent,
    required this.body,
    required this.onTypeChanged,
    required this.onParentChanged,
  });

  /// `Expenses` or `Income`.
  final AccountType type;

  /// Current drill-down level (`type.wire` at the top).
  final String parent;

  /// Content below the header (see [CategoryBreakdownBody]).
  final Widget body;
  final ValueChanged<AccountType> onTypeChanged;
  final ValueChanged<String> onParentChanged;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final theme = Theme.of(context);
    final crumbs = breadcrumbOf(parent);
    return Card.outlined(
      margin: const EdgeInsets.fromLTRB(16, 8, 16, 8),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Row(
                children: [
                  Expanded(child: Text(l10n.reportsBreakdownTitle, style: theme.textTheme.titleSmall)),
                  SegmentedButton<AccountType>(
                    key: const Key('reports.rankType'),
                    showSelectedIcon: false,
                    style: const ButtonStyle(visualDensity: VisualDensity.compact),
                    segments: [
                      ButtonSegment(value: AccountType.expenses, label: Text(l10n.reportsExpenses)),
                      ButtonSegment(value: AccountType.income, label: Text(l10n.reportsIncomeSegment)),
                    ],
                    selected: {type},
                    onSelectionChanged: (s) => onTypeChanged(s.first),
                  ),
                ],
              ),
            ),
            if (crumbs.length > 1)
              Padding(
                padding: const EdgeInsets.fromLTRB(4, 4, 16, 0),
                child: Row(
                  children: [
                    IconButton(
                      key: const Key('reports.rankUp'),
                      tooltip: l10n.reportsUpOneLevel,
                      icon: const Icon(Icons.arrow_upward),
                      visualDensity: VisualDensity.compact,
                      onPressed: () => onParentChanged(crumbs[crumbs.length - 2]),
                    ),
                    Expanded(
                      child: SingleChildScrollView(
                        scrollDirection: Axis.horizontal,
                        reverse: true,
                        child: Row(
                          children: [
                            for (final (i, c) in crumbs.indexed) ...[
                              if (i > 0)
                                Icon(Icons.chevron_right, size: 16, color: theme.colorScheme.onSurfaceVariant),
                              TextButton(
                                key: Key('reports.crumb.$c'),
                                style: TextButton.styleFrom(
                                  visualDensity: VisualDensity.compact,
                                  padding: const EdgeInsets.symmetric(horizontal: 6),
                                  minimumSize: const Size(0, 36),
                                ),
                                onPressed: i == crumbs.length - 1 ? null : () => onParentChanged(c),
                                child: Text(c.split(':').last),
                              ),
                            ],
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            const SizedBox(height: 8),
            body,
          ],
        ),
      ),
    );
  }
}

/// Donut + ranked list for one [StatisticRank] at drill-down level [parent].
class CategoryBreakdownBody extends StatelessWidget {
  const CategoryBreakdownBody({
    super.key,
    required this.rank,
    required this.type,
    required this.parent,
    required this.commodity,
    required this.commodities,
    required this.onDrill,
    required this.onOpenAccount,
  });

  final StatisticRank rank;
  final AccountType type;
  final String parent;
  final String commodity;
  final Map<String, Commodity> commodities;
  final ValueChanged<String> onDrill;
  final ValueChanged<String> onOpenAccount;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final theme = Theme.of(context);
    final items = aggregateRank(rank.detail, parent);
    final slices = groupDonut(items);
    if (slices.isEmpty) {
      return SizedBox(
        height: 120,
        child: Center(
          child: Text(
            type == AccountType.income ? l10n.reportsNoIncome : l10n.reportsNoExpenses,
            key: const Key('reports.rankEmpty'),
            style: theme.textTheme.bodyMedium?.copyWith(color: theme.colorScheme.onSurfaceVariant),
          ),
        ),
      );
    }
    final slots = assignColorSlots(
      [for (final s in slices) if (s.key != null) s.key!],
      paletteSize: kCategoryPaletteSize,
    );
    final otherColor = otherCategoryColor(context);
    Color colorOf(String? key) {
      final slot = key == null ? null : slots[key];
      return slot == null ? otherColor : categoryColor(context, slot);
    }

    final total = slices.fold(Decimal.zero, (sum, s) => sum + s.value);
    final maxValue = items.map((i) => i.value).fold(Decimal.zero, (a, b) => a > b ? a : b);
    String fmt(Decimal v) => formatAmount(commodities, v, commodity);

    return Column(
      children: [
        SizedBox(
          height: 200,
          child: Stack(
            alignment: Alignment.center,
            children: [
              PieChart(
                key: const Key('reports.donut'),
                PieChartData(
                  startDegreeOffset: -90,
                  sectionsSpace: 2,
                  centerSpaceRadius: 64,
                  pieTouchData: PieTouchData(enabled: false),
                  sections: [
                    for (final s in slices)
                      PieChartSectionData(
                        value: s.value.toDouble(),
                        color: colorOf(s.key),
                        radius: 30,
                        showTitle: false,
                      ),
                  ],
                ),
              ),
              SizedBox(
                width: 112,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      l10n.reportsTotal,
                      style: theme.textTheme.labelMedium?.copyWith(color: theme.colorScheme.onSurfaceVariant),
                    ),
                    FittedBox(
                      fit: BoxFit.scaleDown,
                      child: Text(
                        fmt(total),
                        key: const Key('reports.donutTotal'),
                        style: amountStyle(theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w600)),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 8),
        for (final item in items)
          _RankRow(
            item: item,
            color: colorOf(slots.containsKey(item.key) ? item.key : null),
            amount: fmt(item.value),
            share: shareOf(item.value, total),
            barFraction: shareOf(item.value, maxValue),
            onTap: item.hasChildren ? () => onDrill(item.key) : () => onOpenAccount(item.key),
          ),
        if (slices.any((s) => s.isOther))
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 4, 16, 0),
            child: Row(
              children: [
                Container(
                  width: 10,
                  height: 10,
                  decoration: BoxDecoration(color: otherColor, shape: BoxShape.circle),
                ),
                const SizedBox(width: 8),
                Text(
                  '${l10n.reportsOther} · ${fmt(slices.last.value)}',
                  style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.onSurfaceVariant),
                ),
              ],
            ),
          ),
      ],
    );
  }
}

class _RankRow extends StatelessWidget {
  const _RankRow({
    required this.item,
    required this.color,
    required this.amount,
    required this.share,
    required this.barFraction,
    required this.onTap,
  });

  final RankItem item;
  final Color color;
  final String amount;
  final double share;
  final double barFraction;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final percent = share == 0
        ? '—'
        : (share < 0.005 ? '<1%' : '${(share * 100).round()}%');
    return Semantics(
      hint: item.hasChildren ? l10n.reportsShowSubAccounts : l10n.reportsOpenAccount,
      child: InkWell(
        key: Key('reports.rank.${item.key}'),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 8, 8),
          child: Column(
            children: [
              Row(
                children: [
                  Container(
                    width: 10,
                    height: 10,
                    decoration: BoxDecoration(color: color, shape: BoxShape.circle),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(item.label, style: theme.textTheme.bodyLarge, overflow: TextOverflow.ellipsis),
                  ),
                  Text(
                    percent,
                    style: amountStyle(theme.textTheme.bodySmall?.copyWith(color: scheme.onSurfaceVariant)),
                  ),
                  const SizedBox(width: 12),
                  Text(amount, style: amountStyle(theme.textTheme.titleSmall)),
                  Icon(
                    item.hasChildren ? Icons.chevron_right : Icons.north_east,
                    size: item.hasChildren ? 20 : 14,
                    color: scheme.onSurfaceVariant,
                  ),
                ],
              ),
              const SizedBox(height: 6),
              Padding(
                padding: const EdgeInsets.only(left: 20, right: 20),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(3),
                  child: SizedBox(
                    height: 6,
                    child: Stack(
                      children: [
                        Positioned.fill(child: ColoredBox(color: scheme.surfaceContainerHighest)),
                        FractionallySizedBox(
                          widthFactor: barFraction,
                          heightFactor: 1,
                          child: ColoredBox(color: color),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
