import '../../core/utils/dates.dart';
import 'account.dart';
import 'amount.dart';
import 'json_utils.dart';

/// `interval` of `/api/statistic/graph` (required by the server, but ignored:
/// output is always daily).
enum GraphInterval {
  day('Day'),
  week('Week'),
  month('Month');

  const GraphInterval(this.wire);

  final String wire;
}

/// `GET /api/statistic/summary?from&to`.
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

  factory StatisticSummary.fromJson(Object? json) {
    final m = asMap(json, 'summary');
    return StatisticSummary(
      from: ZhangDates.parseNaiveUtc(reqString(m, 'from')),
      to: ZhangDates.parseNaiveUtc(reqString(m, 'to')),
      balance: CalculatedAmount.fromJson(m['balance']),
      liability: CalculatedAmount.fromJson(m['liability']),
      income: CalculatedAmount.fromJson(m['income']),
      expense: CalculatedAmount.fromJson(m['expense']),
      transactionNumber: reqInt(m, 'transaction_number'),
    );
  }

  /// Echo of the requested range (UTC instants).
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

  /// Includes balance check/pad items (server bug).
  final int transactionNumber;
}

/// `GET /api/statistic/graph?from&to&interval`.
///
/// Map keys are `YYYY-MM-DD` dates, exposed as **sorted** lists here.
/// [balances] keys are UTC calendar dates, [changes] keys are ledger-local
/// dates (docs §3.7).
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
      from: ZhangDates.parseNaiveUtc(reqString(m, 'from')),
      to: ZhangDates.parseNaiveUtc(reqString(m, 'to')),
      balances: balanceList,
      changes: changeList,
    );
  }

  /// Echo of the requested range (UTC instants).
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

/// `{account, amount}` item of the rank endpoint.
class AccountAmount {
  const AccountAmount({required this.account, required this.amount});

  factory AccountAmount.fromJson(JsonMap m) =>
      AccountAmount(account: reqString(m, 'account'), amount: CalculatedAmount.fromJson(m['amount']));

  final String account;
  final CalculatedAmount amount;
}

/// `GET /api/statistic/{account_type}?from&to`.
class StatisticRank {
  const StatisticRank({
    required this.from,
    required this.to,
    required this.detail,
    required this.topTransactions,
  });

  factory StatisticRank.fromJson(Object? json) {
    final m = asMap(json, 'rank');
    return StatisticRank(
      from: ZhangDates.parseNaiveUtc(reqString(m, 'from')),
      to: ZhangDates.parseNaiveUtc(reqString(m, 'to')),
      detail: parseList(m['detail'] ?? const [], AccountAmount.fromJson, 'detail'),
      topTransactions: parseList(
        m['top_transactions'] ?? const [],
        AccountJournalEntry.fromJson,
        'top_transactions',
      ),
    );
  }

  final DateTime from;
  final DateTime to;

  /// Total per account in range, ascending by `amount.calculated.number`
  /// (server order is kept).
  final List<AccountAmount> detail;

  /// Up to 10 largest postings; `trxId` is the real transaction id here.
  final List<AccountJournalEntry> topTransactions;
}
