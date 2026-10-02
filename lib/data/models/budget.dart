import '../../core/utils/dates.dart';
import 'account.dart';
import 'amount.dart';
import 'json_utils.dart';

/// `GET /api/budgets?year&month` item (`BudgetListItem`).
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

  factory Budget.fromJson(JsonMap m) => Budget(
    name: reqString(m, 'name'),
    alias: optString(m, 'alias'),
    category: optString(m, 'category'),
    closed: optBool(m, 'closed'),
    assignedAmount: Amount.fromJson(m['assigned_amount']),
    activityAmount: Amount.fromJson(m['activity_amount']),
    availableAmount: Amount.fromJson(m['available_amount']),
  );

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

/// `GET /api/budgets/{name}?year&month`.
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

  factory BudgetDetail.fromJson(JsonMap m) {
    final b = Budget.fromJson(m);
    return BudgetDetail(
      name: b.name,
      alias: b.alias,
      category: b.category,
      closed: b.closed,
      assignedAmount: b.assignedAmount,
      activityAmount: b.activityAmount,
      availableAmount: b.availableAmount,
      relatedAccounts: stringList(m['related_accounts']),
    );
  }

  /// Accounts linked via the `budget:` account meta.
  final List<String> relatedAccounts;
}

/// Item of `GET /api/budgets/{name}/interval/{year}/{month}` (newest first).
sealed class BudgetIntervalItem {
  const BudgetIntervalItem();

  factory BudgetIntervalItem.fromJson(JsonMap m) {
    final type = reqString(m, 'type');
    return switch (type) {
      'BudgetEvent' => BudgetEvent.fromJson(m),
      'Posting' => BudgetPosting(AccountJournalEntry.fromJson(m)),
      _ => throw FormatException('unknown budget interval item type "$type"'),
    };
  }

  /// Epoch seconds.
  int get timestamp;
}

/// `{"type":"BudgetEvent","timestamp","amount","event_type"}`.
class BudgetEvent extends BudgetIntervalItem {
  const BudgetEvent({required this.timestamp, required this.amount, required this.eventType});

  factory BudgetEvent.fromJson(JsonMap m) => BudgetEvent(
    timestamp: reqInt(m, 'timestamp'),
    amount: Amount.fromJson(m['amount']),
    eventType: reqString(m, 'event_type'),
  );

  @override
  final int timestamp;
  final Amount amount;

  /// `AddAssignedAmount` | `Transfer`.
  final String eventType;

  DateTime get instant => ZhangDates.fromEpochSeconds(timestamp);
}

/// `{"type":"Posting", …AccountJournal fields}` (real transaction id).
class BudgetPosting extends BudgetIntervalItem {
  const BudgetPosting(this.entry);

  final AccountJournalEntry entry;

  @override
  int get timestamp => entry.timestamp;
}
