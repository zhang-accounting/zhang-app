import 'package:decimal/decimal.dart';
import 'package:flutter/foundation.dart';

import '../../core/utils/money.dart';
import '../../data/models/amount.dart';
import '../../data/models/json_utils.dart';
import '../../data/models/transaction_request.dart';

/// One posting of the advanced editor (docs/design-research.md S06), as
/// typed. Pure data: the screen keeps the text controllers and snapshots
/// them into an [AdvancedDraft] on every change.
@immutable
class PostingDraft {
  const PostingDraft({
    required this.key,
    this.account,
    this.amount = '',
    this.commodity,
    this.cost = '',
    this.price = '',
    this.comment = '',
    this.metas = const [],
    this.originalUnit,
    this.originalScale,
    this.origin,
  });

  /// From posting [key] of a request (an edit, a copy or the simple form's
  /// postings); [origin] is that index.
  factory PostingDraft.fromRequest(int key, PostingRequest p) {
    final unit = p.unit;
    return PostingDraft(
      key: key,
      account: p.account,
      amount: unit == null ? '' : decimalToJson(unit.number, minScale: p.scale),
      commodity: unit?.commodity,
      cost: p.cost ?? '',
      price: p.price ?? '',
      comment: p.comment ?? '',
      metas: p.metas,
      originalUnit: unit,
      originalScale: p.scale,
      origin: key,
    );
  }

  /// Stable identity (reordering, text controllers).
  final int key;
  final String? account;

  /// Signed number as typed; empty = no units (balanced by the server).
  final String amount;

  /// Commodity of [amount].
  final String? commodity;

  /// Cost in the ledger's syntax (`{150 USD}`) or shorthand (`150 USD`);
  /// empty = none.
  final String cost;

  /// Price in the ledger's syntax (`@ 7.2 CNY`, `@@ 72 CNY`) or shorthand
  /// (`7.2 CNY`); empty = none.
  final String price;
  final String comment;

  /// Posting metadata, kept as read (not edited by the app).
  final List<Meta> metas;

  /// The unit this posting was opened with and the decimals it was written
  /// with: an unchanged amount is written back exactly (`88.5` stays
  /// `88.5`).
  final Amount? originalUnit;
  final int? originalScale;

  /// Index of the posting of the edited transaction this row was opened
  /// from; `null` for a row added in the editor.
  final int? origin;

  /// Nothing typed or chosen: the row is ignored.
  bool get isBlank =>
      (account == null || account!.isEmpty) &&
      amount.trim().isEmpty &&
      cost.trim().isEmpty &&
      price.trim().isEmpty &&
      comment.trim().isEmpty &&
      metas.isEmpty;

  /// The amount is left empty: the server infers it.
  bool get isAuto => amount.trim().isEmpty;

  PostingDraft copyWith({
    String? account,
    String? amount,
    String? commodity,
    String? cost,
    String? price,
    String? comment,
  }) => PostingDraft(
    key: key,
    account: account ?? this.account,
    amount: amount ?? this.amount,
    commodity: commodity ?? this.commodity,
    cost: cost ?? this.cost,
    price: price ?? this.price,
    comment: comment ?? this.comment,
    metas: metas,
    originalUnit: originalUnit,
    originalScale: originalScale,
    origin: origin,
  );
}

/// The whole advanced entry: header fields plus N postings.
@immutable
class AdvancedDraft {
  const AdvancedDraft({
    this.datetime,
    this.flag = TransactionFlag.complete,
    this.payee = '',
    this.narration = '',
    this.tags = const [],
    this.links = const [],
    this.metas = const [],
    this.postings = const [],
    this.originalPayee,
    this.originalNarration,
  });

  /// Every field of [request] (an edit, a copy or the simple form's entry).
  /// [keepDate] `false` leaves [datetime] empty ("now" when saving).
  factory AdvancedDraft.fromRequest(CreateTransactionRequest request, {bool keepDate = true}) => AdvancedDraft(
    datetime: keepDate ? request.datetime : null,
    flag: request.flag ?? TransactionFlag.complete,
    payee: request.payee,
    narration: request.narration,
    tags: request.tags,
    links: request.links,
    metas: request.metas,
    postings: [for (final (i, p) in request.postings.indexed) PostingDraft.fromRequest(i, p)],
    originalPayee: request.payee,
    originalNarration: request.narration,
  );

  /// `null` = the ledger's "now" when saving.
  final DateTime? datetime;
  final String flag;
  final String payee;
  final String narration;
  final List<String> tags;
  final List<String> links;
  final List<Meta> metas;
  final List<PostingDraft> postings;

