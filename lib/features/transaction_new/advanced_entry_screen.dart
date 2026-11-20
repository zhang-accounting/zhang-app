import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../core/category_icons.dart';
import '../../core/utils/dates.dart';
import '../../data/models/account.dart';
import '../../data/models/amount.dart';
import '../../data/models/commodity.dart';
import '../../data/models/transaction_preview.dart';
import '../../data/models/transaction_request.dart';
import '../../data/repositories/journal_repository.dart';
import '../../data/repositories/ledger_data_providers.dart';
import '../../data/repositories/ledger_revision.dart';
import '../../l10n/l10n.dart';
import '../../router.dart';
import '../account_picker/account_picker_sheet.dart';
import '../journals/widgets/amount_format.dart';
import 'advanced_draft.dart';
import 'transaction_edit.dart';
import 'transaction_history.dart';
import 'widgets/save_error_banner.dart';
import 'widgets/tags_sheet.dart';

/// Opens the advanced editor (on the router when there is one) and returns
/// what it saved, `null` when left without saving.
Future<EntrySaved?> pushAdvancedEntry(BuildContext context, AdvancedEntryArgs args) {
  final router = GoRouter.maybeOf(context);
  if (router != null) return router.push<EntrySaved>(AppRoutes.advancedTransaction, extra: args);
  return Navigator.of(context).push<EntrySaved>(
    MaterialPageRoute(builder: (_) => AdvancedEntryScreen(args: args)),
  );
}

/// `/transactions/advanced` – the multi-posting editor (S06): date, flag,
/// payee, narration, tags, links, N postings (account, signed amount and
/// commodity – one may be left empty for the server to balance – cost,
/// price, comment), metadata, and a live remainder per commodity. Saves
/// like the simple form: preview first (blocking problems vs warnings with
/// "Save anyway"), then `POST`, or `PUT` for an edit ([AdvancedEntryArgs]).
/// Posting metadata is kept as read. Pops with [EntrySaved].
class AdvancedEntryScreen extends ConsumerStatefulWidget {
  const AdvancedEntryScreen({super.key, this.args});

  final AdvancedEntryArgs? args;

  @override
  ConsumerState<AdvancedEntryScreen> createState() => _AdvancedEntryScreenState();
}

/// Editable state of one posting row.
class _PostingRow {
  _PostingRow(PostingDraft d)
    : key = d.key,
      account = d.account,
      commodity = d.commodity,
      amount = TextEditingController(text: d.amount),
      cost = TextEditingController(text: d.cost),
      price = TextEditingController(text: d.price),
      comment = TextEditingController(text: d.comment),
      metas = d.metas,
      originalUnit = d.originalUnit,
      originalScale = d.originalScale,
      expanded = d.cost.isNotEmpty || d.price.isNotEmpty || d.comment.isNotEmpty;

  final int key;
  String? account;
  String? commodity;
  final TextEditingController amount;
  final TextEditingController cost;
  final TextEditingController price;
  final TextEditingController comment;
  final List<Meta> metas;
  final Amount? originalUnit;
  final int? originalScale;

  /// Cost / price / comment fields shown.
  bool expanded;

  PostingDraft draft(String? fallbackCommodity) => PostingDraft(
    key: key,
    account: account,
    amount: amount.text,
    commodity: commodity ?? fallbackCommodity,
    cost: cost.text,
    price: price.text,
    comment: comment.text,
    metas: metas,
    originalUnit: originalUnit,
    originalScale: originalScale,
  );

  void dispose() {
    amount.dispose();
    cost.dispose();
    price.dispose();
    comment.dispose();
  }
}

class _MetaRow {
  _MetaRow(this.id, Meta meta) : key = TextEditingController(text: meta.key), value = TextEditingController(text: meta.value);

  final int id;
  final TextEditingController key;
  final TextEditingController value;

  void dispose() {
    key.dispose();
    value.dispose();
  }
}

enum _PostingAction { moveUp, moveDown, remove }

