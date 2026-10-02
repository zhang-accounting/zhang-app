import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/theme/app_colors.dart';
import '../../core/utils/dates.dart';
import '../../core/widgets/error_view.dart';
import '../../data/models/journal.dart';
import '../../data/repositories/ledger_data_providers.dart';
import '../../data/repositories/ledger_revision.dart';
import '../../l10n/l10n.dart';
import 'journal_grouping.dart';
import 'journal_providers.dart';
import 'journal_routes.dart';
import 'widgets/amount_format.dart';
import 'widgets/journal_tile.dart';
import 'widgets/skeleton.dart';
import 'year_month.dart';

/// Journal tab (S07): infinite list of transactions and balance items with
/// sticky month headers (month expense / income from the statistic
/// summary), day groups with the day's net, type chips (client-side),
/// keyword search (server) and tag filter chips.
class JournalsScreen extends ConsumerStatefulWidget {
  const JournalsScreen({super.key});

  @override
  ConsumerState<JournalsScreen> createState() => _JournalsScreenState();
}

class _JournalsScreenState extends ConsumerState<JournalsScreen> {
  final _search = TextEditingController();
  Timer? _debounce;
  bool _searching = false;

  @override
  void initState() {
    super.initState();
    final keyword = ref.read(journalFilterProvider).keyword;
    _search.text = keyword;
    _searching = keyword.isNotEmpty;
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _search.dispose();
    super.dispose();
  }

