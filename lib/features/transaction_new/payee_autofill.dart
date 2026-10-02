import 'package:decimal/decimal.dart';
import 'package:flutter/foundation.dart';

import '../../data/models/account.dart';
import 'entry_mode.dart';
import 'transaction_history.dart';

/// What a payee's last transaction suggests for the current mode
/// (Fava's `payee_transaction`, docs/design-research.md P-09).
@immutable
class PayeeAutofill {
  const PayeeAutofill({
    this.category,
    this.funding,
    this.from,
    this.to,
    this.narration,
    this.amount,
    this.commodity,
  });

  /// Category posting account (`Expenses:…` / `Income:…`), may be a leaf.
  final String? category;

  /// Funding account (expense / income modes).
  final String? funding;

  /// Transfer source / destination.
  final String? from;
  final String? to;
  final String? narration;

  /// Positive amount of the last transaction – shown as a hint only.
  final Decimal? amount;
  final String? commodity;

  bool get isEmpty =>
      category == null && funding == null && from == null && to == null && narration == null && amount == null;

  @override
  String toString() =>
      'PayeeAutofill(category: $category, funding: $funding, from: $from, to: $to, narration: $narration, amount: $amount $commodity)';
}

/// Maps [entry] (the payee's latest transaction) onto the fields of [mode].
/// Only postings that fit the mode are used, so an income transaction does
/// not fill an expense form with an `Income:*` category.
PayeeAutofill autofillFromEntry(HistoryEntry entry, EntryMode mode) {
  HistoryPosting? find(bool Function(HistoryPosting p) test) {
    for (final p in entry.postings) {
      if (test(p)) return p;
    }
    return null;
  }

  bool isFunding(HistoryPosting p) => mode.fundingTypes.contains(p.type);
  final narration = entry.narration.trim().isEmpty ? null : entry.narration.trim();

  switch (mode) {
    case EntryMode.expense:
      final category = find((p) => p.type == AccountType.expenses && p.number > Decimal.zero) ??
          find((p) => p.type == AccountType.expenses);
      final funding = find((p) => isFunding(p) && p.number < Decimal.zero) ?? find(isFunding);
      return PayeeAutofill(
        category: category?.account,
        funding: funding?.account,
        narration: narration,
        amount: category?.number.abs(),
        commodity: category?.commodity,
      );
    case EntryMode.income:
      final category = find((p) => p.type == AccountType.income && p.number < Decimal.zero) ??
          find((p) => p.type == AccountType.income);
      final funding = find((p) => isFunding(p) && p.number > Decimal.zero) ?? find(isFunding);
      return PayeeAutofill(
        category: category?.account,
        funding: funding?.account,
        narration: narration,
        amount: category?.number.abs(),
        commodity: category?.commodity,
      );
    case EntryMode.transfer:
      final hasCategory = entry.postings.any(
        (p) => p.type == AccountType.expenses || p.type == AccountType.income,
      );
      if (hasCategory) return PayeeAutofill(narration: narration);
      final from = find((p) => isFunding(p) && p.number < Decimal.zero);
      final to = find((p) => isFunding(p) && p.number > Decimal.zero);
      return PayeeAutofill(
        from: from?.account,
        to: to?.account,
        narration: narration,
        amount: to?.number.abs(),
        commodity: to?.commodity,
      );
  }
}
