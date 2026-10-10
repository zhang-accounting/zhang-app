import 'package:decimal/decimal.dart';
import 'package:zhang_app/data/models/journal.dart';

/// `(account, number, commodity)`; `number == null` → implicit posting
/// whose inferred amount must be given via [inferred].
typedef P = (String account, String number, String commodity);

/// JSON of a `Transaction` journal item (the shape `/api/journals` returns).
Map<String, Object?> txnJson({
  required String id,
  required String datetime,
  String payee = '',
  String? narration,
  List<P> postings = const [],
  Set<int> implicit = const {},
  List<String> tags = const [],
  List<String> links = const [],
  String flag = '*',
  bool isBalanced = true,
  List<Map<String, String>> metas = const [],
  int sequence = 0,
}) => {
  'type': 'Transaction',
  'id': id,
  'sequence': sequence,
  'datetime': datetime,
  'payee': payee,
  'narration': narration,
  'tags': tags,
  'links': links,
  'flag': flag,
  'is_balanced': isBalanced,
  'postings': [
    for (final (i, (account, number, commodity)) in postings.indexed)
      {
        'account': account,
        'unit': implicit.contains(i) ? null : {'number': number, 'commodity': commodity},
        'cost': null,
        'inferred_unit': {'number': number, 'commodity': commodity},
        'account_before': {'number': '0', 'commodity': commodity},
        'account_after': {'number': number, 'commodity': commodity},
      },
  ],
  'metas': metas,
};

/// Parsed [JournalTransaction] built from [txnJson].
JournalTransaction txn({
  String id = 't',
  String datetime = '2023-09-16T21:56:16',
  String payee = '',
  String? narration,
  required List<P> postings,
  Set<int> implicit = const {},
  List<String> tags = const [],
  List<String> links = const [],
  String flag = '*',
  bool isBalanced = true,
  List<Map<String, String>> metas = const [],
}) =>
    JournalItem.fromJson(
          txnJson(
            id: id,
            datetime: datetime,
            payee: payee,
            narration: narration,
            postings: postings,
            implicit: implicit,
            tags: tags,
            links: links,
            flag: flag,
            isBalanced: isBalanced,
            metas: metas,
          ),
        )
        as JournalTransaction;

/// JSON of a `BalanceCheck` item asserting [asserted] on [account] whose
/// balance is [checked] (it passes when they are equal).
Map<String, Object?> balanceCheckJson({
  required String id,
  required String datetime,
  String account = 'Assets:WeChat',
  String asserted = '100.00',
  String checked = '146094.50',
  int sequence = 0,
}) {
  final difference = Decimal.parse(asserted) - Decimal.parse(checked);
  Map<String, Object?> cny(Object n) => {'number': '$n', 'commodity': 'CNY'};
  return {
    'type': 'BalanceCheck',
    'id': id,
    'sequence': sequence,
    'datetime': datetime,
    'payee': 'Balance Check',
    'narration': account,
    'type_': 'C',
    // zhang >= 0.2: a zero entry whose balances are the checked balance.
    'postings': [
      {
        'account': account,
        'unit': null,
        'cost': null,
        'inferred_unit': cny('0'),
        'account_before': cny(checked),
        'account_after': cny(checked),
        'metas': [],
        'written': null,
      },
    ],
    'asserted': cny(asserted),
    'checked_balance': cny(checked),
    'difference': cny(difference),
    'tolerance': null,
    'passed': difference == Decimal.zero,
  };
}

/// A `BalancePad` item: [account] padded by [amount] from [pad] (the pad of
/// a `balance … with pad`, which also yields a check at the same datetime).
Map<String, Object?> balancePadJson({
  required String id,
  required String datetime,
  String account = 'Assets:WeChat',
  String pad = 'Equity:OpenBalancing',
  String amount = '500',
  String before = '0',
  int sequence = 0,
}) {
  Map<String, Object?> cny(Object n) => {'number': '$n', 'commodity': 'CNY'};
  final after = Decimal.parse(before) + Decimal.parse(amount);
  return {
    'type': 'BalancePad',
    'id': id,
    'sequence': sequence,
    'datetime': datetime,
    'payee': 'Balance Pad',
    'narration': 'pad $account to $pad',
    'type_': 'P',
    'postings': [
      {
        'account': account,
        'unit': cny(amount),
        'cost': null,
        'inferred_unit': cny(amount),
        'account_before': cny(before),
        'account_after': cny(after),
      },
      {
        'account': pad,
        'unit': null,
        'cost': null,
        'inferred_unit': cny('-$amount'),
        'account_before': cny('0'),
        'account_after': cny('-$amount'),
      },
    ],
  };
}

/// A simple expense transaction (`Assets:WeChat -amount`, `Expenses:Food +amount`)
/// on [datetime].
Map<String, Object?> expenseJson(String id, String datetime, {String amount = '10', String payee = 'Shop'}) =>
    txnJson(
      id: id,
      datetime: datetime,
      payee: payee,
      narration: 'n-$id',
      postings: [('Assets:WeChat', '-$amount', 'CNY'), ('Expenses:Food', amount, 'CNY')],
      implicit: {1},
    );

/// `{"data": Pageable}` envelope for [records].
Map<String, Object?> pageJson(
  List<Map<String, Object?>> records, {
  required int page,
  required int size,
  required int total,
}) => {
  'data': {
    'total_count': total,
    'total_page': (total + size - 1) ~/ size,
    'page_size': size,
    'current_page': page,
    'records': records,
  },
};
