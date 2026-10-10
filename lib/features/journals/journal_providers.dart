import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/models/journal.dart';
import '../../data/models/ledger_error.dart';
import '../../data/models/pageable.dart';
import '../../data/models/statistic.dart';
import '../../data/profiles/profile_providers.dart';
import '../../data/repositories/journal_repository.dart';
import '../../data/repositories/ledger_data_providers.dart';
import '../../data/repositories/ledger_repository.dart';
import '../../data/repositories/ledger_revision.dart';
import '../../data/repositories/statistic_repository.dart';
import '../../main.dart' show zhangRetryPolicy;
import 'journal_grouping.dart';
import 'year_month.dart';

/// Page size of the journal list (design S07).
const journalPageSize = 50;

/// Retry policy of the browsing providers: the app-wide policy of
/// `bootstrap()` (only transient network failures, max 2×), set per provider
/// so they behave the same in containers created without it (widget tests):
/// HTTP / parse errors are shown at once instead of being retried for ~40 s
/// by Riverpod's default policy.
const browseRetry = zhangRetryPolicy;

// ---------------------------------------------------------------------------
// Filters
// ---------------------------------------------------------------------------

/// Filters of the journal screen. [keyword] and [tags] go to the repository
/// (tags are applied client-side by `JournalRepository.list`); [type] is a
/// purely client-side view filter and does not refetch.
@immutable
class JournalFilter {
  const JournalFilter({this.keyword = '', this.tags = const [], this.type = JournalTypeFilter.all});

  final String keyword;
  final List<String> tags;
  final JournalTypeFilter type;

  bool get isActive => keyword.isNotEmpty || tags.isNotEmpty || type != JournalTypeFilter.all;

  /// The part that changes the server request.
  JournalQuery query({int page = 1, int size = journalPageSize}) => JournalQuery(
    page: page,
    size: size,
    keyword: keyword.isEmpty ? null : keyword,
    tags: tags,
  );

  JournalFilter copyWith({String? keyword, List<String>? tags, JournalTypeFilter? type}) => JournalFilter(
    keyword: keyword ?? this.keyword,
    tags: tags ?? this.tags,
    type: type ?? this.type,
  );

  @override
  bool operator ==(Object other) =>
      other is JournalFilter && other.keyword == keyword && listEquals(other.tags, tags) && other.type == type;

  @override
  int get hashCode => Object.hash(keyword, Object.hashAll(tags), type);
}

final journalFilterProvider = NotifierProvider<JournalFilterController, JournalFilter>(
  JournalFilterController.new,
);

class JournalFilterController extends Notifier<JournalFilter> {
  /// Starts empty and resets when the active profile changes (tags and
  /// keywords of one ledger mean nothing in another).
  @override
  JournalFilter build() {
    ref.watch(activeProfileProvider.select((p) => p?.id));
    return const JournalFilter();
  }

  void setKeyword(String keyword) {
    final k = keyword.trim();
    if (k != state.keyword) state = state.copyWith(keyword: k);
  }

  void setType(JournalTypeFilter type) => state = state.copyWith(type: type);

  void toggleTag(String tag) {
    final tags = [...state.tags];
    if (!tags.remove(tag)) tags.add(tag);
    state = state.copyWith(tags: tags);
  }

  /// Shows only [tag] (used from the detail screen).
  void onlyTag(String tag) => state = JournalFilter(tags: [tag]);

  void clear() => state = const JournalFilter();
}

// ---------------------------------------------------------------------------
// Pagination
// ---------------------------------------------------------------------------

/// Loaded pages of the journal list plus "load more" status.
@immutable
class JournalListData {
  const JournalListData({
    required this.items,
    required this.loadedPage,
    required this.totalPage,
    required this.totalCount,
    this.isLoadingMore = false,
    this.loadMoreError,
  });

  /// State after page 1.
  factory JournalListData.firstPage(Pageable<JournalItem> page) => JournalListData(
    items: _dedupe(const [], page.records),
    loadedPage: page.currentPage < 1 ? 1 : page.currentPage,
    totalPage: page.totalPage,
    totalCount: page.totalCount,
  );

  /// Items in server order (newest first), unique by id.
  final List<JournalItem> items;

  /// Last page fetched (1-based).
  final int loadedPage;
  final int totalPage;

  /// Server's count (unfiltered by tags, see `JournalRepository.list`).
  final int totalCount;
  final bool isLoadingMore;
  final Object? loadMoreError;

  bool get hasMore => loadedPage < totalPage;
  int get nextPage => loadedPage + 1;

  /// Appends [page] (the result for [nextPage]); items whose id is already
  /// present are skipped – offset pagination over live data can repeat
  /// items when the ledger changes between requests. A page past the end
  /// (`current_page > total_page`) ends the list; an empty page that is not
  /// past the end (all records filtered out client-side) does not.
  JournalListData appendPage(Pageable<JournalItem> page) => JournalListData(
    items: _dedupe(items, page.records),
    loadedPage: page.currentPage < loadedPage ? loadedPage : page.currentPage,
    totalPage: page.totalPage,
    totalCount: page.totalCount,
  );

