import 'amount.dart';
import 'json_utils.dart';

/// A posting inside a `/api/journals` item.
class JournalPosting {
  const JournalPosting({
    required this.account,
    this.unit,
    this.cost,
    required this.inferredUnit,
    required this.accountBefore,
    required this.accountAfter,
  });

  factory JournalPosting.fromJson(JsonMap m) => JournalPosting(
    account: reqString(m, 'account'),
    unit: Amount.fromJsonOrNull(m['unit']),
    cost: Amount.fromJsonOrNull(m['cost']),
    inferredUnit: Amount.fromJson(m['inferred_unit']),
    accountBefore: Amount.fromJson(m['account_before']),
    accountAfter: Amount.fromJson(m['account_after']),
  );

  final String account;

  /// Amount as written in the ledger; `null` = implicit (auto-balanced) leg.
  /// Send this (not [inferredUnit]) back when editing a transaction.
  final Amount? unit;

  /// Per-unit cost (`{26000 USD}`), if any. Read-only through the API.
  final Amount? cost;

  /// Effective amount of the posting – use this for display.
  final Amount inferredUnit;

  /// Running balance of [account] in `inferredUnit.commodity` before/after.
  final Amount accountBefore;
  final Amount accountAfter;
}

/// An item of `GET /api/journals` (tagged union on `type`).
///
/// ```dart
/// switch (item) {
///   JournalTransaction() => ...,
///   JournalBalance() => ...,   // balance check ("C") or pad ("P")
///   JournalUnknown() => ...,   // a `type` this client does not know
/// }
/// ```
///
/// Ids and [sequence] are NOT stable across ledger reloads (docs §1.6):
/// never persist them; refetch after every mutation.
sealed class JournalItem {
  const JournalItem({
    required this.id,
    required this.sequence,
    required this.datetime,
    required this.payee,
    this.narration,
    this.postings = const [],
  });

  factory JournalItem.fromJson(JsonMap m) {
    final type = reqString(m, 'type');
    return switch (type) {
      'Transaction' => JournalTransaction.fromJson(m),
      'BalanceCheck' || 'BalancePad' => JournalBalance.fromJson(m),
      _ => JournalUnknown.fromJson(m),
    };
  }

  final String id;

  /// Chronological index over the whole ledger (newest = highest).
  final int sequence;

  /// Naive ledger-local wall-clock time (see `ZhangDates.parseNaive`).
  final DateTime datetime;

  /// `""` when the transaction has no payee.
  final String payee;
  final String? narration;
  final List<JournalPosting> postings;
}

/// `type == "Transaction"`.
class JournalTransaction extends JournalItem {
  const JournalTransaction({
    required super.id,
    required super.sequence,
    required super.datetime,
    required super.payee,
    super.narration,
    super.postings,
    this.tags = const [],
    this.links = const [],
    this.flag = '*',
    this.isBalanced = true,
    this.metas = const [],
  });

  factory JournalTransaction.fromJson(JsonMap m) => JournalTransaction(
    id: reqString(m, 'id'),
    sequence: reqInt(m, 'sequence'),
    datetime: reqNaiveDateTime(m, 'datetime'),
    payee: optString(m, 'payee') ?? '',
    narration: optString(m, 'narration'),
    postings: parseList(m['postings'] ?? const [], JournalPosting.fromJson, 'postings'),
    tags: stringList(m['tags']),
    links: stringList(m['links']),
    flag: optString(m, 'flag') ?? '*',
    isBalanced: optBool(m, 'is_balanced', fallback: true),
    metas: m['metas'] == null ? const [] : [for (final e in asList(m['metas'])) Meta.fromJson(e)],
  );

  /// Without `#`.
  final List<String> tags;

  /// Without `^`.
  final List<String> links;

  /// `"*"` (complete), `"!"` (pending/warning) or a custom character.
  final String flag;

  /// `false` when the server reported an `UnbalancedTransaction` error.
  final bool isBalanced;

  /// Metadata; attached documents appear as `document` metas.
  final List<Meta> metas;

  bool get isPending => flag == '!';

  /// Paths of attached documents (`document` metas).
  List<String> get documentPaths => [
    for (final m in metas)
      if (m.key == 'document') m.value,
  ];
}

/// `type == "BalanceCheck"` (`type_ == "C"`) or `"BalancePad"` (`"P"`).
class JournalBalance extends JournalItem {
  const JournalBalance({
    required super.id,
    required super.sequence,
    required super.datetime,
    required super.payee,
    super.narration,
    super.postings,
    required this.isPad,
  });

  factory JournalBalance.fromJson(JsonMap m) {
    final type = reqString(m, 'type');
    final marker = optString(m, 'type_');
    return JournalBalance(
      id: reqString(m, 'id'),
      sequence: reqInt(m, 'sequence'),
      datetime: reqNaiveDateTime(m, 'datetime'),
      payee: optString(m, 'payee') ?? '',
      narration: optString(m, 'narration'),
      postings: parseList(m['postings'] ?? const [], JournalPosting.fromJson, 'postings'),
      isPad: type == 'BalancePad' || marker == 'P',
    );
  }

  /// `true` for a pad (`"P"`), `false` for a check (`"C"`).
  final bool isPad;
  bool get isCheck => !isPad;
}

/// A journal item whose `type` is not known to this client version.
class JournalUnknown extends JournalItem {
  const JournalUnknown({
    required this.type,
    required super.id,
    required super.sequence,
    required super.datetime,
    required super.payee,
    super.narration,
  });

  factory JournalUnknown.fromJson(JsonMap m) => JournalUnknown(
    type: reqString(m, 'type'),
    id: optString(m, 'id') ?? '',
    sequence: m['sequence'] == null ? 0 : reqInt(m, 'sequence'),
    datetime: optNaiveDateTime(m, 'datetime') ?? DateTime.fromMillisecondsSinceEpoch(0),
    payee: optString(m, 'payee') ?? '',
    narration: optString(m, 'narration'),
  );

  final String type;
}
