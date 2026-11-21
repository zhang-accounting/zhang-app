import '../../data/models/account.dart';

/// The three simple entry modes of the "记一笔" screen (decisions.md §5).
/// The multi-posting "advanced" editor is a screen of its own
/// (`AdvancedEntryScreen`), opened from the form's "Advanced" segment.
enum EntryMode {
  expense,
  income,
  transfer;

  /// Parses `?mode=` of `/transactions/new` (defaults to [expense]).
  static EntryMode fromQuery(String? value) {
    for (final m in values) {
      if (m.name == value) return m;
    }
    return expense;
  }

  /// Root of the category grid (`Expenses` / `Income`), `null` for transfers.
  AccountType? get categoryRoot => switch (this) {
    expense => AccountType.expenses,
    income => AccountType.income,
    transfer => null,
  };

  /// Account types allowed for the funding account (expense / income) or for
  /// both sides of a transfer. Income may be received on a liability too
  /// (a refund or cashback paid onto a credit card); the defaults still
  /// prefer asset accounts (`resolveFunding`).
  Set<AccountType> get fundingTypes => switch (this) {
    expense => const {AccountType.assets, AccountType.liabilities},
    income => const {AccountType.assets, AccountType.liabilities},
    transfer => const {AccountType.assets, AccountType.liabilities},
  };

  bool allowsFunding(String account) => fundingTypes.contains(AccountType.ofAccount(account));
}
