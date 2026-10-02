import 'package:decimal/decimal.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:zhang_app/features/transaction_new/entry_mode.dart';
import 'package:zhang_app/features/transaction_new/transaction_builder.dart';

final _when = DateTime.utc(2026, 10, 2, 9, 30);

EntryDraft draft(
  EntryMode mode, {
  String? amount = '15.5',
  String? commodity = 'CNY',
  bool categoryChosen = true,
  String? category,
  String? funding,
  String? from,
  String? to,
  String payee = '',
  String narration = '',
  List<String> tags = const [],
}) => EntryDraft(
  mode: mode,
  amount: amount == null ? null : Decimal.parse(amount),
  commodity: commodity,
  datetime: _when,
  categoryChosen: categoryChosen,
  categoryAccount: category,
  funding: funding,
  from: from,
  to: to,
  payee: payee,
  narration: narration,
  tags: tags,
);

void main() {
  group('buildTransactionRequest', () {
    test('expense: funding −A then category +A, both explicit', () {
      final req = buildTransactionRequest(
        draft(EntryMode.expense, category: 'Expenses:Food:Dining', funding: 'Assets:WeChat', payee: ' KFC '),
      );
      final json = req.toJson();
      expect(json['postings'], [
        {'account': 'Assets:WeChat', 'unit': {'number': '-15.5', 'commodity': 'CNY'}},
        {'account': 'Expenses:Food:Dining', 'unit': {'number': '15.5', 'commodity': 'CNY'}},
      ]);
      expect(json['payee'], 'KFC');
      expect(json['narration'], '', reason: 'narration is always sent');
      expect(json['tags'], <String>[]);
      expect(json['links'], <String>[]);
      expect(json['metas'], <Object>[]);
      expect(json['datetime'], '2026-10-02T09:30:00Z');
    });

    test('amounts are written with the commodity precision, never exponent notation', () {
      EntryDraft withPrecision(String amount, String commodity, int precision) => EntryDraft(
        mode: EntryMode.expense,
        amount: Decimal.parse(amount),
        commodity: commodity,
        datetime: _when,
        precision: precision,
        categoryChosen: true,
        categoryAccount: 'Expenses:Food',
        funding: 'Assets:Cash',
      );
      List<Object?> numbers(EntryDraft d) => [
        for (final p in buildTransactionRequest(d).toJson()['postings']! as List)
          ((p as Map)['unit'] as Map)['number'],
      ];
      expect(numbers(withPrecision('15.50', 'CNY', 2)), ['-15.50', '15.50']);
      expect(numbers(withPrecision('12', 'CNY', 2)), ['-12.00', '12.00']);
      expect(numbers(withPrecision('1E-8', 'BTC', 8)), ['-0.00000001', '0.00000001']);
      expect(numbers(withPrecision('1E+3', 'JPY', 0)), ['-1000', '1000']);
    });

    test('income: category −A then funding +A', () {
      final req = buildTransactionRequest(
        draft(
          EntryMode.income,
          amount: '2000',
          category: 'Income:Salary',
          funding: 'Assets:Bank',
          narration: ' October ',
          tags: ['work', ' '],
        ),
      );
      expect(req.postings.map((p) => (p.account, p.unit!.number.toString(), p.unit!.commodity)), [
        ('Income:Salary', '-2000', 'CNY'),
        ('Assets:Bank', '2000', 'CNY'),
      ]);
      expect(req.narration, 'October');
      expect(req.tags, ['work']);
    });

    test('transfer: from −A then to +A, no category needed', () {
      final req = buildTransactionRequest(
        draft(EntryMode.transfer, categoryChosen: false, from: 'Assets:Bank', to: 'Liabilities:Card', commodity: 'USD'),
      );
      expect(req.postings.map((p) => (p.account, p.unit!.number.toString(), p.unit!.commodity)), [
        ('Assets:Bank', '-15.5', 'USD'),
        ('Liabilities:Card', '15.5', 'USD'),
      ]);
    });

    test('every mode balances to zero', () {
      for (final mode in EntryMode.values) {
        final req = buildTransactionRequest(
          draft(mode, category: mode == EntryMode.income ? 'Income:X' : 'Expenses:X', funding: 'Assets:A', from: 'Assets:A', to: 'Assets:B'),
        );
        expect(req.postings, hasLength(2));
        final sum = req.postings.fold(Decimal.zero, (s, p) => s + p.unit!.number);
        expect(sum, Decimal.zero, reason: '$mode');
      }
    });

    test('throws for an invalid draft', () {
      expect(() => buildTransactionRequest(draft(EntryMode.expense)), throwsStateError);
    });
  });

  group('validateEntry', () {
    test('missing pieces in flow order', () {
      expect(validateEntry(draft(EntryMode.expense, amount: null, categoryChosen: false)), [
        EntryIssue.categoryMissing,
        EntryIssue.fundingMissing,
        EntryIssue.amountMissing,
      ]);
      expect(
        validateEntry(draft(EntryMode.expense, categoryChosen: true, category: null, funding: 'Assets:A')),
        [EntryIssue.subcategoryMissing],
      );
      expect(
        validateEntry(draft(EntryMode.income, amount: '0', category: 'Income:X', funding: 'Assets:A')),
        [EntryIssue.amountNotPositive],
      );
      expect(
        validateEntry(draft(EntryMode.expense, amount: '-3', category: 'Expenses:X', funding: 'Assets:A')),
        [EntryIssue.amountNotPositive],
      );
      expect(validateEntry(draft(EntryMode.transfer, from: 'Assets:A', to: 'Assets:A')), [EntryIssue.sameAccount]);
      expect(validateEntry(draft(EntryMode.transfer, to: 'Assets:A')), [EntryIssue.fromMissing]);
      expect(
        validateEntry(draft(EntryMode.expense, commodity: null, category: 'Expenses:X', funding: 'Assets:A')),
        [EntryIssue.commodityMissing],
      );
      expect(validateEntry(draft(EntryMode.expense, category: 'Expenses:X', funding: 'Assets:A')), isEmpty);
    });
  });

  test('normalizeTag strips # and whitespace', () {
    expect(normalizeTag(' #trip 2026 '), 'trip-2026');
    expect(normalizeTag('##food'), 'food');
    expect(normalizeTag(' # '), isNull);
  });

  test('EntryMode funding types and query parsing', () {
    expect(EntryMode.expense.allowsFunding('Liabilities:Card'), isTrue);
    expect(EntryMode.income.allowsFunding('Liabilities:Card'), isFalse);
    expect(EntryMode.income.allowsFunding('Assets:Bank'), isTrue);
    expect(EntryMode.transfer.allowsFunding('Expenses:Food'), isFalse);
    expect(EntryMode.fromQuery('income'), EntryMode.income);
    expect(EntryMode.fromQuery('advanced'), EntryMode.expense);
    expect(EntryMode.fromQuery(null), EntryMode.expense);
  });
}
