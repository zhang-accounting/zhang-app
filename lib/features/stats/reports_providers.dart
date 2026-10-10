import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/models/account.dart';
import '../../data/models/statistic.dart';
import '../../data/repositories/ledger_data_providers.dart';
import '../../data/repositories/ledger_revision.dart';
import '../../data/repositories/statistic_repository.dart';
import 'report_period.dart';

/// Clock used to pick the initial period: the ledger's clock (overridable in
/// tests).
final reportsClockProvider = Provider<DateTime Function()>((ref) => ref.watch(ledgerClockProvider));

/// The selected reporting period (current month by default).
final reportPeriodProvider = NotifierProvider<ReportPeriodController, ReportPeriod>(
  ReportPeriodController.new,
);

class ReportPeriodController extends Notifier<ReportPeriod> {
  @override
  ReportPeriod build() => ReportPeriod.month(ref.watch(reportsClockProvider)());

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

/// Summary figures of a period (`report.*` built-in queries in the
/// operating currency).
final reportSummaryProvider = FutureProvider.autoDispose.family<StatisticSummary, ReportPeriod>((
  ref,
  period,
) async {
  ref.watch(ledgerRevisionProvider);
  final repository = ref.watch(statisticRepositoryProvider);
  final options = await ref.watch(ledgerOptionsProvider.future);
  return repository.summary(period.start, period.end, currency: options.operatingCurrency);
});

/// `GET /api/statistic/graph` for a period (daily).
final reportGraphProvider = FutureProvider.autoDispose.family<StatisticGraph, ReportPeriod>((
  ref,
  period,
) {
  ref.watch(ledgerRevisionProvider);
  return ref.watch(statisticRepositoryProvider).graph(period.start, period.end);
});

/// Per-account totals and top postings of an account type in a period
/// (`report.account_totals` + `report.top_postings`).
final reportRankProvider =
    FutureProvider.autoDispose.family<StatisticRank, (AccountType, ReportPeriod)>((ref, arg) async {
      ref.watch(ledgerRevisionProvider);
      final (type, period) = arg;
      final repository = ref.watch(statisticRepositoryProvider);
      final options = await ref.watch(ledgerOptionsProvider.future);
      return repository.rank(type, period.start, period.end, currency: options.operatingCurrency);
    });
