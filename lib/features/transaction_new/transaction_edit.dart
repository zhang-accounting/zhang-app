import 'package:decimal/decimal.dart';
import 'package:flutter/foundation.dart';

import '../../data/models/account.dart';
import '../../data/models/journal.dart';
import '../../data/models/transaction_request.dart';
import '../../data/repositories/journal_repository.dart';
import 'advanced_draft.dart';
import 'category_tree.dart';
import 'entry_mode.dart';

/// Why a journal item cannot be edited (`PUT /api/transactions/{id}`)
/// without losing something (docs/known-issues.md).
enum EditBlock {
  /// A balance check / pad or an unknown item: not a transaction.
  notTransaction,

  /// The server does not report posting metadata or whether an edit drops
  /// text (older zhang): an edit could drop what it does not show.
  unknownShape,

  /// A posting has no written form (cost, price, comment): a transaction a
  /// plugin made (the server refuses to edit it) or one whose postings do
  /// not line up with its text.
  notWritten,

  /// The transaction's text has comments (between its postings, on its
  /// header line or after a metadata line) that any edit through the API
  /// deletes.
  dropsText,

  /// A posting has its own flag (`! Assets:Cash`): the journal does not
  /// report posting flags and an update keeps one only while the posting
  /// keeps its account, so an edit could drop it unseen.
  postingFlag,

  /// The server refuses the transaction as it is (the update preview has
  /// no text): the app cannot check what an edit would keep.
  unverified,
}

/// `null` when [item] can be edited losslessly: every field the API reads
/// can be sent back by [CreateTransactionRequest.fromJournal].
EditBlock? editBlockFor(JournalItem item) {
  if (item is! JournalTransaction) return EditBlock.notTransaction;
  if (item.editDropsText == null || item.postings.any((p) => !p.metasReported)) return EditBlock.unknownShape;
  if (item.postings.isEmpty || item.postings.any((p) => p.written == null)) return EditBlock.notWritten;
  if (item.editDropsText!) return EditBlock.dropsText;
  return null;
}

/// [editBlockFor], then what only the server can tell: the update preview
/// of the transaction unchanged (`POST /api/transactions/{id}/preview`)
/// must have a text, without posting flags. Throws the API error (a 404 =
/// the id is out of date).
Future<EditBlock?> checkEditable(JournalRepository repository, JournalTransaction tx) async {
  final block = editBlockFor(tx);
  if (block != null) return block;
  final preview = await repository.previewUpdate(tx.id, CreateTransactionRequest.fromJournal(tx));
  final text = preview.text;
  if (text == null) return EditBlock.unverified;
  if (hasPostingFlags(text)) return EditBlock.postingFlag;
  return null;
}

/// Whether a transaction [text] (as the server writes it) has a posting
/// line with its own flag, such as `  ! Assets:Cash -1 CNY`.
bool hasPostingFlags(String text) {
  final posting = RegExp(r'^[ \t]+([^\s\w;])[ \t]+[^\s;]*:');
  return text.split('\n').skip(1).any(posting.hasMatch);
}

/// What an editor pops with after saving.
@immutable
class EntrySaved {
  const EntrySaved({required this.revision, this.hint});

  /// `ledgerRevisionProvider` before the write: a later revision includes it.
  final int revision;

  /// A keyword to find the saved transaction again (payee, narration or an
  /// account).
  final String? hint;

  /// For [request]: its payee, else its narration, else its first account.
  static String? hintFor(CreateTransactionRequest request) {
    if (request.payee.trim().isNotEmpty) return request.payee.trim();
    if (request.narration.trim().isNotEmpty) return request.narration.trim();
    return request.postings.isEmpty ? null : request.postings.first.account;
  }
}

/// How a two-posting transaction maps onto the simple form (decisions.md
/// §5): which posting is the money source (negative) and which the target.
@immutable
class SimpleFit {
  const SimpleFit({
    required this.mode,
    required this.amount,
    required this.commodity,
    required this.source,
    required this.target,
  });

  final EntryMode mode;

  /// Positive amount of the target posting.
  final Decimal amount;
  final String commodity;

  /// The negative posting: funding (expense), category (income), from
  /// (transfer).
  final String source;

  /// The positive posting: category (expense), funding (income), to
  /// (transfer).
  final String target;

  String? get category => switch (mode) {
    EntryMode.expense => target,
    EntryMode.income => source,
    EntryMode.transfer => null,
  };

  String? get funding => switch (mode) {
    EntryMode.expense => source,
    EntryMode.income => target,
    EntryMode.transfer => null,
  };

  String? get from => mode == EntryMode.transfer ? source : null;
  String? get to => mode == EntryMode.transfer ? target : null;
}

