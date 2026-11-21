import 'dart:convert';

import 'package:decimal/decimal.dart';
import 'package:flutter/foundation.dart';

import '../../core/utils/dates.dart';
import '../../data/api/api_exception.dart';
import '../../data/models/account.dart';
import '../../data/models/amount.dart';
import '../../data/models/journal.dart';
import '../../data/models/transaction_preview.dart';
import '../../data/models/transaction_request.dart';
import '../../data/repositories/journal_repository.dart';
import 'advanced_draft.dart';
import 'category_tree.dart';
import 'create_intent.dart';
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

/// The transaction an edit starts from, as checked by [checkEditable].
@immutable
class EditTarget {
  const EditTarget(this.tx, {this.bareMetas = const {}});

  /// The transaction as read (the snapshot the edit is made against).
  final JournalTransaction tx;

  /// Postings (by index) whose metadata has unquoted values (`lot: 8`),
  /// with those lines as the server writes them.
  final Map<int, List<String>> bareMetas;

  String get id => tx.id;

  /// Sent as `If-Match` (servers with `version`, zhang PR #818).
  String? get version => tx.version;
}

/// Thrown when the transaction being edited is no longer the one the edit
/// started from (another one has its id now, it was changed or removed).
class TransactionChanged implements Exception {
  const TransactionChanged();

  @override
  String toString() => 'TransactionChanged';
}

/// Whether [error] means the transaction changed on the server since it was
/// read: [TransactionChanged], a 404 for its id or a 412 for its `version`.
bool isStaleEdit(Object error) =>
    error is TransactionChanged ||
    (error is ApiNotFound && !error.isMissingRoute) ||
    (error is ZhangApiException && error.statusCode == 412);

/// A keyword to find [tx] again: its payee, else its narration, else its
/// first account.
String? lookupHint(JournalTransaction tx) {
  if (tx.payee.trim().isNotEmpty) return tx.payee.trim();
  final narration = tx.narration?.trim() ?? '';
  if (narration.isNotEmpty) return narration;
  return tx.postings.isEmpty ? null : tx.postings.first.account;
}

/// Whether [a] and [b] read the same: everything an edit sends back, and the
/// `version` when both have one.
bool sameTransaction(JournalTransaction a, JournalTransaction b) {
  if (a.version != null && b.version != null && a.version != b.version) return false;
  if (a.editDropsText != b.editDropsText) return false;
  return jsonEncode(CreateTransactionRequest.fromJournal(a).toJson()) ==
      jsonEncode(CreateTransactionRequest.fromJournal(b).toJson());
}

/// Reads [target] again by id and throws [TransactionChanged] unless the
/// server still lists the same transaction under it (ids are places in a
/// file: after another write the id may name another transaction).
Future<void> verifyUnchanged(JournalRepository repository, JournalTransaction snapshot) async {
  final fresh = await repository.findById(snapshot.id, keyword: lookupHint(snapshot));
  if (fresh is! JournalTransaction || !sameTransaction(fresh, snapshot)) throw const TransactionChanged();
}

/// What [checkEditable] found.
typedef EditCheck = ({EditBlock? block, EditTarget? target});

/// [editBlockFor], then what only the server can tell: the transaction must
/// still be listed unchanged under its id ([verifyUnchanged], only without
/// a `version`: the lookup searches a few pages), and the update preview of
/// it unchanged (`POST /api/transactions/{id}/preview`, with
/// `If-Match` when it has a `version`) must have a text, without posting
/// flags. Throws [TransactionChanged] or the API error (404 / 412 = changed,
/// see [isStaleEdit]).
Future<EditCheck> checkEditable(JournalRepository repository, JournalTransaction tx) async {
  final block = editBlockFor(tx);
  if (block != null) return (block: block, target: null);
  // With a `version`, `If-Match` makes the server refuse another or a
  // changed transaction; without one, read it again by id.
  if (tx.version == null) await verifyUnchanged(repository, tx);
  final preview = await repository.previewUpdate(tx.id, CreateTransactionRequest.fromJournal(tx), version: tx.version);
  final text = preview.text;
  if (text == null) return (block: EditBlock.unverified, target: null);
  if (hasPostingFlags(text)) return (block: EditBlock.postingFlag, target: null);
  return (block: null, target: EditTarget(tx, bareMetas: bareMetaLines(text)));
}

/// A posting line of a transaction text: optional flag (`*`, `!`, `&`, `?`,
/// `%`, `#` or `A`–`Z`, zhang's parser) and an account – `Type:Name[:…]`,
/// a capital first letter and a non-space after every colon. A metadata
/// key, capitalised or not, is followed by `: ` (`Lot: 8`), so it never
/// reads as an account.
final _postingLine = RegExp(r'^[ \t]+(?:([*!&?%#A-Z])[ \t]+)?[A-Z][^\s:"]*(?::[^\s:"]+)+(?=[ \t;]|$)');

/// `key: value` of a metadata line (a key may be quoted).
final _metaLine = RegExp(r'^[ \t]+(?:"(?:[^"\\]|\\.)*"|[^\s:"]+):[ \t]*(.*)$');

