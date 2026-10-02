import 'package:decimal/decimal.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:zhang_app/data/models/account.dart';
import 'package:zhang_app/features/transaction_new/frecency.dart';
import 'package:zhang_app/features/transaction_new/transaction_history.dart';

final _now = DateTime(2026, 10, 2, 12);
DateTime daysAgo(num days) => _now.subtract(Duration(minutes: (days * 24 * 60).round()));

HistoryEntry entry(
  num daysBack,
  String payee, {
  String narration = '',
  List<String> tags = const [],
  Map<String, String> postings = const {},
}) => HistoryEntry(
  datetime: daysAgo(daysBack),
  payee: payee,
  narration: narration,
  tags: tags,
  postings: [for (final e in postings.entries) HistoryPosting(e.key, Decimal.parse(e.value), 'CNY')],
);

void main() {
  group('ExponentialDecayRanker', () {
    test('recency beats old frequency, frequency beats a single recent use', () {
      final r = ExponentialDecayRanker<String>();
      for (var i = 0; i < 3; i++) {
        r.update('old-frequent', daysAgo(100 + i)); // 3 × e^(−100/30) ≈ 0.11
      }
      r.update('yesterday', daysAgo(1)); // ≈ 0.97
      for (final d in [2, 3, 4]) {
        r.update('this-week', daysAgo(d)); // ≈ 2.7
      }
      r.update('today', daysAgo(0)); // 1.0
      expect(r.ranked(), ['this-week', 'today', 'yesterday', 'old-frequent']);
    });

    test('score equals log Σ exp(rate·t) (order independent)', () {
      final a = ExponentialDecayRanker<String>()
        ..update('x', daysAgo(10))
        ..update('x', daysAgo(1));
      final b = ExponentialDecayRanker<String>()
        ..update('x', daysAgo(1))
        ..update('x', daysAgo(10));
      expect(a.score('x'), closeTo(b.score('x'), 1e-9));
      final single = ExponentialDecayRanker<String>()..update('y', daysAgo(1));
      expect(a.score('x'), greaterThan(single.score('y')));
    });

    test('sort is stable and puts unseen items last in input order', () {
      final r = ExponentialDecayRanker<String>()..update('b', daysAgo(1));
      expect(r.sort(['z', 'a', 'b', 'c']), ['b', 'z', 'a', 'c']);
      expect(r.score('nope'), double.negativeInfinity);
    });
  });

  group('SuggestionIndex', () {
    final history = [
      entry(0.5, '隆江猪脚饭', narration: 'Eating Lunch', postings: {'Liabilities:Card': '-27', 'Expenses:Diet:Lunch': '27'}),
      entry(1, 'Starbucks', narration: 'Latte', tags: ['coffee'], postings: {'Assets:WeChat': '-30', 'Expenses:Coffee': '30'}),
      entry(2, '隆江猪脚饭', narration: 'Eating Dinner', postings: {'Assets:Bank': '-21', 'Expenses:Diet:Dinner': '21'}),
      entry(3, '隆江猪脚饭', narration: 'Eating Dinner', postings: {'Assets:Bank': '-21', 'Expenses:Diet:Dinner': '21'}),
      entry(40, 'Balance Check', postings: {'Assets:Bank': '1'}),
      entry(200, 'Old Shop', narration: 'Stuff', tags: ['old'], postings: {'Assets:Paypal': '-5', 'Expenses:Misc': '5'}),
    ];
    final index = SuggestionIndex.build(history, serverPayees: ['Zeta', 'Apple Store', 'Starbucks', 'Balance Pad']);

    test('payees by frecency, then server-only payees A→Z, synthetic ones dropped', () {
      expect(index.payees, ['隆江猪脚饭', 'Starbucks', 'Old Shop', 'Apple Store', 'Zeta']);
    });

    test('narrations and tags by frecency; payee narrations first', () {
      expect(index.narrations, ['Eating Dinner', 'Eating Lunch', 'Latte', 'Stuff']);
      expect(index.narrationsFor('Starbucks'), ['Latte', 'Eating Dinner', 'Eating Lunch', 'Stuff']);
      expect(index.tags, ['coffee', 'old']);
    });

    test('last transaction per payee and funding fallbacks', () {
      expect(index.lastForPayee('隆江猪脚饭')!.narration, 'Eating Lunch');
      expect(index.lastForPayee('nobody'), isNull);
      const funding = {AccountType.assets, AccountType.liabilities};
      expect(index.lastFundingFor('Expenses:Diet', funding), 'Liabilities:Card');
      expect(index.lastFundingFor('Expenses:Diet:Dinner', funding), 'Assets:Bank');
      expect(index.lastFundingFor('Expenses:Nothing', funding), isNull);
      expect(index.mostRecentAccount(const {AccountType.assets}), 'Assets:WeChat');
      expect(
        index.mostRecentAccount(const {AccountType.assets}, where: (a) => a != 'Assets:WeChat'),
        'Assets:Bank',
      );
      expect(index.rankedAccounts(const {AccountType.assets}).first, 'Assets:Bank');
    });

    test('filterSuggestions: prefix matches before substring matches, max 6, no echo', () {
      final ranked = ['Starbucks', 'Bar Star', 'Costar', 'stationery', 'Apple'];
      expect(filterSuggestions(ranked, 'sta'), ['Starbucks', 'stationery', 'Bar Star', 'Costar']);
      expect(filterSuggestions(ranked, ''), ranked);
      expect(filterSuggestions(ranked, 'Starbucks'), isEmpty);
      expect(filterSuggestions(List.generate(10, (i) => 'p$i'), 'p'), hasLength(6));
    });
  });
}
