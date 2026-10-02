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

/// JSON of a `BalanceCheck` item asserting [after] on [account].
Map<String, Object?> balanceCheckJson({
  required String id,
  required String datetime,
  String account = 'Assets:WeChat',
  String delta = '-145994.50',
  String before = '146094.50',
  String after = '100.00',
}) => {
  'type': 'BalanceCheck',
  'id': id,
  'sequence': 0,
  'datetime': datetime,
  'payee': 'Balance Check',
  'narration': account,
  'type_': 'C',
  'postings': [
    {
      'account': account,
      'unit': {'number': delta, 'commodity': 'CNY'},
      'cost': null,
      'inferred_unit': {'number': delta, 'commodity': 'CNY'},
      'account_before': {'number': before, 'commodity': 'CNY'},
      'account_after': {'number': after, 'commodity': 'CNY'},
    },
  ],
};

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