  void _onSearchChanged(String value) {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 400), () {
      if (mounted) ref.read(journalFilterProvider.notifier).setKeyword(value);
    });
  }

  void _toggleSearch() {
    setState(() => _searching = !_searching);
    if (!_searching) {
      _debounce?.cancel();
      _search.clear();
      ref.read(journalFilterProvider.notifier).setKeyword('');
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final list = ref.watch(journalListProvider);
    // Keep the search field in sync when the filter is changed elsewhere
    // (e.g. "clear filters" or a tag tapped in the detail screen).
    ref.listen(journalFilterProvider.select((f) => f.keyword), (_, keyword) {
      if (_search.text.trim() != keyword) _search.text = keyword;
    });
    return Scaffold(
      appBar: AppBar(
        title: _searching
            ? TextField(
                key: const Key('journal.search'),
                controller: _search,
                autofocus: true,
                textInputAction: TextInputAction.search,
                decoration: InputDecoration(hintText: l10n.journalSearchHint, border: InputBorder.none),
                onChanged: _onSearchChanged,
                onSubmitted: (v) {
                  _debounce?.cancel();
                  ref.read(journalFilterProvider.notifier).setKeyword(v);
                },
              )
            : Text(l10n.tabJournal),
        actions: [
          IconButton(
            key: const Key('journal.searchToggle'),
            tooltip: _searching ? l10n.journalCloseSearch : l10n.journalSearch,
            icon: Icon(_searching ? Icons.close : Icons.search),
            onPressed: _toggleSearch,
          ),
        ],
      ),
      body: Column(
        children: [
          const _FilterBar(),
          if (list.isLoading && list.hasValue) const LinearProgressIndicator(minHeight: 2),
          Expanded(
            child: list.when(
              skipLoadingOnReload: true,
              loading: () => const SingleChildScrollView(
                physics: NeverScrollableScrollPhysics(),
                child: SkeletonTileList(count: 10),
              ),
              error: (e, _) => ErrorView(error: e, onRetry: () => ref.invalidate(journalListProvider)),
              data: (data) => _JournalList(data: data),
            ),
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Filter bar
// ---------------------------------------------------------------------------

class _FilterBar extends ConsumerWidget {
  const _FilterBar();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final filter = ref.watch(journalFilterProvider);
    final notifier = ref.read(journalFilterProvider.notifier);
    String label(JournalTypeFilter t) => switch (t) {
      JournalTypeFilter.all => l10n.journalFilterAll,
      JournalTypeFilter.expense => l10n.journalKindExpense,
      JournalTypeFilter.income => l10n.journalKindIncome,
      JournalTypeFilter.transfer => l10n.journalKindTransfer,
    };
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.fromLTRB(12, 4, 12, 8),
      child: Row(
        children: [
          for (final t in JournalTypeFilter.values) ...[
            ChoiceChip(
              key: Key('journal.type.${t.name}'),
              label: Text(label(t)),
              selected: filter.type == t,
              onSelected: (_) => notifier.setType(t),
            ),
            const SizedBox(width: 8),
          ],
          for (final tag in filter.tags) ...[
            InputChip(
              key: Key('journal.tag.$tag'),
              label: Text('#$tag'),
              selected: true,
              showCheckmark: false,
              onPressed: () => notifier.toggleTag(tag),
              onDeleted: () => notifier.toggleTag(tag),
              deleteButtonTooltipMessage: l10n.journalRemoveTag(tag),
            ),
            const SizedBox(width: 8),
          ],
          ActionChip(
            key: const Key('journal.tags'),
            avatar: const Icon(Icons.sell_outlined, size: 18),
            label: Text(l10n.journalTags),
            onPressed: () => _showTagSheet(context),
          ),
        ],
      ),
    );
  }

  void _showTagSheet(BuildContext context) {
    showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      builder: (context) => const _TagSheet(),
    );
  }
}

/// Tags found in the loaded transactions (plus the active ones) as
/// toggleable chips.
class _TagSheet extends ConsumerWidget {
  const _TagSheet();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final filter = ref.watch(journalFilterProvider);
    final items = ref.watch(journalListProvider).value?.items ?? const <JournalItem>[];
    final tags = <String>{
      ...filter.tags,
      for (final i in items)
        if (i is JournalTransaction) ...i.tags,
    }.toList()
      ..sort();
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(l10n.journalTagsTitle, style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 12),
            if (tags.isEmpty)
              Text(l10n.journalNoTags)
            else
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  for (final tag in tags)
                    FilterChip(
                      label: Text('#$tag'),
                      selected: filter.tags.contains(tag),
                      onSelected: (_) => ref.read(journalFilterProvider.notifier).toggleTag(tag),
                    ),
                ],
              ),
          ],
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// List
// ---------------------------------------------------------------------------

sealed class _Row {
  const _Row();
}

class _DayRow extends _Row {
  const _DayRow(this.group);

  final JournalDayGroup group;
}

class _ItemRow extends _Row {
  const _ItemRow(this.item);

  final JournalItem item;
}

class _JournalList extends ConsumerStatefulWidget {
  const _JournalList({required this.data});

  final JournalListData data;

  @override
  ConsumerState<_JournalList> createState() => _JournalListState();
}

class _JournalListState extends ConsumerState<_JournalList> {
  /// Load the next page when less than this many pixels are left below the
  /// viewport.
  static const _loadMoreThreshold = 800.0;

  final _scroll = ScrollController();

  @override
  void initState() {
    super.initState();
    _scroll.addListener(_maybeLoadMore);
  }

  @override
  void dispose() {
    _scroll.dispose();
    super.dispose();
  }

  /// Infinite scroll: also called after every build, so a list that does
  /// not fill the screen (e.g. after a type filter) keeps loading pages.
  void _maybeLoadMore() {
    if (!mounted || !_scroll.hasClients) return;
    final data = widget.data;
    if (!data.hasMore || data.isLoadingMore || data.loadMoreError != null) return;
    final position = _scroll.position;
    if (!position.hasContentDimensions || position.extentAfter > _loadMoreThreshold) return;
    ref.read(journalListProvider.notifier).loadMore();
  }

  Future<void> _refresh() async {
    ref.read(ledgerRevisionProvider.notifier).bump();
    try {
      await ref.read(journalListProvider.future);
    } catch (_) {
      // The error state is rendered by the screen.
    }
  }

  @override
  Widget build(BuildContext context) {
    final data = widget.data;
    WidgetsBinding.instance.addPostFrameCallback((_) => _maybeLoadMore());
    final filter = ref.watch(journalFilterProvider);
    final opCurrency = ref.watch(operatingCurrencyProvider);
    final visible = filter.type == JournalTypeFilter.all
        ? data.items
        : data.items.where((i) => filter.type.accepts(i, operatingCurrency: opCurrency)).toList();
    final groups = groupJournal(visible, hasMore: data.hasMore, operatingCurrency: opCurrency);

    return RefreshIndicator(
      onRefresh: _refresh,
      child: CustomScrollView(
        key: const PageStorageKey('journal.list'),
        controller: _scroll,
        physics: const AlwaysScrollableScrollPhysics(),
        slivers: [
          if (groups.isEmpty && !data.hasMore)
            SliverFillRemaining(
              hasScrollBody: false,
              child: filter.isActive ? const _NoMatch() : const _EmptyJournal(),
            ),
          for (final month in groups)
            SliverMainAxisGroup(
              key: ValueKey('journal.month.${month.month}'),
              slivers: [
                PinnedHeaderSliver(child: MonthHeader(month: month.month)),
                _monthRows(month),
              ],
            ),
          const SliverToBoxAdapter(child: SizedBox(height: 4)),
          const SliverToBoxAdapter(child: _LoadMoreFooter()),
          // Room for the centre FAB.
          const SliverToBoxAdapter(child: SizedBox(height: 48)),
        ],
      ),
    );
  }

  Widget _monthRows(JournalMonthGroup month) {
    final rows = <_Row>[
      for (final day in month.days) ...[
        _DayRow(day),
        for (final item in day.items) _ItemRow(item),
      ],
    ];
    return SliverList.builder(
      itemCount: rows.length,
      itemBuilder: (context, i) => switch (rows[i]) {
        _DayRow(:final group) => DayHeader(
          key: ValueKey('journal.day.${ZhangDates.toIsoDate(group.day)}'),
          day: group.day,
          net: group.complete && group.net.isNotEmpty ? group.net.first : null,
        ),
        _ItemRow(:final item) => JournalItemTile(
          key: ValueKey('journal.item.${item.id}'),
          item: item,
          onTap: () => openJournalDetail(context, item),
        ),
      },
    );
  }
}

/// Sticky month header: month name and that month's expense / income from
/// `GET /api/statistic/summary` (one cached request per month).
class MonthHeader extends ConsumerWidget {
  const MonthHeader({super.key, required this.month});

  final YearMonth month;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final colors = context.zhangColors;
    final locale = Localizations.localeOf(context).toLanguageTag();
    final summary = ref.watch(monthSummaryProvider(month));
    final small = tabular(theme.textTheme.labelMedium);
    // Commodities are only needed (and fetched) once there is a summary.
    final commodities = summary.hasValue ? ref.watch(commoditiesProvider).value : null;
    return Material(
      color: scheme.surfaceContainerLow,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        child: Row(
          children: [
            Expanded(
              child: Text(
                ZhangDates.formatMonth(month.start, locale),
                style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w600),
              ),
            ),
            ...switch (summary) {
              AsyncData(:final value) => [
                Text(
                  l10n.journalMonthExpense(formatAmount(value.expense.calculated, commodities)),
                  style: small?.copyWith(color: colors.expense),
                ),
                const SizedBox(width: 12),
                Text(
                  l10n.journalMonthIncome(formatAmount(-value.income.calculated, commodities)),
                  style: small?.copyWith(color: colors.income),
                ),
              ],
              AsyncError() => [Icon(Icons.error_outline, size: 16, color: scheme.error)],
              _ => [const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2))],
            },
          ],
        ),
      ),
    );
  }
}