  JournalListData copyWith({bool? isLoadingMore, Object? loadMoreError, bool clearError = false}) =>
      JournalListData(
        items: items,
        loadedPage: loadedPage,
        totalPage: totalPage,
        totalCount: totalCount,
        isLoadingMore: isLoadingMore ?? this.isLoadingMore,
        loadMoreError: clearError ? null : (loadMoreError ?? this.loadMoreError),
      );

  /// Finds a loaded item by id.
  JournalItem? byId(String id) {
    for (final i in items) {
      if (i.id == id) return i;
    }
    return null;
  }

  static List<JournalItem> _dedupe(List<JournalItem> existing, List<JournalItem> incoming) {
    final seen = {for (final i in existing) i.id};
    return [
      ...existing,
      for (final i in incoming)
        if (seen.add(i.id)) i,
    ];
  }
}

/// Paginated journal list for the current [journalFilterProvider] keyword /
/// tags. Refetches page 1 when the filter, the active profile or the ledger
/// revision changes; [loadMore] appends the next page.
final journalListProvider = AsyncNotifierProvider<JournalListController, JournalListData>(
  JournalListController.new,
  retry: browseRetry,
);

class JournalListController extends AsyncNotifier<JournalListData> {
  int _generation = 0;
  JournalQuery _query = const JournalFilter().query();

  @override
  Future<JournalListData> build() async {
    ref.watch(ledgerRevisionProvider);
    final query = ref.watch(journalFilterProvider.select((f) => f.query()));
    final repo = ref.watch(journalRepositoryProvider);
    _generation++;
    _query = query;
    final page = await repo.list(query);
    return JournalListData.firstPage(page);
  }

  /// Fetches the next page. No-op while loading, when everything is loaded
  /// or while the first page is (re)loading.
  Future<void> loadMore() async {
    final current = state.value;
    if (state.isLoading || current == null || !current.hasMore || current.isLoadingMore) return;
    final generation = _generation;
    state = AsyncData(current.copyWith(isLoadingMore: true, clearError: true));
    try {
      final page = await ref.read(journalRepositoryProvider).list(_query.copyWith(page: current.nextPage));
      if (!ref.mounted || generation != _generation) return;
      final latest = state.value ?? current;
      state = AsyncData(latest.appendPage(page));
    } catch (e) {
      if (!ref.mounted || generation != _generation) return;
      final latest = state.value ?? current;
      state = AsyncData(latest.copyWith(isLoadingMore: false, loadMoreError: e));
    }
  }

  /// Reloads from page 1 (pull-to-refresh) and completes when done.
  Future<void> refresh() async {
    ref.invalidateSelf();
    try {
      await future;
    } catch (_) {
      // Shown by the screen's error state.
    }
  }
}

// ---------------------------------------------------------------------------
// Shared data
// ---------------------------------------------------------------------------

/// Summary figures of one month (`report.*` built-in queries in the
/// operating currency), cached per month (month headers of the journal, the
/// Home summary card).
final monthSummaryProvider = FutureProvider.family<StatisticSummary, YearMonth>((ref, month) async {
  ref.watch(ledgerRevisionProvider);
  final repository = ref.watch(statisticRepositoryProvider);
  final options = await ref.watch(ledgerOptionsProvider.future);
  return repository.summary(month.start, month.end, currency: options.operatingCurrency);
}, retry: browseRetry);

/// Ledger errors (built-in `journals.errors`, first 100, with the total).
final ledgerErrorsProvider = FutureProvider<Pageable<LedgerError>>((ref) {
  ref.watch(ledgerRevisionProvider);
  return ref.watch(ledgerRepositoryProvider).errors(size: 100);
}, retry: browseRetry);

/// Operating currency, or `null` until the options are loaded.
final operatingCurrencyProvider = Provider<String?>(
  (ref) => ref.watch(ledgerOptionsProvider).value?.operatingCurrency,
);

/// A journal item by `(id, keyword)` for the detail screen when it was not
/// passed as route `extra` (deep link, a row of an account's postings):
/// looks in the loaded journal pages first, then searches `/api/journals`
/// for `keyword` (the payee or narration, up to 5 pages of 100), then page 1.
/// Pads come with their balance check folded in. `null` = not found (ids
/// change on every ledger reload).
final journalItemByIdProvider = FutureProvider.autoDispose.family<JournalItem?, (String, String?)>((
  ref,
  arg,
) async {
  final (id, keyword) = arg;
  final loaded = ref.read(journalListProvider).value?.byId(id);
  if (loaded != null) return loaded;
  final repository = ref.watch(journalRepositoryProvider);
  JournalItem? find(List<JournalItem> records) {
    for (final item in foldBalancePads(records)) {
      if (item.id == id) return item;
    }
    return null;
  }

  if (keyword != null && keyword.trim().isNotEmpty) {
    for (var page = 1; page <= 5; page++) {
      final result = await repository.list(JournalQuery(page: page, size: 100, keyword: keyword.trim()));
      final found = find(result.records);
      if (found != null) return found;
      if (!result.hasNextPage) break;
    }
  }
  final page = await repository.list(const JournalQuery(page: 1, size: 100));
  return find(page.records);
}, retry: browseRetry);
