import 'dart:convert';

import 'package:decimal/decimal.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:zhang_app/data/models/models.dart';
import 'package:zhang_app/data/repositories/journal_repository.dart';

import '../helpers/builtin_fake.dart';
import '../helpers/fixtures.dart';

Decimal d(String s) => Decimal.parse(s);

QueryResult q(Map<String, Object?> json) => QueryResult.fromJson(json);

void main() {
  group('amounts', () {
    test('parses decimal strings including exponent notation', () {
      expect(Amount.fromJson({'number': '1E-8', 'commodity': 'BTC'}).number, d('0.00000001'));
      expect(Amount.fromJson({'number': '-1E+3', 'commodity': 'CNY'}).number, d('-1000'));
      expect(Amount.fromJson({'number': '132768.0', 'commodity': 'CNY'}).number, d('132768'));
      expect(parseDecimal('1e-8'), d('0.00000001'));
    });

    test('rejects garbage', () {
      expect(() => Amount.fromJson({'number': 'abc', 'commodity': 'X'}), throwsFormatException);
    });

    test('serialises numbers as plain-notation strings, never JSON numbers', () {
      final json = jsonEncode(Amount(d('1E-8'), 'BTC').toJson());
      expect(json, '{"number":"0.00000001","commodity":"BTC"}');
      expect(jsonEncode(Amount(d('-1E+3'), 'CNY').toJson()), '{"number":"-1000","commodity":"CNY"}');
    });
  });

  group('info', () {
    test('v0.2 info has format and no reload failure', () {
      final info = ServerInfo.fromJson(fixtureData('info.json'));
      expect(info.title, 'My Accounting');
      expect(info.version, '0.1.0');
      expect(info.format, 'zhang');
      expect(info.reloadFailure, isNull);
      expect(info.isSupported, isTrue);
    });

    test('a reload failure is parsed', () {
      final info = ServerInfo.fromJson({
        'title': 'My Accounting',
        'version': '0.1.0',
        'build_date': '2026-10-10',
        'format': 'zhang',
        'reload_failure': {'file': 'data/2023/12.zhang', 'message': 'cannot parse data/2023/12.zhang'},
      });
      expect(info.reloadFailure, const ReloadFailure(file: 'data/2023/12.zhang', message: 'cannot parse data/2023/12.zhang'));
    });

    test('an info without format (zhang < 0.2) is not supported', () {
      final info = ServerInfo.fromJson({'title': 'x', 'version': '0.1.0', 'build_date': '2026-10-02'});
      expect(info.isSupported, isFalse);
    });
  });

  test('options', () {
    final o = LedgerOptions.fromJson(fixtureData('options.json'));
    expect(o.operatingCurrency, 'CNY');
    expect(o.timezone, 'Asia/Tokyo');
    expect(o.defaultCommodityPrecision, 2);
    expect(o['default_booking_method'], 'FIFO');
  });

  test('ledger errors (journals.errors rows)', () {
    final result = q(singleResult('errors.json'));
    expect(result.total, 2);
    final errors = [for (final r in result.rows) LedgerError.fromQueryRow(r)];
    expect(errors.first.type, LedgerErrorType.unbalancedTransaction);
    expect(errors.first.span!.filename, 'data/2023/12.zhang');
    expect(errors.first.span!.line, 38);
    expect(errors.first.span!.content, startsWith('2023-09-08 11:00:00 "Oops" "Unbalanced"'));
    expect(errors.first.metas['txn_id'], errors.first.id);
    expect(errors.last.type, LedgerErrorType.accountBalanceCheckError);
    expect(errors.last.metas['account_name'], 'Assets:WeChat');
    expect(LedgerErrorType.fromWire('SomethingNew'), LedgerErrorType.unknown);
    expect(LedgerErrorType.fromWire('CommodityNotAllowed'), LedgerErrorType.commodityNotAllowed);
  });

  group('journals', () {
    late Pageable<JournalItem> page;
    setUp(() => page = Pageable.fromJson(fixtureData('journals.json'), JournalItem.fromJson));

    test('page metadata', () {
      expect(page.totalCount, 214);
      expect(page.currentPage, 1);
      expect(page.hasNextPage, isTrue);
      expect(page.records, hasLength(10));
    });

    test('transaction with tags, links, metas, implicit posting', () {
      final tx = page.records[2] as JournalTransaction;
      expect(tx.datetime, DateTime(2026, 10, 2, 18, 30));
      expect(tx.payee, 'Mobile Test Cafe');
      expect(tx.narration, 'Flat white');
      expect(tx.tags, ['mobile']);
      expect(tx.links, ['order-42']);
      expect(tx.flag, '*');
      expect(tx.isBalanced, isTrue);
      expect(tx.documentPaths, ['attachments/71b1fd90-a3eb-4ad1-ad61-78bd7ae6a733/photo.png']);
      expect(tx.postings[0].unit, Amount(d('-32.50'), 'CNY'));
      expect(tx.postings[1].unit, isNull);
      expect(tx.postings[1].inferredUnit, Amount(d('32.50'), 'CNY'));
    });

    test('naive datetime is kept as wall-clock time', () {
      final tx = page.records[3] as JournalTransaction;
      expect(tx.datetime.isUtc, isFalse);
      expect(tx.datetime, DateTime(2023, 9, 16, 21, 56, 16));
      expect(tx.payee, '隆江猪脚饭');
    });

    test('pending flag, cost postings and tiny amounts in plain notation', () {
      expect((page.records[0] as JournalTransaction).isPending, isTrue);
      final tiny = page.records[1] as JournalTransaction;
      expect(tiny.postings[0].unit!.number, d('0.00000001'));
      final btc = page.records[6] as JournalTransaction;
      expect(btc.narration, 'Buy BTC (edited)');
      expect(btc.postings[0].cost, Amount(d('26000'), 'USD'));
      expect(btc.postings[0].unit, Amount(d('0.01'), 'BTC'));
      expect((page.records[5] as JournalTransaction).isBalanced, isFalse);
    });

    test('balance checks carry asserted / passed; pads their padded amount', () {
      final failed = page.records[4] as JournalBalance;
      expect(failed.isCheck, isTrue);
      expect(failed.narration, 'Assets:WeChat');
      expect(failed.postings.single.inferredUnit.number, Decimal.zero);
      expect(failed.asserted, Amount(d('100'), 'CNY'));
      expect(failed.checkedBalance, Amount(d('146183'), 'CNY'));
      expect(failed.difference, Amount(d('-146083'), 'CNY'));
      expect(failed.passed, isFalse);
      expect(failed.failed, isTrue);
      final passed = page.records[8] as JournalBalance;
      expect(passed.asserted, Amount(d('158059'), 'CNY'));
      expect(passed.passed, isTrue);
      expect(passed.failed, isFalse);
      final pad = page.records[9] as JournalBalance;
      expect(pad.isPad, isTrue);
      expect(pad.postings, hasLength(2));
      expect(pad.asserted, isNull);
      expect(pad.failed, isFalse);
      expect(pad.postings.first.inferredUnit, Amount(d('158059'), 'CNY'));
    });

    test('unknown item types do not break the page', () {
      final item = JournalItem.fromJson({
        'type': 'Document',
        'id': 'x',
        'sequence': 1,
        'datetime': '2023-01-01T00:00:00',
      });
      expect(item, isA<JournalUnknown>());
    });
  });

  group('transaction request', () {
    test('always sends narration, tags, links, metas; datetime as ledger wall clock', () {
      final req = CreateTransactionRequest(
        datetime: DateTime(2026, 10, 2, 9, 30),
        payee: 'Mobile Test Cafe',
        postings: [
          PostingRequest(account: 'Assets:WeChat', unit: Amount(d('-32.50'), 'CNY')),
          const PostingRequest(account: 'Expenses:PersonalDiet:Lunch'),
        ],
      );
      final json = jsonDecode(jsonEncode(req.toJson())) as Map<String, dynamic>;
      expect(json['datetime'], '2026-10-02T09:30:00');
      expect(json['narration'], '');
      expect(json['flag'], '*');
      expect(json['tags'], isEmpty);
      expect(json['links'], isEmpty);
      expect(json['metas'], isEmpty);
      expect(json['postings'][0]['unit']['number'], isA<String>());
      expect(json['postings'][1]['unit'], isNull);
    });

    test('fromJournal preserves tags, links, metas and written units', () {
      final page = Pageable.fromJson(fixtureData('journals.json'), JournalItem.fromJson);
      final tx = page.records[2] as JournalTransaction;
      final json = CreateTransactionRequest.fromJournal(tx).copyWith(payee: 'Edited').toJson();
      expect(json['payee'], 'Edited');
      expect(json['datetime'], '2026-10-02T18:30:00');
      expect(json['tags'], ['mobile']);
      expect(json['links'], ['order-42']);
      expect((json['metas'] as List).map((m) => (m as Map)['key']), ['document', 'source']);
      expect((json['postings'] as List)[1], {'account': 'Expenses:PersonalDiet:Lunch', 'unit': null});
    });
  });

  test('for-new-transaction from journals.payees + journals.accounts', () {
    final f = ForNewTransaction.fromResults(
      q(batchResult('for_new_transaction.json', 0)),
      q(batchResult('for_new_transaction.json', 1)),
    );
    expect(f.payees, isNot(contains('Balance Check')));
    expect(f.payees, isNot(contains('Balance Pad')));
    expect(f.payees.first, 'Adidas');
    expect(f.payees.last, '隆江猪脚饭');
    expect(f.accountNames.first, 'Assets:CitiBank:9999');
    expect(f.accountNames, contains('Expenses:Groceries'));
  });

  group('accounts', () {
    test('list', () {
      final list = parseList(fixtureData('accounts.json'), Account.fromJson);
      final citi = list.first;
      expect(citi.name, 'Assets:CitiBank:9999');
      expect(citi.type, AccountType.assets);
      expect(citi.isOpen, isTrue);
      final crypto = list[1];
      expect(crypto.amount.calculated, Amount(d('1885.0000'), 'CNY'), reason: 'BTC valued via its USD price');
      expect(crypto.amount.nonZeroDetail, [Amount(d('0.01'), 'BTC')]);
      expect(list[2].shortName, 'Paypal');
      expect(list[2].amount.detail, {'CNY': d('134614'), 'USD': d('-250')});
    });

    test('detail', () {
      final a = AccountDetail.fromJson(fixtureData('account_detail.json') as Map<String, Object?>);
      expect(a.openDate, DateTime(1970));
      expect(a.rawType, 'Assets');
      expect(a.amount.calculated.number, d('132801.50'));
    });

    test('journals (timestamp, naive datetime, real transaction id)', () {
      final list = parseList(fixtureData('account_journals.json'), AccountJournalEntry.fromJson);
      expect(list.first.datetime, DateTime(2026, 10, 6, 8));
      expect(list.first.timestamp, 1791241200);
      expect(list.first.account, 'Assets:WeChat');
      expect(list.first.payee, 'Pending Shop');
      final journal = Pageable.fromJson(fixtureData('journals.json'), JournalItem.fromJson);
      final cafe = list.firstWhere((e) => e.payee == 'Mobile Test Cafe');
      expect(cafe.trxId, journal.records[2].id, reason: 'trx_id is the /api/journals id');
      expect(list.last.isBalanceItem, isTrue);
    });

    test('journals: balance check rows carry asserted / passed', () {
      final list = parseList(fixtureData('account_journals.json'), AccountJournalEntry.fromJson);
      final failed = list.firstWhere((e) => e.payee == 'Balance Check' && e.passed == false);
      expect(failed.isCheck, isTrue);
      expect(failed.inferredUnit.number, Decimal.zero);
      expect(failed.asserted, Amount(d('100'), 'CNY'));
      expect(failed.checkedBalance, Amount(d('146183'), 'CNY'));
      final pad = list.last;
      expect(pad.isPad, isTrue);
      expect(pad.asserted, isNull);
      expect(pad.passed, isNull);
    });

    test('balance history (accounts.balance_history) grouped by currency and sorted', () {
      final h = AccountBalanceHistory.fromQuery(q(singleResult('account_balances.json')));
      expect(h.commodities, ['CNY', 'USD']);
      final cny = h.byCommodity['CNY']!;
      expect(cny.first.date, DateTime(2023, 5, 31));
      expect(cny.first.balance, Amount(d('135125'), 'CNY'));
      for (var i = 1; i < cny.length; i++) {
        expect(cny[i].date.isBefore(cny[i - 1].date), isFalse);
      }
    });

    test('documents (accounts.documents)', () {
      final docs = [for (final r in q(singleResult('account_documents.json')).rows) DocumentEntity.fromQueryRow(r)];
      final doc = docs.single;
      expect(doc.filename, 'receipt.txt');
      expect(doc.mimeType, 'text/plain');
      expect(doc.account, 'Assets:Paypal');
      expect(doc.trxId, isNull);
      expect(doc.datetime, DateTime(2023, 9, 7));
      expect(doc.b64Path, 'YXR0YWNobWVudHMvcmVjZWlwdC50eHQ=');
    });

    test('AccountType helpers', () {
      expect(AccountType.ofAccount('Expenses:Food'), AccountType.expenses);
      expect(AccountType.ofAccount('expenses:Food'), isNull);
      expect(AccountType.income.isNaturallyNegative, isTrue);
    });
  });

  test('documents (journals.documents, newest first)', () {
    final docs = [for (final r in q(singleResult('documents.json')).rows) DocumentEntity.fromQueryRow(r)];
    expect(docs, hasLength(3));
    expect(docs.first.isImage, isTrue);
    expect(docs.first.account, 'Assets:WeChat');
    expect(docs[1].trxId, '869ee8f5-efa2-1074-bc5d-0b9ef97a15f2');
    expect(docs[1].filename, 'photo.png');
    expect(docs[1].datetime, DateTime(2026, 10, 2, 18, 30));
    expect(docs.last.account, 'Assets:Paypal');
    expect(DocumentEntity.mimeTypeOf('a/B.JPG'), 'image/jpeg');
    expect(DocumentEntity.mimeTypeOf('noext'), isNull);
  });

  group('commodities', () {
    test('list', () {
      final list = parseList(fixtureData('commodities.json'), Commodity.fromJson);
      final cny = list.first;
      expect(cny.prefix, '¥');
      expect(cny.format(d('0.125')), '¥0.12', reason: 'RoundDown = HalfDown');
      expect(cny.format(d('-1234.5')), '−¥1,234.50');
      final usd = list[1];
      expect(usd.latestPriceAmount, d('7.25'));
      expect(usd.latestPriceDate, DateTime(2023, 9, 1));
      final btc = list[2];
      expect(btc.precision, 8);
      expect(btc.format(d('0.01')), '0.01000000 BTC');
      expect(btc.latestPriceAmount, isNull);
    });

    test('detail: lots and chronological prices', () {
      final usd = CommodityDetail.fromJson(fixtureData('commodity_usd.json'));
      expect(usd.lots, hasLength(2), reason: 'only Assets and Liabilities lots');
      expect(usd.prices.map((p) => p.amount.number), [d('7.1'), d('7.25')]);
      final btc = CommodityDetail.fromJson(fixtureData('commodity_btc.json'));
      expect(btc.lots.single.cost, Amount(d('26000'), 'USD'));
      expect(btc.lots.single.acquisitionDate, DateTime(2023, 9, 6));
    });
  });

  group('statistics', () {
    test('summary from the report.* batch', () {
      final s = StatisticSummary.fromResults(
        [for (var i = 0; i < 4; i++) q(batchResult('statistic_summary.json', i))],
        from: DateTime(2023, 9),
        to: DateTime(2023, 9, 30),
        currency: 'CNY',
      );
      expect(s.from, DateTime(2023, 9));
      expect(s.to, DateTime(2023, 9, 30));
      expect(s.balance.calculated, Amount(d('444531.8225'), 'CNY'));
      expect(s.balance.detail, {'BTC': d('0.01'), 'CNY': d('444553.50'), 'USD': d('-262.99')});
      expect(s.liability.calculated, Amount(d('-745.1775'), 'CNY'));
      expect(s.expense.calculated, Amount(d('798.6775'), 'CNY'));
      expect(s.expense.detail, {'CNY': d('704.50'), 'USD': d('12.99')});
      expect(s.income.calculated, Amount(d('-436'), 'CNY'));
      expect(s.income.detail['CNY'], d('-436'));
      expect(s.transactionNumber, 40);
    });

    test('summary of a period without flows is zero', () {
      final flowsColumns = batchResult('statistic_summary.json', 2)['columns'];
      final s = StatisticSummary.fromResults(
        [
          q(batchResult('statistic_summary.json', 0)),
          q(batchResult('statistic_summary.json', 1)),
          q({'columns': flowsColumns, 'rows': const <Object?>[]}),
          q({
            'columns': [
              {'name': 'transactions', 'type': 'int'},
            ],
            'rows': [
              [0],
            ],
          }),
        ],
        from: DateTime(2030),
        to: DateTime(2030, 1, 31),
        currency: 'CNY',
      );
      expect(s.expense.calculated, Amount(Decimal.zero, 'CNY'));
      expect(s.income.calculated.number, Decimal.zero);
      expect(s.transactionNumber, 0);
    });

    test('graph (ledger-local echoes, sorted maps)', () {
      final g = StatisticGraph.fromJson(fixtureData('statistic_graph.json'));
      expect(g.from, DateTime(2023, 9));
      expect(g.to, DateTime(2023, 9, 5, 23, 59, 59));
      expect(g.balances.map((b) => b.date), [
        for (var day = 1; day <= 5; day++) DateTime(2023, 9, day),
      ]);
      expect(g.changes.first.date, DateTime(2023, 9, 1));
      expect(g.changes.first.byType[AccountType.income]!.calculated.number, d('-200'));
      expect(g.changes.last.byType.keys, containsAll([AccountType.assets, AccountType.expenses]));
    });

    test('rank from report.account_totals + report.top_postings', () {
      final r = StatisticRank.fromResults(
        q(batchResult('statistic_rank.json', 0)),
        q(batchResult('statistic_rank.json', 1)),
        from: DateTime(2023, 9),
        to: DateTime(2023, 9, 30),
        currency: 'CNY',
      );
      expect(r.detail.first.account, 'Expenses:RemunerationTax');
      expect(r.detail.last.account, 'Expenses:PersonalDiet:Lunch');
      expect(r.detail.last.amount.calculated.number, d('298'));
      final clothing = r.detail.firstWhere((a) => a.account == 'Expenses:Clothing');
      expect(clothing.amount.calculated, Amount(d('184.1775'), 'CNY'));
      expect(clothing.amount.detail, {'CNY': d('90'), 'USD': d('12.99')});
      final top = r.topTransactions.first;
      expect(top.trxId, '257ba3ec-06a5-60a6-c012-db8495939e46');
      expect(top.datetime, DateTime(2023, 9, 5, 10));
      expect(top.inferredUnit, Amount(d('12.99'), 'USD'));
      expect(top.payee, 'UNIQLO');
      expect(r.to, DateTime(2023, 9, 30));
    });
  });

  group('budgets', () {
    test('month list and detail', () {
      final list = [for (final r in q(singleResult('budgets.json')).rows) Budget.fromQueryRow(r)];
      expect(list.single.displayName, 'Eating');
      expect(list.single.assignedAmount, Amount(d('1000'), 'CNY'));
      expect(list.single.activityAmount, Amount(d('88.50'), 'CNY'));
      expect(list.single.availableAmount, Amount(d('911.50'), 'CNY'));
      final detail = BudgetDetail.fromQueryRows(
        q(batchResult('budget_detail.json', 1)).rows.single,
        q(batchResult('budget_detail.json', 0)).rows.single,
      );
      expect(detail.relatedAccounts, ['Expenses:Groceries']);
      expect(detail.category, 'Living');
    });

    test('events and postings', () {
      final event = BudgetEvent.fromQueryRow(q(batchResult('budget_interval.json', 0)).rows.single);
      expect(event.eventType, 'assign');
      expect(event.amount.number, d('1000'));
      expect(event.instant, DateTime.utc(2023, 8, 31, 15));
      final posting = AccountJournalEntry.fromBudgetPosting(q(batchResult('budget_interval.json', 1)).rows.single);
      expect(posting.payee, 'Supermarket');
      expect(posting.trxId, '3bcdbf6a-ae47-0f9d-679a-3c4257b87b17');
      expect(posting.accountAfter, Amount(d('88.50'), 'CNY'));
    });
  });

  group('transaction preview', () {
    test('clean preview', () {
      final p = TransactionPreview.fromJson(fixtureData('transaction_preview.json'));
      expect(p.isClean, isTrue);
      expect(p.unbalanced, isEmpty);
      expect(p.text, contains('Assets:WeChat -32.50 CNY'));
    });

    test('refused field: no text, balance not checked', () {
      final p = TransactionPreview.fromJson(fixtureData('transaction_preview_errors.json'));
      expect(p.isClean, isFalse);
      expect(p.text, isNull);
      expect(p.unbalanced, isNull);
      final f = p.fieldErrors.single;
      expect(f.posting, 1);
      expect(f.field, 'account');
      expect(f.kind, 'invalid_account');
      expect(f.value, 'Foo:Bar');
      expect(f.message, startsWith('invalid account "Foo:Bar"'));
    });

    test('unbalanced (captured)', () {
      final p = TransactionPreview.fromJson(fixtureData('transaction_preview_unbalanced.json'));
      expect(p.isUnbalanced, isTrue);
      expect(p.unbalanced, [Amount(d('-1'), 'CNY')]);
      expect(p.errors.single.type, 'UnbalancedTransaction');
    });

    test('ledger errors and unbalanced amounts', () {
      final p = TransactionPreview.fromJson({
        'text': '2026-10-03 09:30:00 * "V" ""\n  Assets:Nope -1 CNY\n  Expenses:Medical',
        'field_errors': [],
        'unbalanced': [
          {'number': '-1', 'commodity': 'CNY'},
        ],
        'errors': [
          {
            'error_type': 'AccountDoesNotExist',
            'metas': {'account_name': 'Assets:Nope'},
          },
        ],
      });
      expect(p.isUnbalanced, isTrue);
      expect(p.errors.single.type, 'AccountDoesNotExist');
      expect(p.errors.single.account, 'Assets:Nope');
    });
  });

  test('balance requests', () {
    final check = BalanceCheckRequest(amount: Amount(d('20.50'), 'CNY'));
    expect(check.toJson(), {
      'type': 'Check',
      'amount': {'number': '20.5', 'commodity': 'CNY'},
    });
    final pad = BalancePadRequest(
      accountName: 'Assets:WeChat',
      amount: Amount(d('0'), 'CNY'),
      pad: 'Equity:OpenBalancing',
    );
    expect(pad.toJson(), {
      'type': 'Pad',
      'account_name': 'Assets:WeChat',
      'amount': {'number': '0', 'commodity': 'CNY'},
      'pad': 'Equity:OpenBalancing',
    });
  });

  test('SSE events', () {
    expect(ServerEvent.parse('{"type":"Connected"}'), isA<ServerConnected>());
    expect(ServerEvent.parse('{"type":"Reload"}'), isA<ServerReload>());
    final v = ServerEvent.parse('{"type":"NewVersionFound","version":"0.1.10"}');
    expect((v as ServerNewVersionFound).version, '0.1.10');
    expect(ServerEvent.parse('{"type":"Other"}'), isA<ServerUnknownEvent>());
  });

  test('JournalQuery builds literal bracket arrays', () {
    const q = JournalQuery(page: 1, size: 20, keyword: 'a b', tags: ['weekly', 'food'], links: ['r-1']);
    expect(
      q.toQueryString(),
      'page=1&size=20&keyword=a%20b&tags[0]=weekly&tags[1]=food&links[0]=r-1',
    );
    expect(const JournalQuery(page: 0, size: 0).toQueryString(), 'page=1&size=1');
    expect(const JournalQuery(size: 5000).toQueryString(), 'page=1&size=1000');
  });
}
