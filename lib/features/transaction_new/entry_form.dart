import 'package:flutter/foundation.dart';

import '../../data/models/account.dart';
import 'amount_expression.dart';
import 'category_tree.dart';
import 'entry_mode.dart';
import 'payee_autofill.dart';
import 'transaction_history.dart';

const _unset = Object();

/// State of the "记一笔" form (everything except the payee / narration text,
/// which live in text controllers). Immutable; every transition returns a
/// new value so the rules are unit-testable.
@immutable
class EntryForm {
  const EntryForm({
    this.mode = EntryMode.expense,
    this.amount = AmountExpression.empty,
    this.commodity,
    this.category,
    this.categoryRequiresSub = false,
    this.subcategory,
    this.funding,
    this.fundingExplicit = false,
    this.from,
    this.to,
    this.date,
    this.tags = const [],
  });

  final EntryMode mode;
  final AmountExpression amount;

  /// Explicitly chosen commodity; `null` = the ledger's operating currency.
  final String? commodity;

  /// Selected category tile (second-level account). Never pre-selected
  /// (decisions.md §3).
  final String? category;
  final bool categoryRequiresSub;
  final String? subcategory;

  /// Funding account picked by the user ([fundingExplicit]) or filled from a
  /// payee's last transaction; `null` = use the suggested default.
  final String? funding;
  final bool fundingExplicit;

  /// Transfer accounts (`null` = suggested default / not chosen).
  final String? from;
  final String? to;

  /// Chosen date-time; `null` = "now" at save time.
  final DateTime? date;
  final List<String> tags;

  /// The category posting account: the sub-category, else the tile itself
  /// unless it requires a sub-category.
  String? get categoryAccount => subcategory ?? (categoryRequiresSub ? null : category);

  EntryForm _copy({
    EntryMode? mode,
    AmountExpression? amount,
    Object? commodity = _unset,
    Object? category = _unset,
    bool? categoryRequiresSub,
    Object? subcategory = _unset,
    Object? funding = _unset,
    bool? fundingExplicit,
    Object? from = _unset,
    Object? to = _unset,
    Object? date = _unset,
    List<String>? tags,
  }) => EntryForm(
    mode: mode ?? this.mode,
    amount: amount ?? this.amount,
    commodity: identical(commodity, _unset) ? this.commodity : commodity as String?,
    category: identical(category, _unset) ? this.category : category as String?,
    categoryRequiresSub: categoryRequiresSub ?? this.categoryRequiresSub,
    subcategory: identical(subcategory, _unset) ? this.subcategory : subcategory as String?,
    funding: identical(funding, _unset) ? this.funding : funding as String?,
    fundingExplicit: fundingExplicit ?? this.fundingExplicit,
    from: identical(from, _unset) ? this.from : from as String?,
    to: identical(to, _unset) ? this.to : to as String?,
    date: identical(date, _unset) ? this.date : date as DateTime?,
    tags: tags ?? this.tags,
  );

  /// Switching mode clears the category (other root); an explicitly chosen
  /// funding account survives when the new mode allows its type.
  EntryForm withMode(EntryMode next) {
    if (next == mode) return this;
    final keepFunding = funding != null && fundingExplicit && next.allowsFunding(funding!);
    return _copy(
      mode: next,
      category: null,
      categoryRequiresSub: false,
      subcategory: null,
      funding: keepFunding ? funding : null,
      fundingExplicit: keepFunding,
    );
  }

  EntryForm withAmount(AmountExpression value) => _copy(amount: value);

  EntryForm withCommodity(String value) => _copy(commodity: value);

  /// Selects a tile. When the tile is not an account itself and has exactly
  /// one sub-category, that one is selected too.
  EntryForm withCategory(CategoryNode node) {
    if (node.name == category) return this;
    final onlyChild = node.requiresSubcategory && node.children.length == 1 ? node.children.single.name : null;
    return _copy(category: node.name, categoryRequiresSub: node.requiresSubcategory, subcategory: onlyChild);
  }

  /// Selects / toggles a sub-category chip (cannot be cleared when required).
  EntryForm withSubcategory(String name) {
    if (name == subcategory) return categoryRequiresSub ? this : _copy(subcategory: null);
    return _copy(subcategory: name);
  }

