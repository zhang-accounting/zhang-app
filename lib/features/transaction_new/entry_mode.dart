import '../../data/models/account.dart';

/// The three simple entry modes of the "记一笔" screen (decisions.md §5).
/// The multi-posting "advanced" mode is P1 and intentionally absent.
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
  /// both sides of a transfer.
  Set<AccountType> get fundingTypes => switch (this) {
    expense => const {AccountType.assets, AccountType.liabilities},
    income => const {AccountType.assets},
    transfer => const {AccountType.assets, AccountType.liabilities},
  };

  bool allowsFunding(String account) => fundingTypes.contains(AccountType.ofAccount(account));
}
