import 'package:decimal/decimal.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:zhang_app/data/api/api_exception.dart';
import 'package:zhang_app/data/api/zhang_api_client.dart';
import 'package:zhang_app/data/models/account.dart';
import 'package:zhang_app/data/models/amount.dart';
import 'package:zhang_app/data/models/commodity.dart';
import 'package:zhang_app/data/models/for_new_transaction.dart';
import 'package:zhang_app/data/models/journal.dart';
import 'package:zhang_app/data/models/options.dart';
import 'package:zhang_app/data/models/transaction_preview.dart';
import 'package:zhang_app/data/models/transaction_request.dart';
import 'package:zhang_app/data/profiles/profile_providers.dart';
import 'package:zhang_app/data/profiles/server_profile.dart';
import 'package:zhang_app/data/repositories/journal_repository.dart';
import 'package:zhang_app/data/repositories/ledger_data_providers.dart';
import 'package:zhang_app/features/account_picker/account_picker_data.dart';
import 'package:zhang_app/features/transaction_new/advanced_entry_screen.dart';
import 'package:zhang_app/features/transaction_new/entry_mode.dart';
import 'package:zhang_app/features/transaction_new/new_transaction_screen.dart';
import 'package:zhang_app/features/transaction_new/transaction_edit.dart';
import 'package:zhang_app/features/transaction_new/transaction_history.dart';
import 'package:zhang_app/l10n/l10n.dart';

const _profile = ServerProfile(id: 'p1', name: 'Test', baseUrl: 'http://127.0.0.1:1');

Account _acc(String name) => Account(
  name: name,
  status: AccountStatus.open,
  amount: CalculatedAmount(calculated: Amount(Decimal.zero, 'CNY')),
);

final _accounts = [
  for (final name in [
    'Assets:WeChat',
    'Assets:Bank',
    'Liabilities:Card',
    'Expenses:PersonalDiet:Lunch',
    'Expenses:Clothing',
    'Expenses:Fees',
    'Income:Salary',
  ])
    _acc(name),
];

class _FakeHistory extends TransactionHistory {
  @override
  Future<List<HistoryEntry>> build() async => const [];
}

/// Records previews and writes; `(id or null, request)`.
class _Repo extends JournalRepository {
  _Repo() : super(ZhangApiClient(_profile));

  final previews = <(String?, CreateTransactionRequest)>[];
  final writes = <(String?, CreateTransactionRequest)>[];
  TransactionPreview previewResult = const TransactionPreview(text: 'ok', unbalanced: []);
  Object? previewError;

  @override
  Future<TransactionPreview> preview(CreateTransactionRequest request) async {
    previews.add((null, request));
    return previewResult;
  }

  @override
  Future<TransactionPreview> previewUpdate(String id, CreateTransactionRequest request) async {
    previews.add((id, request));
    if (previewError != null) throw previewError!;
    return previewResult;
  }

  @override
  Future<void> create(CreateTransactionRequest request) async => writes.add((null, request));

  @override
  Future<void> update(String id, CreateTransactionRequest request) async => writes.add((id, request));
}

/// Pumps a home page whose "open" button pushes [screen]; the popped value
/// is stored in the returned list.
Future<(_Repo, List<Object?>)> _pump(WidgetTester tester, Widget Function() screen) async {
  tester.view.physicalSize = const Size(1179, 2556);
  tester.view.devicePixelRatio = 3;
  addTearDown(tester.view.reset);
  SharedPreferences.setMockInitialValues({});
  final prefs = await SharedPreferences.getInstance();
  final repo = _Repo();
  final results = <Object?>[];
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        sharedPreferencesProvider.overrideWithValue(prefs),
        activeProfileProvider.overrideWithValue(_profile),
        journalRepositoryProvider.overrideWithValue(repo),
        ledgerClockOffsetProvider.overrideWith((ref) async => Duration.zero),
        pickerAccountsProvider.overrideWith((ref) async => _accounts),
        ledgerOptionsProvider.overrideWith((ref) async => const LedgerOptions({'operating_currency': 'CNY'})),
        commoditiesProvider.overrideWith(
          (ref) async => {
            'CNY': Commodity(name: 'CNY', precision: 2, prefix: '¥', totalAmount: Decimal.zero),
            'USD': Commodity(name: 'USD', precision: 2, prefix: r'$', totalAmount: Decimal.zero),
          },
        ),
        transactionHistoryProvider.overrideWith(_FakeHistory.new),
        forNewTransactionProvider.overrideWith((ref) async => const ForNewTransaction(payees: [], accountNames: [])),
      ],
      child: MaterialApp(
        locale: const Locale('en'),
        localizationsDelegates: const [
          AppLocalizations.delegate,
          GlobalMaterialLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
        ],
        supportedLocales: AppLocalizations.supportedLocales,
        home: Builder(
          builder: (context) => Scaffold(
            body: Center(
              child: FilledButton(
                onPressed: () async =>
                    results.add(await Navigator.of(context).push<Object?>(MaterialPageRoute(builder: (_) => screen()))),
                child: const Text('open'),
              ),
            ),
          ),
        ),
      ),
    ),
  );
  await tester.tap(find.text('open'));
  await tester.pumpAndSettle();
  return (repo, results);
}

