import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/theme/app_colors.dart';
import '../../core/utils/dates.dart';
import '../../core/utils/money.dart';
import '../../core/widgets/error_view.dart';
import '../../core/widgets/ledger_widgets.dart';
import '../../data/api/api_exception.dart';
import '../../data/models/journal.dart';
import '../../data/models/ledger_error.dart';
import '../../data/models/pageable.dart';
import '../../data/profiles/profile_providers.dart';
import '../../data/repositories/ledger_data_providers.dart';
import '../../data/repositories/ledger_revision.dart';
import '../../l10n/l10n.dart';
import '../../router.dart';
import '../journals/journal_grouping.dart';
import '../journals/journal_providers.dart';
import '../journals/journal_routes.dart';
import '../journals/widgets/amount_format.dart';
import '../journals/widgets/journal_tile.dart';
import '../journals/widgets/skeleton.dart';
import 'home_providers.dart';

/// Home tab (S02): month summary card, ledger-error chip, recent
/// transactions; pull-to-refresh, skeleton / empty / card-level error states
/// and a banner when the server rejects the credentials (401).
///
/// Keep `ActiveLedgerTitle` + `SettingsButton` in the app bar: settings are
/// only reachable from here.
class HomeScreen extends ConsumerWidget {
  const HomeScreen({super.key});

