import 'dart:math' as math;

import 'package:decimal/decimal.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../../core/theme/app_colors.dart';
import '../../../data/models/commodity.dart';
import '../../../l10n/l10n.dart';
import '../../accounts/widgets/amount_format.dart';
import '../report_aggregation.dart';
import '../report_period.dart';

const double _kLeftReserved = 44;
const double _kBottomReserved = 22;

/// A "nice" axis step (1, 2, 2.5, 5 × 10^n) for about [range] / 4.
double niceStep(double range) {
  if (range <= 0) return 1;
  final raw = range / 4;
  final mag = math.pow(10, (math.log(raw) / math.ln10).floor()).toDouble();
  final norm = raw / mag;
  final step = norm <= 1 ? 1.0 : (norm <= 2 ? 2.0 : (norm <= 2.5 ? 2.5 : (norm <= 5 ? 5.0 : 10.0)));
  return step * mag;
}

/// Card: income vs expense grouped bars per bucket with a net line overlay,
/// sharing one y axis.
class CashflowChartCard extends StatelessWidget {
  const CashflowChartCard({
    super.key,
    required this.buckets,
    required this.period,
    required this.commodity,
    required this.commodities,
  });

  final List<CashflowBucket> buckets;
  final ReportPeriod period;
  final String commodity;
  final Map<String, Commodity> commodities;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final theme = Theme.of(context);
    final colors = context.zhangColors;
    final hasData = buckets.any((b) => b.income != Decimal.zero || b.expense != Decimal.zero);
    return Card.outlined(
      margin: const EdgeInsets.fromLTRB(16, 8, 16, 8),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(12, 12, 16, 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.only(left: 4),
              child: Text(l10n.reportsCashflowTitle, style: theme.textTheme.titleSmall),
            ),
            const SizedBox(height: 6),
            Padding(
              padding: const EdgeInsets.only(left: 4),
              child: Wrap(
                spacing: 16,
                runSpacing: 4,
                children: [
                  _LegendItem(color: colors.income, label: l10n.reportsIncome),
                  _LegendItem(color: colors.expense, label: l10n.reportsExpense),
                  _LegendItem(color: theme.colorScheme.onSurface, label: l10n.reportsNet, line: true),
                ],
              ),
            ),
            const SizedBox(height: 12),
            if (hasData)
              SizedBox(
                height: 200,
                child: _CashflowChart(
                  key: const Key('reports.cashflowChart'),
                  buckets: buckets,
                  period: period,
                  commodity: commodity,
                  commodities: commodities,
                ),
              )
            else
              SizedBox(
                height: 120,
                child: Center(
                  child: Text(
                    l10n.reportsNoData,
                    key: const Key('reports.cashflowEmpty'),
                    style: theme.textTheme.bodyMedium?.copyWith(color: theme.colorScheme.onSurfaceVariant),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _LegendItem extends StatelessWidget {
  const _LegendItem({required this.color, required this.label, this.line = false});

  final Color color;
  final String label;
  final bool line;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: line ? 14 : 10,
          height: line ? 2 : 10,
          decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(line ? 1 : 2)),
        ),
        const SizedBox(width: 6),
        Text(label, style: theme.textTheme.labelMedium?.copyWith(color: theme.colorScheme.onSurfaceVariant)),
      ],
    );
  }
}

class _CashflowChart extends StatelessWidget {
  const _CashflowChart({
    super.key,
    required this.buckets,
    required this.period,
    required this.commodity,
    required this.commodities,
  });

  final List<CashflowBucket> buckets;
  final ReportPeriod period;
  final String commodity;
  final Map<String, Commodity> commodities;

  String _axisLabel(DateTime start, String locale) => switch (period.bucketUnit) {
    BucketUnit.day =>
      period.kind == PeriodKind.week ? DateFormat.E(locale).format(start) : DateFormat.d(locale).format(start),
    BucketUnit.week => DateFormat.Md(locale).format(start),
    BucketUnit.month => DateFormat.MMM(locale).format(start),
  };