Future<void> _pickAccount(WidgetTester tester, int posting, String account) async {
  await tester.tap(find.byKey(Key('adv.account.$posting')));
  await tester.pumpAndSettle();
  await tester.enterText(find.byKey(const Key('picker.search')), account);
  await tester.pumpAndSettle();
  await tester.tap(find.byKey(Key('picker.account.$account')));
  await tester.pumpAndSettle();
}

Future<void> _enter(WidgetTester tester, String key, String text) async {
  await tester.ensureVisible(find.byKey(Key(key)));
  await tester.enterText(find.byKey(Key(key)), text);
  await tester.pump();
}

String _remainder(WidgetTester tester) => tester.widget<Text>(find.byKey(const Key('adv.remainder'))).data!;

bool _saveEnabled(WidgetTester tester) =>
    tester.widget<FilledButton>(find.byKey(const Key('adv.save'))).onPressed != null;

/// A transaction as a zhang ≥ 0.2 journal lists it (written forms, metadata).
JournalTransaction _journal({
  String id = 'tx-7',
  required List<(String, String?, String)> postings,
  Map<int, String> comments = const {},
  Map<int, String> prices = const {},
  Map<int, String> costs = const {},
  Map<int, List<Map<String, String>>> postingMetas = const {},
  List<Map<String, String>> metas = const [],
  List<String> links = const [],
  String flag = '*',
}) =>
    JournalItem.fromJson({
          'type': 'Transaction',
          'id': id,
          'sequence': 7,
          'datetime': '2026-11-02T10:00:00',
          'payee': 'Supermarket',
          'narration': 'Weekly',
          'tags': ['weekly'],
          'links': links,
          'flag': flag,
          'is_balanced': true,
          'postings': [
            for (final (i, (account, number, commodity)) in postings.indexed)
              {
                'account': account,
                'unit': number == null ? null : {'number': number, 'commodity': commodity},
                'cost': null,
                'inferred_unit': {'number': number ?? '0', 'commodity': commodity},
                'account_before': {'number': '0', 'commodity': commodity},
                'account_after': {'number': '0', 'commodity': commodity},
                'metas': postingMetas[i] ?? const [],
                'written': {'cost': costs[i], 'price': prices[i], 'comment': comments[i]},
              },
          ],
          'metas': metas,
          'edit_drops_text': false,
        })
        as JournalTransaction;

