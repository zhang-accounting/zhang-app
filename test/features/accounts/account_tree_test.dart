import 'package:decimal/decimal.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:zhang_app/data/models/models.dart';
import 'package:zhang_app/features/accounts/account_tree.dart';

import '../../helpers/fixtures.dart';

Decimal d(String v) => Decimal.parse(v);

Account acc(
  String name, {
  Map<String, String> detail = const {},
  String? calculated,
  bool closed = false,
  String? alias,
}) {
  final det = {for (final e in detail.entries) e.key: d(e.value)};
  final calc = calculated ?? (det['CNY']?.toString() ?? '0');
  return Account(
    name: name,
    status: closed ? AccountStatus.close : AccountStatus.open,
    alias: alias,
    amount: CalculatedAmount(calculated: Amount(d(calc), 'CNY'), detail: det),
  );
}

final _accounts = [
  acc('Assets:Bank:CMB', detail: {'CNY': '2754.06'}, alias: '招商银行储蓄'),
  acc('Assets:Bank:ICBC', detail: {'CNY': '1000'}),
  acc('Assets:Bank:HSBC', detail: {'CNY': '0', 'USD': '100'}, calculated: '710'),
  acc('Assets:Cash', detail: {'CNY': '50.5'}),
  acc('Assets:Old', detail: {'CNY': '0'}, closed: true),
  acc('Liabilities:CreditCard:CMB', detail: {'CNY': '-2703.29'}),
  acc('Expenses:Food:Lunch', detail: {'CNY': '30'}),
  acc('Expenses:Food', detail: {'CNY': '5'}),
  acc('Income:Salary', detail: {'CNY': '-9000'}),
  acc('Equity:Opening', detail: {'CNY': '-1000'}),
  acc('Bogus:Account', detail: {'CNY': '1'}),
];

AccountNode child(AccountNode n, String segment) => n.children.firstWhere((c) => c.segment == segment);

