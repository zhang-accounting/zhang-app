import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/theme/app_colors.dart';
import '../../core/utils/dates.dart';
import '../../core/utils/money.dart';
import '../../core/widgets/error_view.dart';
import '../../data/api/idempotency.dart';
import '../../data/models/amount.dart';
import '../../data/models/commodity.dart';
import '../../data/models/journal.dart';
import '../../data/repositories/journal_repository.dart';
import '../../data/repositories/ledger_data_providers.dart';
import '../../data/repositories/ledger_revision.dart';
import '../../l10n/l10n.dart';
import '../../router.dart';
import '../documents/widgets/document_sections.dart';
import '../transaction_new/transaction_edit.dart';
import 'classify.dart';
import 'journal_providers.dart';
import 'transaction_actions.dart';
import 'transaction_text.dart';
import 'widgets/amount_format.dart';
import 'widgets/journal_tile.dart';

/// Monospace style for full account paths (design §3.2).
const _mono = TextStyle(fontFamily: 'monospace', fontFamilyFallback: ['Menlo', 'Courier']);

/// S08: header, postings with running balances, details, and the actions
/// edit, copy as a new transaction, copy as text and (zhang ≥ 0.3) delete.
/// The item comes from the route `extra`; deep links fall back to
/// [journalItemByIdProvider]. After an edit the transaction is read again
/// once the ledger has reloaded (ids stay with the edited transaction, see
/// docs/zhang-api.md §1.6); after a delete the screen closes and the lists
/// refresh on the reload.
class TransactionDetailScreen extends ConsumerStatefulWidget {
  const TransactionDetailScreen({super.key, required this.id, this.initial, this.searchHint, this.expectedVersion});

  final String id;
  final JournalItem? initial;

  /// Payee or narration to search for when [initial] is missing.
  final String? searchHint;

  /// `version` the transaction had where it was listed (an account row's
  /// `trx_version`): a different one under the id means it changed or
  /// another transaction has the id now.
  final String? expectedVersion;

  @override
  ConsumerState<TransactionDetailScreen> createState() => _TransactionDetailScreenState();
}

class _TransactionDetailScreenState extends ConsumerState<TransactionDetailScreen> {
  /// How long to wait for the server to list a saved edit.
  static const landTimeout = Duration(seconds: 15);

  /// Set once an edit was saved: what it saved (with the ledger revision
  /// before the write) and the item shown until the server lists it.
  ({EntrySaved saved, JournalItem shown})? _edited;

  /// The server listed what was saved ([entryMatches]); from then on the
  /// screen shows whatever it lists under the id.
  bool _landed = false;

  /// The saved version did not show up within [landTimeout].
  bool _timedOut = false;
  Timer? _timeout;

  /// The last version read after the edit (shown while reading again).
  JournalItem? _lastRead;

  /// Checking whether the transaction can be edited (spinner on the button).
  bool _checking = false;

  /// An edit, a copy or a delete is under way: a second tap opens nothing.
  bool _busy = false;

  /// The delete request is under way.
  bool _deleting = false;

  @override
  void dispose() {
    _timeout?.cancel();
    super.dispose();
  }

  Future<void> _edit(JournalTransaction tx) async {
    if (_busy) return;
    _busy = true;
    setState(() => _checking = true);
    try {
      final saved = await editTransaction(
        context,
        ref,
        tx,
        onChecked: () {
          if (mounted) setState(() => _checking = false);
        },
      );
      if (!mounted || saved == null) return;
      _timeout?.cancel();
      _timeout = Timer(landTimeout, () {
        if (mounted && !_landed) setState(() => _timedOut = true);
      });
      setState(() {
        _edited = (saved: saved, shown: tx);
        _lastRead = null;
        _landed = false;
        _timedOut = false;
      });
    } finally {
      _busy = false;
    }
  }

  Future<void> _copy(JournalTransaction tx) async {
    if (_busy) return;
    _busy = true;
    try {
      await copyTransaction(context, ref, tx);
    } finally {
      _busy = false;
    }
  }

