import 'amount.dart';
import 'json_utils.dart';
import 'query_result.dart';

/// The five top-level account types (first segment of an account name).
enum AccountType {
  assets('Assets'),
  liabilities('Liabilities'),
  equity('Equity'),
  income('Income'),
  expenses('Expenses');

  const AccountType(this.wire);

  /// Exact (case-sensitive) server spelling, used in names and URLs.
  final String wire;

  static AccountType? tryParse(String value) {
    for (final t in values) {
      if (t.wire == value) return t;
    }
    return null;
  }

  /// Type of an account name like `Assets:Bank:Checking`.
  static AccountType? ofAccount(String accountName) =>
      tryParse(accountName.split(':').first);

  /// Whether balances of this type are naturally negative (Liabilities,
  /// Equity, Income) – flip the sign to present "owed" / "earned".
  bool get isNaturallyNegative =>
      this == liabilities || this == equity || this == income;
}

enum AccountStatus {
  open,
  close;

  static AccountStatus fromWire(String? value) =>
      value == 'Close' ? AccountStatus.close : AccountStatus.open;
}

/// `GET /api/accounts` item (`AccountEntity`).
class Account {
  const Account({required this.name, required this.status, this.alias, required this.amount});

  factory Account.fromJson(JsonMap m) => Account(
    name: reqString(m, 'name'),
    status: AccountStatus.fromWire(optString(m, 'status')),
    alias: optString(m, 'alias'),
    amount: CalculatedAmount.fromJson(m['amount']),
  );

  final String name;
  final AccountStatus status;
  final String? alias;

  /// Current balance.
  final CalculatedAmount amount;

  AccountType? get type => AccountType.ofAccount(name);
  bool get isOpen => status == AccountStatus.open;

  /// Last name segment, e.g. `9999` for `Assets:CitiBank:9999`.
  String get shortName => name.split(':').last;

  /// [alias] when set, else [name].
  String get displayName => (alias == null || alias!.isEmpty) ? name : alias!;
}

/// `GET /api/accounts/{name}`.
class AccountDetail extends Account {
  const AccountDetail({
    required super.name,
    required super.status,
    super.alias,
    required super.amount,
    required this.openDate,
    required this.rawType,
  });

  factory AccountDetail.fromJson(JsonMap m) => AccountDetail(
    name: reqString(m, 'name'),
    status: AccountStatus.fromWire(optString(m, 'status')),
    alias: optString(m, 'alias'),
    amount: CalculatedAmount.fromJson(m['amount']),
    openDate: reqNaiveDateTime(m, 'date'),
    rawType: optString(m, 'type') ?? '',
  );

  /// Account open date (naive ledger-local).
  final DateTime openDate;

  /// `type` as sent (`"Assets"`, …).
  final String rawType;
}

/// A posting as seen from one account: items of
/// `/api/accounts/{name}/journals`, rows of the `report.top_postings` and
/// `budgets.postings` built-in queries. [trxId] is the transaction id
/// everywhere (the same id as in `/api/journals`).
class AccountJournalEntry {
  const AccountJournalEntry({
    required this.datetime,
    required this.timestamp,
    required this.account,
    required this.trxId,
    this.payee,
    this.narration,
    required this.inferredUnit,
    required this.accountAfter,
  });

  factory AccountJournalEntry.fromJson(JsonMap m) => AccountJournalEntry(
    datetime: reqNaiveDateTime(m, 'datetime'),
    timestamp: reqInt(m, 'timestamp'),
    account: reqString(m, 'account'),
    trxId: optString(m, 'trx_id') ?? '',
    payee: optString(m, 'payee'),
    narration: optString(m, 'narration'),
    inferredUnit: Amount.fromJson(m['inferred_unit']),
    accountAfter: Amount.fromJson(m['account_after']),
  );

  /// `report.top_postings` row: `[date, time, timestamp, account, id, payee,
  /// narration, units, account_balance, value]`.
  factory AccountJournalEntry.fromTopPosting(QueryRow r) => AccountJournalEntry(
    datetime: r.dateTime('date', 'time'),
    timestamp: r.integer('timestamp'),
    account: r.string('account'),
    trxId: r.stringOrNull('id') ?? '',
    payee: r.stringOrNull('payee'),
    narration: r.stringOrNull('narration'),
    inferredUnit: r.amount('units'),
    accountAfter: r.amount('account_balance'),
  );

  /// `budgets.postings` row: `[date, time, timestamp, account, id, payee,
  /// narration, units, balance]`.
  factory AccountJournalEntry.fromBudgetPosting(QueryRow r) => AccountJournalEntry(
    datetime: r.dateTime('date', 'time'),
    timestamp: r.integer('timestamp'),
    account: r.string('account'),
    trxId: r.stringOrNull('id') ?? '',
    payee: r.stringOrNull('payee'),
    narration: r.stringOrNull('narration'),
    inferredUnit: r.amount('units'),
    accountAfter: r.amount('balance'),
  );

  /// Naive ledger-local wall-clock time.
  final DateTime datetime;

  /// Epoch seconds (true instant).
  final int timestamp;

  /// The posting's account: the requested account or one of its
  /// sub-accounts.
  final String account;
  final String trxId;
  final String? payee;
  final String? narration;

  /// This posting's amount.
  final Amount inferredUnit;

  /// Running balance after this posting.
  final Amount accountAfter;

  bool get isBalanceItem => payee == 'Balance Check' || payee == 'Balance Pad';
}

/// One point of an account's balance history.
class BalancePoint {
  const BalancePoint({required this.date, required this.balance});

  /// Local midnight of the `YYYY-MM-DD` date.
  final DateTime date;

  /// End-of-day balance.
  final Amount balance;
}

/// Daily balances per commodity of an account **and its sub-accounts**
/// (built-in `accounts.balance_history`), sorted ascending by date.
class AccountBalanceHistory {
  const AccountBalanceHistory(this.byCommodity);

  /// Rows `[date, currency, balance]` (date order).
  factory AccountBalanceHistory.fromQuery(QueryResult result) {
    final out = <String, List<BalancePoint>>{};
    for (final r in result.rows) {
      final balance = r.amount('balance');
      final currency = r.stringOrNull('currency') ?? balance.commodity;
      out.putIfAbsent(currency, () => []).add(BalancePoint(date: r.date('date'), balance: balance));
    }
    for (final points in out.values) {
      points.sort((a, b) => a.date.compareTo(b.date));
    }
    return AccountBalanceHistory(out);
  }

  final Map<String, List<BalancePoint>> byCommodity;

  List<String> get commodities => byCommodity.keys.toList()..sort();
}