void main() {
  testWidgets('advanced from the simple form: entry carried over, third posting, empty amount balances', (tester) async {
    final (repo, results) = await _pump(tester, () => const NewTransactionScreen());
    await tester.tap(find.byKey(const Key('add.category.Expenses:Clothing')));
    await tester.pumpAndSettle();
    for (final k in ['1', '5']) {
      await tester.tap(find.byKey(Key('add.key.$k')));
      await tester.pump();
    }
    await tester.enterText(find.byKey(const Key('add.payee')), 'Mall');
    FocusManager.instance.primaryFocus?.unfocus();
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('add.mode.advanced')));
    await tester.pumpAndSettle();
    expect(find.text('New transaction (advanced)'), findsOneWidget);
    expect(tester.widget<TextField>(find.byKey(const Key('adv.payee'))).controller!.text, 'Mall');
    expect(find.descendant(of: find.byKey(const Key('adv.account.0')), matching: find.text('Assets:WeChat')), findsOneWidget);
    expect(find.descendant(of: find.byKey(const Key('adv.account.1')), matching: find.text('Expenses:Clothing')), findsOneWidget);
    expect(tester.widget<TextField>(find.byKey(const Key('adv.amount.0'))).controller!.text, '-15.00');
    expect(tester.widget<TextField>(find.byKey(const Key('adv.amount.1'))).controller!.text, '15.00');
    expect(_remainder(tester), 'Balanced');

    // A fee posting: unbalanced until the source amount is left empty.
    await tester.tap(find.byKey(const Key('adv.addPosting')));
    await tester.pumpAndSettle();
    await _pickAccount(tester, 2, 'Expenses:Fees');
    await _enter(tester, 'adv.amount.2', '2');
    expect(_remainder(tester), 'Off by +¥2.00');
    expect(_saveEnabled(tester), isFalse);
    await _enter(tester, 'adv.amount.0', '');
    expect(_remainder(tester), 'Empty amount takes −¥17.00');
    expect(_saveEnabled(tester), isTrue);

    await tester.tap(find.byKey(const Key('adv.save')));
    await tester.pumpAndSettle();
    expect(repo.previews.single.$1, isNull, reason: 'a new entry is previewed as a create');
    final (id, request) = repo.writes.single;
    expect(id, isNull);
    expect(request.toJson()['postings'], [
      {'account': 'Assets:WeChat', 'unit': null},
      {
        'account': 'Expenses:Clothing',
        'unit': {'number': '15.00', 'commodity': 'CNY'},
      },
      {
        'account': 'Expenses:Fees',
        'unit': {'number': '2.00', 'commodity': 'CNY'},
      },
    ]);
    expect(find.text('open'), findsOneWidget, reason: 'both editors closed');
    expect(results.single, isA<EntrySaved>());
  });

  testWidgets('two commodities balance with a price; reorder and remove postings', (tester) async {
    final (repo, _) = await _pump(tester, () => const AdvancedEntryScreen());
    expect(_saveEnabled(tester), isFalse);
    await _pickAccount(tester, 0, 'Assets:Bank');
    await _enter(tester, 'adv.amount.0', '10');
    await tester.tap(find.byKey(const Key('adv.commodity.0')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('adv.commodity.0.USD')).last);
    await tester.pumpAndSettle();
    await _pickAccount(tester, 1, 'Assets:WeChat');
    await _enter(tester, 'adv.amount.1', '72');
    expect(find.descendant(of: find.byKey(const Key('adv.commodity.1')), matching: find.text('USD')), findsOneWidget,
        reason: 'the last commodity used');
    await tester.tap(find.byKey(const Key('adv.commodity.1')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('adv.commodity.1.CNY')).last);
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('adv.sign.1')));
    await tester.pump();
    expect(tester.widget<TextField>(find.byKey(const Key('adv.amount.1'))).controller!.text, '-72');
    expect(_remainder(tester), r'Off by −¥72.00, +$10.00');
    expect(find.byKey(const Key('adv.needsPrice')), findsOneWidget);

    await tester.tap(find.byKey(const Key('adv.more.0')));
    await tester.pumpAndSettle();
    await _enter(tester, 'adv.price.0', '7.2 CNY');
    expect(_remainder(tester), 'Balanced');

    // A blank third row is ignored; move the CNY posting first, then drop the blank one.
    await tester.tap(find.byKey(const Key('adv.addPosting')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('adv.menu.1')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('adv.moveUp')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('adv.menu.2')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('adv.remove')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('adv.account.2')), findsNothing);

    await tester.tap(find.byKey(const Key('adv.save')));
    await tester.pumpAndSettle();
    expect(repo.writes.single.$2.toJson()['postings'], [
      {
        'account': 'Assets:WeChat',
        'unit': {'number': '-72.00', 'commodity': 'CNY'},
      },
      {
        'account': 'Assets:Bank',
        'unit': {'number': '10.00', 'commodity': 'USD'},
        'price': '@ 7.2 CNY',
      },
    ]);
  });

  testWidgets('edit (advanced): previewed and saved on the id; unchanged fields round-trip', (tester) async {
    final tx = _journal(
      postings: [
        ('Assets:Crypto', '0.0100', 'BTC'),
        ('Assets:Paypal', '-260', 'USD'),
        ('Expenses:Fees', null, 'USD'),
      ],
      costs: {0: '{ 26000 USD }'},
      comments: {1: 'via paypal'},
      postingMetas: {
        0: [
          {'key': 'lot', 'value': '7'},
        ],
      },
      metas: [
        {'key': 'count', 'value': '3'},
        {'key': 'document', 'value': 'receipts/r.pdf'},
      ],
      links: ['receipt-001'],
      flag: '!',
    );
    final (repo, results) = await _pump(tester, () => AdvancedEntryScreen(args: AdvancedEntryArgs.edit(tx)));
    expect(find.text('Edit transaction'), findsOneWidget);
    expect(tester.widget<TextField>(find.byKey(const Key('adv.amount.0'))).controller!.text, '0.0100');
    expect(tester.widget<TextField>(find.byKey(const Key('adv.cost.0'))).controller!.text, '{ 26000 USD }');
    expect(find.byKey(const Key('adv.postingMetas.0')), findsOneWidget);
    expect(_remainder(tester), 'Balanced', reason: 'the BTC cost balances the USD; the empty amount takes nothing');

    await _enter(tester, 'adv.narration', 'Weekly (edited)');
    await tester.tap(find.byKey(const Key('adv.save')));
    await tester.pumpAndSettle();

    final expected = CreateTransactionRequest.fromJournal(tx).copyWith(narration: 'Weekly (edited)').toJson();
    expect(repo.previews.single.$1, 'tx-7', reason: 'POST /api/transactions/{id}/preview');
    expect(repo.previews.single.$2.toJson(), expected);
    expect(repo.writes.single.$1, 'tx-7', reason: 'PUT /api/transactions/{id}');
    expect(repo.writes.single.$2.toJson(), expected);
    expect(find.text('Changes saved'), findsOneWidget);
    expect((results.single! as EntrySaved).hint, 'Supermarket');
  });

  testWidgets('edit (simple form): mode kept, hidden fields kept, unchanged amount keeps its decimals', (tester) async {
    final tx = _journal(
      postings: [('Expenses:Clothing', '88.5', 'CNY'), ('Assets:Bank', '-88.5', 'CNY')],
      comments: {0: 'paid by card'},
      postingMetas: {
        0: [
          {'key': 'category', 'value': 'food'},
        ],
      },
      metas: [
        {'key': 'receipt_no', 'value': 'A-1'},
      ],
      links: ['receipt-001'],
      flag: '!',
    );
    final fit = simpleFitFor(tx, _accounts)!;
    final (repo, results) = await _pump(tester, () => NewTransactionScreen(prefill: EntryPrefill.edit(tx, fit)));
    expect(find.text('Edit transaction'), findsOneWidget);
    expect(find.text('Paid from: Bank'), findsOneWidget);
    expect(tester.widget<Text>(find.byKey(const Key('add.amount'))).data, '¥88.5');
    final segments = tester.widget<SegmentedButton<EntryMode?>>(find.byType(SegmentedButton<EntryMode?>));
    expect([for (final s in segments.segments) s.enabled], [true, false, false, true]);
    expect(
      tester.widget<InkWell>(find.descendant(of: find.byKey(const Key('add.key.again')), matching: find.byType(InkWell))).onTap,
      isNull,
      reason: 'no "save and add another" for an edit',
    );

    await tester.enterText(find.byKey(const Key('add.narration')), 'Weekly shop');
    FocusManager.instance.primaryFocus?.unfocus();
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('add.key.save')));
    await tester.pumpAndSettle();
    final expected = CreateTransactionRequest.fromJournal(tx).copyWith(narration: 'Weekly shop').toJson();
    expect(repo.previews.single.$1, 'tx-7');
    expect(repo.writes.single.$1, 'tx-7');
    expect(repo.writes.single.$2.toJson(), expected);
    expect(results.single, isA<EntrySaved>());
  });

  testWidgets('edit (simple form): a new amount and category, carried to the advanced editor', (tester) async {
    final tx = _journal(
      postings: [('Expenses:Clothing', '88.5', 'CNY'), ('Assets:Bank', '-88.5', 'CNY')],
      comments: {1: 'card'},
    );
    final (repo, _) = await _pump(
      tester,
      () => NewTransactionScreen(prefill: EntryPrefill.edit(tx, simpleFitFor(tx, _accounts)!)),
    );
    await tester.tap(find.byKey(const Key('add.key.backspace')));
    await tester.pump();
    await tester.tap(find.byKey(const Key('add.key.backspace')));
    await tester.pump();
    await tester.tap(find.byKey(const Key('add.key.backspace')));
    await tester.pump();
    await tester.tap(find.byKey(const Key('add.key.0')));
    await tester.pump();
    expect(tester.widget<Text>(find.byKey(const Key('add.amount'))).data, '¥80');
    await tester.tap(find.byKey(const Key('add.category.Expenses:PersonalDiet')));
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('add.mode.advanced')));
    await tester.pumpAndSettle();
    expect(find.text('Edit transaction'), findsOneWidget);
    expect(find.descendant(of: find.byKey(const Key('adv.account.0')), matching: find.text('Expenses:PersonalDiet:Lunch')), findsOneWidget);
    expect(tester.widget<TextField>(find.byKey(const Key('adv.amount.1'))).controller!.text, '-80.00');
    expect(tester.widget<TextField>(find.byKey(const Key('adv.comment.1'))).controller!.text, 'card');
    await tester.tap(find.byKey(const Key('adv.save')));
    await tester.pumpAndSettle();
    expect(repo.writes.single.$1, 'tx-7');
    expect(repo.writes.single.$2.toJson()['postings'], [
      {
        'account': 'Expenses:PersonalDiet:Lunch',
        'unit': {'number': '80.00', 'commodity': 'CNY'},
        'cost': null,
        'price': null,
        'comment': null,
      },
      {
        'account': 'Assets:Bank',
        'unit': {'number': '-80.00', 'commodity': 'CNY'},
        'cost': null,
        'price': null,
        'comment': 'card',
      },
    ]);
    expect(find.text('open'), findsOneWidget, reason: 'simple form closed with the advanced editor');
  });

  testWidgets('copy (simple form): a new transaction dated now without the metadata', (tester) async {
    final tx = _journal(
      postings: [('Expenses:Clothing', '88.5', 'CNY'), ('Assets:Bank', '-88.5', 'CNY')],
      metas: [
        {'key': 'document', 'value': 'r.pdf'},
      ],
    );
    final (repo, _) = await _pump(tester, () => NewTransactionScreen(prefill: EntryPrefill.copy(tx, simpleFitFor(tx, _accounts)!)));
    expect(find.text('New transaction'), findsOneWidget);
    expect(find.text('Today'), findsOneWidget);
    await tester.tap(find.byKey(const Key('add.key.save')));
    await tester.pumpAndSettle();
    final (id, request) = repo.writes.single;
    expect(id, isNull, reason: 'a copy is created');
    final json = request.toJson();
    expect(json['metas'], isEmpty);
    expect(json['payee'], 'Supermarket');
    expect(json['tags'], ['weekly']);
    expect(request.datetime.year, DateTime.now().year);
    expect(request.postings.map((p) => (p.account, '${p.unit!.number}')), [
      ('Expenses:Clothing', '88.5'),
      ('Assets:Bank', '-88.5'),
    ]);
  });

  testWidgets('edit with a stale id: the preview 404 explains and nothing is written', (tester) async {
    final tx = _journal(postings: [('Expenses:Clothing', '1', 'CNY'), ('Assets:Bank', null, 'CNY')]);
    final (repo, _) = await _pump(tester, () => AdvancedEntryScreen(args: AdvancedEntryArgs.edit(tx)));
    repo.previewError = const ApiNotFound('there is no transaction tx-7 in the ledger');
    await _enter(tester, 'adv.payee', 'Other');
    await tester.tap(find.byKey(const Key('adv.save')));
    await tester.pumpAndSettle();
    expect(repo.writes, isEmpty);
    expect(find.textContaining('its id is out of date'), findsOneWidget);
  });
}