/// The lines after the header of a transaction [text] at the postings'
/// level – the least indented ones: transaction metadata and postings –,
/// each with the deeper (posting metadata) lines that follow it.
List<(String line, List<String> deeper)> _bodyBlocks(String text) {
  int indent(String line) => line.length - line.trimLeft().length;
  final lines = [
    for (final line in text.split('\n').skip(1))
      if (line.trim().isNotEmpty) line,
  ];
  if (lines.isEmpty) return const [];
  final level = lines.map(indent).reduce((a, b) => a < b ? a : b);
  final blocks = <(String, List<String>)>[];
  for (final line in lines) {
    if (indent(line) <= level || blocks.isEmpty) {
      blocks.add((line, <String>[]));
    } else {
      blocks.last.$2.add(line);
    }
  }
  return blocks;
}

/// Whether a transaction [text] (as the server writes it) has a posting
/// line with its own flag, such as `  ! Assets:Cash -1 CNY` or
/// `  C Expenses:Food 1 USD`.
bool hasPostingFlags(String text) =>
    _bodyBlocks(text).any((block) => _postingLine.firstMatch(block.$1)?.group(1) != null);

/// The metadata lines with an unquoted value (`lot: 8`, `Lot: 8`,
/// `when: 2026-11-02`) of each posting (by index) of a transaction [text]:
/// the lines indented below a posting line.
Map<int, List<String>> bareMetaLines(String text) {
  final out = <int, List<String>>{};
  var posting = -1;
  for (final (line, deeper) in _bodyBlocks(text)) {
    if (!_postingLine.hasMatch(line)) continue; // transaction metadata
    posting++;
    for (final meta in deeper) {
      final value = _metaLine.firstMatch(meta)?.group(1)?.trim();
      if (value == null || value.isEmpty || value.startsWith('"')) continue;
      out.putIfAbsent(posting, () => []).add(meta.trim());
    }
  }
  return out;
}

/// The posting of [original] the server edits with request posting [index]
/// of [request] (`original_posting` in zhang's transaction route): the only
/// one to its account when [request] has only it for that account, else the
/// only one with its account and units when [request] has only it with
/// those; `null` when there is no such single pair.
int? serverMatch(List<JournalPosting> original, List<PostingRequest> request, int index) {
  final r = request[index];
  final sameAccount = [
    for (final (i, p) in original.indexed)
      if (p.account == r.account) i,
  ];
  if (sameAccount.length == 1 && request.where((p) => p.account == r.account).length == 1) return sameAccount.single;
  final sameUnits = [
    for (final i in sameAccount)
      if (original[i].unit == r.unit) i,
  ];
  final requestSameUnits = request.where((p) => p.account == r.account && p.unit == r.unit).length;
  return sameUnits.length == 1 && requestSameUnits == 1 ? sameUnits.single : null;
}

/// Postings of [target] with unquoted metadata values that [request] does
/// not give back to them: the server keeps a value unquoted only for the
/// posting it matches ([serverMatch]), so after an account change `lot: 8`
/// is written `lot: "8"`. [origins] gives, per request posting, the index of
/// the posting of [target] it was opened from (`null` = a new one).
/// Returns the affected postings' metadata lines, by original index.
Map<int, List<String>> requotedMetas(EditTarget target, CreateTransactionRequest request, List<int?> origins) {
  final out = <int, List<String>>{};
  for (final (i, origin) in origins.indexed) {
    final lines = origin == null ? null : target.bareMetas[origin];
    if (lines == null || i >= request.postings.length) continue;
    if (request.postings[i].metas.isEmpty) continue;
    if (serverMatch(target.tx.postings, request.postings, i) != origin) out[origin!] = lines;
  }
  return out;
}

/// What an editor pops with after saving.
@immutable
class EntrySaved {
  const EntrySaved({required this.revision, required this.request, this.hint});

  /// `ledgerRevisionProvider` before the write: a later revision may include
  /// it ([entryMatches] tells).
  final int revision;

