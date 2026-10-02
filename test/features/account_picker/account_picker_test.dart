import 'package:decimal/decimal.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:zhang_app/data/models/account.dart';
import 'package:zhang_app/data/models/amount.dart';
import 'package:zhang_app/data/models/commodity.dart';
import 'package:zhang_app/data/profiles/profile_providers.dart';
import 'package:zhang_app/data/profiles/server_profile.dart';
import 'package:zhang_app/data/repositories/ledger_data_providers.dart';
import 'package:zhang_app/features/account_picker/account_picker_data.dart';
import 'package:zhang_app/features/account_picker/account_picker_sheet.dart';
import 'package:zhang_app/l10n/l10n.dart';

Account acc(String name, {bool open = true, String? alias, String balance = '0'}) => Account(
  name: name,
  status: open ? AccountStatus.open : AccountStatus.close,
  alias: alias,
  amount: CalculatedAmount(calculated: Amount(Decimal.parse(balance), 'CNY')),
);

final _accounts = [
  acc('Assets:WeChat', balance: '312'),
  acc('Assets:Bank:CMB', alias: '招行储蓄', balance: '2754.06'),
  acc('Assets:Bank:ICBC', balance: '1000'),
  acc('Assets:Old', open: false),
  acc('Liabilities:CreditCard:Apple', balance: '-2703.29'),
  acc('Expenses:Food'),
  acc('Income:Salary'),
];

void main() {
  group('buildAccountForest', () {
    test('one tree per allowed type with synthesized intermediate nodes', () {
      final forest = buildAccountForest(_accounts, const {AccountType.liabilities, AccountType.assets});
      expect(forest.map((n) => n.path), ['Assets', 'Liabilities'], reason: 'AccountType order');
      final assets = forest.first;
      expect(assets.children.map((n) => n.path), ['Assets:Bank', 'Assets:WeChat']);
      final bank = assets.children.first;
      expect(bank.isSelectable, isFalse, reason: 'Assets:Bank is not an account');
      expect(bank.children.map((n) => n.path), ['Assets:Bank:CMB', 'Assets:Bank:ICBC']);
      expect(bank.children.first.depth, 2);
      expect(bank.children.first.account!.alias, '招行储蓄');
      expect(
        assets.descendantsAndSelf.map((n) => n.path),
        isNot(contains('Assets:Old')),
        reason: 'closed accounts are hidden',
      );
      expect(forest.last.children.single.children.single.path, 'Liabilities:CreditCard:Apple');
    });

    test('types without open accounts produce no tree', () {
      expect(buildAccountForest(_accounts, const {AccountType.equity}), isEmpty);
    });
  });

  group('searchAccounts', () {
    test('matches segments, alias and substrings; segment prefixes first', () {
      final types = {AccountType.assets, AccountType.liabilities};
      expect(searchAccounts(_accounts, 'bank', types).map((a) => a.name), ['Assets:Bank:CMB', 'Assets:Bank:ICBC']);
      expect(searchAccounts(_accounts, '招行', types).map((a) => a.name), ['Assets:Bank:CMB']);
      expect(searchAccounts(_accounts, 'pp', types).map((a) => a.name), ['Liabilities:CreditCard:Apple']);
      expect(searchAccounts(_accounts, 'ch', types).map((a) => a.name), ['Assets:WeChat'],
          reason: 'substring match (no segment starts with "ch")');
      expect(searchAccounts(_accounts, 'old', types), isEmpty);
      expect(searchAccounts(_accounts, 'food', types), isEmpty, reason: 'type filter');
    });
  });

  group('AccountPickerPrefs', () {
    test('favourites toggle and recent is MRU, per profile', () async {
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();
      final a = AccountPickerPrefs(prefs, 'p1');
      final b = AccountPickerPrefs(prefs, 'p2');
      expect(await a.toggleFavourite('Assets:WeChat'), isTrue);
      expect(await a.toggleFavourite('Assets:Bank:CMB'), isTrue);
      expect(a.favourites, ['Assets:WeChat', 'Assets:Bank:CMB']);
      expect(await a.toggleFavourite('Assets:WeChat'), isFalse);
      expect(a.favourites, ['Assets:Bank:CMB']);
      expect(b.favourites, isEmpty);
      await a.pushRecent('X');
      await a.pushRecent('Y');
      await a.pushRecent('X');
      expect(a.recent, ['X', 'Y']);
      for (var i = 0; i < 20; i++) {
        await a.pushRecent('A$i');
      }
      expect(a.recent, hasLength(AccountPickerPrefs.maxRecent));
    });
  });

  testWidgets('picker sheet: tree, star by long-press, search and pick', (tester) async {
    tester.view.physicalSize = const Size(1179, 2556);
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.reset);
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    String? picked;
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          sharedPreferencesProvider.overrideWithValue(prefs),
          activeProfileProvider.overrideWithValue(const ServerProfile(id: 'p1', name: 'T', baseUrl: 'http://x')),
          pickerAccountsProvider.overrideWith((ref) async => _accounts),
          commoditiesProvider.overrideWith(
            (ref) async => {'CNY': Commodity(name: 'CNY', precision: 2, prefix: '¥', totalAmount: Decimal.zero)},
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
                  onPressed: () async => picked = await showAccountPicker(
                    context,
                    types: const {AccountType.assets, AccountType.liabilities},
                    suggested: const ['Liabilities:CreditCard:Apple'],
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

    expect(find.text('Choose account'), findsOneWidget);
    expect(find.byKey(const Key('picker.account.Assets:Bank:CMB')), findsOneWidget);
    expect(find.text('招行储蓄'), findsOneWidget);
    expect(find.text('¥2,754.06'), findsOneWidget);
    expect(find.byKey(const Key('picker.recent.Liabilities:CreditCard:Apple')), findsOneWidget);
    expect(find.text('Long-press an account to star it'), findsOneWidget);
    expect(find.byKey(const Key('picker.account.Assets:Old')), findsNothing);

    // Long-press stars the account (stored per profile).
    await tester.longPress(find.byKey(const Key('picker.account.Assets:WeChat')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('picker.fav.Assets:WeChat')), findsOneWidget);
    expect(AccountPickerPrefs(prefs, 'p1').favourites, ['Assets:WeChat']);

    // Type filter.
    await tester.tap(find.byKey(const Key('picker.type.Liabilities')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('picker.account.Assets:Bank:CMB')), findsNothing);
    await tester.tap(find.byKey(const Key('picker.type.all')));
    await tester.pumpAndSettle();

    // Collapse a group.
    await tester.tap(find.byKey(const Key('picker.account.Assets:Bank')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('picker.account.Assets:Bank:ICBC')), findsNothing);

    // Search and pick.
    await tester.enterText(find.byKey(const Key('picker.search')), 'icbc');
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('picker.account.Assets:Bank:ICBC')));
    await tester.pumpAndSettle();
    expect(picked, 'Assets:Bank:ICBC');
    expect(AccountPickerPrefs(prefs, 'p1').recent, ['Assets:Bank:ICBC']);
  });
}
