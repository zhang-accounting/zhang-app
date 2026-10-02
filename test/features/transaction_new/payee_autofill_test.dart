import 'package:decimal/decimal.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:zhang_app/data/models/account.dart';
import 'package:zhang_app/data/models/amount.dart';
import 'package:zhang_app/features/transaction_new/category_tree.dart';
import 'package:zhang_app/features/transaction_new/entry_form.dart';
import 'package:zhang_app/features/transaction_new/entry_mode.dart';
import 'package:zhang_app/features/transaction_new/payee_autofill.dart';
import 'package:zhang_app/features/transaction_new/transaction_history.dart';

HistoryEntry entry(Map<String, String> postings, {String narration = '', int daysAgo = 1}) => HistoryEntry(
  datetime: DateTime(2026, 10, 2).subtract(Duration(days: daysAgo)),
  payee: 'P',
  narration: narration,
  postings: [for (final e in postings.entries) HistoryPosting(e.key, Decimal.parse(e.value), 'CNY')],
);

Account acc(String name, {bool open = true}) => Account(
  name: name,
  status: open ? AccountStatus.open : AccountStatus.close,
  amount: CalculatedAmount(calculated: Amount(Decimal.zero, 'CNY')),
);

final _accounts = [
  acc('Assets:WeChat'),
  acc('Assets:Bank'),
  acc('Assets:Closed', open: false),
  acc('Liabilities:Card'),
  acc('Expenses:Diet:Lunch'),
  acc('Expenses:Diet:Dinner'),
  acc('Expenses:Clothing'),
  acc('Income:Salary'),
];
final _open = {for (final a in _accounts) if (a.isOpen) a.name};
bool _isOpen(String a) => _open.contains(a);
final _expenseTree = CategoryTree.fromAccounts(_accounts, AccountType.expenses);