  /// The user picked the funding account.
  EntryForm withFunding(String account) => _copy(funding: account, fundingExplicit: true);

  EntryForm withFrom(String account) => _copy(from: account);

  EntryForm withTo(String account) => _copy(to: account);

  /// Swaps the (resolved) transfer accounts.
  EntryForm swapTransfer({required String? from, required String? to}) => _copy(from: to, to: from);

  EntryForm withDate(DateTime value) => _copy(date: value);

  EntryForm withTags(List<String> value) => _copy(tags: List.unmodifiable(value));

  /// Applies a payee's last transaction, but only to fields the user has not
  /// chosen yet (category, funding, transfer accounts). [isOpen] filters out
  /// accounts that were closed since.
  EntryForm withAutofill(PayeeAutofill fill, {CategoryTree? tree, required bool Function(String account) isOpen}) {
    var next = this;
    final fillCategory = fill.category;
    if (category == null && fillCategory != null && tree != null) {
      final location = tree.locate(fillCategory);
      if (location != null) {
        next = next._copy(
          category: location.category.name,
          categoryRequiresSub: location.category.requiresSubcategory,
          subcategory: location.subcategory?.name,
        );
      }
    }
    bool usable(String? account) => account != null && mode.allowsFunding(account) && isOpen(account);
    if (!fundingExplicit && usable(fill.funding) && mode != EntryMode.transfer) {
      next = next._copy(funding: fill.funding, fundingExplicit: false);
    }
    if (mode == EntryMode.transfer) {
      if (from == null && usable(fill.from)) next = next._copy(from: fill.from);
      if (to == null && usable(fill.to) && fill.to != (next.from ?? fill.from)) next = next._copy(to: fill.to);
    }
    return next;
  }

  /// "再记": keep mode, date, commodity and accounts; clear the amount,
  /// category and tags (payee / narration are cleared by the screen).
  EntryForm afterSaveAndAnother() =>
      _copy(amount: AmountExpression.empty, category: null, categoryRequiresSub: false, subcategory: null, tags: const []);

  /// Whether the user typed or chose anything worth a discard confirmation.
  bool get hasInput => !amount.isEmpty || category != null || tags.isNotEmpty;
}

/// Resolves the funding account shown / used for [form]:
/// explicit or autofilled choice → per-category memory → the category's last
/// funding account in the history → the most recently used asset account →
/// the first open asset account. Only open accounts allowed by the mode
/// qualify.
String? resolveFunding(
  EntryForm form, {
  required bool Function(String account) isOpen,
  required SuggestionIndex index,
  required List<String> openAccounts,
  String? Function(String category)? remembered,
}) {
  bool ok(String? a) => a != null && form.mode.allowsFunding(a) && isOpen(a);
  if (form.mode == EntryMode.transfer) return null;
  if (ok(form.funding)) return form.funding;
  final leaf = form.categoryAccount;
  final category = form.category;
  if (remembered != null) {
    if (leaf != null && ok(remembered(leaf))) return remembered(leaf);
    if (category != null && ok(remembered(category))) return remembered(category);
  }
  if (category != null) {
    final fromHistory = index.lastFundingFor(leaf ?? category, form.mode.fundingTypes, where: ok);
    if (fromHistory != null) return fromHistory;
  }
  final recent = index.mostRecentAccount(const {AccountType.assets}, where: ok);
  if (recent != null) return recent;
  for (final a in openAccounts) {
    if (AccountType.ofAccount(a) == AccountType.assets && ok(a)) return a;
  }
  for (final a in openAccounts) {
    if (ok(a)) return a;
  }
  return null;
}

/// Resolved transfer source: the chosen one, else the most recently used
/// asset account (unless it is the destination).
String? resolveTransferFrom(EntryForm form, {required bool Function(String account) isOpen, required SuggestionIndex index}) {
  if (form.from != null) return isOpen(form.from!) ? form.from : null;
  return index.mostRecentAccount(
    const {AccountType.assets},
    where: (a) => isOpen(a) && a != form.to,
  );
}
