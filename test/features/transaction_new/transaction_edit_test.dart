import 'package:decimal/decimal.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:zhang_app/data/api/zhang_api_client.dart';
import 'package:zhang_app/data/models/account.dart';
import 'package:zhang_app/data/models/amount.dart';
import 'package:zhang_app/data/models/journal.dart';
import 'package:zhang_app/data/models/transaction_preview.dart';
import 'package:zhang_app/data/models/transaction_request.dart';
import 'package:zhang_app/data/profiles/server_profile.dart';
import 'package:zhang_app/data/repositories/journal_repository.dart';
import 'package:zhang_app/features/transaction_new/entry_mode.dart';
import 'package:zhang_app/features/transaction_new/transaction_edit.dart';

Decimal d(String s) => Decimal.parse(s);

/// `(account, number or null for an implicit unit, extras)`.
Map<String, Object?> posting(
  String account,
  String? number, {
  String commodity = 'CNY',
  String? cost,
  String? price,
  String? comment,
  List<Map<String, String>> metas = const [],
  bool written = true,
  bool reportsMetas = true,
}) => {
  'account': account,
  'unit': number == null ? null : {'number': number, 'commodity': commodity},
  'cost': null,
  'inferred_unit': {'number': number ?? '0', 'commodity': commodity},
  'account_before': {'number': '0', 'commodity': commodity},
  'account_after': {'number': '0', 'commodity': commodity},
  if (reportsMetas) 'metas': metas,
  'written': written ? {'cost': cost, 'price': price, 'comment': comment} : null,
};

JournalTransaction tx(
  List<Map<String, Object?>> postings, {
  String id = 'tx-1',
  bool? dropsText = false,
  List<Map<String, String>> metas = const [],
  List<String> links = const [],
  String flag = '*',
}) =>
    JournalItem.fromJson({
          'type': 'Transaction',
          'id': id,
          'sequence': 1,
          'datetime': '2026-11-02T10:00:00',
          'payee': 'Supermarket',
          'narration': 'Weekly',
          'tags': ['weekly'],
          'links': links,
          'flag': flag,
          'is_balanced': true,
          'postings': postings,
          'metas': metas,
          'edit_drops_text': ?dropsText,
        })
        as JournalTransaction;

Account open(String name, {bool closed = false}) => Account(
  name: name,
  status: closed ? AccountStatus.close : AccountStatus.open,
  amount: CalculatedAmount(calculated: Amount(Decimal.zero, 'CNY')),
);

final accounts = [
  open('Assets:Bank'),
  open('Assets:Cash'),
  open('Liabilities:Card'),
  open('Expenses:Food'),
  open('Expenses:Food:Lunch'),
  open('Expenses:Old', closed: true),
  open('Income:Salary'),
];

class _Repo extends JournalRepository {
  _Repo(this.answer) : super(ZhangApiClient(const ServerProfile(id: 'p', name: 'p', baseUrl: 'http://127.0.0.1:1')));

  final TransactionPreview answer;
  final calls = <(String, Map<String, Object?>)>[];

  @override
  Future<TransactionPreview> previewUpdate(String id, CreateTransactionRequest request) async {
    calls.add((id, request.toJson()));
    return answer;
  }
}

