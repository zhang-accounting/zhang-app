import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../l10n/l10n.dart';
import '../report_period.dart';
import '../reports_providers.dart';

/// Week / month / year / custom selector with ← → stepping.
class PeriodSelector extends ConsumerWidget {
  const PeriodSelector({super.key});

  Future<void> _pickCustom(BuildContext context, WidgetRef ref) async {
    final period = ref.read(reportPeriodProvider);
    final now = ref.read(reportsClockProvider)();
    final range = await showDateRangePicker(
      context: context,
      firstDate: DateTime(1970),
      lastDate: DateTime(now.year + 1, 12, 31),
      initialDateRange: DateTimeRange(start: period.start, end: period.lastDay),
      helpText: context.l10n.reportsPickRange,
    );
    if (range != null) {
      ref.read(reportPeriodProvider.notifier).setCustom(range.start, range.end);
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final theme = Theme.of(context);
    final period = ref.watch(reportPeriodProvider);
    final now = ref.watch(reportsClockProvider)();
    final notifier = ref.read(reportPeriodProvider.notifier);
    final locale = Localizations.localeOf(context).toLanguageTag();
    final canGoNext = !period.step(1).start.isAfter(now);

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
      child: Column(
        children: [
          SizedBox(
            width: double.infinity,
            child: SegmentedButton<PeriodKind>(
              key: const Key('reports.periodKind'),
              showSelectedIcon: false,
              style: const ButtonStyle(visualDensity: VisualDensity.compact),
              segments: [
                ButtonSegment(value: PeriodKind.week, label: Text(l10n.reportsPeriodWeek)),
                ButtonSegment(value: PeriodKind.month, label: Text(l10n.reportsPeriodMonth)),
                ButtonSegment(value: PeriodKind.year, label: Text(l10n.reportsPeriodYear)),
                ButtonSegment(value: PeriodKind.custom, label: Text(l10n.reportsPeriodCustom)),
              ],
              selected: {period.kind},
              onSelectionChanged: (s) {
                final kind = s.first;
                if (kind == PeriodKind.custom) {
                  _pickCustom(context, ref);
                } else {
                  notifier.setKind(kind);
                }
              },
            ),
          ),
          const SizedBox(height: 4),
          Row(
            children: [
              IconButton(
                key: const Key('reports.prevPeriod'),
                tooltip: l10n.reportsPreviousPeriod,
                icon: const Icon(Icons.chevron_left),
                onPressed: () => notifier.step(-1),
              ),
              Expanded(
                child: InkWell(
                  borderRadius: BorderRadius.circular(8),
                  onTap: period.kind == PeriodKind.custom ? () => _pickCustom(context, ref) : null,
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    child: Text(
                      period.label(locale),
                      key: const Key('reports.periodLabel'),
                      textAlign: TextAlign.center,
                      style: theme.textTheme.titleMedium,
                    ),
                  ),
                ),
              ),
              IconButton(
                key: const Key('reports.nextPeriod'),
                tooltip: l10n.reportsNextPeriod,
                icon: const Icon(Icons.chevron_right),
                onPressed: canGoNext ? () => notifier.step(1) : null,
              ),
            ],
          ),
        ],
      ),
    );
  }
}
