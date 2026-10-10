import 'package:decimal/decimal.dart';

import '../../core/utils/dates.dart';
import 'account.dart';
import 'amount.dart';
import 'json_utils.dart';
import 'query_result.dart';

/// `interval` of `/api/statistic/graph`: daily, or weekly / monthly buckets
/// keyed by the bucket's first day.
enum GraphInterval {
  day('Day'),
  week('Week'),
  month('Month');

  const GraphInterval(this.wire);

  final String wire;
}

/// Figures of a period, from one batch of built-in queries (zhang ≥ 0.2,
/// `StatisticRepository.summary`): `report.net_worth` and
/// `report.liabilities` as of [to], `report.flows` and
/// `report.transaction_count` over [from]–[to].
///
/// Every [CalculatedAmount] has `calculated` = the server's `value` in the
/// operating currency (latest price on or before [to], inverse prices and
/// cost currencies included) and `detail` = the raw units per commodity.
class StatisticSummary {
  const StatisticSummary({
    required this.from,
    required this.to,
    required this.balance,
    required this.liability,
    required this.income,
    required this.expense,
    required this.transactionNumber,
  });

  /// [results] in the order of `StatisticRepository.summaryQueries`.
  factory StatisticSummary.fromResults(
    List<QueryResult> results, {
    required DateTime from,
    required DateTime to,
    required String currency,
  }) {
    if (results.length != 4) throw FormatException('expected 4 summary results, got ${results.length}');
    final [netWorth, liabilities, flows, count] = results;
    CalculatedAmount fromRow(QueryRow? row) => row == null
        ? CalculatedAmount(calculated: Amount(Decimal.zero, currency))
        : calculatedFromInventories(units: row.inventory('units'), value: row.inventory('value'), currency: currency);
    QueryRow? flow(String type) {
      for (final r in flows.rows) {
        if (r.string('type') == type) return r;
      }
      return null;
    }

    return StatisticSummary(
      from: from,
      to: to,
      balance: fromRow(netWorth.firstOrNull),
      liability: fromRow(liabilities.firstOrNull),
      income: fromRow(flow(AccountType.income.wire)),
      expense: fromRow(flow(AccountType.expenses.wire)),
      transactionNumber: count.firstOrNull?.integer('transactions') ?? 0,
    );
  }

  /// The requested range (ledger dates, both included).
  final DateTime from;
  final DateTime to;

  /// Net worth (Assets + Liabilities) as of [to].
  final CalculatedAmount balance;

  /// Liabilities as of [to] (negative = owed).
  final CalculatedAmount liability;

  /// Income postings in range (negative = earned).
  final CalculatedAmount income;

  /// Expense postings in range (positive = spent).
  final CalculatedAmount expense;

  /// Transactions in range (balance checks and pads excluded).
  final int transactionNumber;
}

/// `GET /api/statistic/graph?from&to&interval`.
///
/// Map keys are `YYYY-MM-DD` ledger dates, exposed as **sorted** lists here.
class StatisticGraph {
  const StatisticGraph({
    required this.from,
    required this.to,
    required this.balances,
    required this.changes,
  });

  factory StatisticGraph.fromJson(Object? json) {
    final m = asMap(json, 'graph');
    final balances = asMap(m['balances'] ?? const <String, Object?>{}, 'balances');
    final changes = asMap(m['changes'] ?? const <String, Object?>{}, 'changes');
    final balanceList = [
      for (final e in balances.entries)
        DatedAmount(ZhangDates.parseDate(e.key), CalculatedAmount.fromJson(e.value)),
    ]..sort((a, b) => a.date.compareTo(b.date));
    final changeList = [
      for (final e in changes.entries)
        DailyChange(ZhangDates.parseDate(e.key), {
          for (final t in asMap(e.value, 'changes.${e.key}').entries)
            if (AccountType.tryParse(t.key) != null)
              AccountType.tryParse(t.key)!: CalculatedAmount.fromJson(t.value),
        }),
    ]..sort((a, b) => a.date.compareTo(b.date));
    return StatisticGraph(
      from: ZhangDates.parseNaive(reqString(m, 'from')),
      to: ZhangDates.parseNaive(reqString(m, 'to')),
      balances: balanceList,
      changes: changeList,
    );
  }

  /// Echo of the requested range (naive ledger-local, `to` at 23:59:59).
  final DateTime from;
  final DateTime to;

  /// Daily net worth (Assets + Liabilities), ascending by date.
  final List<DatedAmount> balances;

  /// Days with postings, ascending; per account type sums.
  final List<DailyChange> changes;
}

class DatedAmount {
  const DatedAmount(this.date, this.amount);

  final DateTime date;
  final CalculatedAmount amount;
}

class DailyChange {
  const DailyChange(this.date, this.byType);

  final DateTime date;
  final Map<AccountType, CalculatedAmount> byType;
}

/// Total of one account in a period (`report.account_totals` row).
class AccountAmount {
  const AccountAmount({required this.account, required this.amount});

  final String account;
  final CalculatedAmount amount;
}

/// Per-account totals and the largest postings of one account type in a
/// period: `report.account_totals` + `report.top_postings`
/// (`StatisticRepository.rank`).
class StatisticRank {
  const StatisticRank({
    required this.from,
    required this.to,
    required this.detail,
    required this.topTransactions,
  });

  factory StatisticRank.fromResults(
    QueryResult totals,
    QueryResult top, {
    required DateTime from,
    required DateTime to,
    required String currency,
  }) => StatisticRank(
    from: from,
    to: to,
    detail: [
      for (final r in totals.rows)
        AccountAmount(
          account: r.string('account'),
          amount: calculatedFromInventories(units: r.inventory('units'), value: r.inventory('value'), currency: currency),
        ),
    ],
    topTransactions: [for (final r in top.rows) AccountJournalEntry.fromTopPosting(r)],
  );

  final DateTime from;
  final DateTime to;

  /// Total per account in range (server order; the UI sorts).
  final List<AccountAmount> detail;

  /// The largest postings, ranked by value in the operating currency;
  /// `trxId` is the transaction id.
  final List<AccountJournalEntry> topTransactions;
}
