import 'query_result.dart';

/// Known `kind` values of the built-in `journals.errors` query.
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
  commodityNotAllowed('CommodityNotAllowed'),

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
  const ErrorSpan({
    required this.start,
    required this.end,
    required this.content,
    this.filename,
    this.line,
    this.column,
  });

  /// Byte offsets in [filename].
  final int start;
  final int end;

  /// Source text of the failing directive.
  final String content;

  /// Path relative to the ledger root.
  final String? filename;

  /// 1-based line and column of [start].
  final int? line;
  final int? column;
}

/// One ledger error: a row of the built-in `journals.errors` query
/// (`[id, kind, file, line, column, span_start, span_end, source, metas]`).
class LedgerError {
  const LedgerError({
    required this.id,
    this.span,
    required this.type,
    required this.rawType,
    this.metas = const {},
  });

  factory LedgerError.fromQueryRow(QueryRow r) {
    final raw = r.string('kind');
    final start = r.integerOrNull('span_start');
    return LedgerError(
      id: r.stringOrNull('id') ?? '',
      span: start == null
          ? null
          : ErrorSpan(
              start: start,
              end: r.integerOrNull('span_end') ?? start,
              content: r.stringOrNull('source') ?? '',
              filename: r.stringOrNull('file'),
              line: r.integerOrNull('line'),
              column: r.integerOrNull('column'),
            ),
      type: LedgerErrorType.fromWire(raw),
      rawType: raw,
      metas: {for (final m in r.metas('metas')) m.key: m.value},
    );
  }

  /// For transaction errors equals the transaction id.
  final String id;
  final ErrorSpan? span;
  final LedgerErrorType type;

  /// `kind` exactly as sent by the server.
  final String rawType;

  /// Context such as `txn_id`, `account_name`.
  final Map<String, String> metas;
}
