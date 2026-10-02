import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:zhang_app/data/api/zhang_api_client.dart';
import 'package:zhang_app/data/models/amount.dart';
import 'package:zhang_app/data/models/statistic.dart';
import 'package:zhang_app/features/home/home_providers.dart';
import 'package:zhang_app/features/journals/journal_providers.dart';
import 'package:zhang_app/features/journals/year_month.dart';

import '../../helpers/fixtures.dart';
import '../journals/fake_server.dart';

void main() {
  test('summary figures flip the income sign; net = income − expense', () {
    final summary = StatisticSummary.fromJson(fixtureData('statistic_summary.json'));
    final f = HomeSummaryFigures.from(summary);
    expect(f.expense, Amount.parse('796.729', 'CNY'));
    expect(f.income, Amount.parse('436', 'CNY'));
    expect(f.net, Amount.parse('-360.729', 'CNY'));
    expect(f.isEmpty, isFalse);
  });

  test('month summary requests the whole month as inclusive UTC instants', () async {
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
    final requests = server.requestsTo('/statistic/summary');
    expect(requests, hasLength(1));
    final q = requests.single.uri.queryParameters;
    expect(DateTime.parse(q['from']!), DateTime(2023, 9).toUtc());
    expect(DateTime.parse(q['to']!), DateTime(2023, 9, 30, 23, 59, 59).toUtc());
    expect(q['from'], endsWith('Z'));
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