  /// Asks, then deletes [tx] by its id with `If-Match: <version>` (only
  /// offered with a version, [canDelete]). A 412 / 404 means it is no longer
  /// the transaction opened: nothing was deleted, and the list can be
  /// refreshed. Once deleted the screen closes; the lists refresh on the
  /// ledger's reload, as after an edit.
  Future<void> _delete(JournalTransaction tx) async {
    final version = tx.version;
    if (_busy || version == null) return;
    _busy = true;
    try {
      if (!await confirmDelete(context, _summary(tx)) || !mounted) return;
      final l10n = context.l10n;
      final messenger = ScaffoldMessenger.of(context);
      final repository = ref.read(journalRepositoryProvider);
      setState(() => _deleting = true);
      try {
        await repository.delete(tx.id, version: version);
      } catch (e) {
        if (!mounted) return;
        setState(() => _deleting = false);
        if (!isStaleEdit(e)) {
          messenger.showSnackBar(SnackBar(content: Text(describeApiError(l10n, e))));
          return;
        }
        if (await showDeleteStale(context) && mounted) {
          ref.read(ledgerRevisionProvider.notifier).bump();
          _leave();
        }
        return;
      }
      messenger
        ..hideCurrentSnackBar()
        ..showSnackBar(SnackBar(content: Text(l10n.trxDeletedSnack)));
      if (mounted) _leave();
    } finally {
      _busy = false;
    }
  }

  /// What the delete confirmation names: date, payee, narration, amount.
  String _summary(JournalTransaction tx) {
    final c = classify(tx, operatingCurrency: ref.read(operatingCurrencyProvider));
    final narration = tx.narration?.trim() ?? '';
    return [
      ZhangDates.toIsoDate(tx.datetime),
      if (tx.payee.isNotEmpty) tx.payee,
      if (narration.isNotEmpty) narration,
      if (c.amounts.isNotEmpty)
        formatAmount(c.amounts.first, ref.read(commoditiesProvider).value, signed: c.isDirectional),
    ].join(' · ');
  }

  /// Back to the list the transaction was opened from.
  void _leave() {
    if (context.canPop()) {
      context.pop();
    } else {
      context.go(AppRoutes.journals);
    }
  }

  Widget _scaffold(JournalItem item, {bool refreshing = false}) => _DetailScaffold(
    item: item,
    refreshing: refreshing,
    deleting: _deleting,
    checking: _checking,
    onEdit: item is JournalTransaction && !refreshing && !_deleting ? () => _edit(item) : null,
    onCopy: item is JournalTransaction ? () => _copy(item) : null,
    deletable: canDelete(item),
    onDelete: item is JournalTransaction && !refreshing && !_deleting ? () => _delete(item) : null,
  );

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final edited = _edited;
    if (edited != null) {
      final revision = ref.watch(ledgerRevisionProvider);
      final shown = _lastRead ?? edited.shown;
      // Until the server lists what was saved: the previous version, then
      // after [landTimeout] an explanation.
      Widget waiting() => _timedOut
          ? _MessageScaffold(l10n.trxEditedPending, key: const Key('trx.editedPending'))
          : _scaffold(shown, refreshing: true);
      // Not reloaded since the write yet: the server still has the old text.
      if (!_landed && revision <= edited.saved.revision) return waiting();
      final fresh = ref.watch(editedTransactionProvider((widget.id, edited.saved.hint, revision)));
      return fresh.when(
        data: (found) {
          if (!_landed) {
            // Any reload is not necessarily the one of this write.
            if (found is! JournalTransaction || !entryMatches(found, edited.saved.request)) return waiting();
            _landed = true;
          }
          if (found == null) return _MessageScaffold(l10n.trxEditedNotFound, key: const Key('trx.editedNotFound'));
          _lastRead = found;
          return _scaffold(found);
        },
        loading: () => _landed ? _scaffold(shown, refreshing: true) : waiting(),
        error: (e, _) => Scaffold(
          appBar: AppBar(title: Text(l10n.trxTitle)),
          body: ErrorView(
            error: e,
            onRetry: () => ref.invalidate(editedTransactionProvider((widget.id, edited.saved.hint, revision))),
          ),
        ),
      );
    }
    final item = widget.initial;
    if (item != null) return _scaffold(item);
    final lookup = ref.watch(journalItemByIdProvider((widget.id, widget.searchHint)));
    return lookup.when(
      data: (found) {
        if (found == null) return _MessageScaffold(l10n.trxNotFound, key: const Key('trx.notFound'));
        final expected = widget.expectedVersion;
        if (expected != null && found is JournalTransaction && found.version != null && found.version != expected) {
          return _MessageScaffold(l10n.trxChanged, key: const Key('trx.changed'));
        }
        return _scaffold(found);
      },
      loading: () => Scaffold(
        appBar: AppBar(title: Text(l10n.trxTitle)),
        body: const Center(child: CircularProgressIndicator()),
      ),
      error: (e, _) => Scaffold(
        appBar: AppBar(title: Text(l10n.trxTitle)),
        body: ErrorView(
          error: e,
          onRetry: () => ref.invalidate(journalItemByIdProvider((widget.id, widget.searchHint))),
        ),
      ),
    );
  }
}

