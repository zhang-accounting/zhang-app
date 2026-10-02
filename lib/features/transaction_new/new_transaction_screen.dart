import 'package:decimal/decimal.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../core/category_icons.dart';
import '../../core/theme/app_colors.dart';
import '../../core/utils/dates.dart';
import '../../core/utils/money.dart';
import '../../core/widgets/error_view.dart';
import '../../data/models/account.dart';
import '../../data/models/commodity.dart';
import '../../data/repositories/journal_repository.dart';
import '../../data/repositories/ledger_data_providers.dart';
import '../../l10n/l10n.dart';
import '../../router.dart';
import '../account_picker/account_picker_data.dart';
import '../account_picker/account_picker_sheet.dart';
import 'amount_expression.dart';
import 'category_tree.dart';
import 'entry_form.dart';
import 'entry_mode.dart';
import 'payee_autofill.dart';
import 'record_prefs.dart';
import 'transaction_builder.dart';
import 'transaction_history.dart';
import 'widgets/amount_keypad.dart';
import 'widgets/category_grid.dart';
import 'widgets/suggestion_chips.dart';
import 'widgets/tags_sheet.dart';

/// `/transactions/new` – "记一笔" (docs/design-research.md S03): mode
/// segments, category grid + sub-category chips (or transfer accounts),
/// date / funding / tags chips, payee + narration with completion, and the
/// calculator keypad. Opened full-screen from the shell's centre FAB;
/// `?mode=income|transfer` preselects a mode.
class NewTransactionScreen extends ConsumerStatefulWidget {
  const NewTransactionScreen({super.key, this.initialMode = EntryMode.expense});

  final EntryMode initialMode;

  @override
  ConsumerState<NewTransactionScreen> createState() => _NewTransactionScreenState();
}

/// Everything derived from the form + server data in one build.
class _Resolved {
  const _Resolved({
    required this.draft,
    required this.issues,
    required this.tree,
    required this.openAccounts,
    required this.commodity,
    required this.precision,
    required this.commodities,
    required this.index,
  });

  final EntryDraft draft;
  final List<EntryIssue> issues;
  final CategoryTree? tree;
  final Map<String, Account> openAccounts;
  final String? commodity;
  final int precision;
  final Map<String, Commodity> commodities;
  final SuggestionIndex index;

  bool isOpen(String account) => openAccounts.containsKey(account);

  String label(String account) => accountLabel(account, alias: openAccounts[account]?.alias);

  String format(Decimal value, [String? code]) {
    final c = code ?? commodity;
    if (c == null) return formatDecimal(value, precision: precision);
    return commodities[c]?.format(value) ?? formatMoney(value, c, precision: precision);
  }
}

class _NewTransactionScreenState extends ConsumerState<NewTransactionScreen> {
  late EntryForm _form = EntryForm(mode: widget.initialMode);
  final _payee = TextEditingController();
  final _narration = TextEditingController();
  final _payeeFocus = FocusNode();
  final _narrationFocus = FocusNode();
  bool _submitting = false;
  Object? _error;
  int _savedCount = 0;
  PayeeAutofill? _hint;
  bool _allowPop = false;
  _Resolved? _resolved;

  (List<Account>, AccountType)? _treeKey;
  CategoryTree? _treeCache;

  @override
  void initState() {
    super.initState();
    _payeeFocus.addListener(_onFocusChange);
    _narrationFocus.addListener(_onFocusChange);
  }

  void _onFocusChange() => setState(() {});

  @override
  void dispose() {
    _payee.dispose();
    _narration.dispose();
    _payeeFocus.dispose();
    _narrationFocus.dispose();
    super.dispose();
  }

  CategoryTree? _treeFor(List<Account>? accounts, AccountType? root) {
    if (accounts == null || root == null) return null;
    final key = _treeKey;
    if (key != null && identical(key.$1, accounts) && key.$2 == root) return _treeCache;
    _treeKey = (accounts, root);
    return _treeCache = CategoryTree.fromAccounts(accounts, root);
  }

