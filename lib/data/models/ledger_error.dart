import 'json_utils.dart';

/// Known `error_type` values of `GET /api/errors`.
enum LedgerErrorType {
  unbalancedTransaction('UnbalancedTransaction'),
  transactionCannotInferTradeAmount('TransactionCannotInferTradeAmount'),
  transactionHasMultipleImplicitPosting('TransactionHasMultipleImplicitPosting'),
  transactionExplicitPostingHaveMultipleCommodity('TransactionExplicitPostingHaveMultipleCommodity'),
  accountBalanceCheckError('AccountBalanceCheckError'),
  accountDoesNotExist('AccountDoesNotExist'),
  accountClosed('AccountClosed'),
  commodityDoesNotDefine('CommodityDoesNotDefine'),
  noEnoughCommodityLot('NoEnoughCommodityLot'),
  closeNonZeroAccount('CloseNonZeroAccount'),
  budgetDoesNotExist('BudgetDoesNotExist'),
  defineDuplicatedBudget('DefineDuplicatedBudget'),
  multipleOperatingCurrencyDetect('MultipleOperatingCurrencyDetect'),
  parseInvalidMeta('ParseInvalidMeta'),

  /// Any value this client does not know yet (see [LedgerError.rawType]).
  unknown('');

  const LedgerErrorType(this.wire);

  final String wire;

  static LedgerErrorType fromWire(String value) => LedgerErrorType.values.firstWhere(
    (t) => t.wire == value && t != unknown,
    orElse: () => unknown,
  );
}

/// Source location of a ledger error.
class ErrorSpan {
  const ErrorSpan({required this.start, required this.end, required this.content, this.filename});

  factory ErrorSpan.fromJson(JsonMap m) => ErrorSpan(
    start: reqInt(m, 'start'),
    end: reqInt(m, 'end'),
    content: optString(m, 'content') ?? '',
    filename: optString(m, 'filename'),
  );

  /// Byte offsets in [filename].
  final int start;
  final int end;

  /// Source text of the failing directive.
  final String content;

  /// Path relative to the ledger root.
  final String? filename;
}

/// One entry of `GET /api/errors` (`ErrorEntity`).
class LedgerError {
  const LedgerError({
    required this.id,
    this.span,
    required this.type,
    required this.rawType,
    this.metas = const {},
  });

  factory LedgerError.fromJson(JsonMap m) {
    final raw = reqString(m, 'error_type');
    final span = m['span'];
    final metas = m['metas'];
    return LedgerError(
      id: reqString(m, 'id'),
      span: span == null ? null : ErrorSpan.fromJson(asMap(span, 'span')),
      type: LedgerErrorType.fromWire(raw),
      rawType: raw,
      metas: metas == null ? const {} : {for (final e in asMap(metas).entries) e.key: '${e.value}'},
    );
  }

  /// For transaction errors equals the transaction id.
  final String id;
  final ErrorSpan? span;
  final LedgerErrorType type;

  /// `error_type` exactly as sent by the server.
  final String rawType;

  /// Context such as `txn_id`, `account_name`.
  final Map<String, String> metas;
}