/// A detail screen that only shows [text] (not found, …).
class _MessageScaffold extends StatelessWidget {
  const _MessageScaffold(this.text, {super.key});

  final String text;

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: Text(context.l10n.trxTitle)),
    body: Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Text(text, key: const Key('trx.message'), textAlign: TextAlign.center),
      ),
    ),
  );
}

class _DetailScaffold extends ConsumerWidget {
  const _DetailScaffold({
    required this.item,
    this.onEdit,
    this.onCopy,
    this.onDelete,
    this.deletable = false,
    this.checking = false,
    this.refreshing = false,
    this.deleting = false,
  });

  final JournalItem item;

  /// Edit / copy as a new transaction (transactions only).
  final VoidCallback? onEdit;
  final VoidCallback? onCopy;

  /// The overflow menu offers delete ([canDelete]); [onDelete] `null` =
  /// not now (refreshing, deleting).
  final bool deletable;
  final VoidCallback? onDelete;

  /// The delete request is under way.
  final bool deleting;

  /// The edit check is running.
  final bool checking;

  /// Shown while the transaction is read again after an edit.
  final bool refreshing;

  Future<void> _copy(BuildContext context) async {
    final messenger = ScaffoldMessenger.of(context);
    final message = context.l10n.trxCopied;
    await Clipboard.setData(ClipboardData(text: journalItemToText(item)));
    messenger.showSnackBar(SnackBar(content: Text(message)));
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final commodities = ref.watch(commoditiesProvider).value;
    final opCurrency = ref.watch(operatingCurrencyProvider);
    final item = this.item;
    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.trxTitle),
        actions: [
          if (item is JournalTransaction) ...[
            IconButton(
              key: const Key('trx.edit'),
              tooltip: l10n.trxEdit,
              icon: checking
                  ? const SizedBox.square(dimension: 20, child: CircularProgressIndicator(strokeWidth: 2))
                  : const Icon(Icons.edit_outlined),
              onPressed: checking ? null : onEdit,
            ),
            IconButton(
              key: const Key('trx.duplicate'),
              tooltip: l10n.trxDuplicate,
              icon: const Icon(Icons.control_point_duplicate),
              onPressed: onCopy,
            ),
          ],
          IconButton(
            key: const Key('trx.copy'),
            tooltip: l10n.trxCopyText,
            icon: const Icon(Icons.content_copy_outlined),
            onPressed: () => _copy(context),
          ),
          // Destructive and rare: behind the overflow menu, then a
          // confirmation.
          if (deletable)
            MenuAnchor(
              builder: (context, controller, _) => IconButton(
                key: const Key('trx.more'),
                tooltip: MaterialLocalizations.of(context).showMenuTooltip,
                icon: const Icon(Icons.more_vert),
                onPressed: deleting ? null : () => controller.isOpen ? controller.close() : controller.open(),
              ),
              menuChildren: [
                MenuItemButton(
                  key: const Key('trx.delete'),
                  leadingIcon: Icon(Icons.delete_outline, color: Theme.of(context).colorScheme.error),
                  onPressed: onDelete,
                  child: Text(l10n.delete, style: TextStyle(color: Theme.of(context).colorScheme.error)),
                ),
              ],
            ),
        ],
        bottom: refreshing || deleting
            ? PreferredSize(
                preferredSize: const Size.fromHeight(4),
                child: Semantics(
                  label: deleting ? l10n.trxDeleting : l10n.trxRefreshing,
                  child: LinearProgressIndicator(key: Key(deleting ? 'trx.deleting' : 'trx.refreshing')),
                ),
              )
            : null,
      ),
      body: ListView(
        key: const Key('trx.body'),
        padding: const EdgeInsets.only(bottom: 96),
        children: [
          switch (item) {
            JournalTransaction() => _TransactionHeader(
              txn: item,
              classification: classify(item, operatingCurrency: opCurrency),
              commodities: commodities,
            ),
            JournalBalance() => _BalanceHeader(item: item, commodities: commodities),
            JournalUnknown() => ListTile(title: Text(item.payee)),
          },
          if (item.postings.isNotEmpty) ...[
            _SectionTitle(l10n.trxPostings),
            for (final p in item.postings) _PostingTile(posting: p, commodities: commodities),
          ],
          _SectionTitle(l10n.trxDetails),
          _InfoRow(label: l10n.trxDate, value: _dateTime(item.datetime)),
          if (item is JournalTransaction) ..._transactionDetails(context, ref, item),
          if (item is JournalTransaction) TransactionDocumentsSection(transaction: item),
        ],
      ),
    );
  }

  List<Widget> _transactionDetails(BuildContext context, WidgetRef ref, JournalTransaction txn) {
    final l10n = context.l10n;
    // The `idempotency-key` zhang writes for a create is bookkeeping of the
    // save, not something to read: hidden here, kept in edits and in "copy
    // as text".
    final metas = [
      for (final m in txn.metas)
        if (m.key != Idempotency.metaKey) m,
    ];
    return [
      _InfoRow(label: l10n.trxFlag, value: txn.flag),
      if (txn.tags.isNotEmpty)
        _InfoRow(
          label: l10n.trxTags,
          child: Wrap(
            spacing: 8,
            runSpacing: 4,
            children: [
              for (final tag in txn.tags)
                ActionChip(
                  label: Text('#$tag'),
                  tooltip: l10n.trxFilterByTag(tag),
                  onPressed: () {
                    ref.read(journalFilterProvider.notifier).onlyTag(tag);
                    context.go(AppRoutes.journals);
                  },
                ),
            ],
          ),
        ),
      if (txn.links.isNotEmpty) _InfoRow(label: l10n.trxLinks, value: txn.links.map((l) => '^$l').join('  ')),
      if (metas.isNotEmpty) ...[
        _SectionTitle(l10n.trxMetas),
        for (final m in metas) _InfoRow(label: m.key, value: m.value, selectable: true),
      ],
    ];
  }

  /// ISO wall-clock date (time omitted for date-only directives).
  static String _dateTime(DateTime d) {
    final date = ZhangDates.toIsoDate(d);
    if (d.hour == 0 && d.minute == 0 && d.second == 0) return date;
    return ZhangDates.toNaiveIso(d).replaceFirst('T', ' ');
  }
}

