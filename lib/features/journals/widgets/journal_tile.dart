import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/utils/money.dart';
import '../../../data/models/account.dart';
import '../../../data/models/amount.dart';
import '../../../data/models/journal.dart';
import '../../../data/repositories/ledger_data_providers.dart';
import '../../../l10n/l10n.dart';
import '../classify.dart';
import '../journal_providers.dart';
import 'amount_format.dart';

/// Localised label of a [TxnKind] (refunds get their own label).
String txnKindLabel(AppLocalizations l10n, TxnClassification c) {
  if (c.isRefund) return l10n.journalKindRefund;
  return switch (c.kind) {
    TxnKind.expense => l10n.journalKindExpense,
    TxnKind.income => l10n.journalKindIncome,
    TxnKind.transfer => l10n.journalKindTransfer,
    TxnKind.compound => l10n.journalKindCompound,
    TxnKind.adjustment => l10n.journalKindAdjustment,
  };
}

/// Icon of a classified transaction (design S07: category icon, ⇄ for
/// transfers, ⚖ for adjustments).
IconData txnKindIcon(TxnClassification c) {
  if (c.isRefund) return Icons.undo;
  return switch (c.kind) {
    TxnKind.expense => Icons.shopping_bag_outlined,
    TxnKind.income => Icons.savings_outlined,
    TxnKind.transfer =>
      AccountType.ofAccount(c.primaryAccount ?? '') == AccountType.liabilities
          ? Icons.credit_card
          : Icons.swap_horiz,
    TxnKind.compound => Icons.call_split,
    TxnKind.adjustment => Icons.balance,
  };
}

/// Background / foreground of the leading icon circle.
(Color, Color) txnKindColors(BuildContext context, TxnClassification c) {
  final colors = context.zhangColors;
  final scheme = Theme.of(context).colorScheme;
  return switch (c.toneFor()) {
    AmountTone.negative => (colors.expenseContainer, colors.onExpenseContainer),
    AmountTone.positive => (colors.incomeContainer, colors.onIncomeContainer),
    AmountTone.neutral => (scheme.surfaceContainerHighest, scheme.onSurfaceVariant),
  };
}

/// One row of the journal (Home "recent transactions" and the Journal tab).
///
/// * Transactions: icon by [classify] kind, payee → narration → category as
///   title, narration · account(s) · tags as subtitle, coloured signed
///   amount; `!` flag dot, unbalanced outline + ⚠, attachment clip.
/// * Balance check / pad: ✓ (✗ when the check failed) and the asserted
///   balance in neutral colour.
class JournalItemTile extends ConsumerWidget {
  const JournalItemTile({super.key, required this.item, this.onTap});

  final JournalItem item;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final commodities = ref.watch(commoditiesProvider).value;
    final opCurrency = ref.watch(operatingCurrencyProvider);
    final failed = ref.watch(ledgerErrorIdsProvider).contains(item.id);
    return switch (item) {
      final JournalTransaction t => _TransactionTile(
        txn: t,
        classification: classify(t, operatingCurrency: opCurrency),
        format: (a, {signed = false}) => formatAmount(a, commodities, signed: signed),
        onTap: onTap,
      ),
      final JournalBalance b => _BalanceTile(
        item: b,
        failed: failed,
        format: (a) => formatAmount(a, commodities),
        onTap: onTap,
      ),
      JournalUnknown() => ListTile(
        key: Key('journal.row.${item.id}'),
        leading: const CircleAvatar(child: Icon(Icons.help_outline)),
        title: Text(item.payee.isEmpty ? (item.narration ?? '') : item.payee),
        onTap: onTap,
      ),
    };
  }
}

typedef _Format = String Function(Amount amount, {bool signed});

class _TransactionTile extends StatelessWidget {
  const _TransactionTile({required this.txn, required this.classification, required this.format, this.onTap});

  final JournalTransaction txn;
  final TxnClassification classification;
  final _Format format;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final c = classification;
    final narration = txn.narration?.trim() ?? '';
    final category = c.primaryAccount == null ? '' : accountLabel(c.primaryAccount!);

    final String title;
    final subtitle = <String>[];
    if (txn.payee.isNotEmpty) {
      title = txn.payee;
      if (narration.isNotEmpty) subtitle.add(narration);
    } else if (narration.isNotEmpty) {
      title = narration;
    } else {
      title = category.isEmpty ? txnKindLabel(l10n, c) : category;
    }
    if (c.kind == TxnKind.transfer && c.counterAccount != null && c.primaryAccount != null) {
      subtitle.add('${accountLabel(c.counterAccount!)} → ${accountLabel(c.primaryAccount!)}');
    } else if (c.counterAccount != null) {
      subtitle.add(accountLabel(c.counterAccount!));
    } else if (category.isNotEmpty && title != category) {
      subtitle.add(category);
    }
    if (txn.tags.isNotEmpty) subtitle.add(txn.tags.map((t) => '#$t').join(' '));

    final amount = c.primaryAmount;
    final amountText = amount == null ? '' : format(amount, signed: c.isDirectional);
    final amountColor = toneColor(context, c.toneFor());
    final (bg, fg) = txnKindColors(context, c);