  _Resolved _resolve() {
    final accounts = ref.watch(pickerAccountsProvider).value;
    final options = ref.watch(ledgerOptionsProvider).value;
    final commodities = ref.watch(commoditiesProvider).value ?? const <String, Commodity>{};
    final index = ref.watch(suggestionIndexProvider);
    final recordPrefs = ref.watch(recordPrefsProvider);
    final open = {
      for (final a in accounts ?? const <Account>[])
        if (a.isOpen) a.name: a,
    };
    bool isOpen(String account) => open.containsKey(account);
    final tree = _treeFor(accounts, _form.mode.categoryRoot);
    final commodity = _form.commodity ?? options?.operatingCurrency;
    final precision = commodities[commodity]?.precision ?? options?.defaultCommodityPrecision ?? 2;
    final mode = _form.mode;
    final funding = resolveFunding(
      _form,
      isOpen: isOpen,
      index: index,
      openAccounts: open.keys.toList(),
      remembered: recordPrefs?.lastFunding,
    );
    final from = mode == EntryMode.transfer ? resolveTransferFrom(_form, isOpen: isOpen, index: index) : null;
    final to = mode == EntryMode.transfer && _form.to != null && isOpen(_form.to!) ? _form.to : null;
    final draft = EntryDraft(
      mode: mode,
      amount: _form.amount.value,
      commodity: commodity,
      datetime: _form.date ?? DateTime.now(),
      precision: precision,
      categoryChosen: _form.category != null,
      categoryAccount: _form.categoryAccount,
      funding: funding,
      from: from,
      to: to,
      payee: _payee.text,
      narration: _narration.text,
      tags: _form.tags,
    );
    return _Resolved(
      draft: draft,
      issues: validateEntry(draft),
      tree: tree,
      openAccounts: open,
      commodity: commodity,
      precision: precision,
      commodities: commodities,
      index: index,
    );
  }

  // ---------------------------------------------------------------- actions

  void _update(EntryForm next) {
    if (identical(next, _form)) return;
    setState(() {
      _form = next;
      _error = null;
    });
  }

  void _key(AmountExpression next) {
    if (identical(next, _form.amount)) {
      HapticFeedback.vibrate();
      return;
    }
    _update(_form.withAmount(next));
  }

  void _onSave() {
    if (_form.amount.hasOperator) {
      _update(_form.withAmount(_form.amount.evaluate()));
      return;
    }
    _submit(again: false);
  }

  void _onSaveAndAnother() {
    if (_form.amount.hasOperator) _update(_form.withAmount(_form.amount.evaluate()));
    _submit(again: true);
  }