void main() {
  group('editBlockFor', () {
    test('a fully reported transaction can be edited', () {
      expect(editBlockFor(tx([posting('Assets:Bank', '-1'), posting('Expenses:Food', null)])), isNull);
    });

    test('balance items, plugin-made, old servers and comment lines are blocked', () {
      final check = JournalItem.fromJson({
        'type': 'BalanceCheck',
        'id': 'c',
        'sequence': 1,
        'datetime': '2026-11-02T10:00:00',
        'payee': 'Balance Check',
        'narration': 'Assets:Bank',
        'type_': 'C',
        'postings': const [],
      });
      expect(editBlockFor(check), EditBlock.notTransaction);
      expect(
        editBlockFor(tx([posting('Assets:Bank', '-1', written: false), posting('Expenses:Food', null)])),
        EditBlock.notWritten,
      );
      expect(
        editBlockFor(tx([posting('Assets:Bank', '-1', reportsMetas: false), posting('Expenses:Food', null)])),
        EditBlock.unknownShape,
      );
      expect(
        editBlockFor(tx([posting('Assets:Bank', '-1'), posting('Expenses:Food', null)], dropsText: null)),
        EditBlock.unknownShape,
      );
      expect(
        editBlockFor(tx([posting('Assets:Bank', '-1'), posting('Expenses:Food', null)], dropsText: true)),
        EditBlock.dropsText,
      );
    });
  });

  test('posting flags are found in the preview text, not in metadata or the header', () {
    expect(hasPostingFlags('2026-11-04 12:00:00 * "Exchange" "x"\n  Assets:Paypal 10 USD @ 7.2 CNY\n  ! Assets:Bank -72 CNY'), isTrue);
    expect(
      hasPostingFlags('2026-11-02 10:00:00 ! "Supermarket" "Weekly" #weekly\n  count: 3\n  Assets:Bank -88.5 CNY\n'
          '  Expenses:Food 88.5 CNY ; paid by card\n    category: "food"'),
      isFalse,
    );
  });

  group('checkEditable', () {
    final editable = tx([posting('Assets:Bank', '-1'), posting('Expenses:Food', null)]);

    test('previews the transaction unchanged on its id', () async {
      final repo = _Repo(const TransactionPreview(text: '2026-11-02 * "S" "W"\n  Assets:Bank -1 CNY\n  Expenses:Food'));
      expect(await checkEditable(repo, editable), isNull);
      expect(repo.calls.single.$1, 'tx-1');
      expect(repo.calls.single.$2, CreateTransactionRequest.fromJournal(editable).toJson());
    });

    test('a posting flag or a refused transaction blocks the edit', () async {
      expect(
        await checkEditable(_Repo(const TransactionPreview(text: 'x\n  ! Assets:Bank -1 CNY\n  Expenses:Food')), editable),
        EditBlock.postingFlag,
      );
      expect(await checkEditable(_Repo(const TransactionPreview()), editable), EditBlock.unverified);
    });

    test('blocked without asking the server', () async {
      final repo = _Repo(const TransactionPreview(text: 'x'));
      final blocked = tx([posting('Assets:Bank', '-1'), posting('Expenses:Food', null)], dropsText: true);
      expect(await checkEditable(repo, blocked), EditBlock.dropsText);
      expect(repo.calls, isEmpty);
    });
  });

  group('simpleFitFor', () {
    test('expense, income and transfer, whatever the posting order', () {
      final expense = simpleFitFor(tx([posting('Expenses:Food:Lunch', '18.50'), posting('Assets:Cash', '-18.50')]), accounts)!;
      expect(expense.mode, EntryMode.expense);
      expect((expense.category, expense.funding, expense.amount), ('Expenses:Food:Lunch', 'Assets:Cash', d('18.5')));
      final income = simpleFitFor(tx([posting('Assets:Bank', '5000'), posting('Income:Salary', '-5000')]), accounts)!;
      expect((income.mode, income.category, income.funding), (EntryMode.income, 'Income:Salary', 'Assets:Bank'));
      final transfer = simpleFitFor(tx([posting('Assets:Bank', '-100'), posting('Liabilities:Card', '100')]), accounts)!;
      expect((transfer.mode, transfer.from, transfer.to), (EntryMode.transfer, 'Assets:Bank', 'Liabilities:Card'));
    });

    test('everything the simple form cannot show goes to the advanced editor', () {
      List<Map<String, Object?>> pair({String? cost, String? price}) => [
        posting('Assets:Cash', '-10', price: price),
        posting('Expenses:Food', '10', cost: cost),
      ];
      expect(simpleFitFor(tx(pair()), accounts), isNotNull);
      // auto posting, three postings, two commodities, cost / price
      expect(simpleFitFor(tx([posting('Assets:Cash', '-10'), posting('Expenses:Food', null)]), accounts), isNull);
      expect(
        simpleFitFor(
          tx([posting('Assets:Cash', '-10'), posting('Expenses:Food', '6'), posting('Expenses:Food:Lunch', '4')]),
          accounts,
        ),
        isNull,
      );
      expect(
        simpleFitFor(tx([posting('Assets:Cash', '-10'), posting('Expenses:Food', '10', commodity: 'USD')]), accounts),
        isNull,
      );
      expect(simpleFitFor(tx(pair(price: '@ 1 CNY')), accounts), isNull);
      expect(simpleFitFor(tx(pair(cost: '{1 CNY}')), accounts), isNull);
      // a refund (Expenses −), a closed or unknown account, Liabilities as income target
      expect(simpleFitFor(tx([posting('Assets:Cash', '10'), posting('Expenses:Food', '-10')]), accounts), isNull);
      expect(simpleFitFor(tx([posting('Assets:Cash', '-10'), posting('Expenses:Old', '10')]), accounts), isNull);
      expect(simpleFitFor(tx([posting('Assets:Cash', '-10'), posting('Expenses:Nope', '10')]), accounts), isNull);
      expect(simpleFitFor(tx([posting('Liabilities:Card', '10'), posting('Income:Salary', '-10')]), accounts), isNull);
    });
  });

  group('overlaySimpleEntry', () {
    final original = tx(
      [
        posting('Expenses:Food', '88.5', comment: 'paid by card', metas: [
          {'key': 'category', 'value': 'food'},
        ]),
        posting('Assets:Bank', '-88.5'),
      ],
      metas: [
        {'key': 'receipt_no', 'value': 'A-1'},
      ],
      links: ['receipt-001'],
      flag: '!',
    );
    final base = CreateTransactionRequest.fromJournal(original);

    CreateTransactionRequest built(String amount, {String funding = 'Assets:Bank', String category = 'Expenses:Food'}) =>
        CreateTransactionRequest(
          datetime: DateTime(2026, 11, 3, 8),
          payee: 'Market',
          narration: 'Edited',
          tags: const ['food'],
          postings: [
            PostingRequest(account: funding, unit: Amount(-d(amount), 'CNY'), scale: 2),
            PostingRequest(account: category, unit: Amount(d(amount), 'CNY'), scale: 2),
          ],
        );

    test('unchanged amounts keep their written decimals; everything unshown is kept', () {
      final json = overlaySimpleEntry(base, built('88.5')).toJson();
      expect(json['datetime'], '2026-11-03T08:00:00');
      expect(json['payee'], 'Market');
      expect(json['narration'], 'Edited');
      expect(json['tags'], ['food']);
      expect(json['flag'], '!');
      expect(json['links'], ['receipt-001']);
      expect(json['metas'], [
        {'key': 'receipt_no', 'value': 'A-1'},
      ]);
      expect(json['postings'], [
        {
          'account': 'Expenses:Food',
          'unit': {'number': '88.5', 'commodity': 'CNY'},
          'cost': null,
          'price': null,
          'comment': 'paid by card',
          'metas': [
            {'key': 'category', 'value': 'food'},
          ],
        },
        {
          'account': 'Assets:Bank',
          'unit': {'number': '-88.5', 'commodity': 'CNY'},
          'cost': null,
          'price': null,
          'comment': null,
        },
      ]);
    });

    test('a new amount / account is applied by sign, in the original order', () {
      final json = overlaySimpleEntry(base, built('90', funding: 'Assets:Cash', category: 'Expenses:Food:Lunch')).toJson();
      final postings = json['postings']! as List;
      expect((postings[0] as Map)['account'], 'Expenses:Food:Lunch');
      expect((postings[0] as Map)['unit'], {'number': '90.00', 'commodity': 'CNY'});
      expect((postings[0] as Map)['comment'], 'paid by card');
      expect((postings[1] as Map)['account'], 'Assets:Cash');
      expect((postings[1] as Map)['unit'], {'number': '-90.00', 'commodity': 'CNY'});
    });
  });

  test('a copy keeps the entry but not its metadata', () {
    final original = tx(
      [
        posting('Assets:Paypal', '10', commodity: 'USD', price: '@ 7.2 CNY', metas: [
          {'key': 'lot', 'value': '1'},
        ]),
        posting('Assets:Bank', '-72', comment: 'fx'),
      ],
      metas: [
        {'key': 'document', 'value': 'receipt.pdf'},
      ],
      links: ['trip'],
    );
    final json = copyBaseOf(original).toJson();
    expect(json['metas'], isEmpty);
    expect(json['links'], ['trip']);
    expect(json['tags'], ['weekly']);
    expect(json['postings'], [
      {
        'account': 'Assets:Paypal',
        'unit': {'number': '10', 'commodity': 'USD'},
        'price': '@ 7.2 CNY',
      },
      {
        'account': 'Assets:Bank',
        'unit': {'number': '-72', 'commodity': 'CNY'},
        'comment': 'fx',
      },
    ]);
    final args = AdvancedEntryArgs.copy(original);
    expect(args.isEdit, isFalse);
    expect(args.draft.datetime, isNull, reason: 'a copy is dated "now" when saved');
    expect(AdvancedEntryArgs.edit(original).draft.datetime, DateTime(2026, 11, 2, 10));
  });

  test('saved hint: payee, else narration, else the first account', () {
    CreateTransactionRequest r(String payee, String narration) => CreateTransactionRequest(
      datetime: DateTime(2026),
      payee: payee,
      narration: narration,
      postings: const [PostingRequest(account: 'Assets:Cash')],
    );
    expect(EntrySaved.hintFor(r('Shop', 'x')), 'Shop');
    expect(EntrySaved.hintFor(r(' ', 'Lunch')), 'Lunch');
    expect(EntrySaved.hintFor(r('', '')), 'Assets:Cash');
  });
}