/// Whether [tx] can be shown in the simple form **without losing or
/// changing anything**: exactly two postings with explicit, opposite
/// amounts in one commodity, no cost or price, accounts of the types a mode
/// writes (expense: Expenses + / Assets|Liabilities −, income: Income − /
/// Assets +, transfer: Assets|Liabilities on both sides) that are open, and
/// a category the grid can show. Everything else opens the advanced
/// editor. [accounts] are the ledger's accounts (`GET /api/accounts`).
SimpleFit? simpleFitFor(JournalTransaction tx, List<Account> accounts) {
  if (tx.postings.length != 2) return null;
  final [a, b] = tx.postings;
  final ua = a.unit;
  final ub = b.unit;
  if (ua == null || ub == null || ua.commodity != ub.commodity) return null;
  if (ua.number == Decimal.zero || ua.number != -ub.number) return null;
  for (final p in tx.postings) {
    if (p.cost != null || p.written?.cost != null || p.written?.price != null) return null;
  }
  final (source, target) = ua.number < Decimal.zero ? (a, b) : (b, a);
  final open = {
    for (final acc in accounts)
      if (acc.isOpen) acc.name,
  };
  if (!open.contains(source.account) || !open.contains(target.account)) return null;
  final sourceType = AccountType.ofAccount(source.account);
  final targetType = AccountType.ofAccount(target.account);
  EntryMode? mode;
  if (targetType == AccountType.expenses && EntryMode.expense.allowsFunding(source.account)) {
    mode = EntryMode.expense;
  } else if (sourceType == AccountType.income && EntryMode.income.allowsFunding(target.account)) {
    mode = EntryMode.income;
  } else if (EntryMode.transfer.allowsFunding(source.account) &&
      EntryMode.transfer.allowsFunding(target.account) &&
      source.account != target.account) {
    mode = EntryMode.transfer;
  }
  if (mode == null) return null;
  final fit = SimpleFit(
    mode: mode,
    amount: target.unit!.number,
    commodity: target.unit!.commodity,
    source: source.account,
    target: target.account,
  );
  final category = fit.category;
  if (category != null && CategoryTree.fromAccounts(accounts, mode.categoryRoot!).locate(category) == null) {
    return null;
  }
  return fit;
}

/// The base of a copy: [tx] as a new transaction – everything but its
/// metadata (transaction and posting metas such as `document` attachments
/// or receipt numbers belong to that one entry). The date is set by the
/// editor (the ledger's "now").
CreateTransactionRequest copyBaseOf(JournalTransaction tx) {
  final full = CreateTransactionRequest.fromJournal(tx);
  return full.copyWith(
    metas: const [],
    postings: [
      for (final p in full.postings)
        PostingRequest(
          account: p.account,
          unit: p.unit,
          scale: p.scale,
          cost: p.cost,
          price: p.price,
          comment: p.comment,
        ),
    ],
  );
}

/// Applies what the simple form edits ([built]: date, payee, narration,
/// tags and two postings, source first) onto [base], the two-posting
/// transaction being edited or copied: each posting of [base] takes the
/// account and amount of the [built] posting with the same sign and keeps
/// its own metadata, comment and order; flag, links and transaction metas
/// stay [base]'s. An amount left as it was keeps its written decimals.
CreateTransactionRequest overlaySimpleEntry(CreateTransactionRequest base, CreateTransactionRequest built) {
  assert(base.postings.length == 2 && built.postings.length == 2);
  PostingRequest builtFor(PostingRequest original) {
    final negative = original.unit?.isNegative ?? false;
    return built.postings.firstWhere(
      (p) => (p.unit?.isNegative ?? false) == negative,
      orElse: () => built.postings.first,
    );
  }

  return base.copyWith(
    datetime: built.datetime,
    payee: built.payee,
    narration: built.narration,
    tags: built.tags,
    postings: [
      for (final original in base.postings)
        () {
          final next = builtFor(original);
          final unchanged = next.unit == original.unit && original.scale != null;
          return original.copyWith(
            account: next.account,
            unit: next.unit,
            scale: unchanged ? original.scale : next.scale,
          );
        }(),
    ],
  );
}

/// Everything the simple form is opened with for an edit or a copy.
@immutable
class EntryPrefill {
  const EntryPrefill({
    required this.fit,
    required this.base,
    this.editId,
    this.datetime,
    this.payee = '',
    this.narration = '',
    this.tags = const [],
  });

  /// Edit of [tx] (`PUT` to its id).
  factory EntryPrefill.edit(JournalTransaction tx, SimpleFit fit) => EntryPrefill(
    fit: fit,
    base: CreateTransactionRequest.fromJournal(tx),
    editId: tx.id,
    datetime: tx.datetime,
    payee: tx.payee,
    narration: tx.narration ?? '',
    tags: tx.tags,
  );

  /// Copy of [tx] as a new transaction dated "now".
  factory EntryPrefill.copy(JournalTransaction tx, SimpleFit fit) => EntryPrefill(
    fit: fit,
    base: copyBaseOf(tx),
    payee: tx.payee,
    narration: tx.narration ?? '',
    tags: tx.tags,
  );

  final SimpleFit fit;

  /// What the form does not show and must keep (see [overlaySimpleEntry]).
  final CreateTransactionRequest base;

  /// Transaction replaced on save; `null` = create.
  final String? editId;

  /// `null` = the ledger's "now".
  final DateTime? datetime;
  final String payee;
  final String narration;
  final List<String> tags;

  bool get isEdit => editId != null;
}

/// What the advanced editor is opened with.
@immutable
class AdvancedEntryArgs {
  const AdvancedEntryArgs({required this.draft, this.editId});

  /// Edit of [tx] (`PUT` to its id).
  factory AdvancedEntryArgs.edit(JournalTransaction tx) =>
      AdvancedEntryArgs(draft: AdvancedDraft.fromRequest(CreateTransactionRequest.fromJournal(tx)), editId: tx.id);

  /// Copy of [tx] as a new transaction dated "now".
  factory AdvancedEntryArgs.copy(JournalTransaction tx) =>
      AdvancedEntryArgs(draft: AdvancedDraft.fromRequest(copyBaseOf(tx), keepDate: false));

  final AdvancedDraft draft;

  /// Transaction replaced on save; `null` = create.
  final String? editId;

  bool get isEdit => editId != null;
}