  /// Payee / narration as opened: kept as written (not trimmed) while
  /// unchanged.
  final String? originalPayee;
  final String? originalNarration;

  /// Postings that are not [PostingDraft.isBlank].
  List<PostingDraft> get filled => [
    for (final p in postings)
      if (!p.isBlank) p,
  ];

  AdvancedDraft copyWith({
    DateTime? datetime,
    String? flag,
    String? payee,
    String? narration,
    List<String>? tags,
    List<String>? links,
    List<Meta>? metas,
    List<PostingDraft>? postings,
  }) => AdvancedDraft(
    datetime: datetime ?? this.datetime,
    flag: flag ?? this.flag,
    payee: payee ?? this.payee,
    narration: narration ?? this.narration,
    tags: tags ?? this.tags,
    links: links ?? this.links,
    metas: metas ?? this.metas,
    postings: postings ?? this.postings,
    originalPayee: originalPayee,
    originalNarration: originalNarration,
  );
}

// ---------------------------------------------------------------------------
// Parsing what is typed
// ---------------------------------------------------------------------------

/// Parses a typed amount: optional sign (`-`, `+` or `−` U+2212), digits
/// and one `.` as the decimal point. `,` is only a thousands separator,
/// before groups of exactly three digits (`1,234.50`); anything else with a
/// comma (`12,50`) is not a number – the ledger has no decimal comma, so a
/// guess could write a hundred times the amount. Spaces are ignored. `null`
/// when empty or not a number.
Decimal? parseAmountInput(String text) {
  var t = text.trim().replaceAll('−', '-').replaceAll(RegExp(r'\s'), '');
  if (t.isEmpty) return null;
  if (t.startsWith('+')) t = t.substring(1);
  final number = RegExp(r'^-?(\d{1,3}(,\d{3})+|\d+)?(\.\d*)?$').firstMatch(t);
  if (number == null || (number.group(1) == null && (number.group(3) ?? '.').length < 2)) return null;
  t = t.replaceAll(',', '');
  if (t.endsWith('.')) t = t.substring(0, t.length - 1);
  if (t.startsWith('.') || t.startsWith('-.')) t = t.replaceFirst('.', '0.');
  return Decimal.tryParse(t);
}

/// Decimals typed in [text] (`12.50` → 2).
int typedDecimals(String text) {
  final t = text.trim();
  final dot = t.indexOf('.');
  if (dot < 0) return 0;
  return t.substring(dot + 1).replaceAll(RegExp(r'\D'), '').length;
}

/// Flips the sign of a typed amount (the `±` button: number keyboards
/// often have no minus key). Empty stays empty.
String toggleSign(String text) {
  final t = text.trim().replaceAll('−', '-');
  if (t.isEmpty) return text;
  if (t.startsWith('-')) return t.substring(1).trimLeft();
  if (t.startsWith('+')) return '-${t.substring(1).trimLeft()}';
  return '-$t';
}

/// The cost to send: `null` when empty; ledger syntax as is (`{…}`);
/// shorthand wrapped (`150 USD` → `{150 USD}`).
String? costToSend(String text) {
  final t = text.trim();
  if (t.isEmpty) return null;
  return t.startsWith('{') ? t : '{$t}';
}

/// The price to send: `null` when empty; ledger syntax as is (`@ …`,
/// `@@ …`); shorthand prefixed (`7.2 CNY` → `@ 7.2 CNY`).
String? priceToSend(String text) {
  final t = text.trim();
  if (t.isEmpty) return null;
  return t.startsWith('@') ? t : '@ $t';
}

/// Normalises typed links like `normalizeTag` does tags (strips `^`).
List<String> parseLinks(String text) {
  final out = <String>[];
  for (final raw in text.split(RegExp(r'[\s,]+'))) {
    var t = raw.trim();
    while (t.startsWith('^')) {
      t = t.substring(1);
    }
    t = t.replaceAll(RegExp(r'[":()]+'), '-');
    while (t.startsWith('-') || t.endsWith('-')) {
      t = t.startsWith('-') ? t.substring(1) : t.substring(0, t.length - 1);
    }
    if (t.isNotEmpty && !out.contains(t)) out.add(t);
  }
  return out;
}

/// `<number> <COMMODITY>` (the first component of a cost, a price).
Amount? _amountOf(String text) {
  final m = RegExp(r'^\s*([-+]?[\d,]*\.?\d+)\s+([^\s,{}@]+)\s*$').firstMatch(text);
  if (m == null) return null;
  final number = Decimal.tryParse(m.group(1)!.replaceAll(',', ''));
  return number == null ? null : Amount(number, m.group(2)!);
}

