import '../../core/utils/dates.dart';
import 'amount.dart';
import 'journal.dart';

/// Flags accepted by `POST/PUT /api/transactions` (any single character also
/// works; responses report `"*"` / `"!"`).
abstract final class TransactionFlag {
  static const complete = '*';
  static const pending = '!';
}

/// A posting in a create/update request. `unit == null` lets the server infer
/// the balancing amount (at most one such posting per transaction).
///
/// [cost], [price] and [comment] are in the ledger's own syntax (as
/// `written` of a journal posting reads them). In an update the server keeps
/// a field that is **left out** from the posting it edits (matched by
/// account), removes it on `null` and writes a value as given; [sendWritten]
/// sends the three keys even when `null`, so an edit states every one of
/// them. [metas] are always the posting's whole metadata: posting metadata
/// left out of an update is dropped.
class PostingRequest {
  const PostingRequest({
    required this.account,
    this.unit,
    this.scale,
    this.cost,
    this.price,
    this.comment,
    this.metas = const [],
    this.sendWritten = false,
  });

  final String account;
  final Amount? unit;

  /// Minimum decimals written for [unit] (the commodity precision), so the
  /// ledger gets `15.50 CNY` rather than `15.5 CNY`.
  final int? scale;

  /// `{150 USD}`, `{{1500 USD}}`, `{}` or `{150 USD, 2024-01-15, "lot"}`.
  final String? cost;

  /// `@ 6 USD` or `@@ 60 USD`.
  final String? price;

  /// Comment at the end of the posting line, without the `;`.
  final String? comment;
  final List<Meta> metas;

  /// Send [cost], [price] and [comment] even when `null` (see the class doc).
  final bool sendWritten;

  PostingRequest copyWith({String? account, Amount? unit, int? scale, bool clearUnit = false}) => PostingRequest(
    account: account ?? this.account,
    unit: clearUnit ? null : (unit ?? this.unit),
    scale: clearUnit ? null : (scale ?? this.scale),
    cost: cost,
    price: price,
    comment: comment,
    metas: metas,
    sendWritten: sendWritten,
  );

  Map<String, Object?> toJson() => {
    'account': account,
    'unit': unit?.toJson(minScale: scale),
    if (sendWritten || cost != null) 'cost': cost,
    if (sendWritten || price != null) 'price': price,
    if (sendWritten || comment != null) 'comment': comment,
    if (metas.isNotEmpty) 'metas': [for (final m in metas) m.toJson()],
  };
}

/// Body of `POST /api/transactions` and `PUT /api/transactions/{id}`.
///
/// Encodes the server's rules (docs/zhang-api.md):
/// * [datetime] is the **ledger's wall-clock time** and is sent without an
///   offset (`2026-10-03T09:30:00`, zhang ≥ 0.2 reads it in the ledger's
///   timezone), so editing never shifts the time when the device timezone
///   differs from the ledger's;
/// * [narration] is always sent as a string (`""` for none) – omitting it
///   would turn the payee into the narration;
/// * `tags`, `links` and `metas` are always sent (may be empty);
/// * amounts are decimal strings, never JSON numbers.
class CreateTransactionRequest {
  const CreateTransactionRequest({
    required this.datetime,
    required this.payee,
    this.narration = '',
    this.flag = TransactionFlag.complete,
    required this.postings,
    this.metas = const [],
    this.tags = const [],
    this.links = const [],
  });

  /// Starting point for a safe edit (`PUT`): copies payee, narration, flag,
  /// tags, links, metas (incl. `document` entries) and, per posting, the
  /// *written* unit (with its decimals), metadata and the cost / price /
  /// comment as written, so nothing is lost when only some fields change.
  /// Only valid for a transaction whose postings report `written` and
  /// `metas` (see `editBlockFor` in the edit feature).
  factory CreateTransactionRequest.fromJournal(JournalTransaction tx) =>
      CreateTransactionRequest(
        datetime: tx.datetime,
        payee: tx.payee,
        narration: tx.narration ?? '',
        flag: tx.flag,
        postings: [
          for (final p in tx.postings)
            PostingRequest(
              account: p.account,
              unit: p.unit,
              scale: p.unitScale,
              cost: p.written?.cost,
              price: p.written?.price,
              comment: p.written?.comment,
              metas: p.metas,
              sendWritten: p.written != null,
            ),
        ],
        metas: tx.metas,
        tags: tx.tags,
        links: tx.links,
      );

  /// Ledger wall-clock time (a naive `DateTime` as parsed from responses, or
  /// the ledger clock); serialised with [ZhangDates.toNaiveIso].
  final DateTime datetime;
  final String payee;
  final String narration;

  /// `"*"`, `"!"` (see [TransactionFlag]) or `null` for the default.
  final String? flag;
  final List<PostingRequest> postings;
  final List<Meta> metas;
  final List<String> tags;
  final List<String> links;

  CreateTransactionRequest copyWith({
    DateTime? datetime,
    String? payee,
    String? narration,
    String? flag,
    List<PostingRequest>? postings,
    List<Meta>? metas,
    List<String>? tags,
    List<String>? links,
  }) => CreateTransactionRequest(
    datetime: datetime ?? this.datetime,
    payee: payee ?? this.payee,
    narration: narration ?? this.narration,
    flag: flag ?? this.flag,
    postings: postings ?? this.postings,
    metas: metas ?? this.metas,
    tags: tags ?? this.tags,
    links: links ?? this.links,
  );

  Map<String, Object?> toJson() => {
    'datetime': ZhangDates.toNaiveIso(datetime),
    'payee': payee,
    'narration': narration,
    if (flag != null) 'flag': flag,
    'postings': [for (final p in postings) p.toJson()],
    'metas': [for (final m in metas) m.toJson()],
    'tags': tags,
    'links': links,
  };
}
