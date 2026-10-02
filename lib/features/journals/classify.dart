import 'package:decimal/decimal.dart';

import '../../core/utils/money.dart';
import '../../data/models/account.dart';
import '../../data/models/amount.dart';
import '../../data/models/journal.dart';

/// How a transaction is presented in lists (design-research §2.3).
enum TxnKind {
  /// Has `Expenses`, no `Income` (and a positive expense total).
  expense,

  /// Has `Income`, no `Expenses` – or an expense refund (see
  /// [TxnClassification.isRefund]).
  income,

  /// Only `Assets` / `Liabilities` postings.
  transfer,

  /// Both `Income` and `Expenses` (e.g. salary with tax withheld).
  compound,

  /// Touches `Equity` (opening balances, adjustments).
  adjustment,
}

/// Result of [classify].
class TxnClassification {
  const TxnClassification({
    required this.kind,
    required this.amounts,
    this.primaryAccount,
    this.counterAccount,
    this.isRefund = false,
  });

  final TxnKind kind;

  /// `true` when an expense transaction has a negative expense total (money
  /// came back); [kind] is then [TxnKind.income].
  final bool isRefund;

  /// Account the row is "about": the category for expense / income /
  /// compound, the destination for a transfer, the non-equity account for an
  /// adjustment.
  final String? primaryAccount;

  /// The other side: the funding account for expense / income / compound,
  /// the source for a transfer, the equity account for an adjustment.
  final String? counterAccount;

  /// Signed display amount per commodity, primary commodity first. Negative
  /// = money out (expense), positive = money in (income). Transfers and
  /// adjustments are positive / natural-sign and shown without colour.
  final List<Amount> amounts;

  /// The amount shown at the end of a row (`null` when there are no postings).
  Amount? get primaryAmount => amounts.isEmpty ? null : amounts.first;

  /// Number of commodities beyond [primaryAmount] (the "+1" badge).
  int get extraCommodities => amounts.length <= 1 ? 0 : amounts.length - 1;

  /// Whether amounts carry an explicit `+` / `−` and income/expense colour.
  bool get isDirectional =>
      kind == TxnKind.expense || kind == TxnKind.income || kind == TxnKind.compound;

  /// Colour tone of [amount] (defaults to [primaryAmount]).
  AmountTone toneFor([Amount? amount]) {
    final a = amount ?? primaryAmount;
    if (a == null || a.isZero || !isDirectional) return AmountTone.neutral;
    return a.isNegative ? AmountTone.negative : AmountTone.positive;
  }
}