/// What a posting weighs in the balance, in the ledger's rules: its cost
/// when it has one (`{X C}` per unit, `{{T C}}` in total), else its price
/// (`@ X C`, `@@ T C`), else its units. `null` when it cannot be told here
/// (an empty `{}` cost is booked against lots the server knows).
Amount? postingWeight(Decimal units, String commodity, {String? cost, String? price}) {
  Amount? scaled(String body, {required bool total}) {
    final a = _amountOf(body);
    if (a == null) return null;
    if (total) return Amount(units.sign < 0 ? -a.number.abs() : a.number.abs(), a.commodity);
    return Amount(units * a.number, a.commodity);
  }

  if (cost != null) {
    final c = cost.trim();
    if (c.startsWith('{{') && c.endsWith('}}')) {
      return scaled(c.substring(2, c.length - 2).split(',').first, total: true);
    }
    if (c.startsWith('{') && c.endsWith('}')) {
      final inner = c.substring(1, c.length - 1);
      // `{150 # 5 USD}` (per unit + total) is beancount only: leave it to the server.
      if (inner.contains('#')) return null;
      return scaled(inner.split(',').first, total: false);
    }
    return null;
  }
  if (price != null) {
    final p = price.trim();
    if (p.startsWith('@@')) return scaled(p.substring(2), total: true);
    if (p.startsWith('@')) return scaled(p.substring(1), total: false);
    return null;
  }
  return Amount(units, commodity);
}

// ---------------------------------------------------------------------------
// Balance
// ---------------------------------------------------------------------------

/// How the ledger writes a commodity: its decimals and whether ties round
/// towards zero (`RoundDown`, zhang's default) – `null` when unknown.
typedef CommodityRules = ({int precision, bool halfDown})? Function(String commodity);

/// The live balance of the postings (the remainder bar).
@immutable
class PostingBalance {
  const PostingBalance({
    this.remainder = const [],
    this.autoCount = 0,
    this.indeterminate = false,
  });

  /// Non-zero sums of the weights, per commodity, sorted by commodity
  /// (rounded to each commodity's precision when known).
  final List<Amount> remainder;

  /// Postings left without an amount.
  final int autoCount;

  /// A weight could not be computed (e.g. an empty `{}` cost): only the
  /// server's preview can tell.
  final bool indeterminate;

  /// One posting without an amount takes the [remainder] (negated).
  bool get hasAuto => autoCount == 1;

  /// Balanced as typed (no auto posting needed).
  bool get isBalanced => remainder.isEmpty && !indeterminate;

  /// Cannot be saved: unbalanced with no posting to take the remainder.
  bool get isUnbalanced => autoCount == 0 && !indeterminate && remainder.isNotEmpty;

  /// What the auto posting will be given (one amount per commodity).
  List<Amount> get autoAmounts => [for (final a in remainder) -a];

  /// The empty amount would have to take several commodities: the ledger
  /// cannot infer it (`TransactionExplicitPostingHaveMultipleCommodity`).
  bool get autoNeedsOneCommodity => autoCount == 1 && !indeterminate && remainder.length > 1;
}

/// Sums the weights of [postings] (blank rows ignored). [rules] round the
/// remainder like the ledger checks it (unknown commodity = exact).
PostingBalance balanceOf(List<PostingDraft> postings, {CommodityRules? rules}) {
  final sums = <String, Decimal>{};
  var auto = 0;
  var indeterminate = false;
  for (final p in postings) {
    if (p.isBlank) continue;
    if (p.isAuto) {
      auto++;
      continue;
    }
    final units = parseAmountInput(p.amount);
    final commodity = p.commodity;
    if (units == null || commodity == null || commodity.isEmpty) {
      indeterminate = true;
      continue;
    }
    final weight = postingWeight(units, commodity, cost: costToSend(p.cost), price: priceToSend(p.price));
    if (weight == null) {
      indeterminate = true;
      continue;
    }
    sums[weight.commodity] = (sums[weight.commodity] ?? Decimal.zero) + weight.number;
  }
  final codes = sums.keys.toList()..sort();
  final remainder = <Amount>[];
  for (final code in codes) {
    var value = sums[code]!;
    final rule = rules?.call(code);
    if (rule != null) value = roundDecimal(value, rule.precision, halfDown: rule.halfDown);
    if (value != Decimal.zero) remainder.add(Amount(value, code));
  }
  return PostingBalance(remainder: remainder, autoCount: auto, indeterminate: indeterminate);
}

