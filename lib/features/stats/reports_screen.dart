import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/widgets/error_view.dart';
import '../../data/models/account.dart';
import '../../data/models/commodity.dart';
import '../../data/repositories/ledger_data_providers.dart';
import '../../l10n/l10n.dart';
import '../../router.dart';
import '../accounts/account_detail_screen.dart';
import 'report_aggregation.dart';
import 'reports_providers.dart';
import 'widgets/cashflow_chart.dart';
import 'widgets/category_breakdown.dart';
import 'widgets/kpi_row.dart';
import 'widgets/period_selector.dart';

/// Reports tab (S10): period selector, KPI row, income/expense bars with a
/// net line, and the category breakdown (donut + ranked bars, drill-down).
class ReportsScreen extends ConsumerStatefulWidget {
  const ReportsScreen({super.key});

  @override
  ConsumerState<ReportsScreen> createState() => _ReportsScreenState();
}

class _ReportsScreenState extends ConsumerState<ReportsScreen> {
  AccountType _rankType = AccountType.expenses;

  /// Current drill-down level of the breakdown (`null` = top of the type).
  String? _parent;

  Future<void> _refresh() async {
    final period = ref.read(reportPeriodProvider);
    ref.invalidate(reportSummaryProvider(period));
    ref.invalidate(reportGraphProvider(period));
    ref.invalidate(reportRankProvider((_rankType, period)));
    await ref.read(reportSummaryProvider(period).future);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final period = ref.watch(reportPeriodProvider);
    final summary = ref.watch(reportSummaryProvider(period));
    final graph = ref.watch(reportGraphProvider(period));
    final rank = ref.watch(reportRankProvider((_rankType, period)));
    final commodities = ref.watch(commoditiesProvider).value ?? const <String, Commodity>{};
    final operatingCurrency = ref.watch(ledgerOptionsProvider).value?.operatingCurrency ??
        summary.value?.expense.calculated.commodity ??
        'CNY';
    final parent = _parent ?? _rankType.wire;

    Widget cardError(Object e, VoidCallback retry) => _CardError(error: e, onRetry: retry);

    return Scaffold(
      appBar: AppBar(title: Text(l10n.tabReports)),
      body: RefreshIndicator(
        onRefresh: _refresh,
        child: ListView(
          key: const Key('reports.list'),
          physics: const AlwaysScrollableScrollPhysics(),
          children: [
            const PeriodSelector(),
            summary.when(
              data: (s) => KpiRow(summary: s, commodities: commodities),
              loading: () => const _CardPlaceholder(height: 76),
              error: (e, _) => cardError(e, () => ref.invalidate(reportSummaryProvider(period))),
            ),
            graph.when(
              data: (g) => CashflowChartCard(
                buckets: bucketCashflow(g, period),
                period: period,
                commodity: operatingCurrency,
                commodities: commodities,
              ),
              loading: () => const _CardPlaceholder(height: 260),
              error: (e, _) => cardError(e, () => ref.invalidate(reportGraphProvider(period))),
            ),
            CategoryBreakdownCard(
              type: _rankType,
              parent: parent,
              onTypeChanged: (t) => setState(() {
                _rankType = t;
                _parent = null;
              }),
              onParentChanged: (p) => setState(() => _parent = p),
              body: rank.when(
                data: (r) => CategoryBreakdownBody(
                  rank: r,
                  type: _rankType,
                  parent: parent,
                  commodity: operatingCurrency,
                  commodities: commodities,
                  onDrill: (key) => setState(() => _parent = key),
                  onOpenAccount: (name) =>
                      context.push(accountDetailLocation(name, base: '${AppRoutes.reports}/accounts')),
                ),
                loading: () => const SizedBox(height: 200, child: Center(child: CircularProgressIndicator())),
                error: (e, _) => cardError(e, () => ref.invalidate(reportRankProvider((_rankType, period)))),
              ),
            ),
            // Room for the docked FAB.
            const SizedBox(height: 96),
          ],
        ),
      ),
    );
  }
}

class _CardPlaceholder extends StatelessWidget {
  const _CardPlaceholder({required this.height});

  final double height;

  @override
  Widget build(BuildContext context) => Card.outlined(
    margin: const EdgeInsets.fromLTRB(16, 8, 16, 8),
    child: SizedBox(
      height: height,
      child: const Center(
        child: SizedBox(width: 24, height: 24, child: CircularProgressIndicator(strokeWidth: 2)),
      ),
    ),
  );
}

/// Card-level error: message + retry, without taking over the screen.
class _CardError extends StatelessWidget {
  const _CardError({required this.error, required this.onRetry});

  final Object error;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Card.outlined(
      margin: const EdgeInsets.fromLTRB(16, 8, 16, 8),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 8, 8, 8),
        child: Row(
          children: [
            Icon(iconForApiError(error), color: theme.colorScheme.error),
            const SizedBox(width: 12),
            Expanded(child: Text(describeApiError(context.l10n, error), style: theme.textTheme.bodyMedium)),
            TextButton(onPressed: onRetry, child: Text(context.l10n.retry)),
          ],
        ),
      ),
    );
  }
}