void main() {
  final lunchOnCard = entry({'Liabilities:Card': '-27', 'Expenses:Diet:Lunch': '27'}, narration: 'Eating Lunch');
  final salary = entry({'Income:Salary': '-2709', 'Assets:Bank': '2358', 'Expenses:Tax': '351'}, narration: 'Salary');
  final topUp = entry({'Assets:Bank': '-100', 'Assets:WeChat': '100'});

  group('autofillFromEntry', () {
    test('expense: category posting, negative funding leg, narration, amount hint', () {
      final fill = autofillFromEntry(lunchOnCard, EntryMode.expense);
      expect(fill.category, 'Expenses:Diet:Lunch');
      expect(fill.funding, 'Liabilities:Card');
      expect(fill.narration, 'Eating Lunch');
      expect(fill.amount, Decimal.parse('27'));
      expect(fill.commodity, 'CNY');
    });

    test('income: income posting and the asset that received money', () {
      final fill = autofillFromEntry(salary, EntryMode.income);
      expect(fill.category, 'Income:Salary');
      expect(fill.funding, 'Assets:Bank');
      expect(fill.amount, Decimal.parse('2709'));
    });

    test('postings that do not fit the mode are not used', () {
      final asExpense = autofillFromEntry(salary, EntryMode.expense);
      expect(asExpense.category, 'Expenses:Tax');
      expect(asExpense.funding, 'Assets:Bank');
      final incomeFromExpense = autofillFromEntry(lunchOnCard, EntryMode.income);
      expect(incomeFromExpense.category, isNull);
      expect(incomeFromExpense.funding, isNull, reason: 'income mode only allows Assets');
      final transferFromExpense = autofillFromEntry(lunchOnCard, EntryMode.transfer);
      expect(transferFromExpense.from, isNull);
      expect(transferFromExpense.narration, 'Eating Lunch');
    });

    test('transfer: negative leg is from, positive leg is to', () {
      final fill = autofillFromEntry(topUp, EntryMode.transfer);
      expect(fill.from, 'Assets:Bank');
      expect(fill.to, 'Assets:WeChat');
      expect(fill.amount, Decimal.parse('100'));
      expect(fill.narration, isNull);
    });
  });

  group('EntryForm.withAutofill', () {
    final fill = autofillFromEntry(lunchOnCard, EntryMode.expense);

    test('fills category (tile + chip) and funding of an untouched form', () {
      final form = const EntryForm().withAutofill(fill, tree: _expenseTree, isOpen: _isOpen);
      expect(form.category, 'Expenses:Diet');
      expect(form.subcategory, 'Expenses:Diet:Lunch');
      expect(form.categoryAccount, 'Expenses:Diet:Lunch');
      expect(form.funding, 'Liabilities:Card');
      expect(form.fundingExplicit, isFalse);
    });

    test('never overrides what the user chose', () {
      final chosen = const EntryForm()
          .withCategory(_expenseTree.byName('Expenses:Clothing')!)
          .withFunding('Assets:WeChat')
          .withAutofill(fill, tree: _expenseTree, isOpen: _isOpen);
      expect(chosen.category, 'Expenses:Clothing');
      expect(chosen.categoryAccount, 'Expenses:Clothing');
      expect(chosen.funding, 'Assets:WeChat');
      expect(chosen.fundingExplicit, isTrue);
    });

    test('skips closed / unknown accounts', () {
      final stale = autofillFromEntry(
        entry({'Assets:Closed': '-5', 'Expenses:Gone:Away': '5'}),
        EntryMode.expense,
      );
      final form = const EntryForm().withAutofill(stale, tree: _expenseTree, isOpen: _isOpen);
      expect(form.category, isNull);
      expect(form.funding, isNull);
    });

    test('transfer fills from / to only when empty', () {
      final fill = autofillFromEntry(topUp, EntryMode.transfer);
      final empty = const EntryForm(mode: EntryMode.transfer).withAutofill(fill, isOpen: _isOpen);
      expect((empty.from, empty.to), ('Assets:Bank', 'Assets:WeChat'));
      final withTo = const EntryForm(mode: EntryMode.transfer).withTo('Liabilities:Card').withAutofill(fill, isOpen: _isOpen);
      expect((withTo.from, withTo.to), ('Assets:Bank', 'Liabilities:Card'));
    });
  });

  group('EntryForm rules', () {
    test('no category is pre-selected; a lone required child is auto-selected', () {
      expect(const EntryForm().category, isNull);
      final tree = CategoryTree.fromAccounts([acc('Income:CitiBank:Interest'), acc('Income:Pub:A'), acc('Income:Pub:B')], AccountType.income);
      final interest = const EntryForm(mode: EntryMode.income).withCategory(tree.byName('Income:CitiBank')!);
      expect(interest.categoryAccount, 'Income:CitiBank:Interest');
      final pub = const EntryForm(mode: EntryMode.income).withCategory(tree.byName('Income:Pub')!);
      expect(pub.categoryAccount, isNull, reason: 'two children: user must choose');
      expect(pub.withSubcategory('Income:Pub:B').categoryAccount, 'Income:Pub:B');
      expect(pub.withSubcategory('Income:Pub:B').withSubcategory('Income:Pub:B').subcategory, 'Income:Pub:B',
          reason: 'required sub-category cannot be cleared');
    });

    test('optional sub-category toggles back to the tile', () {
      final tree = CategoryTree.fromAccounts([acc('Expenses:Food'), acc('Expenses:Food:Dining')], AccountType.expenses);
      final form = const EntryForm().withCategory(tree.byName('Expenses:Food')!);
      expect(form.categoryAccount, 'Expenses:Food');
      expect(form.withSubcategory('Expenses:Food:Dining').categoryAccount, 'Expenses:Food:Dining');
      expect(form.withSubcategory('Expenses:Food:Dining').withSubcategory('Expenses:Food:Dining').categoryAccount, 'Expenses:Food');
    });

    test('switching mode clears the category and incompatible funding', () {
      final form = const EntryForm()
          .withCategory(_expenseTree.byName('Expenses:Clothing')!)
          .withFunding('Liabilities:Card');
      final income = form.withMode(EntryMode.income);
      expect(income.category, isNull);
      expect(income.funding, isNull, reason: 'income mode only allows Assets');
      final bank = form.withFunding('Assets:Bank').withMode(EntryMode.income);
      expect(bank.funding, 'Assets:Bank');
    });

    test('再记 keeps mode, date and funding; clears amount, category and tags', () {
      final date = DateTime(2026, 9, 30, 12);
      final form = const EntryForm()
          .withCategory(_expenseTree.byName('Expenses:Clothing')!)
          .withFunding('Assets:Bank')
          .withDate(date)
          .withTags(['trip'])
          .afterSaveAndAnother();
      expect(form.category, isNull);
      expect(form.amount.isEmpty, isTrue);
      expect(form.tags, isEmpty);
      expect(form.funding, 'Assets:Bank');
      expect(form.date, date);
      expect(form.hasInput, isFalse);
    });
  });

  group('resolveFunding', () {
    final index = SuggestionIndex.build([
      entry({'Assets:WeChat': '-10', 'Expenses:Clothing': '10'}, daysAgo: 1),
      entry({'Liabilities:Card': '-27', 'Expenses:Diet:Lunch': '27'}, daysAgo: 2),
    ]);
    final open = _open.toList()..sort();

    test('explicit choice > memory > category history > recent asset > first asset', () {
      final lunch = const EntryForm()
          .withCategory(_expenseTree.byName('Expenses:Diet')!)
          .withSubcategory('Expenses:Diet:Lunch');
      String? resolve(EntryForm f, {Map<String, String> memory = const {}, SuggestionIndex? idx}) => resolveFunding(
        f,
        isOpen: _isOpen,
        index: idx ?? index,
        openAccounts: open,
        remembered: (c) => memory[c],
      );
      expect(resolve(lunch.withFunding('Assets:Bank')), 'Assets:Bank');
      expect(resolve(lunch, memory: {'Expenses:Diet': 'Assets:Bank'}), 'Assets:Bank');
      expect(resolve(lunch, memory: {'Expenses:Diet:Lunch': 'Assets:WeChat', 'Expenses:Diet': 'Assets:Bank'}), 'Assets:WeChat');
      expect(resolve(lunch, memory: {'Expenses:Diet': 'Assets:Closed'}), 'Liabilities:Card',
          reason: 'closed remembered account is skipped; history of the category wins');
      expect(resolve(const EntryForm()), 'Assets:WeChat', reason: 'most recently used asset account');
      expect(resolve(const EntryForm(), idx: SuggestionIndex.empty), 'Assets:Bank', reason: 'first open asset');
      expect(resolve(const EntryForm(mode: EntryMode.transfer)), isNull);
    });

    test('income mode never resolves to a liability', () {
      final incomeIndex = SuggestionIndex.build([entry({'Liabilities:Card': '-1', 'Income:Salary': '1'})]);
      final form = const EntryForm(mode: EntryMode.income).withCategory(
        CategoryTree.fromAccounts(_accounts, AccountType.income).byName('Income:Salary')!,
      );
      expect(
        resolveFunding(form, isOpen: _isOpen, index: incomeIndex, openAccounts: open, remembered: (_) => 'Liabilities:Card'),
        'Assets:Bank',
      );
    });

    test('transfer source defaults to the most recent asset unless it is the destination', () {
      expect(resolveTransferFrom(const EntryForm(mode: EntryMode.transfer), isOpen: _isOpen, index: index), 'Assets:WeChat');
      expect(
        resolveTransferFrom(const EntryForm(mode: EntryMode.transfer).withTo('Assets:WeChat'), isOpen: _isOpen, index: index),
        isNull,
      );
    });
  });
}