  Future<void> _submit({required bool again}) async {
    final r = _resolved;
    if (r == null || _submitting) return;
    final draft = EntryDraft(
      mode: r.draft.mode,
      amount: _form.amount.value,
      commodity: r.draft.commodity,
      datetime: _form.date ?? DateTime.now(),
      precision: r.precision,
      categoryChosen: r.draft.categoryChosen,
      categoryAccount: r.draft.categoryAccount,
      funding: r.draft.funding,
      from: r.draft.from,
      to: r.draft.to,
      payee: _payee.text,
      narration: _narration.text,
      tags: _form.tags,
    );
    if (validateEntry(draft).isNotEmpty) return;
    final request = buildTransactionRequest(draft);
    // Read everything needed after the request now: `ref` must not be used
    // once the screen is gone (e.g. closed while saving).
    final repository = ref.read(journalRepositoryProvider);
    final history = ref.read(transactionHistoryProvider.notifier);
    final recordPrefs = ref.read(recordPrefsProvider);
    final pickerPrefs = ref.read(accountPickerPrefsProvider);
    final category = _form.category;
    FocusScope.of(context).unfocus();
    setState(() {
      _submitting = true;
      _error = null;
    });
    try {
      await repository.create(request);
    } catch (e) {
      if (!mounted) return;
      HapticFeedback.heavyImpact();
      setState(() {
        _submitting = false;
        _error = e;
      });
      return;
    }
    HapticFeedback.mediumImpact();
    history.addLocal(HistoryEntry.fromRequest(request));
    await _rememberAfterSave(draft, category, recordPrefs, pickerPrefs);
    if (!mounted) return;
    final l10n = context.l10n;
    final sign = switch (draft.mode) {
      EntryMode.expense => '−',
      EntryMode.income => '+',
      EntryMode.transfer => '',
    };
    final title = _entryTitle(r, draft);
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(l10n.addSavedSnack('$sign${r.format(draft.amount!)}', title))));
    if (again) {
      setState(() {
        _form = _form.afterSaveAndAnother();
        _payee.clear();
        _narration.clear();
        _hint = null;
        _submitting = false;
        _savedCount++;
      });
      return;
    }
    setState(() {
      _submitting = false;
      _allowPop = true;
    });
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _close();
    });
  }

  String _entryTitle(_Resolved r, EntryDraft draft) {
    final payee = draft.payee.trim();
    if (payee.isNotEmpty) return payee;
    if (draft.mode == EntryMode.transfer) return '${r.label(draft.from!)} → ${r.label(draft.to!)}';
    final category = r.tree?.byName(_form.category ?? '');
    final sub = category?.children.where((c) => c.name == draft.categoryAccount).firstOrNull;
    return sub?.label ?? category?.label ?? draft.categoryAccount ?? '';
  }

  static Future<void> _rememberAfterSave(
    EntryDraft draft,
    String? category,
    RecordPrefs? recordPrefs,
    AccountPickerPrefs? picker,
  ) async {
    try {
      if (draft.mode == EntryMode.transfer) {
        await picker?.pushRecent(draft.to!);
        await picker?.pushRecent(draft.from!);
        return;
      }
      await recordPrefs?.rememberFunding({?category, draft.categoryAccount!}, draft.funding!);
      await picker?.pushRecent(draft.funding!);
    } catch (_) {
      // Local memory is best effort; the transaction is already saved.
    }
  }

  void _close() {
    final navigator = Navigator.of(context);
    if (navigator.canPop()) {
      navigator.pop();
    } else {
      GoRouter.maybeOf(context)?.go(AppRoutes.home);
    }
  }

  bool get _hasInput =>
      _form.hasInput || _payee.text.trim().isNotEmpty || _narration.text.trim().isNotEmpty;

  Future<void> _confirmDiscard() async {
    final l10n = context.l10n;
    final discard = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(l10n.addDiscardTitle),
        content: Text(l10n.addDiscardMessage),
        actions: [
          TextButton(onPressed: () => Navigator.of(context).pop(false), child: Text(l10n.addKeepEditing)),
          FilledButton(
            key: const Key('add.discard'),
            onPressed: () => Navigator.of(context).pop(true),
            child: Text(l10n.addDiscard),
          ),
        ],
      ),
    );
    if (discard != true || !mounted) return;
    setState(() => _allowPop = true);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _close();
    });
  }

  void _applyPayee(String payee, _Resolved r) {
    _payee.value = TextEditingValue(text: payee, selection: TextSelection.collapsed(offset: payee.length));
    FocusScope.of(context).unfocus();
    final entry = r.index.lastForPayee(payee);
    if (entry == null) {
      setState(() => _hint = null);
      return;
    }
    final fill = autofillFromEntry(entry, _form.mode);
    if (_narration.text.trim().isEmpty && fill.narration != null) _narration.text = fill.narration!;
    setState(() {
      _form = _form.withAutofill(fill, tree: r.tree, isOpen: r.isOpen);
      _hint = fill.amount == null ? null : fill;
      _error = null;
    });
  }

  Future<void> _pickFunding(_Resolved r) async {
    final l10n = context.l10n;
    final types = _form.mode.fundingTypes;
    final picked = await showAccountPicker(
      context,
      types: types,
      title: _form.mode == EntryMode.income ? l10n.addFundingIncome : l10n.addFundingExpense,
      selected: r.draft.funding,
      suggested: r.index.rankedAccounts(types),
    );
    if (picked != null && mounted) _update(_form.withFunding(picked));
  }

  Future<void> _pickTransfer(_Resolved r, {required bool from}) async {
    final l10n = context.l10n;
    final types = EntryMode.transfer.fundingTypes;
    final picked = await showAccountPicker(
      context,
      types: types,
      title: from ? l10n.addFrom : l10n.addTo,
      selected: from ? r.draft.from : r.draft.to,
      suggested: r.index.rankedAccounts(types),
    );
    if (picked == null || !mounted) return;
    _update(from ? _form.withFrom(picked) : _form.withTo(picked));
  }

  Future<void> _pickDate() async {
    final now = DateTime.now();
    final current = _form.date ?? now;
    final day = await showDatePicker(
      context: context,
      initialDate: current,
      firstDate: DateTime(1970),
      lastDate: DateTime(now.year + 5, 12, 31),
    );
    if (day == null || !mounted) return;
    final fallback = _form.date != null
        ? TimeOfDay.fromDateTime(_form.date!)
        : ZhangDates.isSameDay(day, now)
        ? TimeOfDay.fromDateTime(now)
        // Not today: noon avoids landing on another day in the ledger timezone.
        : const TimeOfDay(hour: 12, minute: 0);
    final time = await showTimePicker(context: context, initialTime: fallback);
    if (!mounted) return;
    final t = time ?? fallback;
    _update(_form.withDate(DateTime(day.year, day.month, day.day, t.hour, t.minute)));
  }

  Future<void> _pickTags(_Resolved r) async {
    final tags = await showTagsSheet(context, selected: _form.tags, known: r.index.tags);
    if (tags != null && mounted) _update(_form.withTags(tags));
  }

  // ------------------------------------------------------------------ build

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final r = _resolved = _resolve();
    final keyboardVisible = MediaQuery.viewInsetsOf(context).bottom > 0;
    return PopScope(
      canPop: _allowPop || !_hasInput,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) _confirmDiscard();
      },
      child: Scaffold(
        appBar: AppBar(
          leading: IconButton(
            key: const Key('add.close'),
            tooltip: l10n.addClose,
            icon: const Icon(Icons.close),
            onPressed: () => Navigator.of(context).maybePop(),
          ),
          title: Text(l10n.newTransactionTitle),
          actions: [
            if (_savedCount > 0)
              Padding(
                padding: const EdgeInsets.only(right: 12),
                child: Chip(
                  key: const Key('add.savedCount'),
                  visualDensity: VisualDensity.compact,
                  avatar: const Icon(Icons.check, size: 16),
                  label: Text(l10n.addSavedCount(_savedCount)),
                ),
              ),
          ],
          bottom: PreferredSize(
            preferredSize: const Size.fromHeight(52),
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
              child: SizedBox(
                width: double.infinity,
                child: SegmentedButton<EntryMode>(
                  showSelectedIcon: false,
                  segments: [
                    ButtonSegment(
                      value: EntryMode.expense,
                      label: Text(l10n.addModeExpense, key: const Key('add.mode.expense')),
                    ),
                    ButtonSegment(
                      value: EntryMode.income,
                      label: Text(l10n.addModeIncome, key: const Key('add.mode.income')),
                    ),
                    ButtonSegment(
                      value: EntryMode.transfer,
                      label: Text(l10n.addModeTransfer, key: const Key('add.mode.transfer')),
                    ),
                  ],
                  selected: {_form.mode},
                  onSelectionChanged: _submitting
                      ? null
                      : (s) => setState(() {
                          _form = _form.withMode(s.single);
                          _hint = null;
                          _error = null;
                        }),
                ),
              ),
            ),
          ),
        ),
        body: AbsorbPointer(
          absorbing: _submitting,
          child: Column(
            children: [
              Expanded(
                child: ListView(
                  keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
                  padding: const EdgeInsets.only(top: 8, bottom: 16),
                  children: [
                    if (_form.mode == EntryMode.transfer) _transferSection(r) else _categorySection(r),
                    const SizedBox(height: 12),
                    ..._textFields(r),
                  ],
                ),
              ),
              if (!keyboardVisible) _bottomPanel(r),
            ],
          ),
        ),
      ),
    );
  }

  Widget _categorySection(_Resolved r) {
    final l10n = context.l10n;
    final accounts = ref.watch(pickerAccountsProvider);
    final tree = r.tree;
    if (tree == null) {
      if (accounts.hasError && !accounts.isLoading) {
        return SizedBox(
          height: 220,
          child: ErrorView(error: accounts.error!, onRetry: () => ref.invalidate(pickerAccountsProvider)),
        );
      }
      return const SizedBox(height: 172, child: Center(child: CircularProgressIndicator()));
    }
    if (tree.isEmpty) {
      return Padding(
        padding: const EdgeInsets.all(24),
        child: Text(l10n.addNoCategories(tree.root.wire), textAlign: TextAlign.center),
      );
    }
    return CategoryGrid(
      tree: tree,
      selected: _form.category,
      selectedSub: _form.subcategory,
      onSelect: (node) {
        FocusScope.of(context).unfocus();
        HapticFeedback.selectionClick();
        _update(_form.withCategory(node));
      },
      onSelectSub: (name) {
        HapticFeedback.selectionClick();
        _update(_form.withSubcategory(name));
      },
    );
  }

  Widget _transferSection(_Resolved r) {
    final l10n = context.l10n;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Column(
        children: [
          _TransferAccountCard(
            key: const Key('add.from'),
            caption: l10n.addFrom,
            account: r.draft.from,
            resolved: r,
            onTap: () => _pickTransfer(r, from: true),
          ),
          IconButton.filledTonal(
            key: const Key('add.swap'),
            tooltip: l10n.addSwap,
            icon: const Icon(Icons.swap_vert),
            onPressed: () => _update(_form.swapTransfer(from: r.draft.from, to: r.draft.to)),
          ),
          _TransferAccountCard(
            key: const Key('add.to'),
            caption: l10n.addTo,
            account: r.draft.to,
            resolved: r,
            onTap: () => _pickTransfer(r, from: false),
          ),
        ],
      ),
    );
  }

  List<Widget> _textFields(_Resolved r) {
    final l10n = context.l10n;
    final payeeSuggestions = filterSuggestions(r.index.payees, _payee.text);
    final showPayee = _payeeFocus.hasFocus || _payee.text.trim().isEmpty;
    final narrationSuggestions = filterSuggestions(r.index.narrationsFor(_payee.text), _narration.text);
    InputDecoration decoration(String label, IconData icon) => InputDecoration(
      isDense: true,
      filled: true,
      labelText: label,
      prefixIcon: Icon(icon),
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
    );
    return [
      Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16),
        child: TextField(
          key: const Key('add.payee'),
          controller: _payee,
          focusNode: _payeeFocus,
          textInputAction: TextInputAction.next,
          onChanged: (_) => setState(() => _error = null),
          onSubmitted: (_) => _narrationFocus.requestFocus(),
          decoration: decoration(l10n.addPayee, Icons.storefront_outlined),
        ),
      ),
      if (showPayee && payeeSuggestions.isNotEmpty)
        Padding(
          padding: const EdgeInsets.only(top: 4),
          child: SuggestionChipsRow(
            items: payeeSuggestions,
            keyPrefix: 'add.payeeSuggestion.',
            icon: Icons.history,
            onSelected: (p) => _applyPayee(p, r),
          ),
        ),
      const SizedBox(height: 8),
      Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16),
        child: TextField(
          key: const Key('add.narration'),
          controller: _narration,
          focusNode: _narrationFocus,
          textInputAction: TextInputAction.done,
          onChanged: (_) => setState(() {}),
          decoration: decoration(l10n.addNarration, Icons.notes),
        ),
      ),
      if (_narrationFocus.hasFocus && narrationSuggestions.isNotEmpty)
        Padding(
          padding: const EdgeInsets.only(top: 4),
          child: SuggestionChipsRow(
            items: narrationSuggestions,
            keyPrefix: 'add.narrationSuggestion.',
            onSelected: (n) {
              _narration.value = TextEditingValue(text: n, selection: TextSelection.collapsed(offset: n.length));
              FocusScope.of(context).unfocus();
            },
          ),
        ),
    ];
  }

  String _dateLabel() {
    final l10n = context.l10n;
    final date = _form.date;
    if (date == null) return l10n.addToday;
    final locale = Localizations.localeOf(context).toString();
    final now = DateTime.now();
    final time = ZhangDates.formatTime(date, locale);
    if (ZhangDates.isSameDay(date, now)) return '${l10n.addToday} $time';
    final day = date.year == now.year ? DateFormat.MMMd(locale).format(date) : ZhangDates.formatDate(date, locale);
    return '$day $time';
  }

  String _issueText(EntryIssue issue) {
    final l10n = context.l10n;
    return switch (issue) {
      EntryIssue.categoryMissing => l10n.addHintCategory,
      EntryIssue.subcategoryMissing => l10n.addHintSubcategory,
      EntryIssue.fundingMissing => l10n.addHintFunding,
      EntryIssue.fromMissing => l10n.addHintFrom,
      EntryIssue.toMissing => l10n.addHintTo,
      EntryIssue.sameAccount => l10n.addHintSameAccount,
      EntryIssue.amountMissing => l10n.addHintAmount,
      EntryIssue.amountNotPositive => l10n.addHintAmountPositive,
      EntryIssue.commodityMissing => l10n.addHintCommodity,
    };
  }

  Widget _bottomPanel(_Resolved r) {
    final l10n = context.l10n;
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final notToday = _form.date != null && !ZhangDates.isSameDay(_form.date!, DateTime.now());
    final funding = r.draft.funding;
    final valid = r.issues.isEmpty;
    return Material(
      color: scheme.surfaceContainerLow,
      child: SafeArea(
        top: false,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (_error != null) _ErrorBanner(error: _error!, onClose: () => setState(() => _error = null)),
            SizedBox(
              height: 48,
              child: ListView(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.fromLTRB(12, 8, 12, 0),
                children: [
                  ActionChip(
                    key: const Key('add.date'),
                    avatar: const Icon(Icons.event, size: 18),
                    label: Text(_dateLabel()),
                    tooltip: l10n.addDate,
                    backgroundColor: notToday ? scheme.tertiaryContainer : null,
                    onPressed: _pickDate,
                  ),
                  const SizedBox(width: 8),
                  if (_form.mode != EntryMode.transfer) ...[
                    ActionChip(
                      key: const Key('add.funding'),
                      avatar: Icon(funding == null ? Icons.account_balance_wallet_outlined : categoryIcon(funding), size: 18),
                      label: Text(
                        '${_form.mode == EntryMode.income ? l10n.addFundingIncome : l10n.addFundingExpense}: '
                        '${funding == null ? l10n.addChooseAccount : r.label(funding)}',
                      ),
                      tooltip: funding,
                      onPressed: () => _pickFunding(r),
                    ),
                    const SizedBox(width: 8),
                  ],
                  ActionChip(
                    key: const Key('add.tags'),
                    avatar: const Icon(Icons.tag, size: 18),
                    label: Text(_form.tags.isEmpty ? l10n.addTags : _form.tags.map((t) => '#$t').join(' ')),
                    onPressed: () => _pickTags(r),
                  ),
                ],
              ),
            ),
            _amountRow(r),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: SizedBox(
                height: 18,
                child: Align(
                  alignment: Alignment.centerRight,
                  child: valid
                      ? null
                      : Text(
                          _issueText(r.issues.first),
                          key: const Key('add.hint'),
                          style: theme.textTheme.bodySmall?.copyWith(color: scheme.onSurfaceVariant),
                        ),
                ),
              ),
            ),
            AmountKeypad(
              showEquals: _form.amount.hasOperator,
              submitting: _submitting,
              onDigit: (d) => _key(_form.amount.inputDigit(d, precision: r.precision)),
              onDot: () => _key(_form.amount.inputDot(precision: r.precision)),
              onOperator: (op) => _key(_form.amount.inputOperator(op)),
              onBackspace: () => _key(_form.amount.backspace()),
              onClear: () => _update(_form.withAmount(AmountExpression.empty)),
              onSave: _form.amount.hasOperator || valid ? _onSave : null,
              onSaveAndAnother: valid ? _onSaveAndAnother : null,
            ),
          ],
        ),
      ),
    );
  }

  Widget _amountRow(_Resolved r) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final colors = context.zhangColors;
    final expr = _form.amount;
    final color = switch (_form.mode) {
      EntryMode.expense => colors.expense,
      EntryMode.income => colors.income,
      EntryMode.transfer => scheme.onSurface,
    };
    final commodity = r.commodity;
    final c = commodity == null ? null : r.commodities[commodity];
    final String amountText;
    if (expr.isEmpty) {
      amountText = _typed('0', c, commodity);
    } else if (expr.hasOperator) {
      amountText = r.format(expr.value!);
    } else {
      amountText = _typed(expr.tokens.single, c, commodity);
    }
    final codes = r.commodities.keys.toList()
      ..sort((a, b) => a == commodity ? -1 : (b == commodity ? 1 : a.compareTo(b)));
    final hint = _hint;
    return Padding(
      padding: const EdgeInsets.fromLTRB(8, 4, 16, 0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          if (codes.length > 1)
            PopupMenuButton<String>(
              key: const Key('add.commodity'),
              tooltip: context.l10n.addCommodity,
              initialValue: commodity,
              onSelected: (code) => _update(_form.withCommodity(code)),
              itemBuilder: (context) => [
                for (final code in codes) PopupMenuItem(key: Key('add.commodity.$code'), value: code, child: Text(code)),
              ],
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [Text(commodity ?? '…', style: theme.textTheme.titleSmall), const Icon(Icons.arrow_drop_down)],
                ),
              ),
            )
          else
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
              child: Text(commodity ?? '…', style: theme.textTheme.titleSmall),
            ),
          if (hint != null && expr.isEmpty && hint.amount != null)
            ActionChip(
              key: const Key('add.lastAmount'),
              visualDensity: VisualDensity.compact,
              label: Text(context.l10n.addLastAmount(r.format(hint.amount!, hint.commodity))),
              onPressed: () {
                var next = _form.withAmount(AmountExpression.number(hint.amount!));
                final code = hint.commodity;
                if (code != null && code != commodity && r.commodities.containsKey(code)) next = next.withCommodity(code);
                _update(next);
              },
            ),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              mainAxisSize: MainAxisSize.min,
              children: [
                SizedBox(
                  height: 18,
                  child: Text(
                    expr.hasOperator ? expr.display : '',
                    key: const Key('add.expression'),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: scheme.onSurfaceVariant,
                      fontFeatures: const [FontFeature.tabularFigures()],
                    ),
                  ),
                ),
                Semantics(
                  liveRegion: true,
                  child: FittedBox(
                    fit: BoxFit.scaleDown,
                    alignment: Alignment.centerRight,
                    child: Text(
                      amountText,
                      key: const Key('add.amount'),
                      maxLines: 1,
                      style: theme.textTheme.headlineLarge?.copyWith(
                        color: expr.isEmpty ? scheme.outline : color,
                        fontWeight: FontWeight.w600,
                        fontFeatures: const [FontFeature.tabularFigures()],
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  /// The number being typed, grouped but not padded (`12.` stays `12.`).
  static String _typed(String token, Commodity? c, String? code) {
    final negative = token.startsWith('-');
    final unsigned = negative ? token.substring(1) : token;
    final dot = unsigned.indexOf('.');
    final intPart = dot < 0 ? unsigned : unsigned.substring(0, dot);
    final frac = dot < 0 ? '' : unsigned.substring(dot);
    final grouped = formatDecimal(Decimal.parse(intPart.isEmpty ? '0' : intPart), precision: 0);
    final number = '$grouped$frac';
    final sign = negative ? '−' : '';
    final prefix = c?.prefix;
    if (prefix != null && prefix.isNotEmpty) return '$sign$prefix$number';
    final suffix = c?.suffix;
    if (suffix != null && suffix.isNotEmpty) return '$sign$number$suffix';
    return code == null ? '$sign$number' : '$sign$number $code';
  }
}

class _TransferAccountCard extends StatelessWidget {
  const _TransferAccountCard({
    super.key,
    required this.caption,
    required this.account,
    required this.resolved,
    required this.onTap,
  });

  final String caption;
  final String? account;
  final _Resolved resolved;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final a = account;
    final balance = a == null ? null : resolved.openAccounts[a]?.amount.calculated;
    return Card(
      margin: EdgeInsets.zero,
      child: ListTile(
        onTap: onTap,
        leading: Icon(a == null ? Icons.account_balance_wallet_outlined : categoryIcon(a), color: scheme.primary),
        title: Text(caption, style: theme.textTheme.labelMedium?.copyWith(color: scheme.onSurfaceVariant)),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              a == null ? context.l10n.addChooseAccount : resolved.label(a),
              style: theme.textTheme.titleMedium?.copyWith(color: a == null ? scheme.outline : null),
            ),
            if (a != null) Text(a, style: theme.textTheme.bodySmall?.copyWith(color: scheme.onSurfaceVariant)),
          ],
        ),
        trailing: balance == null
            ? const Icon(Icons.chevron_right)
            : Text(
                resolved.format(balance.number, balance.commodity),
                style: theme.textTheme.bodyMedium?.copyWith(fontFeatures: const [FontFeature.tabularFigures()]),
              ),
      ),
    );
  }
}

class _ErrorBanner extends StatelessWidget {
  const _ErrorBanner({required this.error, required this.onClose});

  final Object error;
  final VoidCallback onClose;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final scheme = Theme.of(context).colorScheme;
    return Container(
      key: const Key('add.error'),
      width: double.infinity,
      color: scheme.errorContainer,
      padding: const EdgeInsets.fromLTRB(16, 8, 4, 8),
      child: Row(
        children: [
          Icon(iconForApiError(error), color: scheme.onErrorContainer),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              '${l10n.addSaveFailed}: ${describeApiError(l10n, error)}',
              style: TextStyle(color: scheme.onErrorContainer),
            ),
          ),
          IconButton(
            tooltip: l10n.addClose,
            icon: Icon(Icons.close, color: scheme.onErrorContainer),
            onPressed: onClose,
          ),
        ],
      ),
    );
  }
}

