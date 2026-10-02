import 'package:decimal/decimal.dart';
import 'package:flutter/foundation.dart';

import '../../data/models/amount.dart';
import '../../data/models/transaction_request.dart';
import 'entry_mode.dart';

/// Why an entry cannot be saved yet (first one is shown as the hint).
enum EntryIssue {
  categoryMissing,
  subcategoryMissing,
  fundingMissing,
  fromMissing,
  toMissing,
  sameAccount,
  amountMissing,
  amountNotPositive,
  commodityMissing,
}

/// Everything needed to build a `POST /api/transactions` body from the simple
/// entry modes, with all defaults already resolved.
@immutable
class EntryDraft {
  const EntryDraft({
    required this.mode,
    required this.amount,
    required this.commodity,
    required this.datetime,
    this.precision,
    this.categoryChosen = false,
    this.categoryAccount,
    this.funding,
    this.from,
    this.to,
    this.payee = '',
    this.narration = '',
    this.tags = const [],
  });

  final EntryMode mode;

  /// Evaluated keypad amount (typed as a positive number).
  final Decimal? amount;
  final String? commodity;
  final DateTime datetime;

  /// Decimals of [commodity]; amounts are written with at least this many.
  final int? precision;

  /// A category tile is selected (expense / income).
  final bool categoryChosen;

  /// The category posting account (`null` while a required sub-category is
  /// missing).
  final String? categoryAccount;

  /// Funding account (expense / income).
  final String? funding;

  /// Transfer accounts.
  final String? from;
  final String? to;
  final String payee;
  final String narration;
  final List<String> tags;
}

/// All problems of [draft] in the order of the "category → amount → save"
/// flow (the first one is shown as the hint); empty = savable.
List<EntryIssue> validateEntry(EntryDraft draft) {
  final issues = <EntryIssue>[];
  switch (draft.mode) {
    case EntryMode.expense:
    case EntryMode.income:
      if (!draft.categoryChosen) {
        issues.add(EntryIssue.categoryMissing);
      } else if (draft.categoryAccount == null) {
        issues.add(EntryIssue.subcategoryMissing);
      }
      if (draft.funding == null) issues.add(EntryIssue.fundingMissing);
    case EntryMode.transfer:
      if (draft.from == null) issues.add(EntryIssue.fromMissing);
      if (draft.to == null) issues.add(EntryIssue.toMissing);
      if (draft.from != null && draft.from == draft.to) issues.add(EntryIssue.sameAccount);
  }
  final amount = draft.amount;
  if (amount == null) {
    issues.add(EntryIssue.amountMissing);
  } else if (amount <= Decimal.zero) {
    issues.add(EntryIssue.amountNotPositive);
  }
  if (draft.commodity == null || draft.commodity!.isEmpty) issues.add(EntryIssue.commodityMissing);
  return issues;
}

/// Builds the request for a valid [draft] (decisions.md §5): exactly two
/// postings with explicit amounts, money source first:
///
/// | mode     | postings                                  |
/// |----------|-------------------------------------------|
/// | expense  | `funding −A`, `Expenses:… +A`             |
/// | income   | `Income:… −A`, `funding +A`               |
/// | transfer | `from −A`, `to +A`                        |
///
/// `narration` is always a string (possibly empty), `tags` / `links` /
/// `metas` are always sent (the data layer serialises them).
CreateTransactionRequest buildTransactionRequest(EntryDraft draft) {
  final issues = validateEntry(draft);
  if (issues.isNotEmpty) throw StateError('entry is not valid: $issues');
  final amount = draft.amount!;
  final commodity = draft.commodity!;
  final plus = Amount(amount, commodity);
  final minus = Amount(-amount, commodity);
  PostingRequest posting(String account, Amount unit) =>
      PostingRequest(account: account, unit: unit, scale: draft.precision);
  final postings = switch (draft.mode) {
    EntryMode.expense => [posting(draft.funding!, minus), posting(draft.categoryAccount!, plus)],
    EntryMode.income => [posting(draft.categoryAccount!, minus), posting(draft.funding!, plus)],
    EntryMode.transfer => [posting(draft.from!, minus), posting(draft.to!, plus)],
  };
  return CreateTransactionRequest(
    datetime: draft.datetime,
    payee: draft.payee.trim(),
    narration: draft.narration.trim(),
    postings: postings,
    tags: [
      for (final t in draft.tags)
        if (t.trim().isNotEmpty) t.trim(),
    ],
    links: const [],
    metas: const [],
  );
}

/// Normalises user tag input: strips `#`, whitespace inside becomes `-`.
String? normalizeTag(String input) {
  var t = input.trim();
  while (t.startsWith('#')) {
    t = t.substring(1).trim();
  }
  t = t.replaceAll(RegExp(r'\s+'), '-');
  return t.isEmpty ? null : t;
}
