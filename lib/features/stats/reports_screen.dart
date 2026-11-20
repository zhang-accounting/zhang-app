import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../data/models/account.dart';
import '../../data/models/commodity.dart';
import '../../data/repositories/ledger_data_providers.dart';
import '../../l10n/l10n.dart';
import '../../router.dart';
import '../accounts/account_detail_screen.dart';
import '../budgets/budgets_view.dart';
import 'report_aggregation.dart';
import 'report_period.dart';
import 'reports_providers.dart';
import 'widgets/cashflow_chart.dart';
import 'widgets/category_breakdown.dart';
import 'widgets/kpi_row.dart';
import 'widgets/period_selector.dart';
import 'widgets/report_cards.dart';

/// The two segments of the Reports tab (decisions #2: budgets live here, not
/// in a tab of their own).
enum ReportsSegment { flows, budgets }

/// Reports tab (S10): period selector, KPI row, income/expense bars with a
/// net line, and the category breakdown (donut + ranked bars, drill-down);
/// the Budgets segment (S11) shows [BudgetsView] for the same month.
class ReportsScreen extends ConsumerStatefulWidget {
  const ReportsScreen({super.key});

  @override
  ConsumerState<ReportsScreen> createState() => _ReportsScreenState();
}

class _ReportsScreenState extends ConsumerState<ReportsScreen> {
  ReportsSegment _segment = ReportsSegment.flows;
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

  /// Budgets are monthly: entering their segment turns the shared period
  /// into the month containing it.
  void _setSegment(ReportsSegment segment) {
    if (segment == ReportsSegment.budgets) {
      ref.read(reportPeriodProvider.notifier).setKind(PeriodKind.month);
    }
    setState(() => _segment = segment);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.tabReports),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(52),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
            child: SizedBox(
              width: double.infinity,
              child: SegmentedButton<ReportsSegment>(
                key: const Key('reports.segment'),
                showSelectedIcon: false,
                segments: [
                  ButtonSegment(value: ReportsSegment.flows, label: Text(l10n.reportsSegmentFlows)),
                  ButtonSegment(value: ReportsSegment.budgets, label: Text(l10n.reportsSegmentBudgets)),
                ],
                selected: {_segment},
                onSelectionChanged: (s) => _setSegment(s.first),
              ),
            ),
          ),
        ),
      ),
      body: switch (_segment) {
        ReportsSegment.flows => _flows(context),
        ReportsSegment.budgets => const BudgetsView(),
      },
    );
  }

  Widget _flows(BuildContext context) {
    final period = ref.watch(reportPeriodProvider);
    final summary = ref.watch(reportSummaryProvider(period));
    final graph = ref.watch(reportGraphProvider(period));
    final rank = ref.watch(reportRankProvider((_rankType, period)));
    final commodities = ref.watch(commoditiesProvider).value ?? const <String, Commodity>{};
    final operatingCurrency = ref.watch(ledgerOptionsProvider).value?.operatingCurrency ??
        summary.value?.expense.calculated.commodity ??
        'CNY';
    final parent = _parent ?? _rankType.wire;

    Widget cardError(Object e, VoidCallback retry) => ReportCardError(error: e, onRetry: retry);

    return RefreshIndicator(
      onRefresh: _refresh,
      child: ListView(
        key: const Key('reports.list'),
        physics: const AlwaysScrollableScrollPhysics(),
        children: [
          const PeriodSelector(),
          summary.when(
            data: (s) => KpiRow(summary: s, commodities: commodities),
            loading: () => const ReportCardPlaceholder(height: 76),
            error: (e, _) => cardError(e, () => ref.invalidate(reportSummaryProvider(period))),
          ),
          graph.when(
            data: (g) => CashflowChartCard(
              buckets: bucketCashflow(g, period),
              period: period,
              commodity: operatingCurrency,
              commodities: commodities,
            ),
            loading: () => const ReportCardPlaceholder(height: 260),
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
    );
  }
}