  Future<void> _refresh(WidgetRef ref) async {
    ref.read(ledgerRevisionProvider.notifier).bump();
    final month = ref.read(homeMonthProvider);
    try {
      await Future.wait([
        ref.read(homeRecentProvider.future),
        ref.read(monthSummaryProvider(month).future),
      ]);
    } catch (_) {
      // Errors are rendered inside the cards.
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final month = ref.watch(homeMonthProvider);
    final summary = ref.watch(monthSummaryProvider(month));
    final recent = ref.watch(homeRecentProvider);
    final errors = ref.watch(ledgerErrorsProvider);
    final unauthorized = [summary, recent, errors].any((v) => v.error is ApiUnauthorized);
    final refreshing = (recent.isLoading && recent.hasValue) || (summary.isLoading && summary.hasValue);

    return Scaffold(
      appBar: AppBar(
        title: const ActiveLedgerTitle(),
        actions: [
          if (!errors.hasError && (errors.value?.totalCount ?? 0) > 0) _ErrorsChip(errors: errors.value!),
          const SettingsButton(),
        ],
      ),
      body: Column(
        children: [
          if (refreshing) const LinearProgressIndicator(minHeight: 2),
          Expanded(
            child: RefreshIndicator(
              onRefresh: () => _refresh(ref),
              child: ListView(
                key: const Key('home.list'),
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.only(bottom: 96), // clear the FAB
                children: [
                  if (unauthorized) const _AuthBanner(),
                  const _MonthSwitcher(),
                  const _SummaryCard(),
                  const _RecentHeader(),
                  ..._recentRows(context, ref, recent),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  List<Widget> _recentRows(BuildContext context, WidgetRef ref, AsyncValue<Pageable<JournalItem>> recent) {
    // Errors first: after a profile switch the previous value belongs to the
    // other ledger and must not be shown under this ledger's name.
    return switch (recent) {
      AsyncValue(:final error?) => [
        _InlineError(error: error, onRetry: () => ref.invalidate(homeRecentProvider)),
      ],
      AsyncValue(:final value?, hasValue: true) when value.totalCount == 0 => [const _EmptyLedgerCard()],
      AsyncValue(:final value?, hasValue: true) => [
        for (final month in groupJournal(
          value.records,
          hasMore: value.hasNextPage,
          // Watched only once there is data to format (keeps the options
          // request out of failing / empty states).
          operatingCurrency: ref.watch(operatingCurrencyProvider),
        ))
          for (final day in month.days) ...[
            DayHeader(
              day: day.day,
              net: day.complete && day.net.isNotEmpty ? day.net.first : null,
            ),
            for (final item in day.items)
              JournalItemTile(item: item, onTap: () => openHomeJournalDetail(context, item)),
          ],
      ],
      _ => [const SkeletonTileList(count: 5)],
    };
  }
}

/// `MaterialBanner` shown while the server answers 401 – links to editing
/// the active profile in Settings.
class _AuthBanner extends ConsumerWidget {
  const _AuthBanner();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final profile = ref.watch(activeProfileProvider);
    return MaterialBanner(
      key: const Key('home.authBanner'),
      leading: const Icon(Icons.lock_outline),
      content: Text(l10n.homeAuthBanner),
      actions: [
        TextButton(
          onPressed: () =>
              context.push(profile == null ? AppRoutes.settings : AppRoutes.editProfile(profile.id)),
          child: Text(l10n.homeAuthUpdate),
        ),
      ],
    );
  }
}

class _MonthSwitcher extends ConsumerWidget {
  const _MonthSwitcher();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final month = ref.watch(homeMonthProvider);
    final controller = ref.read(homeMonthProvider.notifier);
    final locale = Localizations.localeOf(context).toLanguageTag();
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 4),
      child: Row(
        children: [
          IconButton(
            key: const Key('home.prevMonth'),
            tooltip: l10n.homePreviousMonth,
            icon: const Icon(Icons.chevron_left),
            onPressed: controller.previous,
          ),
          Text(
            ZhangDates.formatMonth(month.start, locale),
            key: const Key('home.month'),
            style: Theme.of(context).textTheme.titleMedium,
          ),
          IconButton(
            key: const Key('home.nextMonth'),
            tooltip: l10n.homeNextMonth,
            icon: const Icon(Icons.chevron_right),
            onPressed: controller.canGoNext ? controller.next : null,
          ),
        ],
      ),
    );
  }
}

/// Expense (large), income and net of the selected month from
/// `GET /api/statistic/summary`. Tapping opens Reports.
class _SummaryCard extends ConsumerWidget {
  const _SummaryCard();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final colors = context.zhangColors;
    final month = ref.watch(homeMonthProvider);
    final summary = ref.watch(monthSummaryProvider(month));
    final label = theme.textTheme.labelLarge?.copyWith(color: scheme.onSurfaceVariant);

    Widget body;
    // A previous value next to an error may belong to another ledger (profile
    // switch): show the error instead.
    if (summary.hasValue && !summary.hasError) {
      final commodities = ref.watch(commoditiesProvider).value;
      final f = HomeSummaryFigures.from(summary.requireValue);
      Widget figure(String name, String text, Color color, Key key) => Expanded(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(name, style: label),
            const SizedBox(height: 2),
            Text(text, key: key, style: tabular(theme.textTheme.titleMedium)?.copyWith(color: color)),
          ],
        ),
      );
      body = Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(l10n.homeExpense, style: label),
          const SizedBox(height: 4),
          FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: Text(
              formatAmount(f.expense, commodities),
              key: const Key('home.summary.expense'),
              style: tabular(theme.textTheme.displaySmall)?.copyWith(color: colors.expense),
            ),
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              figure(l10n.homeIncome, formatAmount(f.income, commodities), colors.income,
                  const Key('home.summary.income')),
              figure(
                l10n.homeNet,
                formatAmount(f.net, commodities, signed: true),
                f.net.isNegative ? colors.neutral : toneColor(context, toneOf(f.net.number)),
                const Key('home.summary.net'),
              ),
            ],
          ),
        ],
      );
    } else if (summary.hasError) {
      body = _InlineError(
        error: summary.error!,
        onRetry: () => ref.invalidate(monthSummaryProvider(month)),
        padding: EdgeInsets.zero,
      );
    } else {
      body = const Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SkeletonBox(width: 80),
          SizedBox(height: 12),
          SkeletonBox(width: 180, height: 36),
          SizedBox(height: 16),
          Row(children: [SkeletonBox(width: 100), SizedBox(width: 40), SkeletonBox(width: 100)]),
        ],
      );
    }
    return Card(
      key: const Key('home.summary'),
      margin: const EdgeInsets.fromLTRB(16, 0, 16, 8),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: summary.hasValue ? () => context.go(AppRoutes.reports) : null,
        child: Padding(padding: const EdgeInsets.all(16), child: body),
      ),
    );
  }
}

class _RecentHeader extends StatelessWidget {
  const _RecentHeader();

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 8, 0),
      child: Row(
        children: [
          Expanded(child: Text(l10n.homeRecentTitle, style: Theme.of(context).textTheme.titleMedium)),
          TextButton(
            key: const Key('home.seeAll'),
            onPressed: () => context.go(AppRoutes.journals),
            child: Text(l10n.homeSeeAll),
          ),
        ],
      ),
    );
  }
}

