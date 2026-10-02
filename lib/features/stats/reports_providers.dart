import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/models/account.dart';
import '../../data/models/statistic.dart';
import '../../data/repositories/ledger_revision.dart';
import '../../data/repositories/statistic_repository.dart';
import 'report_period.dart';

/// Clock used to pick the initial period (overridable in tests).
final reportsClockProvider = Provider<DateTime Function()>((ref) => DateTime.now);

/// The selected reporting period (current month by default).
final reportPeriodProvider = NotifierProvider<ReportPeriodController, ReportPeriod>(
  ReportPeriodController.new,
);

class ReportPeriodController extends Notifier<ReportPeriod> {
  @override
  ReportPeriod build() => ReportPeriod.month(ref.read(reportsClockProvider)());

  /// Switch to week / month / year. Keeps "now" when the current period
  /// contains it, else anchors on the current period's first day.
  void setKind(PeriodKind kind) {
    if (kind == PeriodKind.custom || kind == state.kind) return;
    final now = ref.read(reportsClockProvider)();
    final anchor = state.contains(now) ? now : state.start;
    state = ReportPeriod.of(kind, anchor);
  }

  void setCustom(DateTime first, DateTime last) => state = ReportPeriod.custom(first, last);

  void step(int delta) => state = state.step(delta);
}

/// `GET /api/statistic/summary` for a period.
final reportSummaryProvider = FutureProvider.autoDispose.family<StatisticSummary, ReportPeriod>((
  ref,
  period,
) {
  ref.watch(ledgerRevisionProvider);
  return ref.watch(statisticRepositoryProvider).summary(period.start, period.end);
});

/// `GET /api/statistic/graph` for a period (always daily).
final reportGraphProvider = FutureProvider.autoDispose.family<StatisticGraph, ReportPeriod>((
  ref,
  period,
) {
  ref.watch(ledgerRevisionProvider);
  return ref.watch(statisticRepositoryProvider).graph(period.start, period.end);
});

/// `GET /api/statistic/{type}` for a period.
final reportRankProvider =
    FutureProvider.autoDispose.family<StatisticRank, (AccountType, ReportPeriod)>((ref, arg) {
      ref.watch(ledgerRevisionProvider);
      final (type, period) = arg;
      return ref.watch(statisticRepositoryProvider).rank(type, period.start, period.end);
    });
