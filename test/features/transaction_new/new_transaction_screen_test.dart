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
import 'package:zhang_app/data/models/options.dart';
import 'package:zhang_app/data/models/transaction_preview.dart';
import 'package:zhang_app/data/models/transaction_request.dart';
import 'package:zhang_app/data/profiles/profile_providers.dart';
import 'package:zhang_app/data/profiles/server_profile.dart';
import 'package:zhang_app/data/repositories/journal_repository.dart';
import 'package:zhang_app/data/repositories/ledger_data_providers.dart';
import 'package:zhang_app/features/account_picker/account_picker_data.dart';
import 'package:zhang_app/features/transaction_new/new_transaction_screen.dart';
import 'package:zhang_app/features/transaction_new/record_prefs.dart';
import 'package:zhang_app/features/transaction_new/transaction_history.dart';
import 'package:zhang_app/l10n/l10n.dart';

import '../../helpers/fixtures.dart';

const _profile = ServerProfile(id: 'p1', name: 'Test', baseUrl: 'http://127.0.0.1:1');

Account acc(String name, {bool open = true, String balance = '100'}) => Account(
  name: name,
  status: open ? AccountStatus.open : AccountStatus.close,
  amount: CalculatedAmount(calculated: Amount(Decimal.parse(balance), 'CNY')),
);

final _accounts = [
  acc('Assets:WeChat'),
  acc('Assets:Bank'),
  acc('Liabilities:Card', balance: '-50'),
  acc('Expenses:PersonalDiet:Lunch'),
  acc('Expenses:PersonalDiet:Dinner'),
  acc('Expenses:Clothing'),
  acc('Expenses:Closed', open: false),
  acc('Income:Salary'),
];

HistoryEntry _entry(int daysAgo, String payee, Map<String, String> postings, {String narration = ''}) => HistoryEntry(
  datetime: DateTime.now().subtract(Duration(days: daysAgo)),
  payee: payee,
  narration: narration,
  postings: [for (final e in postings.entries) HistoryPosting(e.key, Decimal.parse(e.value), 'CNY')],
);

final _history = [
  _entry(1, 'Uniqlo', {'Assets:WeChat': '-99', 'Expenses:Clothing': '99'}),
  _entry(2, '隆江猪脚饭', {'Liabilities:Card': '-27', 'Expenses:PersonalDiet:Lunch': '27'}, narration: 'Eating Lunch'),
];

class _FakeHistory extends TransactionHistory {
  @override
  Future<List<HistoryEntry>> build() async => _history;
}

class _FakeJournalRepository extends JournalRepository {
  _FakeJournalRepository() : super(ZhangApiClient(_profile));

  final requests = <CreateTransactionRequest>[];
  final previews = <CreateTransactionRequest>[];
  Object? failWith;

  /// Answer of `POST /api/transactions/preview` (clean by default).
  TransactionPreview previewResult = TransactionPreview.fromJson(fixtureData('transaction_preview.json'));

  @override
  Future<TransactionPreview> preview(CreateTransactionRequest request) async {
    previews.add(request);
    return previewResult;
  }

  @override
  Future<void> create(CreateTransactionRequest request) async {
    if (failWith != null) throw failWith!;
    requests.add(request);
  }
}

Future<(_FakeJournalRepository, SharedPreferences)> _pump(WidgetTester tester) async {
  tester.view.physicalSize = const Size(1179, 2556);
  tester.view.devicePixelRatio = 3;
  addTearDown(tester.view.reset);
  SharedPreferences.setMockInitialValues({});
  final prefs = await SharedPreferences.getInstance();
  final repo = _FakeJournalRepository();
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
        forNewTransactionProvider.overrideWith(
          (ref) async => const ForNewTransaction(payees: ['Apple Store'], accountNames: []),
        ),
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
                onPressed: () => Navigator.of(context).push(
                  MaterialPageRoute<void>(builder: (_) => const NewTransactionScreen()),
                ),
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
  return (repo, prefs);
}

Future<void> _keys(WidgetTester tester, String keys) async {
  for (final k in keys.split('')) {
    final name = switch (k) {
      '+' => 'plus',
      '-' => 'minus',
      '.' => 'dot',
      _ => k,
    };
    await tester.tap(find.byKey(Key('add.key.$name')));
    await tester.pump();
  }
}

String _amountText(WidgetTester tester) => tester.widget<Text>(find.byKey(const Key('add.amount'))).data!;