class _EmptyLedgerCard extends StatelessWidget {
  const _EmptyLedgerCard();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      key: const Key('home.empty'),
      margin: const EdgeInsets.all(16),
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Row(
          children: [
            Icon(Icons.edit_note, size: 40, color: theme.colorScheme.primary),
            const SizedBox(width: 16),
            Expanded(child: Text(context.l10n.homeEmptyLedger, style: theme.textTheme.bodyLarge)),
          ],
        ),
      ),
    );
  }
}

/// Card-level error: "Failed to load · Retry" plus the error description.
class _InlineError extends StatelessWidget {
  const _InlineError({required this.error, required this.onRetry, this.padding = const EdgeInsets.all(16)});

  final Object error;
  final VoidCallback onRetry;
  final EdgeInsets padding;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final theme = Theme.of(context);
    return Padding(
      padding: padding,
      child: Row(
        children: [
          Icon(iconForApiError(error), color: theme.colorScheme.error),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(l10n.homeLoadFailed, style: theme.textTheme.titleSmall),
                Text(
                  describeApiError(l10n, error),
                  style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.onSurfaceVariant),
                ),
              ],
            ),
          ),
          TextButton(onPressed: onRetry, child: Text(l10n.retry)),
        ],
      ),
    );
  }
}

/// ⚠ chip with the ledger error count; opens [_ErrorsSheet].
class _ErrorsChip extends StatelessWidget {
  const _ErrorsChip({required this.errors});

  final Pageable<LedgerError> errors;

  @override
  Widget build(BuildContext context) {
    final colors = context.zhangColors;
    return Padding(
      padding: const EdgeInsets.only(right: 4),
      child: ActionChip(
        key: const Key('home.errors'),
        avatar: Icon(Icons.warning_amber_rounded, size: 18, color: colors.warning),
        label: Text(context.l10n.homeErrorCount(errors.totalCount)),
        visualDensity: VisualDensity.compact,
        onPressed: () => showModalBottomSheet<void>(
          context: context,
          isScrollControlled: true,
          showDragHandle: true,
          useSafeArea: true,
          builder: (_) => _ErrorsSheet(errors: errors),
        ),
      ),
    );
  }
}

class _ErrorsSheet extends StatelessWidget {
  const _ErrorsSheet({required this.errors});

  final Pageable<LedgerError> errors;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final theme = Theme.of(context);
    final muted = theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.onSurfaceVariant);
    return DraggableScrollableSheet(
      expand: false,
      initialChildSize: 0.6,
      maxChildSize: 0.95,
      builder: (context, controller) => ListView(
        key: const Key('home.errorsSheet'),
        controller: controller,
        padding: const EdgeInsets.only(bottom: 24),
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
            child: Text(l10n.homeErrorsTitle, style: theme.textTheme.titleLarge),
          ),
          for (final e in errors.records)
            ListTile(
              leading: Icon(Icons.error_outline, color: theme.colorScheme.error),
              title: Text(humanizeErrorType(e.rawType)),
              subtitle: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (e.span?.filename != null)
                    Text(
                      e.span!.line == null
                          ? e.span!.filename!
                          : l10n.homeErrorLocation(e.span!.filename!, e.span!.line!),
                      style: muted,
                    ),
                  if ((e.span?.content ?? '').isNotEmpty)
                    Text(
                      e.span!.content,
                      maxLines: 4,
                      overflow: TextOverflow.ellipsis,
                      style: muted?.copyWith(fontFamily: 'monospace', fontFamilyFallback: const ['Menlo']),
                    ),
                  if (e.span == null && e.metas.isNotEmpty)
                    Text(e.metas.entries.map((m) => '${m.key}: ${m.value}').join(' · '), style: muted),
                ],
              ),
            ),
          if (errors.totalCount > errors.records.length)
            Padding(
              padding: const EdgeInsets.all(16),
              child: Text(l10n.homeErrorsMore(errors.records.length, errors.totalCount), style: muted),
            ),
        ],
      ),
    );
  }
}

/// `UnbalancedTransaction` → `Unbalanced transaction`.
String humanizeErrorType(String raw) {
  if (raw.isEmpty) return raw;
  final words = raw
      .replaceAllMapped(RegExp(r'(?<=[a-z0-9])([A-Z])'), (m) => ' ${m[1]}')
      .split(' ');
  return [
    words.first,
    for (final w in words.skip(1)) w.toLowerCase(),
  ].join(' ');
}