class _TransactionHeader extends StatelessWidget {
  const _TransactionHeader({required this.txn, required this.classification, required this.commodities});

  final JournalTransaction txn;
  final TxnClassification classification;
  final Map<String, Commodity>? commodities;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final c = classification;
    final (bg, fg) = txnKindColors(context, c);
    final narration = txn.narration?.trim() ?? '';
    final subtitle = [if (txn.payee.isNotEmpty) txn.payee, if (narration.isNotEmpty) narration].join(' · ');
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
      child: Column(
        children: [
          Chip(
            avatar: Icon(txnKindIcon(c), size: 18, color: fg),
            label: Text(txnKindLabel(l10n, c)),
            backgroundColor: bg,
            labelStyle: TextStyle(color: fg),
            side: BorderSide.none,
          ),
          const SizedBox(height: 8),
          for (final (i, a) in c.amounts.indexed)
            Text(
              formatAmount(a, commodities, signed: c.isDirectional),
              key: i == 0 ? const Key('trx.amount') : null,
              style: tabular(i == 0 ? theme.textTheme.displaySmall : theme.textTheme.titleLarge)
                  ?.copyWith(color: toneColor(context, c.toneFor(a))),
              textAlign: TextAlign.center,
            ),
          if (subtitle.isNotEmpty) ...[
            const SizedBox(height: 8),
            Text(
              subtitle,
              key: const Key('trx.subtitle'),
              style: theme.textTheme.titleMedium,
              textAlign: TextAlign.center,
            ),
          ],
          if (txn.isPending || !txn.isBalanced) ...[
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              alignment: WrapAlignment.center,
              children: [
                if (txn.isPending)
                  Chip(
                    avatar: Icon(Icons.flag_outlined, size: 18, color: scheme.onTertiaryContainer),
                    label: Text(l10n.journalPending),
                    backgroundColor: scheme.tertiaryContainer,
                    side: BorderSide.none,
                  ),
                if (!txn.isBalanced)
                  Chip(
                    avatar: Icon(Icons.warning_amber_rounded, size: 18, color: scheme.onErrorContainer),
                    label: Text(l10n.trxUnbalanced),
                    backgroundColor: scheme.errorContainer,
                    side: BorderSide.none,
                  ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}

/// Header of a balance check (asserted amount; checked balance and
/// difference when it failed) or a pad (padded amount and the balance it
/// pads to, with the folded check's result).
class _BalanceHeader extends StatelessWidget {
  const _BalanceHeader({required this.item, required this.commodities});

  final JournalBalance item;
  final Map<String, Commodity>? commodities;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final failed = item.failed;
    final check = item.isPad ? item.assertion : item;
    final title = item.isPad
        ? l10n.journalBalancePad
        : (failed ? l10n.journalBalanceFailed : l10n.journalBalanceCheck);
    final amount = item.isPad ? item.paddedAmount : item.assertedAmount;
    final target = item.isPad ? item.assertedAmount : null;
    String fmt(Amount a, {bool signed = false}) => formatAmount(a, commodities, signed: signed);
    final muted = theme.textTheme.bodyMedium?.copyWith(color: scheme.onSurfaceVariant);
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
      child: Column(
        children: [
          Chip(
            avatar: Icon(
              item.isPad ? Icons.balance : (failed ? Icons.cancel_outlined : Icons.fact_check_outlined),
              size: 18,
            ),
            label: Text(title),
            backgroundColor: failed ? scheme.errorContainer : scheme.surfaceContainerHighest,
            side: BorderSide.none,
          ),
          if (amount != null) ...[
            const SizedBox(height: 8),
            Text(
              fmt(amount, signed: item.isPad),
              key: const Key('trx.amount'),
              style: tabular(theme.textTheme.displaySmall)?.copyWith(color: context.zhangColors.neutral),
            ),
          ],
          const SizedBox(height: 8),
          Text(item.account, style: _mono.merge(theme.textTheme.bodyMedium), textAlign: TextAlign.center),
          if (target != null) ...[
            const SizedBox(height: 4),
            Text(l10n.journalPadTarget(fmt(target)), style: muted, textAlign: TextAlign.center),
          ],
          if (check != null && check.failed) ...[
            const SizedBox(height: 8),
            if (check.checkedBalance != null)
              Text(
                l10n.trxBalanceActual(fmt(check.checkedBalance!)),
                key: const Key('trx.balanceActual'),
                style: tabular(muted),
                textAlign: TextAlign.center,
              ),
            if (check.difference != null)
              Text(
                l10n.trxBalanceDifference(fmt(check.difference!, signed: true)),
                style: tabular(muted?.copyWith(color: scheme.error)),
                textAlign: TextAlign.center,
              ),
          ],
        ],
      ),
    );
  }
}

class _PostingTile extends StatelessWidget {
  const _PostingTile({required this.posting, required this.commodities});

  final JournalPosting posting;
  final Map<String, Commodity>? commodities;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final theme = Theme.of(context);
    final muted = theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.onSurfaceVariant);
    final p = posting;
    String fmt(Amount a, {bool signed = false}) => formatAmount(a, commodities, signed: signed);
    final unit = p.unit;
    final notes = <String>[
      if (unit == null) l10n.trxAuto,
      if (unit != null && unit != p.inferredUnit) l10n.trxWritten(fmt(unit)),
      if (p.cost != null) '{${fmt(p.cost!)}}',
    ];
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Text(p.account, style: _mono.merge(theme.textTheme.bodyMedium)),
              ),
              const SizedBox(width: 12),
              Text(
                fmt(p.inferredUnit, signed: true),
                style: tabular(theme.textTheme.titleSmall),
              ),
            ],
          ),
          const SizedBox(height: 2),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Text(notes.join(' · '), style: muted?.copyWith(fontStyle: FontStyle.italic)),
              ),
              const SizedBox(width: 8),
              Expanded(
                flex: 3,
                child: Text(
                  '${fmt(p.accountBefore)} → ${fmt(p.accountAfter)}',
                  style: tabular(muted),
                  textAlign: TextAlign.end,
                ),
              ),
            ],
          ),
        ],
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

class _InfoRow extends StatelessWidget {
  const _InfoRow({required this.label, this.value, this.child, this.selectable = false});

  final String label;
  final String? value;
  final Widget? child;
  final bool selectable;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 96,
            child: Text(
              label,
              style: theme.textTheme.bodyMedium?.copyWith(color: theme.colorScheme.onSurfaceVariant),
            ),
          ),
          Expanded(
            child: child ??
                (selectable
                    ? SelectableText(value ?? '', style: theme.textTheme.bodyMedium)
                    : Text(value ?? '', style: theme.textTheme.bodyMedium)),
          ),
        ],
      ),
    );
  }
}