  String _tooltipLabel(int i, String locale) {
    final start = buckets[i].start;
    switch (period.bucketUnit) {
      case BucketUnit.day:
        return DateFormat.yMMMEd(locale).format(start);
      case BucketUnit.week:
        final next = i + 1 < buckets.length ? buckets[i + 1].start : period.endExclusive;
        final last = DateTime(next.year, next.month, next.day - 1);
        return '${DateFormat.MMMd(locale).format(start)} – ${DateFormat.MMMd(locale).format(last)}';
      case BucketUnit.month:
        return DateFormat.yMMM(locale).format(start);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final colors = context.zhangColors;
    final locale = Localizations.localeOf(context).toLanguageTag();
    final n = buckets.length;
    final income = [for (final b in buckets) b.income.toDouble()];
    final expense = [for (final b in buckets) b.expense.toDouble()];
    final net = [for (final b in buckets) b.net.toDouble()];

    final rawMax = [0.0, ...income, ...expense, ...net].reduce(math.max);
    final rawMin = [0.0, ...net, ...income, ...expense].reduce(math.min);
    final interval = niceStep(rawMax - rawMin);
    // Top snaps to a grid line; a negative bottom only gets a little padding
    // (snapping it would waste a whole step for a small negative net day).
    var maxY = (rawMax / interval).ceil() * interval;
    if (maxY <= 0) maxY = interval;
    final minY = rawMin < 0 ? rawMin - (maxY - rawMin) * 0.04 : 0.0;

    final axisStyle = theme.textTheme.labelSmall?.copyWith(color: scheme.onSurfaceVariant);
    final labelEvery = math.max(1, (n / 8).ceil());

    Widget leftTitle(double value, TitleMeta meta) => SideTitleWidget(
      meta: meta,
      child: Text(formatCompactNumber(context, value), style: axisStyle),
    );
    Widget bottomTitle(double value, TitleMeta meta) {
      final i = value.round();
      if (i < 0 || i >= n || i % labelEvery != 0) return const SizedBox.shrink();
      return SideTitleWidget(meta: meta, child: Text(_axisLabel(buckets[i].start, locale), style: axisStyle));
    }

    Widget empty(double value, TitleMeta meta) => const SizedBox.shrink();

    FlTitlesData titles({required bool visible}) => FlTitlesData(
      topTitles: const AxisTitles(),
      rightTitles: const AxisTitles(),
      leftTitles: AxisTitles(
        sideTitles: SideTitles(
          showTitles: true,
          reservedSize: _kLeftReserved,
          interval: interval,
          // A padded negative minimum is not a round number; 0 is still labelled.
          minIncluded: minY == 0,
          getTitlesWidget: visible ? leftTitle : empty,
        ),
      ),
      bottomTitles: AxisTitles(
        sideTitles: SideTitles(
          showTitles: true,
          reservedSize: _kBottomReserved,
          getTitlesWidget: visible ? bottomTitle : empty,
        ),
      ),
    );

    return LayoutBuilder(
      builder: (context, constraints) {
        final plotWidth = math.max(1.0, constraints.maxWidth - _kLeftReserved);
        final groupWidth = plotWidth / n;
        final rodWidth = (groupWidth * 0.36).clamp(2.0, 14.0);
        final radius = Radius.circular(math.min(4, rodWidth / 2));
        BarChartRodData rod(double v, Color c) => BarChartRodData(
          toY: v,
          color: c,
          width: rodWidth,
          borderRadius: v >= 0 ? BorderRadius.vertical(top: radius) : BorderRadius.vertical(bottom: radius),
          // Full-height transparent back rod: makes the whole column touchable.
          backDrawRodData: BackgroundBarChartRodData(show: true, fromY: minY, toY: maxY, color: Colors.transparent),
        );

        final tooltipStyle = amountStyle(theme.textTheme.labelMedium?.copyWith(color: scheme.onInverseSurface));
        String fmt(Decimal v, {bool signed = false}) => formatAmount(commodities, v, commodity, signed: signed);

        final bars = BarChart(
          BarChartData(
            alignment: BarChartAlignment.spaceAround,
            maxY: maxY,
            minY: minY,
            gridData: FlGridData(
              drawVerticalLine: false,
              horizontalInterval: interval,
              getDrawingHorizontalLine: (v) =>
                  FlLine(color: v == 0 ? scheme.outline : scheme.outlineVariant, strokeWidth: v == 0 ? 1 : 0.5),
            ),
            borderData: FlBorderData(show: false),
            titlesData: titles(visible: true),
            barTouchData: BarTouchData(
              allowTouchBarBackDraw: true,
              touchTooltipData: BarTouchTooltipData(
                fitInsideHorizontally: true,
                fitInsideVertically: true,
                maxContentWidth: 200,
                getTooltipColor: (_) => scheme.inverseSurface,
                getTooltipItem: (group, groupIndex, rod, rodIndex) {
                  final b = buckets[groupIndex];
                  return BarTooltipItem(
                    '${_tooltipLabel(groupIndex, locale)}\n'
                    '${l10n.reportsIncome} ${fmt(b.income)}\n'
                    '${l10n.reportsExpense} ${fmt(b.expense)}\n'
                    '${l10n.reportsNet} ${fmt(b.net, signed: true)}',
                    tooltipStyle,
                    textAlign: TextAlign.start,
                  );
                },
              ),
            ),
            barGroups: [
              for (var i = 0; i < n; i++)
                BarChartGroupData(
                  x: i,
                  barsSpace: rodWidth > 4 ? 2 : 1,
                  barRods: [rod(income[i], colors.income), rod(expense[i], colors.expense)],
                ),
            ],
          ),
        );

        // Net line drawn on top with the same axes; group i is centred at
        // (i + 0.5) / n of the plot width with BarChartAlignment.spaceAround,
        // which is x = i on a [-0.5, n - 0.5] line axis.
        final line = IgnorePointer(
          child: LineChart(
            LineChartData(
              minX: -0.5,
              maxX: n - 0.5,
              minY: minY,
              maxY: maxY,
              gridData: const FlGridData(show: false),
              borderData: FlBorderData(show: false),
              titlesData: titles(visible: false),
              lineTouchData: const LineTouchData(enabled: false),
              lineBarsData: [
                LineChartBarData(
                  spots: [for (var i = 0; i < n; i++) FlSpot(i.toDouble(), net[i])],
                  color: scheme.onSurface,
                  barWidth: 2,
                  dotData: FlDotData(
                    show: n <= 12,
                    getDotPainter: (spot, percent, bar, index) => FlDotCirclePainter(
                      radius: 3,
                      color: scheme.onSurface,
                      strokeWidth: 2,
                      strokeColor: scheme.surface,
                    ),
                  ),
                ),
              ],
            ),
          ),
        );

        return Stack(children: [Positioned.fill(child: bars), Positioned.fill(child: line)]);
      },
    );
  }
}
