import 'package:decimal/decimal.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/models/account.dart';
import '../../data/models/for_new_transaction.dart';
import '../../data/models/journal.dart';
import '../../data/models/transaction_request.dart';
import '../../data/repositories/journal_repository.dart';
import '../../data/repositories/ledger_revision.dart';
import 'frecency.dart';

/// One posting of a [HistoryEntry] (effective amount).
@immutable
class HistoryPosting {
  const HistoryPosting(this.account, this.number, this.commodity);

  final String account;
  final Decimal number;
  final String commodity;

  AccountType? get type => AccountType.ofAccount(account);
}

/// A compact past transaction used for suggestions (payee / narration / tag
/// ranking, payee autofill, category → funding fallback).
@immutable
class HistoryEntry {
  const HistoryEntry({
    required this.datetime,
    required this.payee,
    this.narration = '',
    this.tags = const [],
    this.postings = const [],
  });

  factory HistoryEntry.fromJournal(JournalTransaction tx) => HistoryEntry(
    datetime: tx.datetime,
    payee: tx.payee,
    narration: tx.narration ?? '',
    tags: tx.tags,
    postings: [
      for (final p in tx.postings) HistoryPosting(p.account, p.inferredUnit.number, p.inferredUnit.commodity),
    ],
  );

  /// The entry a just-saved request will become (kept until the next fetch).
  factory HistoryEntry.fromRequest(CreateTransactionRequest request) => HistoryEntry(
    datetime: request.datetime,
    payee: request.payee,
    narration: request.narration,
    tags: request.tags,
    postings: [
      for (final p in request.postings)
        if (p.unit != null) HistoryPosting(p.account, p.unit!.number, p.unit!.commodity),
    ],
  );

  final DateTime datetime;
  final String payee;
  final String narration;
  final List<String> tags;
  final List<HistoryPosting> postings;
}

/// Suggestions derived from the recent history (newest first) plus the
/// server's payee list (`/api/for-new-transaction`).
class SuggestionIndex {
  SuggestionIndex._(this._history, this.payees, this.narrations, this.tags, this._accounts, this._lastByPayee);

  factory SuggestionIndex.build(List<HistoryEntry> history, {Iterable<String> serverPayees = const []}) {
    final payeeRanker = ExponentialDecayRanker<String>();
    final narrationRanker = ExponentialDecayRanker<String>();
    final tagRanker = ExponentialDecayRanker<String>();
    final accountRanker = ExponentialDecayRanker<String>();
    final lastByPayee = <String, HistoryEntry>{};
    for (final entry in history) {
      final payee = entry.payee.trim();
      if (payee.isNotEmpty && !ForNewTransaction.syntheticPayees.contains(payee)) {
        payeeRanker.update(payee, entry.datetime);
        final previous = lastByPayee[payee];
        if (previous == null || entry.datetime.isAfter(previous.datetime)) lastByPayee[payee] = entry;
      }
      final narration = entry.narration.trim();
      if (narration.isNotEmpty) narrationRanker.update(narration, entry.datetime);
      for (final tag in entry.tags) {
        tagRanker.update(tag, entry.datetime);
      }
      for (final posting in entry.postings) {
        accountRanker.update(posting.account, entry.datetime);
      }
    }
    final serverOnly = serverPayees
        .where((p) => p.trim().isNotEmpty && !ForNewTransaction.syntheticPayees.contains(p))
        .where((p) => payeeRanker.score(p) == double.negativeInfinity)
        .toSet()
        .toList()
      ..sort();
    final sortedHistory = [...history]..sort((a, b) => b.datetime.compareTo(a.datetime));
    return SuggestionIndex._(
      sortedHistory,
      [...payeeRanker.ranked(), ...serverOnly],
      narrationRanker.ranked(),
      tagRanker.ranked(),
      accountRanker,
      lastByPayee,
    );
  }

  static final empty = SuggestionIndex.build(const []);

  /// Newest first.
  final List<HistoryEntry> _history;

  /// Payees by frecency, then payees only known to the server (A→Z).
  final List<String> payees;

  /// Narrations by frecency.
  final List<String> narrations;

  /// Tags by frecency.
  final List<String> tags;

  final ExponentialDecayRanker<String> _accounts;
  final Map<String, HistoryEntry> _lastByPayee;

  /// The payee's most recent transaction (Fava's `payee_transaction`).
  HistoryEntry? lastForPayee(String payee) => _lastByPayee[payee.trim()];

