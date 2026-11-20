import 'package:decimal/decimal.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../data/models/commodity.dart';
import '../../data/repositories/ledger_data_providers.dart';
import '../../l10n/l10n.dart';
import '../accounts/widgets/amount_format.dart';
import '../stats/report_period.dart';
import '../stats/reports_providers.dart';
import '../stats/widgets/period_selector.dart';
import '../stats/widgets/report_cards.dart';
import 'budget_figures.dart';
import 'budget_providers.dart';
import 'budget_routes.dart';
import 'widgets/budget_widgets.dart';

/// Reports › Budgets segment (S11, read-only): month stepper shared with the
/// income / expense segment, month totals, and the budgets grouped by their
/// `category` meta with assigned / activity / available and a progress bar.
class BudgetsView extends ConsumerWidget {
  const BudgetsView({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final period = ref.watch(reportPeriodProvider);
    final month = DateTime(period.start.year, period.start.month);
    final budgets = ref.watch(budgetsProvider(month));
    final commodities = ref.watch(commoditiesProvider).value ?? const <String, Commodity>{};
    final now = ref.watch(reportsClockProvider)();
    final current = ReportPeriod.month(month).contains(now);
    // Days left in the current month, today included.
    final daysLeft = current ? calendarDaysBetween(now, DateTime(month.year, month.month + 1)) : null;

    return RefreshIndicator(
      onRefresh: () => ref.refresh(budgetsProvider(month).future),
      child: ListView(
        key: const Key('budgets.list'),
        physics: const AlwaysScrollableScrollPhysics(),
        children: [
          const PeriodSelector(monthOnly: true),
          ...budgets.when(
            data: (list) => list.isEmpty
                ? [const _BudgetsEmpty()]
                : [
                    BudgetTotalsCard(totals: budgetTotals(list), commodities: commodities, daysLeft: daysLeft),
                    for (final group in groupBudgets(list)) ...[
                      _GroupHeader(category: group.category),
                      for (final b in group.budgets)
                        BudgetTile(
                          budget: b,
                          commodities: commodities,
                          daysLeft: daysLeft,
                          onTap: () => context.push(budgetDetailLocation(b.name, month)),
                        ),
                    ],
                  ],
            loading: () => [const ReportCardPlaceholder(height: 160)],
            error: (e, _) => [ReportCardError(error: e, onRetry: () => ref.invalidate(budgetsProvider(month)))],
          ),
          // Room for the FAB.
          const SizedBox(height: 96),
        ],
      ),
    );
  }
}

class _GroupHeader extends StatelessWidget {
  const _GroupHeader({required this.category});

  final String? category;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 4),
      child: Text(
        category ?? context.l10n.budgetsUncategorized,
        key: Key('budgets.group.${category ?? ''}'),
        style: theme.textTheme.titleSmall?.copyWith(color: theme.colorScheme.primary),
      ),
    );
  }
}

/// Month totals of the open budgets, one row per currency, with the number of
/// budgets over budget and (current month) the days left.
class BudgetTotalsCard extends StatelessWidget {
  const BudgetTotalsCard({super.key, required this.totals, required this.commodities, this.daysLeft});

  final List<BudgetTotals> totals;
  final Map<String, Commodity> commodities;
  final int? daysLeft;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final over = totals.fold(0, (n, t) => n + t.overCount);
    final muted = theme.textTheme.bodySmall?.copyWith(color: scheme.onSurfaceVariant);
    return Card.filled(
      key: const Key('budgets.totals'),
      margin: const EdgeInsets.fromLTRB(16, 8, 16, 8),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            for (final t in totals)
              Padding(
                padding: const EdgeInsets.only(bottom: 4),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: BudgetFigure(
                        label: l10n.budgetsAssigned,
                        value: formatAmount(commodities, t.assigned, t.currency),
                      ),
                    ),
                    Expanded(
                      child: BudgetFigure(
                        label: l10n.budgetsActivity,
                        value: formatAmount(commodities, t.activity, t.currency),
                      ),
                    ),
                    Expanded(
                      child: BudgetFigure(
                        key: Key('budgets.totals.available.${t.currency}'),
                        label: l10n.budgetsAvailable,
                        value: formatAmount(commodities, t.available, t.currency),
                        color: t.available < Decimal.zero ? scheme.error : null,
                      ),
                    ),
                  ],
                ),
              ),
            if (over > 0 || daysLeft != null)
              Padding(
                padding: const EdgeInsets.fromLTRB(4, 4, 4, 0),
                child: Wrap(
                  spacing: 12,
                  runSpacing: 4,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    if (over > 0)
                      Row(
                        key: const Key('budgets.overCount'),
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.warning_amber_rounded, size: 16, color: scheme.error),
                          const SizedBox(width: 4),
                          Text(l10n.budgetsOverCount(over), style: muted?.copyWith(color: scheme.error)),
                        ],
                      ),
                    if (daysLeft != null) Text(l10n.budgetsDaysLeft(daysLeft!), style: muted),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }
}

/// No budget in the month: what a budget is in the ledger, with an example
/// in the ledger's syntax (zhang or beancount `custom`).
class _BudgetsEmpty extends ConsumerWidget {
  const _BudgetsEmpty();

  static const _zhangExample = '''2024-01-01 open Expenses:Groceries CNY
  budget: Food
2024-03-01 budget Food CNY
  category: "Daily"
2024-03-01 budget-add Food 2000 CNY''';

  static const _beancountExample = '''2024-01-01 open Expenses:Groceries CNY
  budget: "Food"
2024-03-01 custom "budget" "Food" "CNY"
  category: "Daily"
2024-03-01 custom "budget-add" "Food" 2000 CNY''';

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final beancount = ref.watch(serverInfoProvider).value?.format == 'beancount';
    return Padding(
      key: const Key('budgets.empty'),
      padding: const EdgeInsets.fromLTRB(24, 32, 24, 16),
      child: Column(
        children: [
          Icon(Icons.savings_outlined, size: 48, color: scheme.primary),
          const SizedBox(height: 12),
          Text(l10n.budgetsEmptyTitle, style: theme.textTheme.titleMedium, textAlign: TextAlign.center),
          const SizedBox(height: 8),
          Text(
            l10n.budgetsEmptyBody,
            style: theme.textTheme.bodyMedium?.copyWith(color: scheme.onSurfaceVariant),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 16),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(color: scheme.surfaceContainerHigh, borderRadius: BorderRadius.circular(12)),
            child: SelectableText(
              beancount ? _beancountExample : _zhangExample,
              style: accountPathStyle(context).copyWith(color: scheme.onSurface),
            ),
          ),
          const SizedBox(height: 12),
          Text(
            l10n.budgetsReadOnly,
            style: theme.textTheme.bodySmall?.copyWith(color: scheme.onSurfaceVariant),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
}