    final tile = ListTile(
      key: Key('journal.row.${txn.id}'),
      onTap: onTap,
      leading: CircleAvatar(
        backgroundColor: bg,
        foregroundColor: fg,
        child: Icon(txnKindIcon(c), size: 20, semanticLabel: txnKindLabel(l10n, c)),
      ),
      title: Row(
        children: [
          if (txn.isPending) ...[
            Semantics(
              label: l10n.journalPending,
              child: Container(
                width: 8,
                height: 8,
                decoration: BoxDecoration(color: scheme.tertiary, shape: BoxShape.circle),
              ),
            ),
            const SizedBox(width: 6),
          ],
          Flexible(child: Text(title, maxLines: 1, overflow: TextOverflow.ellipsis)),
          if (txn.documentPaths.isNotEmpty) ...[
            const SizedBox(width: 4),
            Icon(Icons.attach_file, size: 14, color: scheme.onSurfaceVariant, semanticLabel: l10n.journalAttachment),
          ],
        ],
      ),
      subtitle: subtitle.isEmpty
          ? null
          : Text(
              subtitle.join(' · '),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: theme.textTheme.bodySmall?.copyWith(color: scheme.onSurfaceVariant),
            ),
      trailing: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.end,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (!txn.isBalanced) ...[
                Icon(Icons.warning_amber_rounded, size: 16, color: scheme.error, semanticLabel: l10n.journalUnbalanced),
                const SizedBox(width: 4),
              ],
              Text(
                amountText,
                style: tabular(theme.textTheme.titleSmall)?.copyWith(color: amountColor),
              ),
            ],
          ),
          if (c.extraCommodities > 0)
            Text(
              '+${c.extraCommodities} ${c.amounts.skip(1).map((a) => a.commodity).join(' ')}',
              style: theme.textTheme.labelSmall?.copyWith(color: scheme.onSurfaceVariant),
            ),
        ],
      ),
    );
    if (txn.isBalanced) return tile;
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        border: Border.all(color: scheme.error),
        borderRadius: BorderRadius.circular(12),
      ),
      child: tile,
    );
  }
}

class _BalanceTile extends StatelessWidget {
  const _BalanceTile({required this.item, required this.failed, required this.format, this.onTap});

  final JournalBalance item;
  final bool failed;
  final String Function(Amount) format;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final posting = item.postings.isEmpty ? null : item.postings.first;
    final account = posting?.account ?? item.narration ?? '';
    final title = item.isPad
        ? l10n.journalBalancePad
        : (failed ? l10n.journalBalanceFailed : l10n.journalBalanceCheck);
    final amount = posting == null ? null : (item.isPad ? posting.inferredUnit : posting.accountAfter);
    final iconColor = failed ? scheme.error : scheme.onSurfaceVariant;
    return ListTile(
      key: Key('journal.row.${item.id}'),
      onTap: onTap,
      leading: CircleAvatar(
        backgroundColor: failed ? scheme.errorContainer : scheme.surfaceContainerHighest,
        foregroundColor: iconColor,
        child: Icon(
          item.isPad ? Icons.balance : (failed ? Icons.cancel_outlined : Icons.fact_check_outlined),
          size: 20,
        ),
      ),
      title: Text(
        title,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: failed ? TextStyle(color: scheme.error) : null,
      ),
      subtitle: Text(
        accountLabel(account),
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: theme.textTheme.bodySmall?.copyWith(color: scheme.onSurfaceVariant),
      ),
      trailing: amount == null
          ? null
          : Text(
              format(amount),
              style: tabular(theme.textTheme.titleSmall)?.copyWith(color: context.zhangColors.neutral),
            ),
    );
  }
}

/// Date header of a day group: "Today · Fri, Oct 2" and the day's net
/// (positive in income colour, negative in neutral colour – design P-17).
/// [net] is hidden when `null` (day may continue on the next page).
class DayHeader extends ConsumerWidget {
  const DayHeader({super.key, required this.day, this.net});

  final DateTime day;
  final Amount? net;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final commodities = ref.watch(commoditiesProvider).value;
    final style = theme.textTheme.labelLarge?.copyWith(color: scheme.onSurfaceVariant);
    final n = net;
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
      child: Row(
        children: [
          Expanded(child: Text(dayLabel(context, day), style: style)),
          if (n != null && !n.isZero)
            Text(
              formatAmount(n, commodities, signed: true),
              style: tabular(style)?.copyWith(
                color: n.isNegative ? context.zhangColors.neutral : context.zhangColors.income,
              ),
            ),
        ],
      ),
    );
  }
}

/// "Today · Fri, Oct 2" / "今天 · 10月2日周五"; the year is added when it is
/// not the current one.
String dayLabel(BuildContext context, DateTime day, {DateTime? now}) {
  final l10n = context.l10n;
  final locale = Localizations.localeOf(context).toLanguageTag();
  final today = now ?? DateTime.now();
  final date = day.year == today.year
      ? DateFormat.MMMEd(locale).format(day)
      : DateFormat.yMMMEd(locale).format(day);
  final d = DateTime(day.year, day.month, day.day);
  if (d == DateTime(today.year, today.month, today.day)) return '${l10n.journalToday} · $date';
  if (d == DateTime(today.year, today.month, today.day - 1)) return '${l10n.journalYesterday} · $date';
  return date;
}