/// Bottom of the list: a spinner while the next page loads (the scroll
/// controller of [_JournalList] triggers the loading) and a retry row when
/// loading more failed.
class _LoadMoreFooter extends ConsumerWidget {
  const _LoadMoreFooter();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final data = ref.watch(journalListProvider).value;
    if (data == null) return const SizedBox.shrink();
    if (data.loadMoreError != null) {
      return Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        child: Row(
          children: [
            Icon(Icons.error_outline, color: Theme.of(context).colorScheme.error),
            const SizedBox(width: 8),
            Expanded(child: Text(l10n.journalLoadMoreFailed)),
            TextButton(
              key: const Key('journal.loadMoreRetry'),
              onPressed: () => ref.read(journalListProvider.notifier).loadMore(),
              child: Text(l10n.retry),
            ),
          ],
        ),
      );
    }
    if (!data.hasMore) return const SizedBox(height: 16);
    // Only animate while a request is running: an idle spinner would tick
    // forever even when it is off screen.
    if (!data.isLoadingMore) return const SizedBox(height: 56);
    return const Padding(
      key: Key('journal.loadingMore'),
      padding: EdgeInsets.all(16),
      child: Center(child: SizedBox(width: 24, height: 24, child: CircularProgressIndicator(strokeWidth: 2))),
    );
  }
}

class _EmptyJournal extends StatelessWidget {
  const _EmptyJournal();

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final theme = Theme.of(context);
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.receipt_long_outlined, size: 56, color: theme.colorScheme.primary),
            const SizedBox(height: 12),
            Text(l10n.journalEmpty, style: theme.textTheme.titleMedium),
            const SizedBox(height: 4),
            Text(l10n.journalEmptyHint, textAlign: TextAlign.center),
          ],
        ),
      ),
    );
  }
}

class _NoMatch extends ConsumerWidget {
  const _NoMatch();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final theme = Theme.of(context);
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.search_off, size: 56, color: theme.colorScheme.onSurfaceVariant),
            const SizedBox(height: 12),
            Text(l10n.journalNoMatch, style: theme.textTheme.titleMedium),
            const SizedBox(height: 12),
            OutlinedButton(
              key: const Key('journal.clearFilters'),
              onPressed: () => ref.read(journalFilterProvider.notifier).clear(),
              child: Text(l10n.journalClearFilters),
            ),
          ],
        ),
      ),
    );
  }
}
