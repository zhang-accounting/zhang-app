import 'amount.dart';
import 'json_utils.dart';

/// `POST /api/transactions/preview` (zhang ≥ 0.2): what saving a
/// transaction would write and the problems the ledger would report, without
/// writing anything.
class TransactionPreview {
  const TransactionPreview({
    this.text,
    this.fieldErrors = const [],
    this.unbalanced,
    this.errors = const [],
  });

  factory TransactionPreview.fromJson(Object? json) {
    final m = asMap(json, 'transaction preview');
    final unbalanced = m['unbalanced'];
    return TransactionPreview(
      text: optString(m, 'text'),
      fieldErrors: parseList(m['field_errors'] ?? const [], PreviewFieldError.fromJson, 'field_errors'),
      unbalanced: unbalanced == null ? null : [for (final a in asList(unbalanced, 'unbalanced')) Amount.fromJson(a)],
      errors: parseList(m['errors'] ?? const [], PreviewLedgerError.fromJson, 'errors'),
    );
  }

  /// The directive as it would be written; `null` when a field is invalid.
  final String? text;

  /// Fields the server refuses (the save would answer 400).
  final List<PreviewFieldError> fieldErrors;

  /// What the postings are off by, per commodity; empty when balanced,
  /// `null` when it could not be checked (invalid fields).
  final List<Amount>? unbalanced;

  /// Ledger errors the transaction would cause (unknown or closed account,
  /// …) – the server would still write it.
  final List<PreviewLedgerError> errors;

  bool get isUnbalanced => unbalanced?.isNotEmpty ?? false;

  /// Ledger error kinds that block the save: the entry would be written
  /// against an account that is not open, or would not balance.
  static const blockingErrorTypes = {'AccountDoesNotExist', 'AccountClosed', 'UnbalancedTransaction'};

  /// Nothing to complain about: safe to save.
  bool get isClean => fieldErrors.isEmpty && !isUnbalanced && errors.isEmpty;

  /// The save must not go ahead: a refused field (the server would answer
  /// 400), unbalanced postings, or an unknown / closed account.
  bool get isBlocked =>
      fieldErrors.isNotEmpty || isUnbalanced || errors.any((e) => blockingErrorTypes.contains(e.type));

  /// Other ledger errors and notices (an undeclared commodity, a commodity
  /// the account's `open` does not list, …): the user may save anyway.
  List<PreviewLedgerError> get warnings => [
    for (final e in errors)
      if (!blockingErrorTypes.contains(e.type)) e,
  ];
}

/// `{posting, field, kind, value, message}`; [posting] is the index of the
/// posting, `null` for transaction-level fields.
class PreviewFieldError {
  const PreviewFieldError({this.posting, required this.field, required this.kind, this.value, required this.message});

  factory PreviewFieldError.fromJson(JsonMap m) => PreviewFieldError(
    posting: m['posting'] == null ? null : reqInt(m, 'posting'),
    field: optString(m, 'field') ?? '',
    kind: optString(m, 'kind') ?? '',
    value: m['value'] == null ? null : '${m['value']}',
    message: optString(m, 'message') ?? '',
  );

  final int? posting;
  final String field;

  /// e.g. `invalid_account`.
  final String kind;
  final String? value;

  /// The server's explanation (English).
  final String message;
}

/// `{error_type, metas}` of a preview, e.g. `AccountDoesNotExist` with
/// `{account_name}`.
class PreviewLedgerError {
  const PreviewLedgerError({required this.type, this.metas = const {}});

  factory PreviewLedgerError.fromJson(JsonMap m) {
    final metas = m['metas'];
    return PreviewLedgerError(
      type: reqString(m, 'error_type'),
      metas: metas is Map ? {for (final e in metas.entries) '${e.key}': '${e.value}'} : const {},
    );
  }

  final String type;
  final Map<String, String> metas;

  String? get account => metas['account_name'];

  /// `CommodityDoesNotDefine` names it `commodity_name`,
  /// `CommodityNotAllowed` `commodity`.
  String? get commodity => metas['commodity_name'] ?? metas['commodity'];
}

/// Thrown by the record screen when the preview reports problems that block
/// the save ([TransactionPreview.isBlocked]); the transaction was **not**
/// saved.
class TransactionRejected implements Exception {
  const TransactionRejected(this.preview);

  final TransactionPreview preview;

  @override
  String toString() => 'TransactionRejected(${preview.fieldErrors.length} field errors, '
      'unbalanced: ${preview.unbalanced}, ${preview.errors.length} ledger errors)';
}

/// Thrown by the record screen when the preview only reports
/// [TransactionPreview.warnings]: nothing was saved yet, the user may save
/// anyway. [again] is the "save and add another" choice to repeat.
class TransactionNeedsConfirmation implements Exception {
  const TransactionNeedsConfirmation(this.preview, {required this.again});

  final TransactionPreview preview;
  final bool again;

  @override
  String toString() => 'TransactionNeedsConfirmation(${preview.warnings.map((e) => e.type).join(', ')})';
}
