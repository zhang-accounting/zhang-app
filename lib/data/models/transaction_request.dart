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
class PostingRequest {
  const PostingRequest({required this.account, this.unit, this.scale});

  final String account;
  final Amount? unit;

  /// Minimum decimals written for [unit] (the commodity precision), so the
  /// ledger gets `15.50 CNY` rather than `15.5 CNY`.
  final int? scale;

  Map<String, Object?> toJson() => {'account': account, 'unit': unit?.toJson(minScale: scale)};
}

/// Body of `POST /api/transactions` and `PUT /api/transactions/{id}`.
///
/// Encodes the server's rules (docs §3.3):
/// * [datetime] is sent as an RFC 3339 UTC instant (`…Z`);
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
  /// tags, links, metas (incl. `document` entries) and the *written* posting
  /// units of [tx], so nothing is lost when only some fields change.
  factory CreateTransactionRequest.fromJournal(JournalTransaction tx) =>
      CreateTransactionRequest(
        datetime: tx.datetime,
        payee: tx.payee,
        narration: tx.narration ?? '',
        flag: tx.flag,
        postings: [
          for (final p in tx.postings) PostingRequest(account: p.account, unit: p.unit),
        ],
        metas: tx.metas,
        tags: tx.tags,
        links: tx.links,
      );

  /// Local or UTC instant; serialised with [ZhangDates.toRfc3339].
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
    'datetime': ZhangDates.toRfc3339(datetime),
    'payee': payee,
    'narration': narration,
    if (flag != null) 'flag': flag,
    'postings': [for (final p in postings) p.toJson()],
    'metas': [for (final m in metas) m.toJson()],
    'tags': tags,
    'links': links,
  };
}