  /// What was saved.
  final CreateTransactionRequest request;

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

/// Whether [read] (as listed after a reload) is what [request] saved:
/// compared value by value, as the server rewrites the text (metadata
/// sorted by key, `{150 USD}` → `{ 150 USD }`, `88.50` vs `88.5`). Cost /
/// price / comment left out of [request] are not compared (the server kept
/// them).
bool entryMatches(JournalTransaction read, CreateTransactionRequest request) {
  List<String> metas(List<Meta> list) => [for (final m in list) '${m.key}\u0000${m.value}']..sort();
  String? squash(String? text) => text?.replaceAll(RegExp(r'\s+'), '');
  if (ZhangDates.toNaiveIso(read.datetime) != ZhangDates.toNaiveIso(request.datetime)) return false;
  if (read.payee != request.payee || (read.narration ?? '') != request.narration) return false;
  if (read.flag != (request.flag ?? TransactionFlag.complete)) return false;
  if (!listEquals(read.tags, request.tags) || !listEquals(read.links, request.links)) return false;
  if (!listEquals(metas(read.metas), metas(request.metas))) return false;
  if (read.postings.length != request.postings.length) return false;
  for (final (i, r) in request.postings.indexed) {
    final p = read.postings[i];
    if (p.account != r.account || p.unit != r.unit) return false;
    if (!listEquals(metas(p.metas), metas(r.metas))) return false;
    final w = p.written;
    if (w == null) continue;
    if ((r.sendWritten || r.cost != null) && squash(w.cost) != squash(r.cost)) return false;
    if ((r.sendWritten || r.price != null) && squash(w.price) != squash(r.price)) return false;
    if ((r.sendWritten || r.comment != null) && w.comment?.trim() != r.comment?.trim()) return false;
  }
  return true;
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
/// metadata and links (transaction and posting metas such as `document`
/// attachments or receipt numbers belong to that one entry; links tie
/// related entries, and a copy is a new one). The date is set by the editor
/// (the ledger's "now").
CreateTransactionRequest copyBaseOf(JournalTransaction tx) {
  final full = CreateTransactionRequest.fromJournal(tx);
  return full.copyWith(
    metas: const [],
    links: const [],
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
/// stay [base]'s. An amount left as it was keeps its written decimals; a
/// payee / narration that only lost surrounding spaces to the form's
/// trimming is kept as written.
CreateTransactionRequest overlaySimpleEntry(CreateTransactionRequest base, CreateTransactionRequest built) {
  assert(base.postings.length == 2 && built.postings.length == 2);
  PostingRequest builtFor(PostingRequest original) {
    final negative = original.unit?.isNegative ?? false;
    return built.postings.firstWhere(
      (p) => (p.unit?.isNegative ?? false) == negative,
      orElse: () => built.postings.first,
    );
  }

  String kept(String written, String typed) => written.trim() == typed ? written : typed;
  return base.copyWith(
    datetime: built.datetime,
    payee: kept(base.payee, built.payee),
    narration: kept(base.narration, built.narration),
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
    this.target,
    this.datetime,
    this.payee = '',
    this.narration = '',
    this.tags = const [],
  });

  /// Edit of [target] (`PUT` to its id).
  factory EntryPrefill.edit(EditTarget target, SimpleFit fit) => EntryPrefill(
    fit: fit,
    base: CreateTransactionRequest.fromJournal(target.tx),
    target: target,
    datetime: target.tx.datetime,
    payee: target.tx.payee,
    narration: target.tx.narration ?? '',
    tags: target.tx.tags,
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
  final EditTarget? target;

  String? get editId => target?.id;

  /// `null` = the ledger's "now".
  final DateTime? datetime;
  final String payee;
  final String narration;
  final List<String> tags;

  bool get isEdit => target != null;
}

/// What the advanced editor is opened with.
@immutable
class AdvancedEntryArgs {
  const AdvancedEntryArgs({required this.draft, this.target, this.intent});

  /// Edit of [target] (`PUT` to its id).
  factory AdvancedEntryArgs.edit(EditTarget target) => AdvancedEntryArgs(
    draft: AdvancedDraft.fromRequest(CreateTransactionRequest.fromJournal(target.tx)),
    target: target,
  );

  /// Copy of [tx] as a new transaction dated "now".
  factory AdvancedEntryArgs.copy(JournalTransaction tx) =>
      AdvancedEntryArgs(draft: AdvancedDraft.fromRequest(copyBaseOf(tx), keepDate: false));

  final AdvancedDraft draft;

  /// Transaction replaced on save; `null` = create.
  final EditTarget? target;

  /// The save of the simple form that opened the editor: a create keeps
  /// its `Idempotency-Key` (an attempt made there may have been written).
  final CreateIntent? intent;

  String? get editId => target?.id;

  bool get isEdit => target != null;
}

/// Saves [request] like both editors do: an edit of [target] without a
/// `version` is first checked to still be the transaction the edit started
/// from ([verifyUnchanged]), then previewed and replaced on its id (with
/// `If-Match` when it has a `version`); anything else is previewed and
/// created with the `Idempotency-Key` of [intent] (a new one when `null`).
/// Answers what a create wrote, `null` for an edit. Throws
/// [TransactionRejected] / [TransactionNeedsConfirmation] (nothing
/// written), [TransactionChanged] or the API error.
Future<CreateResult?> saveEntry(
  JournalRepository repository,
  CreateTransactionRequest request, {
  EditTarget? target,
  CreateIntent? intent,
  bool acceptWarnings = false,
  bool again = false,
}) async {
  final TransactionPreview preview;
  if (target == null) {
    preview = await repository.preview(request);
  } else {
    if (target.version == null) await verifyUnchanged(repository, target.tx);
    preview = await repository.previewUpdate(target.id, request, version: target.version);
  }
  if (preview.isBlocked) throw TransactionRejected(preview);
  if (!acceptWarnings && preview.warnings.isNotEmpty) throw TransactionNeedsConfirmation(preview, again: again);
  if (target == null) return (intent ?? CreateIntent()).create(repository, request);
  await repository.update(target.id, request, version: target.version);
  return null;
}