class _AdvancedEntryScreenState extends ConsumerState<AdvancedEntryScreen> {
  late final AdvancedDraft _initial = widget.args?.draft ?? const AdvancedDraft();
  late DateTime? _datetime = _initial.datetime;
  late String _flag = _initial.flag;
  late final _payee = TextEditingController(text: _initial.payee);
  late final _narration = TextEditingController(text: _initial.narration);
  late List<String> _tags = _initial.tags;
  late final String _initialLinks = _initial.links.map((l) => '^$l').join(' ');
  late final _links = TextEditingController(text: _initialLinks);
  late final List<_PostingRow> _postings = [
    for (final p in _initial.postings) _PostingRow(p),
    for (var i = _initial.postings.length; i < 2; i++) _PostingRow(PostingDraft(key: 1000 + i)),
  ];
  late final List<_MetaRow> _metas = [for (final (i, m) in _initial.metas.indexed) _MetaRow(i, m)];
  late int _nextKey = 2000;

  bool _submitting = false;
  Object? _error;
  bool _touched = false;
  bool _allowPop = false;

  bool get _editing => widget.args?.isEdit ?? false;

  @override
  void dispose() {
    _payee.dispose();
    _narration.dispose();
    _links.dispose();
    for (final p in _postings) {
      p.dispose();
    }
    for (final m in _metas) {
      m.dispose();
    }
    super.dispose();
  }

  // ------------------------------------------------------------------ state

  /// "Now" by the ledger's clock.
  DateTime _now() => ref.read(ledgerClockProvider)();

  /// Commodity for an amount typed without one: the last one used in the
  /// postings, else the operating currency.
  String? _defaultCommodity() {
    for (final p in _postings.reversed) {
      if (p.commodity != null && p.amount.text.trim().isNotEmpty) return p.commodity;
    }
    final options = ref.read(ledgerOptionsProvider);
    return options.hasError ? null : options.value?.operatingCurrency;
  }

  int? _precisionOf(String commodity) => ref.read(commoditiesProvider).value?[commodity]?.precision;

  AdvancedDraft _snapshot() {
    final fallback = _defaultCommodity();
    return AdvancedDraft(
      datetime: _datetime,
      flag: _flag,
      payee: _payee.text,
      narration: _narration.text,
      tags: _tags,
      links: _links.text == _initialLinks ? _initial.links : parseLinks(_links.text),
      metas: [for (final m in _metas) Meta(m.key.text, m.value.text)],
      postings: [for (final p in _postings) p.draft(fallback)],
    );
  }

  void _changed([VoidCallback? change]) {
    setState(() {
      change?.call();
      _touched = true;
      _error = null;
    });
  }

  void _addPosting() => _changed(() => _postings.add(_PostingRow(PostingDraft(key: _nextKey++))));

  void _postingAction(int index, _PostingAction action) {
    _changed(() {
      switch (action) {
        case _PostingAction.moveUp:
          if (index > 0) _postings.insert(index - 1, _postings.removeAt(index));
        case _PostingAction.moveDown:
          if (index < _postings.length - 1) _postings.insert(index + 1, _postings.removeAt(index));
        case _PostingAction.remove:
          _postings.removeAt(index).dispose();
      }
    });
  }

  /// [newIndex] counts after removing the row at [oldIndex].
  void _reorder(int oldIndex, int newIndex) {
    _changed(() => _postings.insert(newIndex, _postings.removeAt(oldIndex)));
  }

  Future<void> _pickAccount(_PostingRow row) async {
    final index = ref.read(suggestionIndexProvider);
    final types = AccountType.values.toSet();
    final picked = await showAccountPicker(
      context,
      types: types,
      title: context.l10n.advAccount,
      selected: row.account,
      suggested: index.rankedAccounts(types),
    );
    if (picked != null && mounted) _changed(() => row.account = picked);
  }

