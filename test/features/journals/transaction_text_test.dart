import 'package:flutter_test/flutter_test.dart';
import 'package:zhang_app/data/models/journal.dart';
import 'package:zhang_app/features/journals/transaction_text.dart';

import '../../helpers/fixtures.dart';
import 'journal_test_utils.dart';

void main() {
  final records = [
    for (final r in ((fixtureData('journals.json') as Map)['records'] as List))
      JournalItem.fromJson(r as Map<String, Object?>),
  ];

  test('transaction with tags, links, metas and an implicit posting', () {
    expect(
      journalItemToText(records[2]),
      '2026-10-02 18:30:00 * "Mobile Test Cafe" "Flat white" #mobile ^order-42\n'
      '  document: "attachments/71b1fd90-a3eb-4ad1-ad61-78bd7ae6a733/photo.png"\n'
      '  source: "zhang-app"\n'
      '  Assets:WeChat                -32.50 CNY\n'
      '  Expenses:PersonalDiet:Lunch',
    );
  });

  test('narration only, custom flag, escaping and date-only directives', () {
    final t = txn(
      datetime: '2023-09-01T00:00:00',
      narration: 'Say "hi" \\o/',
      flag: '!',
      postings: [('Assets:A', '-1', 'CNY'), ('Expenses:B', '1', 'CNY')],
    );
    expect(
      transactionToText(t),
      '2023-09-01 ! "Say \\"hi\\" \\\\o/"\n'
      '  Assets:A    -1.00 CNY\n'
      '  Expenses:B  1.00 CNY',
    );
  });

  test('payee without narration keeps an empty narration', () {
    final t = txn(payee: 'Shop', postings: [('Assets:A', '-1', 'CNY'), ('Expenses:B', '1', 'CNY')]);
    expect(transactionToText(t).split('\n').first, '2023-09-16 21:56:16 * "Shop" ""');
  });

  test('balance check (asserted amount, also when it failed) and balance pad', () {
    expect(journalItemToText(records[4]), '2023-09-10 23:00:00 balance Assets:WeChat 100.00 CNY');
    expect(journalItemToText(records[8]), '2023-05-31 01:01:01 balance Assets:CitiBank:9999 158059.00 CNY');
    const padText = '2023-05-31 01:01:01 balance Assets:CitiBank:9999 158059.00 CNY with pad Equity:OpenBalancing';
    expect(journalItemToText(records[9]), padText);
    final folded = foldBalancePads(records).whereType<JournalBalance>().firstWhere((b) => b.isPad);
    expect(folded.assertion, same(records[8]));
    expect(journalItemToText(folded), padText);
  });
}