  /// Narrations, those used with [payee] first.
  List<String> narrationsFor(String payee) {
    final p = payee.trim();
    if (p.isEmpty) return narrations;
    final used = {
      for (final e in _history)
        if (e.payee.trim() == p && e.narration.trim().isNotEmpty) e.narration.trim(),
    };
    return [...narrations.where(used.contains), ...narrations.where((n) => !used.contains(n))];
  }

  /// Accounts of [types] by frecency (e.g. the account picker's "Recent").
  List<String> rankedAccounts(Set<AccountType> types) =>
      _accounts.ranked().where((a) => types.contains(AccountType.ofAccount(a))).toList();

  /// The most recently used account of [types] (default funding account).
  /// With [commodity], only postings in that commodity count (so a CNY entry
  /// does not default to the BTC wallet that was used last).
  String? mostRecentAccount(Set<AccountType> types, {bool Function(String account)? where, String? commodity}) {
    for (final entry in _history) {
      for (final p in entry.postings) {
        if (types.contains(p.type) && _matches(p, where, commodity)) return p.account;
      }
    }
    return null;
  }

  /// Funding account (of [types]) of the latest transaction that posted to
  /// [category] or to one of its sub-accounts (P-07 fallback when nothing is
  /// remembered locally); [commodity] as in [mostRecentAccount].
  String? lastFundingFor(
    String category,
    Set<AccountType> types, {
    bool Function(String account)? where,
    String? commodity,
  }) {
    for (final entry in _history) {
      final hit = entry.postings.any((p) => p.account == category || p.account.startsWith('$category:'));
      if (!hit) continue;
      for (final p in entry.postings) {
        if (types.contains(p.type) && _matches(p, where, commodity)) return p.account;
      }
    }
    return null;
  }

  static bool _matches(HistoryPosting p, bool Function(String account)? where, String? commodity) =>
      (commodity == null || p.commodity == commodity) && (where == null || where(p.account));
}

/// Up to [limit] items of [ranked] matching [query]: prefix matches first,
/// then substring matches (case-insensitive), keeping the ranking inside each
/// group. The exact text already typed is not suggested again.
List<String> filterSuggestions(List<String> ranked, String query, {int limit = 6}) {
  final q = query.trim().toLowerCase();
  if (q.isEmpty) return ranked.take(limit).toList();
  final prefix = <String>[];
  final contains = <String>[];
  for (final item in ranked) {
    final lower = item.toLowerCase();
    if (item == query.trim()) continue;
    if (lower.startsWith(q)) {
      prefix.add(item);
    } else if (lower.contains(q)) {
      contains.add(item);
    }
  }
  return [...prefix, ...contains].take(limit).toList();
}

/// Recent transactions for suggestions: the newest [limit] journal items,
/// fetched once per profile and kept in memory for the session (not
/// refetched after every write; saved entries are added via [addLocal]).
final transactionHistoryProvider = AsyncNotifierProvider<TransactionHistory, List<HistoryEntry>>(
  TransactionHistory.new,
);

class TransactionHistory extends AsyncNotifier<List<HistoryEntry>> {
  static const limit = 500;

  @override
  Future<List<HistoryEntry>> build() async {
    final page = await ref.watch(journalRepositoryProvider).list(const JournalQuery(size: limit));
    return [
      for (final item in page.records)
        if (item is JournalTransaction) HistoryEntry.fromJournal(item),
    ];
  }

  /// Adds a just-saved transaction so suggestions learn from it at once.
  void addLocal(HistoryEntry entry) {
    final current = state.value;
    if (current == null) return;
    state = AsyncData([entry, ...current]..sort((a, b) => b.datetime.compareTo(a.datetime)));
  }
}

/// `GET /api/for-new-transaction` (server payee list).
final forNewTransactionProvider = FutureProvider<ForNewTransaction>((ref) {
  ref.watch(ledgerRevisionProvider);
  return ref.watch(journalRepositoryProvider).forNewTransaction();
});

/// Suggestion index over the cached history + server payees. Usable while
/// either source is still loading or failed (suggestions are optional).
final suggestionIndexProvider = Provider<SuggestionIndex>((ref) {
  final history = ref.watch(transactionHistoryProvider).value ?? const <HistoryEntry>[];
  final payees = ref.watch(forNewTransactionProvider).value?.payees ?? const <String>[];
  if (history.isEmpty && payees.isEmpty) return SuggestionIndex.empty;
  return SuggestionIndex.build(history, serverPayees: payees);
});