  Future<void> _pickDate() async {
    final now = _now();
    final current = _datetime ?? now;
    final day = await showDatePicker(
      context: context,
      initialDate: current,
      firstDate: DateTime(1970),
      lastDate: DateTime(now.year + 5, 12, 31),
    );
    if (day == null || !mounted) return;
    final fallback = _datetime != null
        ? TimeOfDay.fromDateTime(_datetime!)
        : ZhangDates.isSameDay(day, now)
        ? TimeOfDay.fromDateTime(now)
        // Not today: noon avoids landing on another day in the ledger timezone.
        : const TimeOfDay(hour: 12, minute: 0);
    final time = await showTimePicker(context: context, initialTime: fallback);
    if (!mounted) return;
    final t = time ?? fallback;
    final previous = _datetime;
    // Seconds are kept while the minute stays the same (an edit that only
    // changes the day does not rewrite the time).
    final seconds = previous != null && previous.hour == t.hour && previous.minute == t.minute ? previous.second : 0;
    _changed(() => _datetime = DateTime(day.year, day.month, day.day, t.hour, t.minute, seconds));
  }

  Future<void> _pickTags() async {
    final tags = await showTagsSheet(context, selected: _tags, known: ref.read(suggestionIndexProvider).tags);
    if (tags != null && mounted) _changed(() => _tags = List.unmodifiable(tags));
  }

  // ------------------------------------------------------------------- save

