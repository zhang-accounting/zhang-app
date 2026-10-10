import '../../core/utils/dates.dart';
import 'account.dart';
import 'amount.dart';
import 'query_result.dart';

/// A budget in one month: a row of the built-in `budgets.month` /
/// `budgets.budget_month` queries (`[name, alias, category, currency,
/// last_month, assigned, activity, available, closed]`).
class Budget {
  const Budget({
    required this.name,
    this.alias,
    this.category,
    this.closed = false,
    required this.assignedAmount,
    required this.activityAmount,
    required this.availableAmount,
  });

  factory Budget.fromQueryRow(QueryRow r) {
    final assigned = r.amount('assigned');
    final currency = r.stringOrNull('currency') ?? assigned.commodity;
    return Budget(
      name: r.string('name'),
      alias: r.stringOrNull('alias'),
      category: r.stringOrNull('category'),
      closed: r.booleanOrNull('closed') ?? false,
      assignedAmount: assigned,
      activityAmount: Amount(r.decimal('activity'), currency),
      availableAmount: r.amount('available'),
    );
  }

  final String name;
  final String? alias;

  /// Group budgets by this.
  final String? category;
  final bool closed;

  /// Assigned this month, including last month's rollover.
  final Amount assignedAmount;

  /// Spent this month on linked accounts.
  final Amount activityAmount;

  /// assigned − activity.
  final Amount availableAmount;

  String get displayName => (alias == null || alias!.isEmpty) ? name : alias!;
}

/// A budget in one month with its linked accounts (`budgets.budget` +
/// `budgets.budget_month`).
class BudgetDetail extends Budget {
  const BudgetDetail({
    required super.name,
    super.alias,
    super.category,
    super.closed,
    required super.assignedAmount,
    required super.activityAmount,
    required super.availableAmount,
    this.relatedAccounts = const [],
  });

  /// [month] is the `budgets.budget_month` row, [budget] the
  /// `budgets.budget` row (its `accounts` set).
  factory BudgetDetail.fromQueryRows(QueryRow month, QueryRow budget) {
    final b = Budget.fromQueryRow(month);
    return BudgetDetail(
      name: b.name,
      alias: b.alias,
      category: b.category,
      closed: b.closed,
      assignedAmount: b.assignedAmount,
      activityAmount: b.activityAmount,
      availableAmount: b.availableAmount,
      relatedAccounts: budget.stringSet('accounts'),
    );
  }

  /// Accounts linked via the `budget:` account meta.
  final List<String> relatedAccounts;
}

/// Item of a budget's month history (events and postings, newest first).
sealed class BudgetIntervalItem {
  const BudgetIntervalItem();

  /// Epoch seconds.
  int get timestamp;
}

/// A `budgets.events` row: `[date, time, timestamp, type, amount]`.
class BudgetEvent extends BudgetIntervalItem {
  const BudgetEvent({required this.timestamp, required this.amount, required this.eventType});

  factory BudgetEvent.fromQueryRow(QueryRow r) =>
      BudgetEvent(timestamp: r.integer('timestamp'), amount: r.amount('amount'), eventType: r.string('type'));

  @override
  final int timestamp;
  final Amount amount;

  /// `assign` (a `budget-add`; transfers are two assigns).
  final String eventType;

  DateTime get instant => ZhangDates.fromEpochSeconds(timestamp);
}

/// A `budgets.postings` row (a posting on a linked account).
class BudgetPosting extends BudgetIntervalItem {
  const BudgetPosting(this.entry);

  final AccountJournalEntry entry;

  @override
  int get timestamp => entry.timestamp;
}
