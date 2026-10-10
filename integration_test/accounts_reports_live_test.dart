// Live end-to-end check of the Accounts and Reports tabs against a running
// zhang server without auth. NOT part of `flutter test` (needs a server +
// device):
//
//   zhang serve /tmp/zhang-v3-ledger --addr 127.0.0.1 --port 18080 --no-report
//   flutter test integration_test/accounts_reports_live_test.dart -d <simulator-id> \
//     [--dart-define=ZHANG_URL=http://127.0.0.1:18080] \
//     [--dart-define=ZHANG_SCREENSHOT_PAUSE=6]   # seconds to hold each state for screenshots
//
// The ledger needs postings in the current and the previous month (by the
// ledger's clock) for the report charts (the examples/ ledger stops in 2023;
// seed a throw-away copy, see docs/dev.md).
// Replaces the app's saved profiles with one profile for ZHANG_URL.
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:zhang_app/app.dart';
import 'package:zhang_app/data/profiles/profile_repository.dart';
import 'package:zhang_app/data/profiles/secret_store.dart';
import 'package:zhang_app/data/profiles/server_profile.dart';
import 'package:zhang_app/data/repositories/ledger_data_providers.dart';
import 'package:zhang_app/features/accounts/account_detail_screen.dart';
import 'package:zhang_app/features/journals/transaction_detail_screen.dart';
import 'package:zhang_app/features/stats/report_period.dart';
import 'package:zhang_app/features/stats/reports_providers.dart';
import 'package:zhang_app/main.dart' as app;

const _url = String.fromEnvironment('ZHANG_URL', defaultValue: 'http://127.0.0.1:18080');
const _pause = int.fromEnvironment('ZHANG_SCREENSHOT_PAUSE');

Finder _key(String k) => find.byKey(Key(k));

Future<void> _hold(WidgetTester tester, String marker) async {
  // ignore: avoid_print
  print('ZHANG_STATE $marker');
  if (_pause > 0) {
    await tester.runAsync(() => Future<void>.delayed(const Duration(seconds: _pause)));
    await tester.pumpAndSettle();
  }
}

/// Real network: pump until [finder] matches (or give up after ~15 s).
Future<void> _waitFor(WidgetTester tester, Finder finder) async {
  for (var i = 0; i < 150 && finder.evaluate().isEmpty; i++) {
    await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 100)));
    await tester.pump();
  }
  await tester.pumpAndSettle();
  expect(finder, findsWidgets);
}

Future<void> _show(WidgetTester tester, String listKey, Finder finder, double delta) async {
  final scrollable = find.descendant(of: _key(listKey), matching: find.byType(Scrollable)).first;
  await tester.scrollUntilVisible(finder, delta, scrollable: scrollable);
  await tester.ensureVisible(finder);
  await tester.pumpAndSettle();
}

String _text(WidgetTester tester, Finder f) => tester.widget<Text>(f).data ?? '';

void _log(String line) {
  // ignore: avoid_print
  print('ZHANG_RESULT $line');
}

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('accounts tree, account detail and reports against a live server', (tester) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.clear();
    final repo = ProfileRepository(prefs: prefs, secrets: SecureSecretStore());
    await repo.upsert(const ServerProfile(id: 'line-c', name: 'Line C ledger', baseUrl: _url));
    await repo.setActiveId('line-c');

    await tester.pumpWidget(await app.bootstrap());
    await tester.pumpAndSettle();
    final container = ProviderScope.containerOf(tester.element(find.byType(ZhangApp)));

    // ---- Accounts tab: net worth + tree.
    await tester.tap(find.byIcon(Icons.account_balance_wallet_outlined));
    await tester.pumpAndSettle();
    await _waitFor(tester, _key('accounts.netWorth'));
    _log('net worth ${_text(tester, _key('accounts.netWorth'))}');
    expect(_key('accounts.row.Assets'), findsOneWidget);
    expect(_key('accounts.row.Liabilities'), findsOneWidget);
    expect(_key('accounts.row.Assets:Paypal'), findsOneWidget);
    await _hold(tester, 'accounts');

    // ---- Account detail with posting rows.
    await tester.tap(find.descendant(of: _key('accounts.row.Assets:Paypal'), matching: find.text('Paypal')));
    await tester.pumpAndSettle();
    expect(find.byType(AccountDetailScreen), findsOneWidget);
    await _waitFor(tester, _key('accountDetail.firstRow'));
    // accounts.balance_history (built-in query) feeds the chart.
    await _waitFor(tester, _key('accountDetail.balanceChart'));
    _log('detail balance ${_text(tester, _key('accountDetail.balance'))}');
    await _hold(tester, 'account-detail');

    // A posting opens its transaction (trx_id is the transaction id).
    await _show(tester, 'accountDetail.list', _key('accountDetail.firstRow'), 200);
    await tester.tap(_key('accountDetail.firstRow'));
    await tester.pumpAndSettle();
    await _waitFor(tester, find.byType(TransactionDetailScreen));
    await _waitFor(tester, _key('trx.amount'));
    final subtitle = find.byKey(const Key('trx.subtitle'));
    _log('posting detail ${subtitle.evaluate().isEmpty ? '' : _text(tester, subtitle)} '
        'amount ${_text(tester, _key('trx.amount'))}');
    await _hold(tester, 'posting-detail');
    await tester.pageBack();
    await tester.pumpAndSettle();
    await tester.pageBack();
    await tester.pumpAndSettle();

    // ---- Reports: current month.
    await tester.tap(find.byIcon(Icons.bar_chart_outlined));
    await tester.pumpAndSettle();
    final now = container.read(ledgerClockProvider)();
    expect(container.read(reportPeriodProvider), ReportPeriod.month(now));
    await _waitFor(tester, _key('reports.kpi.income'));
    String kpi(String k) => find
        .descendant(of: _key('reports.kpi.$k'), matching: find.byType(Text))
        .evaluate()
        .map((e) => (e.widget as Text).data)
        .join(' ');
    _log('kpis income="${kpi('income')}" expense="${kpi('expense')}" net="${kpi('net')}"');
    await _waitFor(tester, _key('reports.cashflowChart'));
    expect(_key('reports.kpi.expense'), findsOneWidget);
    expect(_key('reports.kpi.net'), findsOneWidget);
    final current = _text(tester, _key('reports.periodLabel'));
    await _hold(tester, 'reports'); // period, KPIs, bars
    await _show(tester, 'reports.list', _key('reports.donut'), 150);
    _log('period $current, donut total ${_text(tester, _key('reports.donutTotal'))}');
    await _hold(tester, 'reports-breakdown'); // donut + ranked bars

    // ---- Previous month.
    await _show(tester, 'reports.list', _key('reports.prevPeriod'), -300);
    await tester.tap(_key('reports.prevPeriod'));
    await tester.pumpAndSettle();
    expect(container.read(reportPeriodProvider), ReportPeriod.month(DateTime(now.year, now.month - 1)));
    await _waitFor(tester, _key('reports.cashflowChart'));
    await _waitFor(tester, _key('reports.kpi.income'));
    final previous = _text(tester, _key('reports.periodLabel'));
    expect(previous, isNot(current));
    await _hold(tester, 'reports-prev');
    await _show(tester, 'reports.list', _key('reports.donut'), 150);
    _log('period $previous, donut total ${_text(tester, _key('reports.donutTotal'))}');
  });
}
