import 'package:decimal/decimal.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../core/theme/app_colors.dart';
import '../../core/utils/money.dart';
import '../../core/widgets/error_view.dart';
import '../../data/models/budget.dart';
import '../../data/models/commodity.dart';
import '../../data/repositories/ledger_data_providers.dart';
import '../../l10n/l10n.dart';
import '../../router.dart';
import '../accounts/account_detail_screen.dart';
import '../accounts/widgets/amount_format.dart';
import '../journals/journal_routes.dart';
import '../journals/widgets/amount_format.dart' show accountLabel;
import 'budget_figures.dart';
import 'budget_providers.dart';
import 'widgets/budget_widgets.dart';

/// Budget detail (S11, read-only) for one month: assigned / activity /
/// available with the progress bar, the linked accounts (open their detail)
/// and the month's history – assignments and the postings counted toward
/// the budget (open their transaction).
class BudgetDetailScreen extends ConsumerWidget {
  const BudgetDetailScreen({super.key, required this.name, required this.month});

  final String name;

  /// Local midnight of the month's first day.
  final DateTime month;

  Future<void> _refresh(WidgetRef ref) async {
    ref.invalidate(budgetDetailProvider((name, month)));
    ref.invalidate(budgetIntervalProvider((name, month)));
    await ref.read(budgetDetailProvider((name, month)).future);
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final theme = Theme.of(context);
    final detail = ref.watch(budgetDetailProvider((name, month)));
    final history = ref.watch(budgetIntervalProvider((name, month)));
    final commodities = ref.watch(commoditiesProvider).value ?? const <String, Commodity>{};
    final locale = Localizations.localeOf(context).toLanguageTag();
    final monthLabel = DateFormat.yMMMM(locale).format(month);
    final location = GoRouterState.of(context).uri.path;

    return Scaffold(
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(detail.value?.displayName ?? name, overflow: TextOverflow.ellipsis),
            Text(
              monthLabel,
              key: const Key('budgetDetail.month'),
              style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.onSurfaceVariant),
            ),
          ],
        ),
      ),
      body: RefreshIndicator(
        onRefresh: () => _refresh(ref),
        child: ListView(
          key: const Key('budgetDetail.list'),
          physics: const AlwaysScrollableScrollPhysics(),
          children: [
            ...detail.when(
              data: (d) => [
                _Header(budget: d, commodities: commodities),
                _SectionTitle(l10n.budgetsLinkedAccounts),
                _LinkedAccounts(accounts: d.relatedAccounts),
              ],
              loading: () => [const SizedBox(height: 160, child: Center(child: CircularProgressIndicator()))],
              error: (e, _) => [
                ErrorView(error: e, onRetry: () => ref.invalidate(budgetDetailProvider((name, month)))),
              ],
            ),
            _SectionTitle(l10n.budgetsHistory),
            ...history.when(
              data: (items) => items.isEmpty
                  ? [
                      Padding(
                        padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
                        child: Text(
                          l10n.budgetsNoHistory,
                          key: const Key('budgetDetail.noHistory'),
                          style: theme.textTheme.bodyMedium?.copyWith(color: theme.colorScheme.onSurfaceVariant),
                        ),
                      ),
                    ]
                  : [
                      for (final (i, item) in items.indexed)
                        switch (item) {
                          BudgetEvent() => _EventTile(event: item, commodities: commodities),
                          BudgetPosting(:final entry) => _PostingTile(
                            key: Key('budgetDetail.posting.$i'),
                            posting: item,
                            commodities: commodities,
                            onTap: entry.trxId.isEmpty
                                ? null
                                : () => openAccountPostingDetail(
                                    context,
                                    location,
                                    entry.trxId,
                                    (entry.payee?.isNotEmpty ?? false) ? entry.payee : entry.narration,
                                  ),
                          ),
                        },
                    ],
              loading: () => [
                const Padding(
                  padding: EdgeInsets.all(32),
                  child: Center(child: CircularProgressIndicator()),
                ),
              ],
              error: (e, _) => [
                ErrorView(error: e, onRetry: () => ref.invalidate(budgetIntervalProvider((name, month)))),
              ],
            ),
            const SizedBox(height: 96),
          ],
        ),
      ),
    );
  }
}

class _Header extends StatelessWidget {
  const _Header({required this.budget, required this.commodities});

