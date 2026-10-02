import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:zhang_app/data/api/zhang_api_client.dart';
import 'package:zhang_app/data/models/journal.dart';
import 'package:zhang_app/data/models/pageable.dart';
import 'package:zhang_app/data/profiles/profile_providers.dart';
import 'package:zhang_app/data/profiles/profile_repository.dart';
import 'package:zhang_app/data/profiles/secret_store.dart';
import 'package:zhang_app/data/profiles/server_profile.dart';
import 'package:zhang_app/data/repositories/ledger_revision.dart';
import 'package:zhang_app/features/journals/journal_grouping.dart';
import 'package:zhang_app/features/journals/journal_providers.dart';

import 'fake_server.dart';
import 'journal_test_utils.dart';

Pageable<JournalItem> page(List<String> ids, {required int current, required int totalPage}) => Pageable(
  totalCount: totalPage * 2,
  totalPage: totalPage,
  pageSize: 2,
  currentPage: current,
  records: [for (final id in ids) JournalItem.fromJson(expenseJson(id, '2023-09-01T10:00:00'))],
);

ProviderContainer makeContainer(FakeZhangServer server) {
  final container = ProviderContainer(
    overrides: [zhangApiClientProvider.overrideWithValue(server.client)],
    retry: (_, _) => null,
  );
  addTearDown(container.dispose);
  return container;
}