bool _enabled(WidgetTester tester, String key) =>
    tester.widget<InkWell>(find.descendant(of: find.byKey(Key(key)), matching: find.byType(InkWell))).onTap != null;

void main() {
  testWidgets('expense: category + sub-category, keypad 12+3.5, "=" then save → two explicit postings', (tester) async {
    final (repo, prefs) = await _pump(tester);

    expect(find.text('New transaction'), findsOneWidget);
    expect(find.text('Choose a category'), findsOneWidget, reason: 'nothing pre-selected');
    expect(find.byKey(const Key('add.category.Expenses:Closed')), findsNothing);
    expect(_enabled(tester, 'add.key.save'), isFalse);
    expect(_enabled(tester, 'add.key.again'), isFalse);

    await tester.tap(find.byKey(const Key('add.category.Expenses:PersonalDiet')));
    await tester.pumpAndSettle();
    expect(find.text('Choose a sub-category'), findsOneWidget);
    await tester.tap(find.byKey(const Key('add.sub.Expenses:PersonalDiet:Lunch')));
    await tester.pumpAndSettle();
    // Funding default = history fallback for this category.
    expect(find.text('Paid from: Card'), findsOneWidget);

    await _keys(tester, '12+3.5');
    expect(tester.widget<Text>(find.byKey(const Key('add.expression'))).data, '12 + 3.5');
    expect(_amountText(tester), '¥15.50');
    expect(find.descendant(of: find.byKey(const Key('add.key.save')), matching: find.text('=')), findsOneWidget);

    await tester.tap(find.byKey(const Key('add.key.save'))); // "="
    await tester.pumpAndSettle();
    expect(repo.requests, isEmpty);
    expect(_amountText(tester), '¥15.5');
    expect(_enabled(tester, 'add.key.save'), isTrue);
    expect(_enabled(tester, 'add.key.again'), isTrue);

    await tester.enterText(find.byKey(const Key('add.payee')), 'Canteen');
    await tester.testTextInput.receiveAction(TextInputAction.done);
    FocusManager.instance.primaryFocus?.unfocus();
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('add.key.save')));
    await tester.pumpAndSettle();

    expect(repo.previews, hasLength(1), reason: 'validated before saving');
    expect(repo.requests, hasLength(1));
    final json = repo.requests.single.toJson();
    expect(json['payee'], 'Canteen');
    expect(json['datetime'], isNot(endsWith('Z')), reason: 'ledger wall clock');
    expect(json['narration'], '');
    expect(json['postings'], [
      {'account': 'Liabilities:Card', 'unit': {'number': '-15.50', 'commodity': 'CNY'}},
      {'account': 'Expenses:PersonalDiet:Lunch', 'unit': {'number': '15.50', 'commodity': 'CNY'}},
    ]);
    expect(find.text('open'), findsOneWidget, reason: 'screen popped');
    expect(find.text('Recorded −¥15.50 · Canteen'), findsOneWidget);
    expect(RecordPrefs(prefs, 'p1').lastFunding('Expenses:PersonalDiet'), 'Liabilities:Card');
    expect(RecordPrefs(prefs, 'p1').lastFunding('Expenses:PersonalDiet:Lunch'), 'Liabilities:Card');
  });

  testWidgets('payee suggestion autofills category, funding and narration; 再记 keeps the screen', (tester) async {
    final (repo, _) = await _pump(tester);

    await tester.tap(find.byKey(const Key('add.payeeSuggestion.隆江猪脚饭')));
    await tester.pumpAndSettle();
    expect(find.text('Paid from: Card'), findsOneWidget);
    expect(find.text('Eating Lunch'), findsOneWidget);
    expect(find.byKey(const Key('add.sub.Expenses:PersonalDiet:Lunch')), findsOneWidget);

    await tester.tap(find.byKey(const Key('add.lastAmount')));
    await tester.pumpAndSettle();
    expect(_amountText(tester), '¥27');

    await tester.tap(find.byKey(const Key('add.key.again')));
    await tester.pumpAndSettle();
    expect(repo.requests, hasLength(1));
    final req = repo.requests.single;
    expect(req.payee, '隆江猪脚饭');
    expect(req.narration, 'Eating Lunch');
    expect(req.postings.map((p) => (p.account, p.unit!.number.toString())), [
      ('Liabilities:Card', '-27'),
      ('Expenses:PersonalDiet:Lunch', '27'),
    ]);
    // Still on the screen, amount / category / payee cleared, funding kept.
    expect(find.byKey(const Key('add.savedCount')), findsOneWidget);
    expect(find.text('1 saved'), findsOneWidget);
    expect(find.text('Choose a category'), findsOneWidget);
    expect(tester.widget<TextField>(find.byKey(const Key('add.payee'))).controller!.text, isEmpty);
    expect(find.text('Paid from: Card'), findsOneWidget);
  });

  testWidgets('server error is shown inline and the entry is kept', (tester) async {
    final (repo, _) = await _pump(tester);
    repo.failWith = const ApiServerError(500, 'core error: account is invalid');
    await tester.tap(find.byKey(const Key('add.category.Expenses:Clothing')));
    await tester.pumpAndSettle();
    await _keys(tester, '9');
    await tester.tap(find.byKey(const Key('add.key.save')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('add.error')), findsOneWidget);
    expect(find.textContaining('core error: account is invalid'), findsOneWidget);
    expect(_amountText(tester), '¥9');

    // Unauthorized maps to the auth message.
    repo.failWith = const ApiUnauthorized();
    await tester.tap(find.byKey(const Key('add.key.save')));
    await tester.pumpAndSettle();
    expect(find.textContaining('Authentication failed (401)'), findsOneWidget);
  });

  testWidgets('preview problems block the save and are listed', (tester) async {
    final (repo, _) = await _pump(tester);
    // Captured: an invalid account name and an account that is not open.
    repo.previewResult = TransactionPreview.fromJson({
      ...fixtureData('transaction_preview_errors.json')! as Map<String, Object?>,
      'errors': [
        {
          'error_type': 'AccountDoesNotExist',
          'metas': {'account_name': 'Assets:Nope'},
        },
      ],
    });
    await tester.tap(find.byKey(const Key('add.category.Expenses:Clothing')));
    await tester.pumpAndSettle();
    await _keys(tester, '9');
    await tester.tap(find.byKey(const Key('add.key.save')));
    await tester.pumpAndSettle();
    expect(repo.previews, hasLength(1));
    expect(repo.requests, isEmpty, reason: 'not saved');
    expect(find.byKey(const Key('add.error')), findsOneWidget);
    expect(find.textContaining('Not saved'), findsOneWidget);
    expect(find.textContaining('invalid account "Foo:Bar"'), findsOneWidget);
    expect(find.textContaining('Account Assets:Nope is not open.'), findsOneWidget);
    expect(_amountText(tester), '¥9');

    // Unbalanced (captured: off by -1.00 CNY, plus the matching ledger error).
    repo.previewResult = TransactionPreview.fromJson(fixtureData('transaction_preview_unbalanced.json'));
    await tester.tap(find.byKey(const Key('add.key.save')));
    await tester.pumpAndSettle();
    expect(find.textContaining('do not balance (off by −1.00 CNY)'), findsOneWidget);
    expect(find.textContaining('UnbalancedTransaction'), findsNothing);
    expect(repo.requests, isEmpty);
  });

  testWidgets('transfer mode uses from / to accounts; income uses Income tiles', (tester) async {
    final (repo, _) = await _pump(tester);
    await tester.tap(find.byKey(const Key('add.mode.income')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('add.category.Income:Salary')), findsOneWidget);
    expect(find.byKey(const Key('add.category.Expenses:Clothing')), findsNothing);
    expect(find.text('Deposit to: WeChat'), findsOneWidget, reason: 'most recently used asset account');

    await tester.tap(find.byKey(const Key('add.mode.transfer')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('add.from')), findsOneWidget);
    expect(find.text('Choose the destination account'), findsOneWidget);

    await tester.tap(find.byKey(const Key('add.to')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('picker.account.Liabilities:Card')));
    await tester.pumpAndSettle();
    await _keys(tester, '50');
    await tester.tap(find.byKey(const Key('add.key.save')));
    await tester.pumpAndSettle();
    expect(repo.requests.single.postings.map((p) => (p.account, p.unit!.number.toString())), [
      ('Assets:WeChat', '-50'),
      ('Liabilities:Card', '50'),
    ]);
  });

  testWidgets('closing with input asks before discarding', (tester) async {
    await _pump(tester);
    await _keys(tester, '5');
    await tester.tap(find.byKey(const Key('add.close')));
    await tester.pumpAndSettle();
    expect(find.text('Discard this entry?'), findsOneWidget);
    await tester.tap(find.text('Keep editing'));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('add.amount')), findsOneWidget);
    await tester.tap(find.byKey(const Key('add.close')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('add.discard')));
    await tester.pumpAndSettle();
    expect(find.text('open'), findsOneWidget);
  });
}
