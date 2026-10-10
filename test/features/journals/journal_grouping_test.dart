import 'package:flutter_test/flutter_test.dart';
import 'package:zhang_app/data/models/amount.dart';
import 'package:zhang_app/data/models/journal.dart';
import 'package:zhang_app/features/journals/journal_grouping.dart';
import 'package:zhang_app/features/journals/year_month.dart';

import 'journal_test_utils.dart';

JournalItem item(Map<String, Object?> json) => JournalItem.fromJson(json);

void main() {
  final items = [
    item(expenseJson('a', '2023-10-02T19:00:00', amount: '30')),
    item(
      txnJson(
        id: 'b',
        datetime: '2023-10-02T08:00:00',
        payee: 'Boss',
        postings: [('Income:Salary', '-100', 'CNY'), ('Assets:Bank', '100', 'CNY')],
      ),
    ),
    item(
      txnJson(
        id: 'c',
        datetime: '2023-10-02T07:00:00',
        postings: [('Assets:Bank', '-50', 'CNY'), ('Assets:WeChat', '50', 'CNY')],
      ),
    ),
    item(balanceCheckJson(id: 'd', datetime: '2023-10-01T23:00:00')),
    item(expenseJson('e', '2023-10-01T12:00:00', amount: '5')),
    item(expenseJson('f', '2023-09-30T12:00:00', amount: '7')),
    item(expenseJson('g', '2023-09-29T12:00:00', amount: '8')),
  ];

  group('groupJournal', () {
    test('groups newest-first items into months and days, preserving order', () {
      final groups = groupJournal(items, hasMore: false);
      expect(groups.map((g) => g.month), [YearMonth(2023, 10), YearMonth(2023, 9)]);
      expect(groups[0].days.map((d) => d.day), [DateTime(2023, 10, 2), DateTime(2023, 10, 1)]);
      expect(groups[0].days[0].items.map((i) => i.id), ['a', 'b', 'c']);
      expect(groups[0].days[1].items.map((i) => i.id), ['d', 'e']);
      expect(groups[1].days.map((d) => d.day), [DateTime(2023, 9, 30), DateTime(2023, 9, 29)]);
      expect(groups[0].itemCount, 5);
      expect(groups.every((g) => g.days.every((d) => d.complete)), isTrue);
    });

    test('day net = income − expense; transfers and balance items do not count', () {
      final groups = groupJournal(items, hasMore: false, operatingCurrency: 'CNY');
      expect(groups[0].days[0].net, [Amount.parse('70', 'CNY')]); // +100 − 30, transfer ignored
      expect(groups[0].days[1].net, [Amount.parse('-5', 'CNY')]); // balance check ignored
    });

    test('a day with only transfers has no net', () {
      final only = [items[2]];
      expect(groupJournal(only, hasMore: false).single.days.single.net, isEmpty);
    });

    test('the oldest day is incomplete while more pages exist', () {
      final groups = groupJournal(items, hasMore: true);
      expect(groups.last.days.last.complete, isFalse);
      expect(groups.last.days.first.complete, isTrue);
      expect(groups.first.days.every((d) => d.complete), isTrue);
    });

    test('same-day items that are not adjacent are merged', () {
      final shuffled = [items[0], items[4], items[1]];
      final groups = groupJournal(shuffled, hasMore: false);
      expect(groups.single.days.map((d) => d.items.map((i) => i.id).toList()), [
        ['a', 'b'],
        ['e'],
      ]);
    });

    test('empty input → no groups', () {
      expect(groupJournal(const [], hasMore: true), isEmpty);
    });
  });

  group('JournalTypeFilter', () {
    test('accepts by classification; balance items only under all', () {
      expect(JournalTypeFilter.all.accepts(items[3]), isTrue);
      expect(JournalTypeFilter.expense.accepts(items[3]), isFalse);
      expect(JournalTypeFilter.expense.accepts(items[0]), isTrue);
      expect(JournalTypeFilter.income.accepts(items[1]), isTrue);
      expect(JournalTypeFilter.income.accepts(items[0]), isFalse);
      expect(JournalTypeFilter.transfer.accepts(items[2]), isTrue);
      expect(JournalTypeFilter.transfer.accepts(items[1]), isFalse);
    });
  });
}
