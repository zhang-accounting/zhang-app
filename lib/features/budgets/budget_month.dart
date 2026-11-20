import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../stats/report_period.dart';
import '../stats/reports_providers.dart';

/// The month a Reports period stands for in the Budgets segment: the
/// current month when the period contains it, else the month of its first
/// day.
DateTime budgetMonthOf(ReportPeriod period, DateTime now) {
  final anchor = period.contains(now) ? now : period.start;
  return DateTime(anchor.year, anchor.month);
}

/// The month shown in the Budgets segment (local midnight of the 1st).
///
/// Derived from the shared Reports period without changing it: a week, year
/// or custom range stays as it is for the income / expense segment. Stepping
/// here moves the shared period too only when it is a month, so both
/// segments keep showing the same month.
final budgetMonthProvider = NotifierProvider<BudgetMonthController, DateTime>(BudgetMonthController.new);

class BudgetMonthController extends Notifier<DateTime> {
  @override
  DateTime build() => budgetMonthOf(ref.watch(reportPeriodProvider), ref.watch(reportsClockProvider)());

  void step(int delta) {
    if (ref.read(reportPeriodProvider).kind == PeriodKind.month) {
      // Rebuilds this provider with the new month.
      ref.read(reportPeriodProvider.notifier).step(delta);
    } else {
      state = DateTime(state.year, state.month + delta);
    }
  }
}
