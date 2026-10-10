import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:zhang_app/data/api/zhang_api_client.dart';
import 'package:zhang_app/data/models/amount.dart';
import 'package:zhang_app/data/models/query_result.dart';
import 'package:zhang_app/data/models/statistic.dart';
import 'package:zhang_app/features/home/home_providers.dart';
import 'package:zhang_app/features/journals/journal_providers.dart';
import 'package:zhang_app/features/journals/year_month.dart';

import '../../helpers/builtin_fake.dart';
import '../journals/fake_server.dart';

void main() {
  test('summary figures flip the income sign; net = income − expense', () {
    final summary = StatisticSummary.fromResults(
      [for (var i = 0; i < 4; i++) QueryResult.fromJson(batchResult('statistic_summary.json', i))],
      from: DateTime(2023, 9),
      to: DateTime(2023, 9, 30),
      currency: 'CNY',
    );
    final f = HomeSummaryFigures.from(summary);
    expect(f.expense, Amount.parse('798.6775', 'CNY'));
    expect(f.income, Amount.parse('436', 'CNY'));
    expect(f.net, Amount.parse('-362.6775', 'CNY'));
    expect(f.isEmpty, isFalse);
  });

  test('month summary sends the month as ledger dates in one batch', () async {
    final server = FakeZhangServer();
    final container = ProviderContainer(
      overrides: [zhangApiClientProvider.overrideWithValue(server.client)],
      retry: (_, _) => null,
    );
    addTearDown(container.dispose);
    final month = YearMonth(2023, 9);
    await container.read(monthSummaryProvider(month).future);
    // Cached per month: a second read does not refetch.
    await container.read(monthSummaryProvider(month).future);
    expect(server.requestsTo('/query/builtins'), hasLength(1));
    expect(server.builtins.callsTo('report.flows').single.params, {
      'from': '2023-09-01',
      'to': '2023-09-30',
      'currency': 'CNY',
    });
    expect(server.builtins.callsTo('report.net_worth').single.params, {'to': '2023-09-30', 'currency': 'CNY'});
    expect(server.builtins.callsTo('report.transaction_count').single.params, {
      'from': '2023-09-01',
      'to': '2023-09-30',
    });
  });

  test('home month: previous always, next never past the current month', () {
    final container = ProviderContainer();
    addTearDown(container.dispose);
    final now = YearMonth.now();
    final notifier = container.read(homeMonthProvider.notifier);
    expect(container.read(homeMonthProvider), now);
    expect(notifier.canGoNext, isFalse);
    notifier.next();
    expect(container.read(homeMonthProvider), now);
    notifier.previous();
    expect(container.read(homeMonthProvider), now.previous);
    expect(notifier.canGoNext, isTrue);
    notifier.next();
    expect(container.read(homeMonthProvider), now);
  });
}
