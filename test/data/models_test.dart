import 'dart:convert';

import 'package:decimal/decimal.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:zhang_app/data/models/models.dart';
import 'package:zhang_app/data/repositories/journal_repository.dart';

import '../helpers/fixtures.dart';

Decimal d(String s) => Decimal.parse(s);

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

  test('info', () {
    final info = ServerInfo.fromJson(fixtureData('info.json'));
    expect(info.title, 'My Accounting');
    expect(info.version, '0.1.0');
  });

  test('options', () {
    final o = LedgerOptions.fromJson(fixtureData('options.json'));
    expect(o.operatingCurrency, 'CNY');
    expect(o.timezone, 'Asia/Tokyo');
    expect(o.defaultCommodityPrecision, 2);
    expect(o['default_booking_method'], 'FIFO');
  });

  test('errors (pageable)', () {
    final p = Pageable.fromJson(fixtureData('errors.json'), LedgerError.fromJson);
    expect(p.totalCount, 2);
    expect(p.records.first.type, LedgerErrorType.unbalancedTransaction);
    expect(p.records.first.span!.filename, 'data/2023/12.zhang');
    expect(p.records.last.type, LedgerErrorType.accountBalanceCheckError);
    expect(p.records.last.metas['account_name'], 'Assets:WeChat');
    expect(LedgerErrorType.fromWire('SomethingNew'), LedgerErrorType.unknown);
  });

  group('journals', () {
    late Pageable<JournalItem> page;
    setUp(() => page = Pageable.fromJson(fixtureData('journals.json'), JournalItem.fromJson));

    test('page metadata', () {
      expect(page.totalCount, 202);
      expect(page.currentPage, 1);
      expect(page.hasNextPage, isTrue);
      expect(page.records, hasLength(5));
    });

    test('transaction with tags, links, metas, implicit posting', () {
      final tx = page.records.first as JournalTransaction;
      expect(tx.id, '7c785595-5694-c51e-dd34-115dc2cddeb1');
      expect(tx.datetime, DateTime(2026, 10, 2, 18, 30));
      expect(tx.payee, 'Mobile Test Cafe');
      expect(tx.narration, 'Flat white');
      expect(tx.tags, ['mobile']);
      expect(tx.links, ['order-42']);
      expect(tx.flag, '*');
      expect(tx.isBalanced, isTrue);
      expect(tx.documentPaths, ['attachments/13f9ced5-57ad-44ff-b2f6-d23fd7b2f329/photo.png']);
      expect(tx.postings[0].unit, Amount(d('-32.50'), 'CNY'));
      expect(tx.postings[1].unit, isNull);
      expect(tx.postings[1].inferredUnit, Amount(d('32.50'), 'CNY'));
      expect(tx.postings[1].accountAfter.number, d('1235.50'));
    });

    test('naive datetime is kept as wall-clock time', () {
      final tx = page.records[1] as JournalTransaction;
      expect(tx.datetime.isUtc, isFalse);
      expect(tx.datetime, DateTime(2023, 9, 16, 21, 56, 16));
      expect(tx.payee, '隆江猪脚饭');
    });

    test('cost postings and exponent amounts', () {
      final tx = page.records[2] as JournalTransaction;
      expect(tx.isPending, isTrue);
      expect(tx.postings[0].cost, Amount(d('26000'), 'USD'));
      expect(tx.postings[1].unit!.number, d('0.00000001'));
      expect(tx.postings[1].accountBefore.number, d('-1000'));
    });

    test('balance check and pad items', () {
      final check = page.records[3] as JournalBalance;
      expect(check.isCheck, isTrue);
      expect(check.narration, 'Assets:WeChat');
      expect(check.postings.single.inferredUnit.number, d('-145994.50'));
      final pad = page.records[4] as JournalBalance;
      expect(pad.isPad, isTrue);
      expect(pad.postings, hasLength(2));
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
    test('always sends narration, tags, links, metas; datetime with offset', () {
      final req = CreateTransactionRequest(
        datetime: DateTime.utc(2026, 10, 2, 9, 30),
        payee: 'Mobile Test Cafe',
        postings: [
          PostingRequest(account: 'Assets:WeChat', unit: Amount(d('-32.50'), 'CNY')),
          const PostingRequest(account: 'Expenses:PersonalDiet:Lunch'),
        ],
      );
      final json = jsonDecode(jsonEncode(req.toJson())) as Map<String, dynamic>;
      expect(json['datetime'], '2026-10-02T09:30:00Z');
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
      final tx = page.records.first as JournalTransaction;
      final json = CreateTransactionRequest.fromJournal(tx).copyWith(payee: 'Edited').toJson();
      expect(json['payee'], 'Edited');
      expect(json['tags'], ['mobile']);
      expect(json['links'], ['order-42']);
      expect((json['metas'] as List).map((m) => (m as Map)['key']), ['source', 'document']);
      expect((json['postings'] as List)[1], {'account': 'Expenses:PersonalDiet:Lunch', 'unit': null});
    });
  });

  test('for-new-transaction filters synthetic payees and sorts', () {
    final f = ForNewTransaction.fromJson(fixtureData('for_new_transaction.json'));
    expect(f.payees, isNot(contains('Balance Check')));
    expect(f.payees, isNot(contains('Balance Pad')));
    expect(f.payees.first, 'Adidas');
    expect(f.accountNames.first, 'Assets:Paypal');
  });

  group('accounts', () {
    test('list', () {
      final list = parseList(fixtureData('accounts.json'), Account.fromJson);
      final apple = list.first;
      expect(apple.type, AccountType.liabilities);
      expect(apple.isOpen, isTrue);
      expect(apple.amount.calculated, Amount(d('-474.229'), 'CNY'));
      expect(apple.amount.detail, {'CNY': d('-382'), 'USD': d('-12.99')});
      expect(list[1].amount.nonZeroDetail, [Amount(d('0.01'), 'BTC')]);
      expect(list[2].shortName, 'Paypal');
    });

    test('detail', () {
      final a = AccountDetail.fromJson(fixtureData('account_detail.json') as Map<String, Object?>);
      expect(a.openDate, DateTime(1970));
      expect(a.rawType, 'Assets');
      expect(a.amount.calculated.number, d('132768'));
    });

    test('journals (timestamp + naive datetime)', () {
      final list = parseList(fixtureData('account_journals.json'), AccountJournalEntry.fromJson);
      expect(list.first.datetime, DateTime(2023, 9, 13, 14, 25));
      expect(list.first.timestamp, 1694582700);
      expect(list.last.isBalanceItem, isTrue);
    });

    test('balances are sorted by date', () {
      final h = AccountBalanceHistory.fromJson(fixtureData('account_balances.json'));
      expect(h.commodities, ['CNY', 'USD']);
      expect(h.byCommodity['CNY']!.map((p) => p.date), [
        DateTime(2023, 6, 26),
        DateTime(2023, 8, 3),
        DateTime(2023, 8, 29),
      ]);
    });

    test('documents', () {
      final docs = parseList(fixtureData('account_documents.json'), DocumentEntity.fromJson);
      expect(docs.single.mimeType, isNull);
      expect(docs.single.b64Path, 'YXR0YWNobWVudHMvcmVjZWlwdC50eHQ=');
      expect(docs.single.isDownloadable, isTrue);
    });

    test('AccountType helpers', () {
      expect(AccountType.ofAccount('Expenses:Food'), AccountType.expenses);
      expect(AccountType.ofAccount('expenses:Food'), isNull);
      expect(AccountType.income.isNaturallyNegative, isTrue);
    });
  });

  test('documents', () {
    final docs = parseList(fixtureData('documents.json'), DocumentEntity.fromJson);
    expect(docs.first.isImage, isTrue);
    expect(docs.first.trxId, '7c785595-5694-c51e-dd34-115dc2cddeb1');
    expect(docs[1].account, 'Assets:WeChat');
  });

  group('commodities', () {
    test('list', () {
      final list = parseList(fixtureData('commodities.json'), Commodity.fromJson);
      final cny = list.first;
      expect(cny.prefix, '¥');
      expect(cny.format(d('-1234.5')), '-¥1,234.50');
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
      expect(usd.lots, hasLength(3));
      expect(usd.prices.map((p) => p.amount.number), [d('7.1'), d('7.25')]);
      final btc = CommodityDetail.fromJson(fixtureData('commodity_btc.json'));
      expect(btc.lots.single.cost, Amount(d('26000'), 'USD'));
      expect(btc.lots.single.acquisitionDate, DateTime(2023, 9, 6));
    });
  });

  group('statistics', () {
    test('summary (from/to with Z)', () {
      final s = StatisticSummary.fromJson(fixtureData('statistic_summary.json'));
      expect(s.from, DateTime.utc(2023, 8, 31, 15));
      expect(s.to, DateTime.utc(2023, 9, 30, 14, 59, 59));
      expect(s.expense.calculated.number, d('796.729'));
      expect(s.income.detail['CNY'], d('-436'));
      expect(s.transactionNumber, 40);
    });

    test('graph (naive UTC echoes, sorted maps)', () {
      final g = StatisticGraph.fromJson(fixtureData('statistic_graph.json'));
      expect(g.from, DateTime.utc(2023, 8, 31, 15));
      expect(g.balances.map((b) => b.date), [
        DateTime(2023, 8, 31),
        DateTime(2023, 9, 2),
        DateTime(2023, 9, 5),
      ]);
      expect(g.changes.first.date, DateTime(2023, 9, 1));
      expect(g.changes.first.byType[AccountType.income]!.calculated.number, d('-200'));
      expect(g.changes.last.byType.keys, containsAll([AccountType.assets, AccountType.expenses]));
    });

    test('rank', () {
      final r = StatisticRank.fromJson(fixtureData('statistic_rank.json'));
      expect(r.detail.first.account, 'Expenses:RemunerationTax');
      expect(r.detail.last.amount.calculated.number, d('298'));
      expect(r.topTransactions.first.trxId, '107c541d-653f-cb3a-e16d-ae192ec3684c');
      expect(r.to, DateTime.utc(2023, 9, 30, 14, 59, 59));
    });
  });

  group('budgets', () {
    test('list and detail', () {
      final list = parseList(fixtureData('budgets.json'), Budget.fromJson);
      expect(list.single.displayName, 'Eating');
      expect(list.single.availableAmount, Amount(d('911.50'), 'CNY'));
      final detail = BudgetDetail.fromJson(fixtureData('budget_detail.json') as Map<String, Object?>);
      expect(detail.relatedAccounts, ['Expenses:Groceries']);
      expect(detail.category, 'Living');
    });

    test('interval items', () {
      final items = parseList(fixtureData('budget_interval.json'), BudgetIntervalItem.fromJson);
      expect(items.first, isA<BudgetPosting>());
      expect((items.first as BudgetPosting).entry.payee, 'Supermarket');
      final event = items.last as BudgetEvent;
      expect(event.eventType, 'AddAssignedAmount');
      expect(event.amount.number, d('1000'));
      expect(event.instant, DateTime.utc(2023, 8, 31, 15));
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
  });
}
