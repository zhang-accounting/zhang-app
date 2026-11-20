import 'package:decimal/decimal.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:zhang_app/data/models/amount.dart';
import 'package:zhang_app/data/models/transaction_request.dart';
import 'package:zhang_app/features/transaction_new/advanced_draft.dart';

Decimal d(String s) => Decimal.parse(s);

PostingDraft p(
  int key,
  String? account,
  String amount, [
  String? commodity = 'CNY',
  String cost = '',
  String price = '',
]) => PostingDraft(key: key, account: account, amount: amount, commodity: commodity, cost: cost, price: price);

/// CNY / USD / BTC as a zhang ledger declares them (default `RoundDown`).
({int precision, bool halfDown})? rules(String c) => switch (c) {
  'CNY' || 'USD' => (precision: 2, halfDown: true),
  'BTC' => (precision: 8, halfDown: true),
  _ => null,
};

void main() {
  final now = DateTime(2026, 11, 20, 9, 30);

  group('typed input', () {
    test('amounts: sign, U+2212, grouping, partial decimals', () {
      expect(parseAmountInput('-12.50'), d('-12.5'));
      expect(parseAmountInput('−12'), d('-12'));
      expect(parseAmountInput('+1,234.5'), d('1234.5'));
      expect(parseAmountInput('1,234,567'), d('1234567'));
      expect(parseAmountInput('1 234.5'), d('1234.5'));
      expect(parseAmountInput(' 12. '), d('12'));
      expect(parseAmountInput('.5'), d('0.5'));
      expect(parseAmountInput(''), isNull);
      expect(parseAmountInput('12a'), isNull);
      expect(parseAmountInput('1.2.3'), isNull);
      // A comma is only a thousands separator: `12,50` is not 1250 (nor 12.5).
      expect(parseAmountInput('12,50'), isNull);
      expect(parseAmountInput('1,23'), isNull);
      expect(parseAmountInput('1234,567'), isNull);
      expect(parseAmountInput('1,234,56'), isNull);
      expect(parseAmountInput('-'), isNull);
      expect(parseAmountInput('.'), isNull);
      expect(typedDecimals('12.50'), 2);
      expect(typedDecimals('12'), 0);
    });

    test('± toggles the sign, empty stays empty', () {
      expect(toggleSign('12'), '-12');
      expect(toggleSign('-12'), '12');
      expect(toggleSign('−12'), '12');
      expect(toggleSign('+3'), '-3');
      expect(toggleSign(''), '');
    });

    test('cost / price shorthand is wrapped, ledger syntax kept as written', () {
      expect(costToSend(''), isNull);
      expect(costToSend('26000 USD'), '{26000 USD}');
      expect(costToSend('{ 26000 USD }'), '{ 26000 USD }');
      expect(costToSend('{{1500 USD}}'), '{{1500 USD}}');
      expect(priceToSend(' '), isNull);
      expect(priceToSend('7.2 CNY'), '@ 7.2 CNY');
      expect(priceToSend('@@ 72 CNY'), '@@ 72 CNY');
    });

    test('links: ^ stripped, separators split, duplicates dropped', () {
      expect(parseLinks('^trip-2026  ^receipt,order-1 ^trip-2026'), ['trip-2026', 'receipt', 'order-1']);
      expect(parseLinks(''), isEmpty);
    });
  });

  group('weights', () {
    test('units, per-unit / total cost, per-unit / total price; cost wins over price', () {
      expect(postingWeight(d('10'), 'USD'), Amount(d('10'), 'USD'));
      expect(postingWeight(d('0.01'), 'BTC', cost: '{ 26000 USD }'), Amount(d('260'), 'USD'));
      expect(postingWeight(d('-2'), 'AAPL', cost: '{{300 USD}}'), Amount(d('-300'), 'USD'));
      expect(postingWeight(d('2'), 'AAPL', cost: '{150 USD, 2024-01-15, "lot"}'), Amount(d('300'), 'USD'));
      expect(postingWeight(d('10'), 'USD', price: '@ 7.2 CNY'), Amount(d('72'), 'CNY'));
      expect(postingWeight(d('-10'), 'USD', price: '@@ 72 CNY'), Amount(d('-72'), 'CNY'));
      expect(postingWeight(d('2'), 'AAPL', cost: '{150 USD}', price: '@ 160 USD'), Amount(d('300'), 'USD'));
    });

    test('an empty cost {} is booked by the server: unknown here', () {
      expect(postingWeight(d('-2'), 'AAPL', cost: '{}'), isNull);
      expect(postingWeight(d('2'), 'AAPL', cost: '{150 # 5 USD}'), isNull);
    });
  });

  group('balance', () {
    test('balanced single commodity; blank rows ignored', () {
      final b = balanceOf([p(0, 'Assets:Cash', '-30'), p(1, 'Expenses:Food', '30'), p(2, null, '')]);
      expect(b.isBalanced, isTrue);
      expect(b.autoCount, 0);
    });

    test('unbalanced: remainder per commodity, rounded to its precision', () {
      final b = balanceOf([
        p(0, 'Assets:Cash', '-30'),
        p(1, 'Expenses:Food', '29.999'),
        p(2, 'Assets:Paypal', '-5', 'USD'),
      ], rules: rules);
      expect(b.isUnbalanced, isTrue);
      expect(b.remainder, [Amount(d('-5'), 'USD')], reason: '−0.001 CNY rounds to 0 at precision 2');
    });

    test('the remainder rounds like the ledger: RoundDown ties towards zero, RoundUp away', () {
      final postings = [p(0, 'Assets:Cash', '-30'), p(1, 'Expenses:Food', '30.005')];
      expect(balanceOf(postings, rules: rules).isBalanced, isTrue, reason: '0.005 HalfDown → 0.00');
      final up = balanceOf(postings, rules: (c) => (precision: 2, halfDown: false));
      expect(up.remainder, [Amount(d('0.01'), 'CNY')], reason: '0.005 HalfUp → 0.01');
    });

    test('one empty amount takes the remainder (multi-commodity: one amount each)', () {
      final b = balanceOf([
        p(0, 'Expenses:Food', '60'),
        p(1, 'Expenses:Travel', '10', 'USD'),
        p(2, 'Liabilities:Card', ''),
      ]);
      expect(b.hasAuto, isTrue);
      expect(b.isUnbalanced, isFalse);
      expect(b.autoAmounts, [Amount(d('-60'), 'CNY'), Amount(d('-10'), 'USD')]);
      // …which the ledger cannot infer (TransactionExplicitPostingHaveMultipleCommodity).
      expect(b.autoNeedsOneCommodity, isTrue);
      expect(balanceOf([p(0, 'Expenses:Food', '60'), p(1, 'Liabilities:Card', '')]).autoNeedsOneCommodity, isFalse);
    });

    test('cost and price convert: buy BTC at a USD cost, USD at a CNY price', () {
      expect(
        balanceOf([p(0, 'Assets:Crypto', '0.01', 'BTC', '26000 USD'), p(1, 'Assets:Paypal', '-260', 'USD')]).isBalanced,
        isTrue,
      );
      expect(
        balanceOf([p(0, 'Assets:Paypal', '10', 'USD', '', '7.2 CNY'), p(1, 'Assets:Bank', '-72', 'CNY')]).isBalanced,
        isTrue,
      );
      final off = balanceOf([p(0, 'Assets:Paypal', '10', 'USD', '', '@ 7.25 CNY'), p(1, 'Assets:Bank', '-72', 'CNY')]);
      expect(off.remainder, [Amount(d('0.5'), 'CNY')]);
    });

    test('an empty {} cost leaves the balance to the server', () {
      final b = balanceOf([p(0, 'Assets:Stock', '-2', 'AAPL', '{}'), p(1, 'Assets:Cash', '300', 'USD')]);
      expect(b.indeterminate, isTrue);
      expect(b.isUnbalanced, isFalse);
      expect(b.isBalanced, isFalse);
    });
  });

  group('validation', () {
    AdvancedDraft draft(List<PostingDraft> postings) => AdvancedDraft(postings: postings);

    test('needs two postings with accounts, numbers and at most one empty amount', () {
      expect(validateAdvanced(draft([p(0, 'Assets:Cash', '-1')])), contains(AdvancedIssue.tooFewPostings));
      expect(validateAdvanced(draft([p(0, null, '-1'), p(1, 'Expenses:Food', '1')])), [AdvancedIssue.accountMissing]);
      expect(validateAdvanced(draft([p(0, 'Assets:Cash', '-1x'), p(1, 'Expenses:Food', '')])), [
        AdvancedIssue.amountInvalid,
      ]);
      expect(validateAdvanced(draft([p(0, 'Assets:Cash', '-1', null), p(1, 'Expenses:Food', '')])), [
        AdvancedIssue.commodityMissing,
      ]);
      expect(
        validateAdvanced(draft([p(0, 'Assets:Cash', '-1'), p(1, 'Expenses:Food', ''), p(2, 'Expenses:Fees', '')])),
        [AdvancedIssue.tooManyAuto],
      );
      expect(validateAdvanced(draft([p(0, 'Assets:Cash', '-1'), p(1, 'Expenses:Food', '2')])), [
        AdvancedIssue.unbalanced,
      ]);
      expect(
        validateAdvanced(
          draft([p(0, 'Expenses:Food', '60'), p(1, 'Expenses:Travel', '10', 'USD'), p(2, 'Liabilities:Card', '')]),
        ),
        [AdvancedIssue.autoMultipleCommodities],
      );
      expect(validateAdvanced(draft([p(0, 'Assets:Cash', '-1'), p(1, 'Expenses:Food', ''), p(2, null, '')])), isEmpty);
    });
  });

  group('request', () {
    test('N postings in order, auto posting, cost / price / comment; create sends no null keys', () {
      final request = buildAdvancedRequest(
        AdvancedDraft(
          flag: '!',
          payee: ' Sam\'s Club ',
          narration: 'Weekend',
          tags: const ['family'],
          links: const ['trip-2026'],
          metas: const [Meta('receipt', 'R-1'), Meta(' ', 'dropped')],
          postings: [
            p(0, 'Expenses:Food:Groceries', '320'),
            p(1, 'Expenses:Home', '80.5'),
            p(2, 'Assets:Paypal', '10', 'USD', '', '7.2 CNY').copyWith(comment: 'fx\nline'),
            p(3, 'Liabilities:Card', ''),
            p(4, null, ''),
          ],
        ),
        now: now,
        rules: rules,
      );
      final json = request.toJson();
      expect(json['datetime'], '2026-11-20T09:30:00', reason: 'empty date = now');
      expect(json['flag'], '!');
      expect(json['payee'], "Sam's Club");
      expect(json['links'], ['trip-2026']);
      expect(json['metas'], [
        {'key': 'receipt', 'value': 'R-1'},
      ]);
      final postings = json['postings']! as List;
      expect(postings, hasLength(4), reason: 'blank row dropped');
      expect(postings[0], {
        'account': 'Expenses:Food:Groceries',
        'unit': {'number': '320.00', 'commodity': 'CNY'},
      });
      expect((postings[1] as Map)['unit'], {'number': '80.50', 'commodity': 'CNY'});
      expect(postings[2], {
        'account': 'Assets:Paypal',
        'unit': {'number': '10.00', 'commodity': 'USD'},
        'price': '@ 7.2 CNY',
        'comment': 'fx line',
      });
      expect(postings[3], {'account': 'Liabilities:Card', 'unit': null});
    });

    test('an edit states cost / price / comment (null removes) and keeps metadata and written decimals', () {
      final base = CreateTransactionRequest(
        datetime: DateTime(2026, 11, 2, 10),
        payee: 'Supermarket',
        postings: [
          PostingRequest(account: 'Assets:Bank', unit: Amount(d('-88.5'), 'CNY'), scale: 1, sendWritten: true),
          PostingRequest(
            account: 'Expenses:Food',
            unit: Amount(d('88.5'), 'CNY'),
            scale: 1,
            comment: 'paid by card',
            metas: const [Meta('category', 'food')],
            sendWritten: true,
          ),
        ],
      );
      final draft = AdvancedDraft.fromRequest(base);
      expect(draft.postings[1].amount, '88.5');
      expect(draft.postings[1].comment, 'paid by card');
      final unchanged = buildAdvancedRequest(draft, now: now, edit: true, rules: rules).toJson();
      expect(unchanged, base.toJson(), reason: 'an untouched edit sends back what was read');

      final changed = buildAdvancedRequest(
        draft.copyWith(
          postings: [
            draft.postings[0].copyWith(amount: '-90'),
            draft.postings[1].copyWith(amount: '90', comment: ''),
          ],
        ),
        now: now,
        edit: true,
        rules: rules,
      ).toJson();
      final postings = changed['postings']! as List;
      expect(postings[1], {
        'account': 'Expenses:Food',
        'unit': {'number': '90.00', 'commodity': 'CNY'},
        'cost': null,
        'price': null,
        'comment': null,
        'metas': [
          {'key': 'category', 'value': 'food'},
        ],
      });
      expect(changed['datetime'], '2026-11-02T10:00:00');
    });

    test('payee / narration are kept as written while unchanged, trimmed once edited; origins follow the rows', () {
      final base = CreateTransactionRequest(
        datetime: DateTime(2026, 11, 2, 10),
        payee: ' Shop ',
        narration: 'Lunch ',
        postings: [
          PostingRequest(account: 'Assets:Bank', unit: Amount(d('-1'), 'CNY')),
          const PostingRequest(account: 'Expenses:Food'),
        ],
      );
      final draft = AdvancedDraft.fromRequest(base);
      final same = buildAdvancedRequest(draft, now: now, edit: true, rules: rules);
      expect((same.payee, same.narration), (' Shop ', 'Lunch '));
      final edited = buildAdvancedRequest(draft.copyWith(narration: ' Dinner '), now: now, edit: true, rules: rules);
      expect((edited.payee, edited.narration), (' Shop ', 'Dinner'));
      final moved = draft.copyWith(postings: [p(9, 'Expenses:Fees', '0'), draft.postings[1], draft.postings[0]]);
      expect(requestOrigins(moved), [null, 1, 0]);
    });

    test('an invalid draft is refused', () {
      expect(
        () => buildAdvancedRequest(AdvancedDraft(postings: [p(0, 'Assets:Cash', '1')]), now: now),
        throwsStateError,
      );
    });
  });
}
