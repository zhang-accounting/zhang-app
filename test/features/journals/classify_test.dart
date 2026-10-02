import 'package:flutter_test/flutter_test.dart';
import 'package:zhang_app/core/utils/money.dart';
import 'package:zhang_app/data/models/amount.dart';
import 'package:zhang_app/data/models/journal.dart';
import 'package:zhang_app/features/journals/classify.dart';

import '../../helpers/fixtures.dart';
import 'journal_test_utils.dart';

Amount a(String n, [String c = 'CNY']) => Amount.parse(n, c);

void main() {
  group('classify', () {
    test('expense paid from an asset account', () {
      final c = classify(
        txn(postings: [('Assets:CitiBank:9999', '-21', 'CNY'), ('Expenses:PersonalDiet:Lunch', '21', 'CNY')]),
      );
      expect(c.kind, TxnKind.expense);
      expect(c.isRefund, isFalse);
      expect(c.amounts, [a('-21')]);
      expect(c.primaryAccount, 'Expenses:PersonalDiet:Lunch');
      expect(c.counterAccount, 'Assets:CitiBank:9999');
      expect(c.isDirectional, isTrue);
      expect(c.toneFor(), AmountTone.negative);
    });

    test('expense on a credit card', () {
      final c = classify(
        txn(postings: [('Liabilities:CreditCard:Apple', '-27', 'CNY'), ('Expenses:PersonalDiet:Dinner', '27', 'CNY')]),
      );
      expect(c.kind, TxnKind.expense);
      expect(c.counterAccount, 'Liabilities:CreditCard:Apple');
      expect(c.primaryAmount, a('-27'));
    });

    test('negative expense total is a refund shown as income', () {
      final c = classify(
        txn(postings: [('Assets:WeChat', '15', 'CNY'), ('Expenses:Clothing', '-15', 'CNY')]),
      );
      expect(c.kind, TxnKind.income);
      expect(c.isRefund, isTrue);
      expect(c.amounts, [a('15')]);
      expect(c.toneFor(), AmountTone.positive);
    });

    test('income', () {
      final c = classify(
        txn(postings: [('Income:Remuneration', '-200', 'CNY'), ('Assets:CitiBank:9999', '200', 'CNY')]),
      );
      expect(c.kind, TxnKind.income);
      expect(c.isRefund, isFalse);
      expect(c.amounts, [a('200')]);
      expect(c.primaryAccount, 'Income:Remuneration');
      expect(c.counterAccount, 'Assets:CitiBank:9999');
      expect(c.toneFor(), AmountTone.positive);
    });

    test('transfer between assets and paying off a credit card', () {
      final transfer = classify(
        txn(postings: [('Assets:CitiBank:9999', '-100', 'CNY'), ('Assets:WeChat', '100', 'CNY')]),
      );
      expect(transfer.kind, TxnKind.transfer);
      expect(transfer.amounts, [a('100')]);
      expect(transfer.primaryAccount, 'Assets:WeChat');
      expect(transfer.counterAccount, 'Assets:CitiBank:9999');
      expect(transfer.isDirectional, isFalse);
      expect(transfer.toneFor(), AmountTone.neutral);

      final payoff = classify(
        txn(postings: [('Assets:CitiBank:9999', '-500', 'CNY'), ('Liabilities:CreditCard:Apple', '500', 'CNY')]),
      );
      expect(payoff.kind, TxnKind.transfer);
      expect(payoff.primaryAccount, 'Liabilities:CreditCard:Apple');
    });

    test('multi-posting salary with tax is compound; amount = net of money accounts', () {
      final c = classify(
        txn(
          postings: [
            ('Income:GrandLordCompany:Salary', '-2709', 'CNY'),
            ('Assets:CitiBank:9999', '2358', 'CNY'),
            ('Expenses:GrandLordCompany:Tax', '351', 'CNY'),
          ],
          implicit: {2},
        ),
      );
      expect(c.kind, TxnKind.compound);
      expect(c.amounts, [a('2358')]);
      expect(c.primaryAccount, 'Income:GrandLordCompany:Salary');
      expect(c.counterAccount, 'Assets:CitiBank:9999');
      expect(c.toneFor(), AmountTone.positive);
    });

    test('expense split over several categories sums the expenses', () {
      final c = classify(
        txn(
          postings: [
            ('Assets:Cash', '-1', 'CNY'),
            ('Expenses:A', '0.5', 'CNY'),
            ('Expenses:B', '0.5', 'CNY'),
          ],
        ),
      );
      expect(c.kind, TxnKind.expense);
      expect(c.amounts, [a('-1')]);
      expect(c.primaryAccount, 'Expenses:A');
    });

    test('anything touching Equity is an adjustment', () {
      final c = classify(
        txn(postings: [('Assets:CitiBank:9999', '158059', 'CNY'), ('Equity:OpenBalancing', '-158059', 'CNY')]),
      );
      expect(c.kind, TxnKind.adjustment);
      expect(c.amounts, [a('158059')]);
      expect(c.primaryAccount, 'Assets:CitiBank:9999');
      expect(c.counterAccount, 'Equity:OpenBalancing');
      expect(c.toneFor(), AmountTone.neutral);
    });

    test('multi-commodity: operating currency first, one amount per commodity', () {
      final c = classify(
        txn(
          postings: [
            ('Assets:Paypal', '-12.99', 'USD'),
            ('Assets:WeChat', '-20', 'CNY'),
            ('Expenses:Clothing', '12.99', 'USD'),
            ('Expenses:Clothing', '20', 'CNY'),
          ],
        ),
        operatingCurrency: 'CNY',
      );
      expect(c.kind, TxnKind.expense);
      expect(c.amounts, [a('-20'), a('-12.99', 'USD')]);
      expect(c.extraCommodities, 1);

      final noOp = classify(
        txn(
          postings: [
            ('Assets:Paypal', '-12.99', 'USD'),
            ('Assets:WeChat', '-20', 'CNY'),
            ('Expenses:Clothing', '12.99', 'USD'),
            ('Expenses:Clothing', '20', 'CNY'),
          ],
        ),
      );
      expect(noOp.amounts.first.commodity, 'USD');
    });

    test('fixture items: expense and an asset-only (BTC) transfer with exponent amount', () {
      final records = [
        for (final r in ((fixtureData('journals.json') as Map)['records'] as List))
          JournalItem.fromJson(r as Map<String, Object?>),
      ];
      final cafe = classify(records[0] as JournalTransaction, operatingCurrency: 'CNY');
      expect(cafe.kind, TxnKind.expense);
      expect(cafe.amounts, [a('-32.50')]);
      final btc = classify(records[2] as JournalTransaction);
      expect(btc.kind, TxnKind.transfer);
      expect(btc.amounts.single.commodity, 'BTC');
      expect(btc.amounts.single.number.toString(), '0.01000001');
    });
  });
}
