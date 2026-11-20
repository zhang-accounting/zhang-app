import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../l10n/l10n.dart';
import '../../stats/reports_providers.dart';
import '../budget_month.dart';

/// ‹ month › stepper of the Budgets segment (budgets are monthly). Like the
/// Reports period selector it does not step past the current month.
class BudgetMonthSelector extends ConsumerWidget {
  const BudgetMonthSelector({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final month = ref.watch(budgetMonthProvider);
    final now = ref.watch(reportsClockProvider)();
    final notifier = ref.read(budgetMonthProvider.notifier);
    final locale = Localizations.localeOf(context).toLanguageTag();
    final canGoNext = DateTime(month.year, month.month + 1).isBefore(DateTime(now.year, now.month + 1));
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
      child: Row(
        children: [
          IconButton(
            key: const Key('budgets.prevMonth'),
            tooltip: l10n.budgetsPreviousMonth,
            icon: const Icon(Icons.chevron_left),
            onPressed: () => notifier.step(-1),
          ),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 8),
              child: Text(
                DateFormat.yMMMM(locale).format(month),
                key: const Key('budgets.monthLabel'),
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.titleMedium,
              ),
            ),
          ),
          IconButton(
            key: const Key('budgets.nextMonth'),
            tooltip: l10n.budgetsNextMonth,
            icon: const Icon(Icons.chevron_right),
            onPressed: canGoNext ? () => notifier.step(1) : null,
          ),
        ],
      ),
    );
  }
}
