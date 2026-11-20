import 'package:decimal/decimal.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../../core/theme/app_colors.dart';
import '../../../data/models/budget.dart';
import '../../../data/models/commodity.dart';
import '../../../l10n/l10n.dart';
import '../../accounts/widgets/amount_format.dart';
import '../budget_figures.dart';

/// Colour of a budget state (design §3.1 `budgetOk / Warn / Over`). These
/// are not the income / expense colours: those swap with the money colour
/// convention, a budget's state does not.
Color budgetHealthColor(BuildContext context, BudgetHealth health) => switch (health) {
  BudgetHealth.over => Theme.of(context).colorScheme.error,
  BudgetHealth.low => context.zhangColors.warning,
  BudgetHealth.ok => Theme.of(context).colorScheme.primary,
};

/// Small label over a figure (assigned / activity / available).
class BudgetFigure extends StatelessWidget {
  const BudgetFigure({super.key, required this.label, required this.value, this.color});

  final String label;
  final String value;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 4),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: theme.textTheme.labelMedium?.copyWith(color: theme.colorScheme.onSurfaceVariant)),
          const SizedBox(height: 2),
          FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: Text(
              value,
              style: amountStyle(theme.textTheme.titleMedium?.copyWith(color: color, fontWeight: FontWeight.w600)),
            ),
          ),
        ],
      ),
    );
  }
}

/// Activity / assigned bar in the colour of the budget's state.
class BudgetProgressBar extends StatelessWidget {
  const BudgetProgressBar({super.key, required this.budget});

  final Budget budget;

  @override
  Widget build(BuildContext context) {
    final muted = budget.closed;
    final color = budgetHealthColor(context, budget.health);
    return LinearProgressIndicator(
      value: budget.progress,
      minHeight: 6,
      borderRadius: BorderRadius.circular(3),
      color: muted ? Theme.of(context).colorScheme.outline : color,
      backgroundColor: Theme.of(context).colorScheme.surfaceContainerHighest,
      semanticsLabel: context.l10n.budgetsProgressLabel,
      semanticsValue: NumberFormat.percentPattern(Localizations.localeOf(context).toLanguageTag())
          .format(budget.progress),
    );
  }
}

/// "Over budget" marker: icon + text, never colour alone.
class BudgetOverBadge extends StatelessWidget {
  const BudgetOverBadge({super.key});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(Icons.warning_amber_rounded, size: 16, color: scheme.error),
        const SizedBox(width: 4),
        Text(context.l10n.budgetsOver, style: Theme.of(context).textTheme.labelMedium?.copyWith(color: scheme.error)),
      ],
    );
  }
}

/// One budget of the month list: name, available (state colour, ⚠ when
/// over budget), progress bar, "spent X of Y" and (current month, money
/// left) the amount left per day.
class BudgetTile extends StatelessWidget {
  const BudgetTile({super.key, required this.budget, required this.commodities, this.daysLeft, this.onTap});

  final Budget budget;
  final Map<String, Commodity> commodities;

  /// Days left in the month (today included) when it is the current month.
  final int? daysLeft;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final b = budget;
    final health = b.health;
    final currency = b.availableAmount.commodity;
    String fmt(Decimal v) => formatAmount(commodities, v, currency);
    final available = b.availableAmount.number;
    final muted = theme.textTheme.bodySmall?.copyWith(color: scheme.onSurfaceVariant);
    final days = daysLeft;
    // Rounded to the commodity's precision (2 when unknown): the generic
    // formatter would otherwise print every digit of the division.
    final perDay = !b.closed && days != null && days > 0 && available > Decimal.zero
        ? (available / Decimal.fromInt(days))
              .toDecimal(scaleOnInfinitePrecision: 10)
              .round(scale: commodities[currency]?.precision ?? 2)
        : null;
    final status = health == BudgetHealth.over
        ? l10n.budgetsOverBy(fmt(-available))
        : l10n.budgetsSpentOf(fmt(b.activityAmount.number), fmt(b.assignedAmount.number));
    return InkWell(
      key: Key('budgets.row.${b.name}'),
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 10, 16, 10),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        b.displayName,
                        style: theme.textTheme.bodyLarge?.copyWith(color: b.closed ? scheme.onSurfaceVariant : null),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      if (b.closed)
                        Text(l10n.budgetsClosed, style: muted)
                      else if (b.alias != null && b.alias!.isNotEmpty && b.alias != b.name)
                        Text(b.name, style: muted, maxLines: 1, overflow: TextOverflow.ellipsis),
                    ],
                  ),
                ),
                const SizedBox(width: 12),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(l10n.budgetsAvailable, style: muted),
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        if (health == BudgetHealth.over && !b.closed) ...[
                          Icon(
                            Icons.warning_amber_rounded,
                            key: Key('budgets.over.${b.name}'),
                            size: 18,
                            color: scheme.error,
                            semanticLabel: l10n.budgetsOver,
                          ),
                          const SizedBox(width: 4),
                        ],
                        Text(
                          fmt(available),
                          key: Key('budgets.available.${b.name}'),
                          style: amountStyle(
                            theme.textTheme.titleSmall?.copyWith(
                              fontWeight: FontWeight.w600,
                              color: b.closed
                                  ? scheme.onSurfaceVariant
                                  : health == BudgetHealth.ok
                                  ? null
                                  : budgetHealthColor(context, health),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 8),
            BudgetProgressBar(budget: b),
            const SizedBox(height: 6),
            Text.rich(
              TextSpan(
                children: [
                  TextSpan(
                    text: status,
                    style: health == BudgetHealth.over && !b.closed ? TextStyle(color: scheme.error) : null,
                  ),
                  if (perDay != null) TextSpan(text: ' · ${l10n.budgetsPerDay(fmt(perDay))}'),
                ],
              ),
              key: Key('budgets.status.${b.name}'),
              style: amountStyle(muted),
            ),
          ],
        ),
      ),
    );
  }
}
