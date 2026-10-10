import 'package:decimal/decimal.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:zhang_app/data/models/models.dart';
import 'package:zhang_app/features/stats/report_aggregation.dart';
import 'package:zhang_app/features/stats/report_period.dart';

import '../../helpers/builtin_fake.dart';
import '../../helpers/fixtures.dart';

Decimal d(String v) => Decimal.parse(v);

AccountAmount row(String account, String calculated) => AccountAmount(
  account: account,
  amount: CalculatedAmount(calculated: Amount(d(calculated), 'CNY'), detail: {'CNY': d(calculated)}),
);

RankItem item(String key, String value) =>
    RankItem(key: key, value: d(value), hasChildren: false, isDirect: false);

void main() {
  group('aggregateRank', () {
    final rank = StatisticRank.fromResults(
      QueryResult.fromJson(batchResult('statistic_rank.json', 0)),
      QueryResult.fromJson(batchResult('statistic_rank.json', 1)),
      from: DateTime(2023, 9),
      to: DateTime(2023, 9, 30),
      currency: 'CNY',
    );

    test('top level aggregates to the second segment, sorted by value desc', () {
      final items = aggregateRank(rank.detail, 'Expenses');
      expect(items.map((i) => i.key), [
        'Expenses:PersonalDiet',
        'Expenses:Clothing',
        'Expenses:Groceries',
        'Expenses:GrandLordCompany',
        'Expenses:RemunerationTax',
      ]);
      expect(items.first.value, d('468')); // 170 + 298
      expect(items.first.hasChildren, isTrue);
      expect(items.first.label, 'PersonalDiet');
      expect(items[1].value, d('184.1775')); // converted (CNY 90 + USD 12.99 × 7.25)
      expect(items[1].hasChildren, isFalse);
      expect(items[3].hasChildren, isTrue); // GrandLordCompany:Tax
    });

    test('drill-down expands the next segment', () {
      final items = aggregateRank(rank.detail, 'Expenses:PersonalDiet');
      expect(items.map((i) => (i.key, i.value)), [
        ('Expenses:PersonalDiet:Lunch', d('298')),
        ('Expenses:PersonalDiet:Dinner', d('170')),
      ]);
      expect(items.every((i) => !i.hasChildren), isTrue);
      expect(aggregateRank(rank.detail, 'Expenses:Nope'), isEmpty);
    });

    test('postings directly on the drilled account become a direct item', () {
      final detail = [
        row('Expenses:Food', '5'),
        row('Expenses:Food:Lunch', '30'),
        row('Expenses:Food:Lunch:Team', '20'),
        row('Expenses:FoodCourt', '7'), // same prefix text, different account
      ];
      final top = aggregateRank(detail, 'Expenses');
      expect(top.map((i) => (i.key, i.value)), [('Expenses:Food', d('55')), ('Expenses:FoodCourt', d('7'))]);
      final food = aggregateRank(detail, 'Expenses:Food');
      expect(food.map((i) => (i.key, i.value, i.hasChildren, i.isDirect)), [
        ('Expenses:Food:Lunch', d('50'), true, false),
        ('Expenses:Food', d('5'), false, true),
      ]);
    });

    test('income is flipped to positive', () {
      final items = aggregateRank([
        row('Income:Salary', '-200'),
        row('Income:Publisher:A', '-148'),
        row('Income:Publisher:B', '-88'),
        row('Income:Refund', '10'),
      ], 'Income');
      expect(items.map((i) => (i.key, i.value)), [
        ('Income:Publisher', d('236')),
        ('Income:Salary', d('200')),
        ('Income:Refund', d('-10')),
      ]);
    });

    test('breadcrumbOf lists every ancestor level', () {
      expect(breadcrumbOf('Expenses'), ['Expenses']);
      expect(breadcrumbOf('Expenses:Food:Lunch'), ['Expenses', 'Expenses:Food', 'Expenses:Food:Lunch']);
    });
  });

  group('groupDonut', () {
    test('six or fewer positive items are all shown', () {
      final items = [for (var i = 1; i <= 6; i++) item('E:$i', '$i')];
      final slices = groupDonut(items);
      expect(slices.length, 6);
      expect(slices.first.key, 'E:6');
      expect(slices.any((s) => s.isOther), isFalse);
    });

    test('more than six → top six + Other with the rest', () {
      final items = [for (var i = 1; i <= 9; i++) item('E:$i', '$i')];
      final slices = groupDonut(items);
      expect(slices.length, 7);
      expect(slices.take(6).map((s) => s.key), ['E:9', 'E:8', 'E:7', 'E:6', 'E:5', 'E:4']);
      expect(slices.last.isOther, isTrue);
      expect(slices.last.value, d('6')); // 1 + 2 + 3
      expect(slices.last.count, 3);
    });

    test('exactly seven items still folds the smallest into Other', () {
      final slices = groupDonut([for (var i = 1; i <= 7; i++) item('E:$i', '$i')]);
      expect(slices.length, 7);
      expect(slices.last.isOther, isTrue);
      expect(slices.last.value, d('1'));
      expect(slices.last.count, 1);
    });

    test('zero and negative items are not drawn; maxSlices is configurable', () {
      final slices = groupDonut([item('A', '5'), item('B', '0'), item('C', '-3'), item('D', '2')]);
      expect(slices.map((s) => s.key), ['A', 'D']);
      final two = groupDonut([item('A', '5'), item('B', '4'), item('C', '3')], maxSlices: 2);
      expect(two.map((s) => s.key), ['A', 'B', null]);
    });

    test('shareOf', () {
      expect(shareOf(d('25'), d('100')), 0.25);
      expect(shareOf(d('-5'), d('100')), 0);
      expect(shareOf(d('5'), Decimal.zero), 0);
    });
  });

  group('bucketCashflow', () {
    final graph = StatisticGraph.fromJson(fixtureData('statistic_graph.json'));

    test('month view: one bucket per day, income flipped, outside days ignored', () {
      final buckets = bucketCashflow(graph, ReportPeriod.month(DateTime(2023, 9)));
      expect(buckets.length, 30);
      expect(buckets[0].start, DateTime(2023, 9, 1));
      expect(buckets[0].income, d('200'));
      expect(buckets[0].expense, d('53'));
      expect(buckets[0].net, d('147'));
      expect(buckets[2].income, d('34'));
      expect(buckets[4].expense, d('110.1775')); // incl. USD 12.99 at 7.25
      expect(buckets[4].income, Decimal.zero);
      final total = buckets.fold(Decimal.zero, (s, b) => s + b.expense);
      expect(total, d('373.6775'));

      final august = bucketCashflow(graph, ReportPeriod.month(DateTime(2023, 8)));
      expect(august.every((b) => b.income == Decimal.zero && b.expense == Decimal.zero), isTrue);
    });

    test('year view: monthly buckets', () {
      final buckets = bucketCashflow(graph, ReportPeriod.year(DateTime(2023)));
      expect(buckets.length, 12);
      expect(buckets[8].income, d('234'));
      expect(buckets[8].expense, d('373.6775'));
    });
  });

  group('colour slots', () {
    test('FNV-1a reference values', () {
      expect(stableHash(''), 0x811c9dc5);
      expect(stableHash('a'), 0xe40c292c);
    });

    test('stable per key and unique while slots are free', () {
      final keys = ['Expenses:Food', 'Expenses:Rent', 'Expenses:Travel', 'Expenses:Fun', 'Expenses:Car'];
      final a = assignColorSlots(keys);
      final b = assignColorSlots(keys);
      expect(a, b);
      expect(a.values.toSet().length, keys.length);
      expect(a.values.every((s) => s >= 0 && s < 8), isTrue);
      // The first key always gets its preferred slot.
      expect(a['Expenses:Food'], stableHash('Expenses:Food') % 8);
      // Nine keys on eight colours: the ninth reuses a slot instead of failing.
      final nine = assignColorSlots([for (var i = 0; i < 9; i++) 'K$i']);
      expect(nine.length, 9);
      expect(nine.values.toSet().length, 8);
    });
  });
}