  final BudgetDetail budget;
  final Map<String, Commodity> commodities;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final b = budget;
    final health = b.health;
    final currency = b.availableAmount.commodity;
    final over = health == BudgetHealth.over && !b.closed;
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Wrap(
            spacing: 8,
            runSpacing: 4,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              if (b.alias != null && b.alias!.isNotEmpty && b.alias != b.name)
                SelectableText(b.name, style: accountPathStyle(context)),
              if (b.category != null && b.category!.isNotEmpty)
                Chip(
                  avatar: const Icon(Icons.folder_outlined, size: 16),
                  label: Text(b.category!),
                  visualDensity: VisualDensity.compact,
                ),
              if (b.closed)
                Chip(
                  avatar: const Icon(Icons.block, size: 16),
                  label: Text(l10n.budgetsClosed),
                  visualDensity: VisualDensity.compact,
                ),
            ],
          ),
          const SizedBox(height: 8),
          Text(l10n.budgetsAvailable, style: theme.textTheme.labelLarge?.copyWith(color: scheme.onSurfaceVariant)),
          FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: Text(
              formatAmount(commodities, b.availableAmount.number, currency),
              key: const Key('budgetDetail.available'),
              style: amountStyle(
                theme.textTheme.headlineMedium?.copyWith(
                  fontWeight: FontWeight.w600,
                  color: health == BudgetHealth.ok || b.closed ? null : budgetHealthColor(context, health),
                ),
              ),
            ),
          ),
          if (over) ...[const SizedBox(height: 4), const BudgetOverBadge(key: Key('budgetDetail.over'))],
          const SizedBox(height: 12),
          BudgetProgressBar(budget: b),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: BudgetFigure(
                  key: const Key('budgetDetail.assigned'),
                  label: l10n.budgetsAssigned,
                  value: formatAmount(commodities, b.assignedAmount.number, currency),
                ),
              ),
              Expanded(
                child: BudgetFigure(
                  key: const Key('budgetDetail.activity'),
                  label: l10n.budgetsActivity,
                  value: formatAmount(commodities, b.activityAmount.number, b.activityAmount.commodity),
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(l10n.budgetsAssignedHint, style: theme.textTheme.bodySmall?.copyWith(color: scheme.onSurfaceVariant)),
        ],
      ),
    );
  }
}

class _LinkedAccounts extends StatelessWidget {
  const _LinkedAccounts({required this.accounts});

  final List<String> accounts;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    if (accounts.isEmpty) {
      return Padding(
        padding: const EdgeInsets.fromLTRB(16, 4, 16, 4),
        child: Text(
          context.l10n.budgetsNoLinkedAccounts,
          style: theme.textTheme.bodyMedium?.copyWith(color: theme.colorScheme.onSurfaceVariant),
        ),
      );
    }
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Wrap(
        spacing: 8,
        runSpacing: 4,
        children: [
          for (final a in accounts)
            ActionChip(
              key: Key('budgetDetail.account.$a'),
              avatar: const Icon(Icons.account_balance_wallet_outlined, size: 18),
              label: Text(accountLabel(a)),
              tooltip: a,
              onPressed: () => context.push(accountDetailLocation(a, base: '${AppRoutes.reports}/accounts')),
            ),
        ],
      ),
    );
  }
}

/// A `budget-add` or one side of a `budget-transfer` (`transfer_out` has a
/// negative amount).
class _EventTile extends StatelessWidget {
  const _EventTile({required this.event, required this.commodities});

  final BudgetEvent event;
  final Map<String, Commodity> commodities;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final amount = event.amount;
    final (icon, title) = switch (event.eventType) {
      'transfer_out' => (Icons.call_made, l10n.budgetsEventMovedOut),
      'transfer_in' => (Icons.call_received, l10n.budgetsEventMovedIn),
      _ => (Icons.savings_outlined, l10n.budgetsEventAssigned),
    };
    return ListTile(
      leading: CircleAvatar(
        radius: 16,
        backgroundColor: scheme.secondaryContainer,
        child: Icon(icon, size: 16, color: scheme.onSecondaryContainer),
      ),
      title: Text(title),
      subtitle: Text(DateFormat('yyyy-MM-dd HH:mm').format(event.datetime ?? event.instant.toLocal())),
      trailing: Text(
        formatAmount(commodities, amount.number, amount.commodity, signed: true),
        style: amountStyle(theme.textTheme.titleSmall?.copyWith(color: context.zhangColors.neutral)),
      ),
    );
  }
}

/// A posting counted toward the budget: spending shows as an outflow in the
/// expense colour, a refund as an inflow (money colour convention).
class _PostingTile extends StatelessWidget {
  const _PostingTile({super.key, required this.posting, required this.commodities, this.onTap});

  final BudgetPosting posting;
  final Map<String, Commodity> commodities;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final e = posting.entry;
    final title = (e.payee?.isNotEmpty ?? false) ? e.payee! : (e.narration ?? '');
    final narration = e.narration;
    final subtitle = [
      DateFormat('yyyy-MM-dd HH:mm').format(e.datetime),
      accountLabel(e.account),
      if (narration != null && narration.isNotEmpty && narration != title) narration,
    ].join(' · ');
    final flow = -e.inferredUnit.number;
    return ListTile(
      onTap: onTap,
      leading: CircleAvatar(
        radius: 16,
        backgroundColor: scheme.surfaceContainerHighest,
        child: Icon(
          flow < Decimal.zero ? Icons.north_east : Icons.south_west,
          size: 16,
          color: scheme.onSurfaceVariant,
        ),
      ),
      title: Text(title, maxLines: 1, overflow: TextOverflow.ellipsis),
      subtitle: Text(subtitle, maxLines: 2, overflow: TextOverflow.ellipsis),
      trailing: Text(
        formatAmount(commodities, flow, e.inferredUnit.commodity, signed: true),
        style: amountStyle(theme.textTheme.titleSmall?.copyWith(color: amountColor(context, flow))),
      ),
    );
  }
}

class _SectionTitle extends StatelessWidget {
  const _SectionTitle(this.text);

  final String text;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.fromLTRB(16, 20, 16, 6),
    child: Text(
      text,
      style: Theme.of(context).textTheme.titleSmall?.copyWith(color: Theme.of(context).colorScheme.primary),
    ),
  );
}