/// Labels [txn] by the account types of its postings and derives the display
/// accounts and signed amounts (design-research §2.3 "交易显示分类算法"):
///
/// 1. `S` = set of top-level account types of the postings.
/// 2. `Equity ∈ S` → adjustment (neutral).
/// 3. `S ⊆ {Assets, Liabilities}` → transfer; amount = Σ positive postings.
/// 4. `Expenses ∈ S`, `Income ∉ S` → expense; amount = −Σ Expenses. A negative
///    expense total is a refund → income.
/// 5. `Income ∈ S`, `Expenses ∉ S` → income; amount = −Σ Income.
/// 6. both → compound; amount = net change of Assets + Liabilities.
/// 7. Each commodity is summed separately; [operatingCurrency] (if present)
///    becomes the primary commodity, otherwise the first one seen.
TxnClassification classify(JournalTransaction txn, {String? operatingCurrency}) {
  final postings = txn.postings;
  final types = <AccountType>{
    for (final p in postings) ?AccountType.ofAccount(p.account),
  };
  final commodityOrder = _commodityOrder(postings, operatingCurrency);

  bool isType(JournalPosting p, Set<AccountType> set) {
    final t = AccountType.ofAccount(p.account);
    return t != null && set.contains(t);
  }

  const money = {AccountType.assets, AccountType.liabilities};

  if (types.contains(AccountType.equity)) {
    final nonEquity = postings.where((p) => !isType(p, const {AccountType.equity})).toList();
    final equity = postings.where((p) => isType(p, const {AccountType.equity})).toList();
    final source = nonEquity.isEmpty ? equity : nonEquity;
    return TxnClassification(
      kind: TxnKind.adjustment,
      amounts: _sums(source, commodityOrder),
      primaryAccount: _largest(source)?.account,
      counterAccount: nonEquity.isEmpty ? null : _largest(equity)?.account,
    );
  }

  if (types.isEmpty || types.every(money.contains)) {
    final positive = postings.where((p) => p.inferredUnit.number > Decimal.zero).toList();
    final negative = postings.where((p) => p.inferredUnit.number < Decimal.zero).toList();
    return TxnClassification(
      kind: TxnKind.transfer,
      amounts: _sums(positive, commodityOrder),
      primaryAccount: _largest(positive)?.account ?? _largest(postings)?.account,
      counterAccount: _largest(negative)?.account,
    );
  }

  final hasExpenses = types.contains(AccountType.expenses);
  final hasIncome = types.contains(AccountType.income);
  final funding = postings.where((p) => isType(p, money)).toList();

  if (hasExpenses && !hasIncome) {
    final expenses = postings.where((p) => isType(p, const {AccountType.expenses})).toList();
    final amounts = _sums(expenses, commodityOrder, negate: true);
    final refund = amounts.isNotEmpty && amounts.first.number > Decimal.zero;
    return TxnClassification(
      kind: refund ? TxnKind.income : TxnKind.expense,
      isRefund: refund,
      amounts: amounts,
      primaryAccount: _largest(expenses)?.account,
      counterAccount: _largest(funding)?.account,
    );
  }

  if (hasIncome && !hasExpenses) {
    final income = postings.where((p) => isType(p, const {AccountType.income})).toList();
    return TxnClassification(
      kind: TxnKind.income,
      amounts: _sums(income, commodityOrder, negate: true),
      primaryAccount: _largest(income)?.account,
      counterAccount: _largest(funding)?.account,
    );
  }

  // Income and Expenses together.
  final categories =
      postings.where((p) => isType(p, const {AccountType.income, AccountType.expenses})).toList();
  return TxnClassification(
    kind: TxnKind.compound,
    amounts: _sums(funding, commodityOrder),
    primaryAccount: _largest(categories)?.account,
    counterAccount: _largest(funding)?.account,
  );
}

/// Commodities in display order: [operatingCurrency] first when present,
/// then in order of first appearance.
List<String> _commodityOrder(List<JournalPosting> postings, String? operatingCurrency) {
  final seen = <String>[];
  for (final p in postings) {
    final c = p.inferredUnit.commodity;
    if (!seen.contains(c)) seen.add(c);
  }
  if (operatingCurrency != null && seen.remove(operatingCurrency)) {
    seen.insert(0, operatingCurrency);
  }
  return seen;
}

/// Per-commodity sums of [postings] in [order]; zero sums are dropped unless
/// everything is zero (then the first commodity is kept with 0).
List<Amount> _sums(List<JournalPosting> postings, List<String> order, {bool negate = false}) {
  final totals = <String, Decimal>{};
  for (final p in postings) {
    final u = p.inferredUnit;
    totals[u.commodity] = (totals[u.commodity] ?? Decimal.zero) + u.number;
  }
  final result = <Amount>[
    for (final c in order)
      if (totals[c] != null && totals[c] != Decimal.zero)
        Amount(negate ? -totals[c]! : totals[c]!, c),
  ];
  if (result.isEmpty && totals.isNotEmpty) {
    final first = order.firstWhere(totals.containsKey);
    return [Amount(Decimal.zero, first)];
  }
  return result;
}

/// Posting with the largest absolute amount (first wins on ties).
JournalPosting? _largest(List<JournalPosting> postings) {
  JournalPosting? best;
  for (final p in postings) {
    if (best == null || p.inferredUnit.number.abs() > best.inferredUnit.number.abs()) best = p;
  }
  return best;
}