void main() {
  group('JournalListData (pure pagination state)', () {
    test('first page then append; hasMore follows total_page', () {
      var data = JournalListData.firstPage(page(['a', 'b'], current: 1, totalPage: 2));
      expect(data.items.map((i) => i.id), ['a', 'b']);
      expect(data.hasMore, isTrue);
      expect(data.nextPage, 2);
      data = data.appendPage(page(['c', 'd'], current: 2, totalPage: 2));
      expect(data.items.map((i) => i.id), ['a', 'b', 'c', 'd']);
      expect(data.hasMore, isFalse);
    });

    test('dedupes by id when offset pages overlap', () {
      var data = JournalListData.firstPage(page(['a', 'b'], current: 1, totalPage: 3));
      data = data.appendPage(page(['b', 'c'], current: 2, totalPage: 3));
      expect(data.items.map((i) => i.id), ['a', 'b', 'c']);
      expect(data.byId('c')?.id, 'c');
      expect(data.byId('zz'), isNull);
    });

    test('an empty (client-filtered) page does not end the list; a page past the end does', () {
      var data = JournalListData.firstPage(page(['a'], current: 1, totalPage: 3));
      data = data.appendPage(page([], current: 2, totalPage: 3));
      expect(data.hasMore, isTrue);
      data = data.appendPage(page([], current: 4, totalPage: 3));
      expect(data.hasMore, isFalse);
    });

    test('copyWith toggles loading / error flags', () {
      final data = JournalListData.firstPage(page(['a'], current: 1, totalPage: 2));
      final loading = data.copyWith(isLoadingMore: true);
      expect(loading.isLoadingMore, isTrue);
      final failed = loading.copyWith(isLoadingMore: false, loadMoreError: 'x');
      expect(failed.loadMoreError, 'x');
      expect(failed.copyWith(clearError: true).loadMoreError, isNull);
    });
  });

  group('JournalListController', () {
    test('loads page 1, then more pages until the end', () async {
      final server = FakeZhangServer(journals: generateExpenses(120));
      final container = makeContainer(server);
      final sub = container.listen(journalListProvider, (_, _) {});
      addTearDown(sub.close);

      var data = await container.read(journalListProvider.future);
      expect(data.items, hasLength(journalPageSize));
      expect(data.hasMore, isTrue);
      expect(server.requestsTo('/journals').single.uri.queryParameters, {'page': '1', 'size': '50'});

      final notifier = container.read(journalListProvider.notifier);
      await notifier.loadMore();
      data = container.read(journalListProvider).requireValue;
      expect(data.items, hasLength(100));
      expect(data.loadedPage, 2);

      await notifier.loadMore();
      data = container.read(journalListProvider).requireValue;
      expect(data.items, hasLength(120));
      expect(data.hasMore, isFalse);

      // No request once everything is loaded.
      await notifier.loadMore();
      expect(server.requestsTo('/journals'), hasLength(3));
      expect(data.items.map((i) => i.id).toSet(), hasLength(120));
    });

    test('concurrent loadMore calls fetch the next page only once', () async {
      final server = FakeZhangServer(journals: generateExpenses(120));
      final container = makeContainer(server);
      final sub = container.listen(journalListProvider, (_, _) {});
      addTearDown(sub.close);
      await container.read(journalListProvider.future);
      final notifier = container.read(journalListProvider.notifier);
      await Future.wait([notifier.loadMore(), notifier.loadMore()]);
      expect(server.requestsTo('/journals'), hasLength(2));
      expect(container.read(journalListProvider).requireValue.items, hasLength(100));
    });

    test('a failed page keeps the items and exposes loadMoreError; retry succeeds', () async {
      final server = FakeZhangServer(journals: generateExpenses(120))..failingPages = {2};
      final container = makeContainer(server);
      final sub = container.listen(journalListProvider, (_, _) {});
      addTearDown(sub.close);
      await container.read(journalListProvider.future);
      final notifier = container.read(journalListProvider.notifier);

      await notifier.loadMore();
      var data = container.read(journalListProvider).requireValue;
      expect(data.items, hasLength(50));
      expect(data.loadMoreError, isNotNull);
      expect(data.isLoadingMore, isFalse);

      server.failingPages = {};
      await notifier.loadMore();
      data = container.read(journalListProvider).requireValue;
      expect(data.items, hasLength(100));
      expect(data.loadMoreError, isNull);
    });

    test('refresh (ledger revision bump) reloads page 1 and drops loaded pages', () async {
      final server = FakeZhangServer(journals: generateExpenses(120));
      final container = makeContainer(server);
      final sub = container.listen(journalListProvider, (_, _) {});
      addTearDown(sub.close);
      await container.read(journalListProvider.future);
      await container.read(journalListProvider.notifier).loadMore();
      expect(container.read(journalListProvider).requireValue.items, hasLength(100));

      server.journals.insert(0, expenseJson('new', '2023-10-01T09:00:00'));
      container.read(ledgerRevisionProvider.notifier).bump();
      final data = await container.read(journalListProvider.future);
      expect(data.items, hasLength(50));
      expect(data.items.first.id, 'new');
      expect(data.loadedPage, 1);
    });

    test('keyword changes refetch; type filter does not', () async {
      final server = FakeZhangServer(journals: generateExpenses(120));
      final container = makeContainer(server);
      final sub = container.listen(journalListProvider, (_, _) {});
      addTearDown(sub.close);
      await container.read(journalListProvider.future);

      container.read(journalFilterProvider.notifier).setType(JournalTypeFilter.income);
      await container.read(journalListProvider.future);
      expect(server.requestsTo('/journals'), hasLength(1));

      container.read(journalFilterProvider.notifier).setKeyword('Payee 11');
      final data = await container.read(journalListProvider.future);
      expect(server.requestsTo('/journals').last.uri.queryParameters['keyword'], 'Payee 11');
      expect(data.items.map((i) => i.payee), ['Payee 11', 'Payee 110', 'Payee 111', 'Payee 112', 'Payee 113',
        'Payee 114', 'Payee 115', 'Payee 116', 'Payee 117', 'Payee 118', 'Payee 119']);
      expect(data.hasMore, isFalse);
    });

    test('tag filter keeps only tagged transactions (client-side)', () async {
      final journals = generateExpenses(10)
        ..[3] = txnJson(
          id: 'tagged',
          datetime: '2023-09-28T10:00:00',
          tags: ['trip'],
          postings: [('Assets:WeChat', '-1', 'CNY'), ('Expenses:Food', '1', 'CNY')],
        );
      final server = FakeZhangServer(journals: journals);
      final container = makeContainer(server);
      final sub = container.listen(journalListProvider, (_, _) {});
      addTearDown(sub.close);
      container.read(journalFilterProvider.notifier).toggleTag('trip');
      final data = await container.read(journalListProvider.future);
      expect(data.items.map((i) => i.id), ['tagged']);
    });
  });

  test('the journal filter resets when the active profile changes', () async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    const other = ServerProfile(id: 'p2', name: 'Work', baseUrl: 'http://127.0.0.1:18031');
    final container = ProviderContainer(
      overrides: [
        sharedPreferencesProvider.overrideWithValue(prefs),
        secretStoreProvider.overrideWithValue(InMemorySecretStore()),
        initialProfilesStateProvider.overrideWithValue(
          const ProfilesState(profiles: [testProfile, other], activeId: 'p1'),
        ),
      ],
      retry: (_, _) => null,
    );
    addTearDown(container.dispose);
    final sub = container.listen(journalFilterProvider, (_, _) {});
    addTearDown(sub.close);
    container.read(journalFilterProvider.notifier)
      ..toggleTag('trip')
      ..setKeyword('sushi');
    expect(container.read(journalFilterProvider).isActive, isTrue);
    await container.read(profilesProvider.notifier).activate('p2');
    expect(container.read(journalFilterProvider), const JournalFilter());
  });
}
