import 'package:decimal/decimal.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:zhang_app/data/api/api_exception.dart';
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
  String? version,
  String payee = 'Supermarket',
}) =>
    JournalItem.fromJson({
          'type': 'Transaction',
          'id': id,
          'sequence': 1,
          'datetime': '2026-11-02T10:00:00',
          'payee': payee,
          'narration': 'Weekly',
          'tags': ['weekly'],
          'links': links,
          'flag': flag,
          'is_balanced': true,
          'postings': postings,
          'metas': metas,
          'edit_drops_text': ?dropsText,
          'version': ?version,
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
  _Repo(this.answer, {this.listed})
    : super(ZhangApiClient(const ServerProfile(id: 'p', name: 'p', baseUrl: 'http://127.0.0.1:1')));

  final TransactionPreview answer;

  /// What the server lists under an id now (`findById`); `null` = the
  /// transaction asked for, unchanged.
  JournalItem? Function(String id)? listed;
  final calls = <String>[];
  final previews = <(String, Map<String, Object?>, String?)>[];
  final updates = <(String, Map<String, Object?>, String?)>[];
  final lookups = <(String, String?)>[];
  JournalTransaction? snapshot;

  @override
  Future<JournalItem?> findById(String id, {String? keyword}) async {
    calls.add('find $id');
    lookups.add((id, keyword));
    return listed == null ? snapshot : listed!(id);
  }

  @override
  Future<TransactionPreview> previewUpdate(String id, CreateTransactionRequest request, {String? version}) async {
    calls.add('preview $id');
    previews.add((id, request.toJson(), version));
    return answer;
  }

  @override
  Future<void> update(String id, CreateTransactionRequest request, {String? version}) async {
    calls.add('put $id');
    updates.add((id, request.toJson(), version));
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

  group('server text', () {
    test('posting flags: any flag zhang reads (* ! & ? % # A–Z), not metadata or the header', () {
      for (final flag in ['!', '*', '&', '?', '%', '#', 'C', 'P', 'Z']) {
        expect(hasPostingFlags('2026-11-04 12:00:00 * "Exchange" "x"\n  Assets:Paypal 10 USD\n  $flag Expenses:Food 1 USD'), isTrue,
            reason: flag);
      }
      expect(
        hasPostingFlags('2026-11-02 10:00:00 ! "Supermarket" "Weekly" #weekly\n  count: 3\n  "my key": A\n'
            '  Assets:Bank -88.5 CNY\n  Expenses:Food 88.5 CNY ; paid by card\n    category: "food"\n    X: 1'),
        isFalse,
      );
    });

    test('unquoted posting metadata, by posting', () {
      const text = '2026-11-02 10:00:00 * "S" "W"\n'
          '  count: 3\n'
          '  Assets:Bank -88.5 CNY\n'
          '    lot: 8\n'
          '    note: "x"\n'
          '  C Expenses:Food 88.5 CNY\n'
          '    when: 2026-11-02\n'
          '    "my key": TRUE';
      expect(bareMetaLines(text), {
        0: ['lot: 8'],
        1: ['when: 2026-11-02', '"my key": TRUE'],
      });
    });

    test('capitalised metadata keys are metadata, not postings (indentation and `Type:Name`)', () {
      const text = '2026-11-02 10:00:00 * "S" "W"\n'
          '  Receipt: 7\n'
          '  Assets:Bank -8 CNY\n'
          '    Lot: 8\n'
          '    when: 2026-01-02\n'
          '    Ref: Assets:Bank\n'
          '    C: 1\n'
          '  Expenses:Food 8 CNY\n'
          '    Note: "x"';
      expect(bareMetaLines(text), {
        0: ['Lot: 8', 'when: 2026-01-02', 'Ref: Assets:Bank', 'C: 1'],
      });
      expect(hasPostingFlags(text), isFalse);
      expect(hasPostingFlags(text.replaceFirst('  Expenses:Food', '  C Expenses:Food')), isTrue);
    });
  });

  group('checkEditable', () {
    final editable = tx([posting('Assets:Bank', '-1'), posting('Expenses:Food', null)]);
    const clean = TransactionPreview(text: '2026-11-02 * "S" "W"\n  Assets:Bank -1 CNY\n    lot: 8\n  Expenses:Food');

    test('re-reads the id, then previews the transaction unchanged on it', () async {
      final repo = _Repo(clean)..snapshot = editable;
      final check = await checkEditable(repo, editable);
      expect(check.block, isNull);
      expect(check.target!.bareMetas, {
        0: ['lot: 8'],
      });
      expect(repo.calls, ['find tx-1', 'preview tx-1']);
      expect(repo.lookups.single, ('tx-1', 'Supermarket'));
      expect(repo.previews.single.$2, CreateTransactionRequest.fromJournal(editable).toJson());
      expect(repo.previews.single.$3, isNull, reason: 'no version: no If-Match');
    });

    test('with a version: If-Match instead of the lookup (which only searches a few pages)', () async {
      final versioned = tx([posting('Assets:Bank', '-1'), posting('Expenses:Food', null)], version: 'v-1');
      final repo = _Repo(clean, listed: (_) => null);
      expect((await checkEditable(repo, versioned)).target!.version, 'v-1');
      expect(repo.calls, ['preview tx-1']);
      expect(repo.previews.single.$3, 'v-1');
    });

    test('another transaction under the id, a changed one or none: TransactionChanged', () async {
      final other = tx([posting('Assets:Cash', '-5'), posting('Expenses:Food', null)], payee: 'Other');
      for (final listed in <JournalItem?>[other, null, tx([posting('Assets:Bank', '-2'), posting('Expenses:Food', null)])]) {
        final repo = _Repo(clean, listed: (_) => listed);
        await expectLater(checkEditable(repo, editable), throwsA(isA<TransactionChanged>()));
        expect(repo.previews, isEmpty);
      }
    });

    test('a posting flag or a refused transaction blocks the edit', () async {
      expect(
        (await checkEditable(
          _Repo(const TransactionPreview(text: 'x\n  C Assets:Bank -1 CNY\n  Expenses:Food'))..snapshot = editable,
          editable,
        )).block,
        EditBlock.postingFlag,
      );
      expect((await checkEditable(_Repo(const TransactionPreview())..snapshot = editable, editable)).block, EditBlock.unverified);
    });

    test('blocked without asking the server', () async {
      final repo = _Repo(const TransactionPreview(text: 'x'));
      final blocked = tx([posting('Assets:Bank', '-1'), posting('Expenses:Food', null)], dropsText: true);
      expect((await checkEditable(repo, blocked)).block, EditBlock.dropsText);
      expect(repo.calls, isEmpty);
    });

    test('stale errors: TransactionChanged, a 404 for the id, a 412 for the version', () {
      expect(isStaleEdit(const TransactionChanged()), isTrue);
      expect(isStaleEdit(const ApiNotFound('there is no transaction x')), isTrue);
      expect(isStaleEdit(const ApiNotFound('no route PUT /api/transactions/x')), isFalse);
      expect(isStaleEdit(const ApiServerError(412, 'the transaction changed')), isTrue);
      expect(isStaleEdit(const ApiServerError(400, 'bad')), isFalse);
    });
  });

  group('saveEntry', () {
    test('without a version an edit re-reads the id, then previews and replaces', () async {
      final snapshot = tx([posting('Assets:Bank', '-1'), posting('Expenses:Food', null)]);
      final repo = _Repo(const TransactionPreview(text: 'x', unbalanced: []))..snapshot = snapshot;
      final request = CreateTransactionRequest.fromJournal(snapshot).copyWith(narration: 'Edited');
      await saveEntry(repo, request, target: EditTarget(snapshot));
      expect(repo.calls, ['find tx-1', 'preview tx-1', 'put tx-1']);
      expect(repo.updates.single.$3, isNull);
      expect(repo.updates.single.$2['narration'], 'Edited');
    });

    test('with a version an edit previews and replaces with If-Match, no lookup', () async {
      final versioned = tx([posting('Assets:Bank', '-1'), posting('Expenses:Food', null)], version: 'v-1');
      final repo = _Repo(const TransactionPreview(text: 'x', unbalanced: []), listed: (_) => null);
      await saveEntry(repo, CreateTransactionRequest.fromJournal(versioned), target: EditTarget(versioned));
      expect(repo.calls, ['preview tx-1', 'put tx-1']);
      expect([repo.previews.single.$3, repo.updates.single.$3], ['v-1', 'v-1']);
    });

    test('nothing is written when the transaction changed meanwhile', () async {
      final snapshot = tx([posting('Assets:Bank', '-1'), posting('Expenses:Food', null)]);
      final repo = _Repo(const TransactionPreview(text: 'x', unbalanced: []), listed: (_) => null);
      await expectLater(
        saveEntry(repo, CreateTransactionRequest.fromJournal(snapshot), target: EditTarget(snapshot)),
        throwsA(isA<TransactionChanged>()),
      );
      expect(repo.updates, isEmpty);
    });
  });

  group('unquoted metadata after an account change', () {
    final original = tx([
      posting('Assets:Bank', '-88.5'),
      posting('Expenses:Food', '88.5', metas: [
        {'key': 'lot', 'value': '8'},
      ]),
    ]);
    final target = EditTarget(original, bareMetas: const {
      1: ['lot: 8'],
    });
    CreateTransactionRequest moved(String account, {String amount = '88.5'}) {
      final base = CreateTransactionRequest.fromJournal(original);
      return base.copyWith(
        postings: [base.postings[0], base.postings[1].copyWith(account: account, unit: Amount(d(amount), 'CNY'))],
      );
    }

    test('the server matches postings by account, else by account and units', () {
      final request = CreateTransactionRequest.fromJournal(original);
      expect(serverMatch(original.postings, request.postings, 1), 1);
      expect(serverMatch(original.postings, moved('Expenses:Fees').postings, 1), isNull);
      final twice = request.copyWith(postings: [...request.postings, request.postings[1].copyWith(unit: Amount(d('1'), 'CNY'))]);
      expect(serverMatch(original.postings, twice.postings, 1), 1, reason: 'same account and units');
      expect(serverMatch(original.postings, twice.postings, 2), isNull);
    });

    test('only an unmatched posting with unquoted values is reported', () {
      expect(requotedMetas(target, CreateTransactionRequest.fromJournal(original), const [0, 1]), isEmpty);
      expect(requotedMetas(target, moved('Expenses:Food', amount: '90'), const [0, 1]), isEmpty,
          reason: 'still the only posting to its account');
      expect(requotedMetas(target, moved('Expenses:Fees'), const [0, 1]), {
        1: ['lot: 8'],
      });
      expect(requotedMetas(EditTarget(original), moved('Expenses:Fees'), const [0, 1]), isEmpty,
          reason: 'quoted values stay quoted');
    });
  });

  group('after a save', () {
    final read = tx(
      [
        posting('Assets:Bank', '-88.50', comment: 'card'),
        posting('Assets:Crypto', '0.01', commodity: 'BTC', cost: '{ 26000 USD }', metas: [
          {'key': 'lot', 'value': '8'},
          {'key': 'a', 'value': '1'},
        ]),
      ],
      metas: [
        {'key': 'b', 'value': '2'},
        {'key': 'a', 'value': '1'},
      ],
    );

    test('entryMatches compares values, not the server\'s formatting', () {
      final saved = CreateTransactionRequest(
        datetime: DateTime(2026, 11, 2, 10),
        payee: 'Supermarket',
        narration: 'Weekly',
        tags: const ['weekly'],
        metas: const [Meta('a', '1'), Meta('b', '2')],
        postings: [
          PostingRequest(account: 'Assets:Bank', unit: Amount(d('-88.5'), 'CNY'), comment: 'card', sendWritten: true),
          PostingRequest(
            account: 'Assets:Crypto',
            unit: Amount(d('0.01'), 'BTC'),
            cost: '{26000 USD}',
            metas: const [Meta('lot', '8'), Meta('a', '1')],
          ),
        ],
      );
      expect(entryMatches(read, saved), isTrue);
      expect(entryMatches(read, saved.copyWith(narration: 'Other')), isFalse);
      expect(entryMatches(read, saved.copyWith(postings: [saved.postings[1], saved.postings[0]])), isFalse);
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

    test('payee / narration the form only trimmed stay as written', () {
      final spaced = base.copyWith(payee: ' Supermarket ', narration: 'Weekly ');
      final kept = overlaySimpleEntry(spaced, built('88.5').copyWith(payee: 'Supermarket', narration: 'Weekly'));
      expect((kept.payee, kept.narration), (' Supermarket ', 'Weekly '));
      final changed = overlaySimpleEntry(spaced, built('88.5'));
      expect((changed.payee, changed.narration), ('Market', 'Edited'));
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
    expect(json['links'], isEmpty, reason: 'links tie related entries; a copy is a new one');
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
    expect(AdvancedEntryArgs.edit(EditTarget(original)).draft.datetime, DateTime(2026, 11, 2, 10));
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
