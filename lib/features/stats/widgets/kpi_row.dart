import 'package:decimal/decimal.dart';
import 'package:flutter/material.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/utils/money.dart';
import '../../../data/models/commodity.dart';
import '../../../data/models/statistic.dart';
import '../../../l10n/l10n.dart';
import '../../accounts/widgets/amount_format.dart';

/// Income / expense / net of a period, from `/api/statistic/summary`.
/// Income is shown as a positive number (the ledger stores it negative).
class KpiRow extends StatelessWidget {
  const KpiRow({super.key, required this.summary, required this.commodities});

  final StatisticSummary summary;
  final Map<String, Commodity> commodities;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final colors = context.zhangColors;
    final commodity = summary.expense.calculated.commodity;
    final income = -summary.income.calculated.number;
    final expense = summary.expense.calculated.number;
    final net = income - expense;
    return Card.filled(
      margin: const EdgeInsets.fromLTRB(16, 8, 16, 8),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: _Kpi(
                key: const Key('reports.kpi.income'),
                label: l10n.reportsIncome,
                value: formatAmount(commodities, income, commodity),
                color: colors.income,
              ),
            ),
            Expanded(
              child: _Kpi(
                key: const Key('reports.kpi.expense'),
                label: l10n.reportsExpense,
                value: formatAmount(commodities, expense, commodity),
                color: colors.expense,
              ),
            ),
            Expanded(
              child: _Kpi(
                key: const Key('reports.kpi.net'),
                label: l10n.reportsNet,
                value: formatAmount(commodities, net, commodity, signed: true),
                color: net == Decimal.zero ? null : amountColor(context, net),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _Kpi extends StatelessWidget {
  const _Kpi({super.key, required this.label, required this.value, this.color});

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
          Text(
            label,
            style: theme.textTheme.labelMedium?.copyWith(color: theme.colorScheme.onSurfaceVariant),
          ),
          const SizedBox(height: 2),
          FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: Text(
              value,
              style: amountStyle(theme.textTheme.titleMedium?.copyWith(
                color: color,
                fontWeight: FontWeight.w600,
              )),
            ),
          ),
        ],
      ),
    );
  }
}