  /// [acceptWarnings]: the user chose "Save anyway" for preview warnings.
  Future<void> _submit({bool acceptWarnings = false}) async {
    if (_submitting) return;
    final draft = _snapshot();
    if (validateAdvanced(draft, precisionOf: _precisionOf).isNotEmpty) return;
    final request = buildAdvancedRequest(draft, now: _now(), edit: _editing, precisionOf: _precisionOf);
    final editId = widget.args?.editId;
    final repository = ref.read(journalRepositoryProvider);
    final history = ref.read(transactionHistoryProvider.notifier);
    final revision = ref.read(ledgerRevisionProvider);
    FocusScope.of(context).unfocus();
    setState(() {
      _submitting = true;
      _error = null;
    });
    try {
      final preview = editId == null
          ? await repository.preview(request)
          : await repository.previewUpdate(editId, request);
      if (preview.isBlocked) throw TransactionRejected(preview);
      if (!acceptWarnings && preview.warnings.isNotEmpty) {
        throw TransactionNeedsConfirmation(preview, again: false);
      }
      if (editId == null) {
        await repository.create(request);
      } else {
        await repository.update(editId, request);
      }
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
    if (editId == null) history.addLocal(HistoryEntry.fromRequest(request));
    if (!mounted) return;
    final l10n = context.l10n;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(editId == null ? l10n.saved : l10n.editSavedSnack)));
    final saved = EntrySaved(revision: revision, hint: EntrySaved.hintFor(request));
    setState(() {
      _submitting = false;
      _allowPop = true;
    });
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) Navigator.of(context).pop(saved);
    });
  }

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
            key: const Key('adv.discard'),
            onPressed: () => Navigator.of(context).pop(true),
            child: Text(l10n.addDiscard),
          ),
        ],
      ),
    );
    if (discard != true || !mounted) return;
    setState(() => _allowPop = true);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) Navigator.of(context).maybePop();
    });
  }

  // ------------------------------------------------------------------ build

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    ref.watch(ledgerClockProvider);
    ref.watch(ledgerOptionsProvider);
    final commodities = ref.watch(commoditiesProvider).value ?? const <String, Commodity>{};
    final draft = _snapshot();
    final issues = validateAdvanced(draft, precisionOf: _precisionOf);
    final balance = balanceOf(draft.postings, precisionOf: _precisionOf);
    return PopScope(
      canPop: _allowPop || !_touched,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) _confirmDiscard();
      },
      child: Scaffold(
        appBar: AppBar(
          leading: IconButton(
            key: const Key('adv.close'),
            tooltip: l10n.addClose,
            icon: const Icon(Icons.close),
            onPressed: () => Navigator.of(context).maybePop(),
          ),
          title: Text(_editing ? l10n.editTransactionTitle : l10n.advTitle),
          actions: [
            Padding(
              padding: const EdgeInsets.only(right: 12),
              child: FilledButton(
                key: const Key('adv.save'),
                onPressed: issues.isEmpty && !_submitting ? _submit : null,
                child: _submitting
                    ? const SizedBox.square(dimension: 18, child: CircularProgressIndicator(strokeWidth: 2))
                    : Text(l10n.save),
              ),
            ),
          ],
        ),
        body: AbsorbPointer(
          absorbing: _submitting,
          child: Column(
            children: [
              Expanded(
                child: CustomScrollView(
                  key: const Key('adv.body'),
                  keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
                  slivers: [
                    SliverToBoxAdapter(child: _header()),
                    SliverToBoxAdapter(child: _SectionTitle(l10n.trxPostings)),
                    SliverReorderableList(
                      itemCount: _postings.length,
                      onReorderItem: _reorder,
                      itemBuilder: (context, i) => _postingCard(i, balance, commodities),
                    ),
                    SliverToBoxAdapter(
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                        child: Align(
                          alignment: Alignment.centerLeft,
                          child: TextButton.icon(
                            key: const Key('adv.addPosting'),
                            onPressed: _addPosting,
                            icon: const Icon(Icons.add),
                            label: Text(l10n.advAddPosting),
                          ),
                        ),
                      ),
                    ),
                    SliverToBoxAdapter(child: _metasSection()),
                    const SliverToBoxAdapter(child: SizedBox(height: 24)),
                  ],
                ),
              ),
              _bottomPanel(balance, issues, commodities),
            ],
          ),
        ),
      ),
    );
  }

  String _dateLabel() {
    final l10n = context.l10n;
    final date = _datetime;
    if (date == null) return l10n.addToday;
    final locale = Localizations.localeOf(context).toString();
    final now = _now();
    final time = ZhangDates.formatTime(date, locale);
    if (ZhangDates.isSameDay(date, now)) return '${l10n.addToday} $time';
    final day = date.year == now.year ? DateFormat.MMMd(locale).format(date) : ZhangDates.formatDate(date, locale);
    return '$day $time';
  }

  Widget _header() {
    final l10n = context.l10n;
    final scheme = Theme.of(context).colorScheme;
    InputDecoration decoration(String label, IconData icon, {String? hint}) => InputDecoration(
      isDense: true,
      filled: true,
      labelText: label,
      hintText: hint,
      prefixIcon: Icon(icon),
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
    );
    final flags = {TransactionFlag.complete, TransactionFlag.pending, _initial.flag, _flag};
    final notToday = _datetime != null && !ZhangDates.isSameDay(_datetime!, _now());
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Wrap(
            spacing: 8,
            runSpacing: 8,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              ActionChip(
                key: const Key('adv.date'),
                avatar: const Icon(Icons.event, size: 18),
                label: Text(_dateLabel()),
                tooltip: l10n.addDate,
                backgroundColor: notToday ? scheme.tertiaryContainer : null,
                onPressed: _pickDate,
              ),
              SegmentedButton<String>(
                key: const Key('adv.flag'),
                showSelectedIcon: false,
                style: const ButtonStyle(visualDensity: VisualDensity.compact),
                segments: [
                  for (final f in flags)
                    ButtonSegment(
                      value: f,
                      tooltip: switch (f) {
                        TransactionFlag.complete => l10n.advFlagComplete,
                        TransactionFlag.pending => l10n.journalPending,
                        _ => null,
                      },
                      label: Text(f, key: Key('adv.flag.$f')),
                    ),
                ],
                selected: {_flag},
                onSelectionChanged: (s) => _changed(() => _flag = s.single),
              ),
            ],
          ),
          const SizedBox(height: 12),
          TextField(
            key: const Key('adv.payee'),
            controller: _payee,
            textInputAction: TextInputAction.next,
            onChanged: (_) => _changed(),
            decoration: decoration(l10n.addPayee, Icons.storefront_outlined),
          ),
          const SizedBox(height: 8),
          TextField(
            key: const Key('adv.narration'),
            controller: _narration,
            textInputAction: TextInputAction.next,
            onChanged: (_) => _changed(),
            decoration: decoration(l10n.addNarration, Icons.notes),
          ),
          const SizedBox(height: 8),
          TextField(
            key: const Key('adv.links'),
            controller: _links,
            textInputAction: TextInputAction.done,
            onChanged: (_) => _changed(),
            decoration: decoration(l10n.trxLinks, Icons.link, hint: l10n.advLinksHint),
          ),
          const SizedBox(height: 8),
          Align(
            alignment: Alignment.centerLeft,
            child: ActionChip(
              key: const Key('adv.tags'),
              avatar: const Icon(Icons.tag, size: 18),
              label: Text(_tags.isEmpty ? l10n.addTags : _tags.map((t) => '#$t').join(' ')),
              onPressed: _pickTags,
            ),
          ),
        ],
      ),
    );
  }

  Widget _postingCard(int i, PostingBalance balance, Map<String, Commodity> commodities) {
    final l10n = context.l10n;
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final row = _postings[i];
    final account = row.account;
    final hasAmount = row.amount.text.trim().isNotEmpty;
    final invalid = hasAmount && parseAmountInput(row.amount.text) == null;
    final commodity = row.commodity ?? _defaultCommodity();
    final autoHint = !hasAmount && balance.hasAuto && !balance.indeterminate && balance.remainder.isNotEmpty
        ? l10n.advAutoTakes(balance.autoAmounts.map((a) => formatAmount(a, commodities, signed: true)).join(', '))
        : l10n.advAuto;
    final codes = {?commodity, ...commodities.keys}.toList();
    final mono = theme.textTheme.bodyMedium?.copyWith(fontFamily: 'monospace', fontFamilyFallback: const ['Menlo', 'Courier']);
    InputDecoration field(String label, {String? hint}) =>
        InputDecoration(isDense: true, labelText: label, hintText: hint, border: const OutlineInputBorder());
    return Card(
      key: ValueKey(row.key),
      margin: const EdgeInsets.fromLTRB(12, 4, 12, 4),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(0, 4, 4, 8),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                ReorderableDragStartListener(
                  index: i,
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 12),
                    child: Icon(Icons.drag_indicator, color: scheme.onSurfaceVariant),
                  ),
                ),
                Expanded(
                  child: InkWell(
                    key: Key('adv.account.$i'),
                    borderRadius: BorderRadius.circular(8),
                    onTap: () => _pickAccount(row),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(vertical: 10),
                      child: Row(
                        children: [
                          Icon(
                            account == null ? Icons.account_balance_wallet_outlined : categoryIcon(account),
                            size: 18,
                            color: scheme.primary,
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              account ?? l10n.addChooseAccount,
                              style: account == null ? theme.textTheme.bodyMedium?.copyWith(color: scheme.outline) : mono,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
                PopupMenuButton<_PostingAction>(
                  key: Key('adv.menu.$i'),
                  onSelected: (a) => _postingAction(i, a),
                  itemBuilder: (context) => [
                    PopupMenuItem(
                      key: const Key('adv.moveUp'),
                      value: _PostingAction.moveUp,
                      enabled: i > 0,
                      child: Text(l10n.advMoveUp),
                    ),
                    PopupMenuItem(
                      key: const Key('adv.moveDown'),
                      value: _PostingAction.moveDown,
                      enabled: i < _postings.length - 1,
                      child: Text(l10n.advMoveDown),
                    ),
                    PopupMenuItem(
                      key: const Key('adv.remove'),
                      value: _PostingAction.remove,
                      child: Text(l10n.advRemovePosting),
                    ),
                  ],
                ),
              ],
            ),
            Row(
              children: [
                IconButton(
                  key: Key('adv.sign.$i'),
                  tooltip: l10n.advToggleSign,
                  icon: const Icon(Icons.exposure),
                  onPressed: () => _changed(() {
                    final next = toggleSign(row.amount.text);
                    row.amount.value = TextEditingValue(
                      text: next,
                      selection: TextSelection.collapsed(offset: next.length),
                    );
                  }),
                ),
                Expanded(
                  child: TextField(
                    key: Key('adv.amount.$i'),
                    controller: row.amount,
                    textAlign: TextAlign.end,
                    keyboardType: const TextInputType.numberWithOptions(decimal: true, signed: true),
                    inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'[0-9.,+\-−\s]'))],
                    style: tabular(theme.textTheme.titleMedium),
                    onChanged: (text) => _changed(() {
                      if (text.trim().isNotEmpty) row.commodity ??= _defaultCommodity();
                    }),
                    decoration: InputDecoration(
                      isDense: true,
                      hintText: autoHint,
                      errorText: invalid ? l10n.advIssueAmount : null,
                      border: const OutlineInputBorder(),
                    ),
                  ),
                ),
                PopupMenuButton<String>(
                  key: Key('adv.commodity.$i'),
                  tooltip: l10n.addCommodity,
                  onSelected: (code) => _changed(() => row.commodity = code),
                  itemBuilder: (context) => [
                    for (final code in codes)
                      PopupMenuItem(key: Key('adv.commodity.$i.$code'), value: code, child: Text(code)),
                  ],
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(commodity ?? '…', style: theme.textTheme.titleSmall),
                        const Icon(Icons.arrow_drop_down),
                      ],
                    ),
                  ),
                ),
              ],
            ),
            if (row.expanded) ...[
              const SizedBox(height: 8),
              Padding(
                padding: const EdgeInsets.only(left: 12, right: 8),
                child: Row(
                  children: [
                    Expanded(
                      child: TextField(
                        key: Key('adv.cost.$i'),
                        controller: row.cost,
                        onChanged: (_) => _changed(),
                        decoration: field(l10n.advCost, hint: l10n.advCostHint),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: TextField(
                        key: Key('adv.price.$i'),
                        controller: row.price,
                        onChanged: (_) => _changed(),
                        decoration: field(l10n.advPrice, hint: l10n.advPriceHint),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 8),
              Padding(
                padding: const EdgeInsets.only(left: 12, right: 8),
                child: TextField(
                  key: Key('adv.comment.$i'),
                  controller: row.comment,
                  onChanged: (_) => _changed(),
                  decoration: field(l10n.advComment),
                ),
              ),
            ] else
              Padding(
                padding: const EdgeInsets.only(left: 4),
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: TextButton.icon(
                    key: Key('adv.more.$i'),
                    onPressed: () => setState(() => row.expanded = true),
                    icon: const Icon(Icons.expand_more, size: 18),
                    label: Text(l10n.advMoreFields),
                  ),
                ),
              ),
            if (row.metas.isNotEmpty)
              Padding(
                padding: const EdgeInsets.fromLTRB(12, 6, 8, 0),
                child: Text(
                  '${l10n.trxMetas}: ${row.metas.map((m) => '${m.key}: ${m.value}').join(' · ')}',
                  key: Key('adv.postingMetas.$i'),
                  style: theme.textTheme.bodySmall?.copyWith(color: scheme.onSurfaceVariant),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _metasSection() {
    final l10n = context.l10n;
    return ExpansionTile(
      key: const Key('adv.metas'),
      initiallyExpanded: _metas.isNotEmpty,
      title: Text(_metas.isEmpty ? l10n.trxMetas : '${l10n.trxMetas} (${_metas.length})'),
      childrenPadding: const EdgeInsets.fromLTRB(16, 0, 8, 8),
      children: [
        for (final (i, m) in _metas.indexed)
          Padding(
            key: ValueKey('meta-${m.id}'),
            padding: const EdgeInsets.only(bottom: 8),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  flex: 2,
                  child: TextField(
                    key: Key('adv.metaKey.$i'),
                    controller: m.key,
                    onChanged: (_) => _changed(),
                    decoration: InputDecoration(isDense: true, labelText: l10n.advMetaKey, border: const OutlineInputBorder()),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  flex: 3,
                  child: TextField(
                    key: Key('adv.metaValue.$i'),
                    controller: m.value,
                    maxLines: null,
                    onChanged: (_) => _changed(),
                    decoration: InputDecoration(isDense: true, labelText: l10n.advMetaValue, border: const OutlineInputBorder()),
                  ),
                ),
                IconButton(
                  key: Key('adv.metaRemove.$i'),
                  tooltip: l10n.delete,
                  icon: const Icon(Icons.remove_circle_outline),
                  onPressed: () => _changed(() => _metas.removeAt(i).dispose()),
                ),
              ],
            ),
          ),
        Align(
          alignment: Alignment.centerLeft,
          child: TextButton.icon(
            key: const Key('adv.addMeta'),
            onPressed: () => _changed(() => _metas.add(_MetaRow(_nextKey++, const Meta('', '')))),
            icon: const Icon(Icons.add),
            label: Text(l10n.advAddMeta),
          ),
        ),
      ],
    );
  }

  String _issueText(AdvancedIssue issue) {
    final l10n = context.l10n;
    return switch (issue) {
      AdvancedIssue.tooFewPostings => l10n.advIssuePostings,
      AdvancedIssue.accountMissing => l10n.advIssueAccount,
      AdvancedIssue.amountInvalid => l10n.advIssueAmount,
      AdvancedIssue.commodityMissing => l10n.addHintCommodity,
      AdvancedIssue.tooManyAuto => l10n.advIssueAuto,
      AdvancedIssue.unbalanced => l10n.advIssueUnbalanced,
    };
  }

  Widget _bottomPanel(PostingBalance balance, List<AdvancedIssue> issues, Map<String, Commodity> commodities) {
    final l10n = context.l10n;
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    String amounts(List<Amount> list) => list.map((a) => formatAmount(a, commodities, signed: true)).join(', ');
    final (IconData icon, Color color, String text) = switch (balance) {
      _ when balance.autoCount > 1 => (Icons.error_outline, scheme.error, l10n.advIssueAuto),
      PostingBalance(indeterminate: true) => (Icons.info_outline, scheme.onSurfaceVariant, l10n.advBalanceUnknown),
      PostingBalance(isBalanced: true) => (Icons.check_circle_outline, scheme.primary, l10n.advBalanced),
      PostingBalance(hasAuto: true) => (Icons.auto_fix_high, scheme.onSurfaceVariant, l10n.advAutoTakes(amounts(balance.autoAmounts))),
      _ => (Icons.cancel_outlined, scheme.error, l10n.advUnbalancedBy(amounts(balance.remainder))),
    };
    final hint = issues.where((i) => i != AdvancedIssue.unbalanced && i != AdvancedIssue.tooManyAuto).firstOrNull;
    final error = _error;
    return Material(
      color: scheme.surfaceContainerLow,
      child: SafeArea(
        top: false,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (error != null)
              SaveErrorBanner(
                error: error,
                editing: _editing,
                onClose: () => setState(() => _error = null),
                onSaveAnyway: error is TransactionNeedsConfirmation ? () => _submit(acceptWarnings: true) : null,
              ),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 10, 16, 2),
              child: Row(
                children: [
                  Text(l10n.advRemainder, style: theme.textTheme.labelLarge),
                  const SizedBox(width: 12),
                  Icon(icon, size: 18, color: color),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      text,
                      key: const Key('adv.remainder'),
                      style: tabular(theme.textTheme.bodyMedium)?.copyWith(color: color),
                    ),
                  ),
                ],
              ),
            ),
            if (balance.isUnbalanced && balance.remainder.length > 1)
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 2, 16, 0),
                child: Text(
                  l10n.advNeedsPrice,
                  key: const Key('adv.needsPrice'),
                  style: theme.textTheme.bodySmall?.copyWith(color: scheme.onSurfaceVariant),
                ),
              ),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 2, 16, 10),
              child: SizedBox(
                width: double.infinity,
                child: Text(
                  hint == null ? '' : _issueText(hint),
                  key: const Key('adv.hint'),
                  style: theme.textTheme.bodySmall?.copyWith(color: scheme.onSurfaceVariant),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SectionTitle extends StatelessWidget {
  const _SectionTitle(this.text);

  final String text;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.fromLTRB(16, 20, 16, 6),
    child: Text(
      text,
      style: Theme.of(context).textTheme.titleSmall?.copyWith(color: Theme.of(context).colorScheme.primary),
    ),
  );
}