// ---------------------------------------------------------------------------
// Validation and the request
// ---------------------------------------------------------------------------

/// Why an advanced entry cannot be saved yet (the first one is shown).
enum AdvancedIssue {
  /// Fewer than two postings.
  tooFewPostings,

  /// A posting without an account.
  accountMissing,

  /// An amount that is not a number.
  amountInvalid,

  /// An amount without a commodity.
  commodityMissing,

  /// More than one posting left without an amount.
  tooManyAuto,

  /// The posting left without an amount would take several commodities.
  autoMultipleCommodities,

  /// Does not balance and no posting takes the remainder.
  unbalanced,
}

/// All problems of [draft] (blank rows ignored); empty = savable.
List<AdvancedIssue> validateAdvanced(AdvancedDraft draft, {CommodityRules? rules}) {
  final postings = draft.filled;
  final issues = <AdvancedIssue>{};
  if (postings.length < 2) issues.add(AdvancedIssue.tooFewPostings);
  for (final p in postings) {
    if (p.account == null || p.account!.trim().isEmpty) issues.add(AdvancedIssue.accountMissing);
    if (p.isAuto) continue;
    if (parseAmountInput(p.amount) == null) issues.add(AdvancedIssue.amountInvalid);
    if (p.commodity == null || p.commodity!.trim().isEmpty) issues.add(AdvancedIssue.commodityMissing);
  }
  final balance = balanceOf(postings, rules: rules);
  if (balance.autoCount > 1) issues.add(AdvancedIssue.tooManyAuto);
  if (!issues.contains(AdvancedIssue.amountInvalid) && balance.autoNeedsOneCommodity) {
    issues.add(AdvancedIssue.autoMultipleCommodities);
  }
  if (!issues.contains(AdvancedIssue.amountInvalid) && balance.isUnbalanced) issues.add(AdvancedIssue.unbalanced);
  return [
    for (final i in AdvancedIssue.values)
      if (issues.contains(i)) i,
  ];
}

/// The request for a valid [draft] (blank rows dropped, in order).
///
/// * An amount typed exactly as the posting was opened with keeps its
///   written decimals; others get at least the commodity's precision.
/// * [edit]: the posting's cost, price and comment are always sent, `null`
///   included, so clearing one removes it (an update keeps a left-out one).
/// * Posting metadata is sent back as read; payee / narration are trimmed
///   unless unchanged.
CreateTransactionRequest buildAdvancedRequest(
  AdvancedDraft draft, {
  required DateTime now,
  bool edit = false,
  CommodityRules? rules,
}) {
  final issues = validateAdvanced(draft, rules: rules);
  if (issues.isNotEmpty) throw StateError('advanced entry is not valid: $issues');
  String? text(String value) => value.trim().isEmpty ? null : value.trim();
  final postings = <PostingRequest>[];
  for (final p in draft.filled) {
    Amount? unit;
    int? scale;
    if (!p.isAuto) {
      unit = Amount(parseAmountInput(p.amount)!, p.commodity!.trim());
      if (unit == p.originalUnit && p.originalScale != null) {
        scale = p.originalScale;
      } else {
        final precision = rules?.call(unit.commodity)?.precision ?? 0;
        final typed = typedDecimals(p.amount);
        scale = typed > precision ? typed : precision;
      }
    }
    postings.add(
      PostingRequest(
        account: p.account!.trim(),
        unit: unit,
        scale: scale,
        cost: costToSend(p.cost),
        price: priceToSend(p.price),
        // A comment is written after `;` on the posting line: keep it on one line.
        comment: text(p.comment.replaceAll(RegExp(r'[\r\n]+'), ' ')),
        metas: p.metas,
        sendWritten: edit,
      ),
    );
  }
  String kept(String typed, String? original) => typed == original ? typed : typed.trim();
  return CreateTransactionRequest(
    datetime: draft.datetime ?? now,
    payee: kept(draft.payee, draft.originalPayee),
    narration: kept(draft.narration, draft.originalNarration),
    flag: draft.flag,
    postings: postings,
    metas: [
      for (final m in draft.metas)
        if (m.key.trim().isNotEmpty) Meta(m.key.trim(), m.value),
    ],
    tags: draft.tags,
    links: draft.links,
  );
}

/// Per request posting of [buildAdvancedRequest]: the index of the edited
/// posting it was opened from ([PostingDraft.origin]).
List<int?> requestOrigins(AdvancedDraft draft) => [for (final p in draft.filled) p.origin];
