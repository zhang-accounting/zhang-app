import 'package:decimal/decimal.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:zhang_app/core/category_icons.dart';
import 'package:zhang_app/data/models/account.dart';
import 'package:zhang_app/data/models/amount.dart';
import 'package:zhang_app/features/transaction_new/category_tree.dart';
import 'package:zhang_app/features/transaction_new/widgets/category_grid.dart';

Account acc(String name, {bool open = true, String? alias}) => Account(
  name: name,
  status: open ? AccountStatus.open : AccountStatus.close,
  alias: alias,
  amount: CalculatedAmount(calculated: Amount(Decimal.zero, 'CNY')),
);

final _accounts = [
  acc('Expenses:Transport'),
  acc('Expenses:Food', alias: '餐饮'),
  acc('Expenses:Food:Dining'),
  acc('Expenses:Food:Groceries', alias: '买菜'),
  acc('Expenses:Food:Dining:Lunch'),
  acc('Expenses:PersonalDiet:Lunch'),
  acc('Expenses:PersonalDiet:Dinner'),
  acc('Expenses:Old', open: false),
  acc('Expenses:Old:Thing', open: false),
  acc('Expenses:Clothing:Shoes', open: false),
  acc('Expenses:Clothing:Coats'),
  acc('Expenses:Clothing', open: false),
  acc('Expenses:GrandLordCompany:Tax'),
  acc('Income:Salary'),
  acc('Assets:Bank'),
];

void main() {
  group('CategoryTree.fromAccounts', () {
    final tree = CategoryTree.fromAccounts(_accounts, AccountType.expenses);

    test('second-level tiles in stable name order, closed accounts excluded', () {
      expect(
        tree.categories.map((c) => c.name),
        ['Expenses:Clothing', 'Expenses:Food', 'Expenses:GrandLordCompany', 'Expenses:PersonalDiet', 'Expenses:Transport'],
      );
      expect(tree.byName('Expenses:Old'), isNull, reason: 'all accounts below are closed');
      // Same result whatever the input order.
      final shuffled = CategoryTree.fromAccounts(_accounts.reversed, AccountType.expenses);
      expect(shuffled.categories.map((c) => c.name), tree.categories.map((c) => c.name));
    });

    test('labels use the alias, else the last segment', () {
      expect(tree.byName('Expenses:Food')!.label, '餐饮');
      expect(tree.byName('Expenses:Transport')!.label, 'Transport');
      final food = tree.byName('Expenses:Food')!;
      expect(food.children.map((s) => s.label), ['Dining', 'Dining:Lunch', '买菜']);
      expect(food.children.map((s) => s.name), [
        'Expenses:Food:Dining',
        'Expenses:Food:Dining:Lunch',
        'Expenses:Food:Groceries',
      ]);
    });

    test('a tile that is not an open account itself requires a sub-category', () {
      final diet = tree.byName('Expenses:PersonalDiet')!;
      expect(diet.isOpen, isFalse);
      expect(diet.requiresSubcategory, isTrue);
      expect(diet.children.map((s) => s.label), ['Dinner', 'Lunch']);
      final clothing = tree.byName('Expenses:Clothing')!;
      expect(clothing.isOpen, isFalse, reason: 'Expenses:Clothing is closed');
      expect(clothing.children.map((s) => s.name), ['Expenses:Clothing:Coats']);
      expect(tree.byName('Expenses:Food')!.requiresSubcategory, isFalse);
      expect(tree.byName('Expenses:Transport')!.children, isEmpty);
    });

    test('only accounts of the root type are used', () {
      final income = CategoryTree.fromAccounts(_accounts, AccountType.income);
      expect(income.categories.map((c) => c.name), ['Income:Salary']);
      expect(CategoryTree.fromAccounts(const [], AccountType.income).isEmpty, isTrue);
    });

    test('locate maps posting accounts to tile + chip', () {
      final lunch = tree.locate('Expenses:PersonalDiet:Lunch')!;
      expect(lunch.category.name, 'Expenses:PersonalDiet');
      expect(lunch.subcategory!.name, 'Expenses:PersonalDiet:Lunch');
      final food = tree.locate('Expenses:Food')!;
      expect(food.subcategory, isNull);
      expect(tree.locate('Expenses:PersonalDiet'), isNull, reason: 'not an open account');
      expect(tree.locate('Expenses:Old:Thing'), isNull);
      expect(tree.locate('Expenses:Food:Unknown'), isNull);
    });

    test('accountLabel prefers a non-blank alias', () {
      expect(accountLabel('Assets:CMB:Savings', alias: '招行储蓄'), '招行储蓄');
      expect(accountLabel('Assets:CMB:Savings', alias: '  '), 'Savings');
      expect(accountLabel('Assets:CMB:Savings'), 'Savings');
    });
  });

  test('softWrapLabel breaks CamelCase labels between words only', () {
    expect(softWrapLabel('PersonalDiet'), 'Personal\u200BDiet');
    expect(softWrapLabel('GrandLordCompany'), 'Grand\u200BLord\u200BCompany');
    expect(softWrapLabel('HSBC'), 'HSBC');
    expect(softWrapLabel('餐饮'), '餐饮');
  });

  test('fitWordScale shrinks a single word that is wider than the tile', () {
    // The test font draws every glyph 1 em wide: "Transportation" = 140 px.
    const style = TextStyle(fontSize: 10);
    expect(fitWordScale('Food', style, 120), 1.0);
    expect(fitWordScale('Transportation', style, 120), closeTo(120 / 140 * 0.98, 0.001));
    expect(fitWordScale('Remuneration​Tax', style, 120), 1.0, reason: 'widest word is 120 px');
    expect(fitWordScale('Supercalifragilistic', style, 120), 0.7, reason: 'never below 0.7');
    expect(fitWordScale('日常生活用品与家居', style, 40), 1.0, reason: 'CJK wraps between characters');
  });

  group('category icons', () {
    test('english words and chinese keywords map to icons', () {
      expect(categoryIcon('Expenses:PersonalDiet'), Icons.restaurant);
      expect(categoryIcon('Expenses:Transportation'), Icons.directions_bus);
      expect(categoryIcon('Expenses:Clothing'), Icons.checkroom);
      expect(categoryIcon('Expenses:RemunerationTax'), Icons.request_quote, reason: 'last word wins');
      expect(categoryIcon('Expenses:Food', alias: '餐饮'), Icons.restaurant);
      expect(categoryIcon('Expenses:JiaJu', alias: '家具'), Icons.chair);
      expect(categoryIcon('Income:Salary'), Icons.payments);
      expect(categoryIcon('Expenses:Coffee'), Icons.local_cafe, reason: '"fee" must not match inside "coffee"');
    });

    test('children and the account type provide fallbacks', () {
      expect(
        categoryIcon('Expenses:GrandLordCompany', childNames: ['Expenses:GrandLordCompany:Tax']),
        Icons.request_quote,
      );
      expect(categoryIcon('Expenses:Zzz'), accountTypeIcon(AccountType.expenses));
      expect(categoryIcon('Liabilities:CreditCard:Apple'), Icons.credit_card);
      expect(matchCategoryIcon('Qwerty'), isNull);
      expect(matchCategoryIcon('CreditCard'), Icons.credit_card, reason: '"car" must not match "Card"');
    });
  });
}
