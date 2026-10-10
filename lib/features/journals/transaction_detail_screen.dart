import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/theme/app_colors.dart';
import '../../core/utils/dates.dart';
import '../../core/utils/money.dart';
import '../../core/widgets/error_view.dart';
import '../../data/models/amount.dart';
import '../../data/models/commodity.dart';
import '../../data/models/journal.dart';
import '../../data/repositories/ledger_data_providers.dart';
import '../../l10n/l10n.dart';
import '../../router.dart';
import 'classify.dart';
import 'journal_providers.dart';
import 'transaction_text.dart';
import 'widgets/amount_format.dart';
import 'widgets/journal_tile.dart';

/// Monospace style for full account paths (design §3.2).
const _mono = TextStyle(fontFamily: 'monospace', fontFamilyFallback: ['Menlo', 'Courier']);

/// S08 (read-only): header, postings with running balances, details and a
/// "copy as text" action. The item comes from the route `extra`; deep links
/// fall back to [journalItemByIdProvider].
class TransactionDetailScreen extends ConsumerWidget {
  const TransactionDetailScreen({super.key, required this.id, this.initial, this.searchHint});

  final String id;
  final JournalItem? initial;

  /// Payee or narration to search for when [initial] is missing.
  final String? searchHint;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final item = initial;
    if (item != null) return _DetailScaffold(item: item);
    final lookup = ref.watch(journalItemByIdProvider((id, searchHint)));
    return lookup.when(
      data: (found) => found == null
          ? Scaffold(
              appBar: AppBar(title: Text(l10n.trxTitle)),
              body: Center(
                child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: Text(l10n.trxNotFound, key: const Key('trx.notFound'), textAlign: TextAlign.center),
                ),
              ),
            )
          : _DetailScaffold(item: found),
      loading: () => Scaffold(
        appBar: AppBar(title: Text(l10n.trxTitle)),
        body: const Center(child: CircularProgressIndicator()),
      ),
      error: (e, _) => Scaffold(
        appBar: AppBar(title: Text(l10n.trxTitle)),
        body: ErrorView(error: e, onRetry: () => ref.invalidate(journalItemByIdProvider((id, searchHint)))),
      ),
    );
  }
}

class _DetailScaffold extends ConsumerWidget {
  const _DetailScaffold({required this.item});

  final JournalItem item;

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
          IconButton(
            key: const Key('trx.copy'),
            tooltip: l10n.trxCopyText,
            icon: const Icon(Icons.content_copy_outlined),
            onPressed: () => _copy(context),
          ),
        ],
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
        ],
      ),
    );
  }

  List<Widget> _transactionDetails(BuildContext context, WidgetRef ref, JournalTransaction txn) {
    final l10n = context.l10n;
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
      if (txn.metas.isNotEmpty) ...[
        _SectionTitle(l10n.trxMetas),
        for (final m in txn.metas) _InfoRow(label: m.key, value: m.value, selectable: true),
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
