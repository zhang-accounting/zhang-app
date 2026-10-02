import 'dart:math' as math;

import 'package:decimal/decimal.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../../data/models/account.dart';
import '../../../data/models/commodity.dart';
import '../../../l10n/l10n.dart';
import 'amount_format.dart';

/// A point of the step line: calendar day + balance.
class BalanceStep {
  const BalanceStep(this.day, this.value);

  /// Local midnight.
  final DateTime day;
  final Decimal value;
}

int _dayNumber(DateTime d) => DateTime.utc(d.year, d.month, d.day).millisecondsSinceEpoch ~/ 86400000;

DateTime _fromDayNumber(int n) {
  final u = DateTime.fromMillisecondsSinceEpoch(n * 86400000, isUtc: true);
  return DateTime(u.year, u.month, u.day);
}

/// Balance points of [commodity], extended with a final point at [today]
/// (balances only change on posting days, so the last value holds).
List<BalanceStep> balanceSteps(AccountBalanceHistory history, String commodity, DateTime today) {
  final points = history.byCommodity[commodity] ?? const [];
  final steps = [for (final p in points) BalanceStep(p.date, p.balance.number)];
  if (steps.isNotEmpty) {
    final last = steps.last;
    final day = DateTime(today.year, today.month, today.day);
    if (day.isAfter(last.day)) steps.add(BalanceStep(day, last.value));
  }
  return steps;
}

/// Card with a step line of an account's daily balance per commodity
/// (choice chips when the account holds several commodities).
class BalanceHistoryCard extends StatefulWidget {
  const BalanceHistoryCard({
    super.key,
    required this.history,
    required this.commodities,
    this.preferredCommodity,
  });

  final AccountBalanceHistory history;
  final Map<String, Commodity> commodities;

  /// Initially selected commodity (e.g. the operating currency) if present.
  final String? preferredCommodity;

  @override
  State<BalanceHistoryCard> createState() => _BalanceHistoryCardState();
}

class _BalanceHistoryCardState extends State<BalanceHistoryCard> {
  String? _selected;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final theme = Theme.of(context);
    final codes = widget.history.commodities;
    final selected = (_selected != null && codes.contains(_selected))
        ? _selected!
        : (codes.contains(widget.preferredCommodity)
              ? widget.preferredCommodity!
              : (codes.isEmpty ? null : codes.first));
    final steps = selected == null
        ? const <BalanceStep>[]
        : balanceSteps(widget.history, selected, DateTime.now());

    return Card.outlined(
      margin: const EdgeInsets.fromLTRB(16, 8, 16, 8),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(child: Text(l10n.accountsBalanceHistory, style: theme.textTheme.titleSmall)),
                if (codes.length > 1)
                  Wrap(
                    spacing: 6,
                    children: [
                      for (final c in codes)
                        ChoiceChip(
                          label: Text(c),
                          visualDensity: VisualDensity.compact,
                          selected: c == selected,
                          onSelected: (_) => setState(() => _selected = c),
                        ),
                    ],
                  ),
              ],
            ),
            const SizedBox(height: 12),
            if (steps.isEmpty)
              SizedBox(
                height: 80,
                child: Center(
                  child: Text(
                    l10n.accountsNoBalanceHistory,
                    style: theme.textTheme.bodyMedium?.copyWith(color: theme.colorScheme.onSurfaceVariant),
                  ),
                ),
              )
            else
              SizedBox(
                height: 180,
                child: _StepChart(
                  key: const Key('accountDetail.balanceChart'),
                  steps: steps,
                  commodity: selected!,
                  commodities: widget.commodities,
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _StepChart extends StatelessWidget {
  const _StepChart({super.key, required this.steps, required this.commodity, required this.commodities});

  final List<BalanceStep> steps;
  final String commodity;
  final Map<String, Commodity> commodities;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final locale = Localizations.localeOf(context).toLanguageTag();
    final spots = [
      for (final s in steps) FlSpot(_dayNumber(s.day).toDouble(), s.value.toDouble()),
    ];
    var minX = spots.first.x;
    var maxX = spots.last.x;
    if (maxX - minX < 1) {
      minX -= 1;
      maxX += 1;
    }
    var minY = spots.map((s) => s.y).reduce(math.min);
    var maxY = spots.map((s) => s.y).reduce(math.max);
    minY = math.min(minY, 0);
    maxY = math.max(maxY, 0);
    if (maxY - minY == 0) {
      maxY += 1;
      minY -= 1;
    }
    final pad = (maxY - minY) * 0.08;
    maxY += pad;
    if (minY < 0) minY -= pad;
    final spanDays = maxX - minX;
    final dateFormat = spanDays > 120 ? DateFormat.yMMM(locale) : DateFormat.MMMd(locale);
    final axisStyle = theme.textTheme.labelSmall?.copyWith(color: scheme.onSurfaceVariant);
    final color = scheme.primary;

    return LineChart(
      LineChartData(
        minX: minX,
        maxX: maxX,
        minY: minY,
        maxY: maxY,
        clipData: const FlClipData.all(),
        gridData: FlGridData(
          drawVerticalLine: false,
          getDrawingHorizontalLine: (_) => FlLine(color: scheme.outlineVariant, strokeWidth: 0.5),
        ),
        borderData: FlBorderData(show: false),
        titlesData: FlTitlesData(
          topTitles: const AxisTitles(),
          rightTitles: const AxisTitles(),
          leftTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              reservedSize: 44,
              getTitlesWidget: (value, meta) {
                if (value == meta.max || value == meta.min) return const SizedBox.shrink();
                return SideTitleWidget(
                  meta: meta,
                  child: Text(formatCompactNumber(context, value), style: axisStyle),
                );
              },
            ),
          ),
          bottomTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              reservedSize: 24,
              interval: math.max(1, spanDays / 3),
              getTitlesWidget: (value, meta) => SideTitleWidget(
                meta: meta,
                fitInside: SideTitleFitInsideData.fromTitleMeta(meta),
                child: Text(dateFormat.format(_fromDayNumber(value.round())), style: axisStyle),
              ),
            ),
          ),
        ),
        lineTouchData: LineTouchData(
          touchTooltipData: LineTouchTooltipData(
            fitInsideHorizontally: true,
            fitInsideVertically: true,
            getTooltipColor: (_) => scheme.inverseSurface,
            getTooltipItems: (spots) => [
              for (final s in spots)
                LineTooltipItem(
                  '${DateFormat.yMMMd(locale).format(_fromDayNumber(s.x.round()))}\n'
                  '${formatAmount(commodities, steps[s.spotIndex].value, commodity)}',
                  amountStyle(theme.textTheme.labelMedium?.copyWith(color: scheme.onInverseSurface)),
                ),
            ],
          ),
        ),
        lineBarsData: [
          LineChartBarData(
            spots: spots,
            isStepLineChart: true,
            color: color,
            barWidth: 2,
            dotData: FlDotData(show: spots.length <= 2),
            belowBarData: BarAreaData(show: true, color: color.withValues(alpha: 0.10)),
          ),
        ],
      ),
    );
  }
}