void main() {
  group('buildAccountTree', () {
    final tree = buildAccountTree(_accounts);

    test('sections follow Assets, Liabilities, Income, Expenses, Equity; invalid types are ignored', () {
      expect(tree.sections.map((s) => s.type), [
        AccountType.assets,
        AccountType.liabilities,
        AccountType.income,
        AccountType.expenses,
        AccountType.equity,
      ]);
      expect(tree.sections.first.root.path, 'Assets');
      expect(tree.sections.first.root.depth, 1);
    });

    test('nests colon-separated names and sorts children by segment', () {
      final assets = tree.sections.first.root;
      expect(assets.children.map((c) => c.segment), ['Bank', 'Cash']);
      final bank = child(assets, 'Bank');
      expect(bank.isAccount, isFalse); // virtual parent
      expect(bank.depth, 2);
      expect(bank.children.map((c) => c.path), [
        'Assets:Bank:CMB',
        'Assets:Bank:HSBC',
        'Assets:Bank:ICBC',
      ]);
      expect(child(bank, 'CMB').depth, 3);
      expect(child(bank, 'CMB').displayName, '招商银行储蓄');
      expect(child(bank, 'ICBC').displayName, 'ICBC');
      expect(child(bank, 'CMB').hasChildren, isFalse);
    });

    test('parent rows sum per commodity (like commodities only) and drop zeros', () {
      final assets = tree.sections.first.root;
      final bank = child(assets, 'Bank');
      expect(bank.balances, {'CNY': d('3754.06'), 'USD': d('100')});
      expect(bank.isMultiCommodity, isTrue);
      expect(bank.calculated, d('4464.06')); // 2754.06 + 1000 + 710
      expect(bank.calculatedCommodity, 'CNY');
      expect(assets.balances, {'CNY': d('3804.56'), 'USD': d('100')});
      expect(child(bank, 'HSBC').balances, {'USD': d('100')}); // CNY 0 dropped
    });

    test('an opened parent includes its own balance and its children', () {
      final food = child(tree.sections[3].root, 'Food');
      expect(food.isAccount, isTrue);
      expect(food.hasChildren, isTrue);
      expect(food.balances, {'CNY': d('35')});
    });

    test('closed accounts are hidden by default and counted', () {
      final assets = tree.sections.first.root;
      expect(assets.children.any((c) => c.segment == 'Old'), isFalse);
      expect(tree.closedCount, 1);

      final withClosed = buildAccountTree(_accounts, showClosed: true);
      final old = child(withClosed.sections.first.root, 'Old');
      expect(old.isClosed, isTrue);
      expect(withClosed.closedCount, 1);
    });

    test('search keeps matches and their ancestors (case-insensitive, all terms, alias)', () {
      final t = buildAccountTree(_accounts, query: 'icbc');
      expect(t.sections.map((s) => s.type), [AccountType.assets]);
      final assets = t.sections.single.root;
      expect(assets.children.map((c) => c.segment), ['Bank']);
      expect(assets.children.single.children.map((c) => c.segment), ['ICBC']);
      // Sums only cover the visible accounts.
      expect(assets.balances, {'CNY': d('1000')});

      final byAlias = buildAccountTree(_accounts, query: '招商');
      expect(byAlias.sections.single.root.descendantsAndSelf.last.path, 'Assets:Bank:CMB');

      final multi = buildAccountTree(_accounts, query: ' CMB   credit ');
      expect(multi.sections.single.type, AccountType.liabilities);

      expect(buildAccountTree(_accounts, query: 'nothing-like-this').isEmpty, isTrue);
    });

    test('works on the API fixture (multi-currency, unconverted BTC)', () {
      final list = (fixtureData('accounts.json') as List)
          .map((e) => Account.fromJson((e as Map).cast<String, Object?>()))
          .toList();
      final t = buildAccountTree(list);
      final assets = t.sections.first.root;
      expect(assets.balances, {'BTC': d('0.01'), 'CNY': d('134614'), 'USD': d('-260')});
      expect(assets.calculated, d('132768.0'));
    });
  });

  group('flattenTree', () {
    final tree = buildAccountTree(_accounts);

    test('default: Assets/Liabilities open, other sections and deeper parents closed', () {
      final assetRows = flattenTree(tree.sections[0].root);
      expect(assetRows.map((r) => r.node.path), ['Assets', 'Assets:Bank', 'Assets:Cash']);
      expect(assetRows.first.expanded, isTrue);
      expect(assetRows[1].expanded, isFalse);
      final expenseRows = flattenTree(tree.sections[3].root);
      expect(expenseRows.map((r) => r.node.path), ['Expenses']);
      expect(expenseRows.single.expanded, isFalse);
    });

    test('toggled paths flip the default', () {
      final rows = flattenTree(tree.sections[0].root, toggled: {'Assets:Bank'});
      expect(rows.map((r) => r.node.path), [
        'Assets',
        'Assets:Bank',
        'Assets:Bank:CMB',
        'Assets:Bank:HSBC',
        'Assets:Bank:ICBC',
        'Assets:Cash',
      ]);
      final collapsed = flattenTree(tree.sections[0].root, toggled: {'Assets'});
      expect(collapsed.map((r) => r.node.path), ['Assets']);
    });

    test('expandAll shows everything (search mode)', () {
      final rows = flattenTree(tree.sections[3].root, toggled: {'Expenses'}, expandAll: true);
      expect(rows.map((r) => r.node.path), ['Expenses', 'Expenses:Food', 'Expenses:Food:Lunch']);
      expect(rows.last.expanded, isFalse); // leaves never expanded
    });
  });

  group('computeNetWorth', () {
    test('assets + liabilities of calculated amounts, closed accounts included', () {
      final nw = computeNetWorth(
        [..._accounts, acc('Assets:Gone', detail: {'CNY': '1'}, closed: true)],
        operatingCurrency: 'CNY',
      );
      expect(nw.assets, d('4515.56')); // 2754.06 + 1000 + 710 + 50.5 + 0 + 1
      expect(nw.liabilities, d('-2703.29'));
      expect(nw.net, d('1812.27'));
      expect(nw.commodity, 'CNY');
      expect(nw.unconverted, isEmpty);
    });

    test('flags held commodities without a price to the operating currency', () {
      final list = (fixtureData('accounts.json') as List)
          .map((e) => Account.fromJson((e as Map).cast<String, Object?>()))
          .toList();
      final commodities = {
        for (final c in (fixtureData('commodities.json') as List))
          (c as Map)['name'] as String: Commodity.fromJson(c.cast<String, Object?>()),
      };
      final nw = computeNetWorth(list, operatingCurrency: 'CNY', commodities: commodities);
      expect(nw.assets, d('132768.0'));
      expect(nw.liabilities, d('-474.229'));
      expect(nw.unconverted, ['BTC']); // USD has a CNY price
    });
  });
}
