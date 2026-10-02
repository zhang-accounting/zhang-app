import 'package:decimal/decimal.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../core/utils/money.dart';
import '../../core/widgets/error_view.dart';
import '../../data/models/account.dart';
import '../../data/models/commodity.dart';
import '../../data/repositories/ledger_data_providers.dart';
import '../../l10n/l10n.dart';
import '../../router.dart';
import 'accounts_providers.dart';
import 'widgets/amount_format.dart';
import 'widgets/balance_history_chart.dart';

/// Location of the account detail page inside the tab [base] (the Accounts
/// tab by default; Reports pushes `/reports/accounts/<name>` so the user
/// stays in the Reports tab).
String accountDetailLocation(String name, {String base = AppRoutes.accounts}) =>
    '$base/${Uri.encodeComponent(name)}';

/// Account detail (S13): balances per commodity, status, balance-history
/// step chart and the account's postings with running balance.
class AccountDetailScreen extends ConsumerWidget {
  const AccountDetailScreen({super.key, required this.name});

  /// Full account name, e.g. `Assets:Bank:CMB`.
  final String name;

  Future<void> _refresh(WidgetRef ref) async {
    ref.invalidate(accountBalanceHistoryProvider(name));
    ref.invalidate(accountDetailProvider(name));
    ref.invalidate(accountJournalsProvider(name));
    await ref.read(accountJournalsProvider(name).future);
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final detail = ref.watch(accountDetailProvider(name));
    final journals = ref.watch(accountJournalsProvider(name));
    final history = ref.watch(accountBalanceHistoryProvider(name));
    final commodities = ref.watch(commoditiesProvider).value ?? const <String, Commodity>{};
    final operatingCurrency = ref.watch(ledgerOptionsProvider).value?.operatingCurrency;
    final alias = detail.value?.alias;
    final title = (alias != null && alias.isNotEmpty) ? alias : name.split(':').last;
    final type = AccountType.ofAccount(name);

    return Scaffold(
      appBar: AppBar(
        title: Text(title, overflow: TextOverflow.ellipsis),
        actions: [
          IconButton(
            tooltip: l10n.accountsCopyName,
            icon: const Icon(Icons.copy_outlined),
            onPressed: () async {
              await Clipboard.setData(ClipboardData(text: name));
              if (!context.mounted) return;
              ScaffoldMessenger.of(context)
                ..hideCurrentSnackBar()
                ..showSnackBar(SnackBar(content: Text(l10n.accountsNameCopied)));
            },
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: () => _refresh(ref),
        child: CustomScrollView(
          key: const Key('accountDetail.list'),
          physics: const AlwaysScrollableScrollPhysics(),
          slivers: [
            SliverToBoxAdapter(
              child: detail.when(
                data: (d) => _Header(detail: d, commodities: commodities),
                loading: () => const SizedBox(
                  height: 120,
                  child: Center(child: CircularProgressIndicator()),
                ),
                error: (e, _) => ErrorView(
                  error: e,
                  onRetry: () => ref.invalidate(accountDetailProvider(name)),
                ),
              ),
            ),
            SliverToBoxAdapter(
              child: history.when(
                data: (h) => BalanceHistoryCard(
                  history: h,
                  commodities: commodities,
                  preferredCommodity: operatingCurrency,
                ),
                loading: () => const SizedBox(height: 120),
                error: (e, _) => ErrorView(
                  error: e,
                  onRetry: () => ref.invalidate(accountBalanceHistoryProvider(name)),
                ),
              ),
            ),
            SliverToBoxAdapter(child: _JournalHeader()),
            ...journals.when(
              data: (list) => list.isEmpty
                  ? [
                      SliverToBoxAdapter(
                        child: Padding(
                          padding: const EdgeInsets.all(32),
                          child: Text(
                            l10n.accountsNoTransactions,
                            key: const Key('accountDetail.empty'),
                            textAlign: TextAlign.center,
                            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                              color: Theme.of(context).colorScheme.onSurfaceVariant,
                            ),
                          ),
                        ),
                      ),
                    ]
                  : [
                      SliverList.builder(
                        itemCount: list.length,
                        itemBuilder: (context, i) => _JournalTile(
                          key: i == 0 ? const Key('accountDetail.firstRow') : null,
                          entry: list[i],
                          type: type,
                          commodities: commodities,
                        ),
                      ),
                    ],
              loading: () => [
                const SliverToBoxAdapter(
                  child: Padding(
                    padding: EdgeInsets.all(32),
                    child: Center(child: CircularProgressIndicator()),
                  ),
                ),
              ],
              error: (e, _) => [
                SliverToBoxAdapter(
                  child: ErrorView(
                    error: e,
                    onRetry: () => ref.invalidate(accountJournalsProvider(name)),
                  ),
                ),
              ],
            ),
            const SliverToBoxAdapter(child: SizedBox(height: 96)),
          ],
        ),
      ),
    );
  }
}

class _Header extends StatelessWidget {
  const _Header({required this.detail, required this.commodities});

  final AccountDetail detail;
  final Map<String, Commodity> commodities;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final balances = detail.amount.nonZeroDetail;
    final locale = Localizations.localeOf(context).toLanguageTag();
    final big = amountStyle(theme.textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w600));
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SelectableText(detail.name, style: accountPathStyle(context)),
          const SizedBox(height: 8),
          if (balances.isEmpty)
            Text(
              formatAmount(commodities, Decimal.zero, detail.amount.calculated.commodity),
              key: const Key('accountDetail.balance'),
              style: big,
            )
          else
            for (final (i, b) in balances.indexed)
              FittedBox(
                fit: BoxFit.scaleDown,
                alignment: Alignment.centerLeft,
                child: Text(
                  formatAmount(commodities, b.number, b.commodity),
                  key: i == 0 ? const Key('accountDetail.balance') : null,
                  style: big,
                ),
              ),
          if (balances.length > 1)
            Text(
              l10n.accountsConvertedTotal(
                formatAmount(
                  commodities,
                  detail.amount.calculated.number,
                  detail.amount.calculated.commodity,
                ),
              ),
              style: amountStyle(theme.textTheme.bodyMedium?.copyWith(color: scheme.onSurfaceVariant)),
            ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 4,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              Chip(
                avatar: Icon(
                  detail.isOpen ? Icons.check_circle_outline : Icons.block,
                  size: 16,
                ),
                label: Text(detail.isOpen ? l10n.accountsOpenBadge : l10n.accountsClosedBadge),
                visualDensity: VisualDensity.compact,
              ),
              Text(
                l10n.accountsOpened(DateFormat.yMMMd(locale).format(detail.openDate)),
                style: theme.textTheme.bodySmall?.copyWith(color: scheme.onSurfaceVariant),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _JournalHeader extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final theme = Theme.of(context);
    final style = theme.textTheme.labelMedium?.copyWith(color: theme.colorScheme.onSurfaceVariant);
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 4),
      child: Row(
        children: [
          Expanded(child: Text(l10n.accountsTransactions, style: theme.textTheme.titleSmall)),
          Text(l10n.accountsRunningBalance, style: style),
        ],
      ),
    );
  }
}

class _JournalTile extends StatelessWidget {
  const _JournalTile({super.key, required this.entry, required this.type, required this.commodities});

  final AccountJournalEntry entry;
  final AccountType? type;
  final Map<String, Commodity> commodities;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final unit = entry.inferredUnit;
    final isCheck = entry.payee == 'Balance Check';
    final isPad = entry.payee == 'Balance Pad';
    final title = isCheck
        ? l10n.accountsBalanceCheck
        : isPad
        ? l10n.accountsBalancePad
        : (entry.payee?.isNotEmpty ?? false)
        ? entry.payee!
        : (entry.narration ?? '');
    final date = DateFormat('yyyy-MM-dd HH:mm').format(entry.datetime);
    final narration = entry.isBalanceItem ? null : entry.narration;
    final subtitle = [date, if (narration != null && narration.isNotEmpty && narration != title) narration]
        .join(' · ');

    // Earned income and spent expenses are shown in the income / expense
    // colours; asset and liability postings by direction; equity neutral.
    final Color amountColorValue = switch (type) {
      AccountType.income || AccountType.expenses => amountColor(context, unit.number, invert: true),
      AccountType.equity || null => scheme.onSurfaceVariant,
      _ => amountColor(context, unit.number),
    };
    final IconData icon = entry.isBalanceItem
        ? Icons.fact_check_outlined
        : (unit.isNegative ? Icons.north_east : Icons.south_west);

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Row(
        children: [
          CircleAvatar(
            radius: 16,
            backgroundColor: scheme.surfaceContainerHighest,
            child: Icon(icon, size: 16, color: scheme.onSurfaceVariant),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: theme.textTheme.bodyLarge, maxLines: 1, overflow: TextOverflow.ellipsis),
                Text(
                  subtitle,
                  style: theme.textTheme.bodySmall?.copyWith(color: scheme.onSurfaceVariant),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                formatAmount(commodities, unit.number, unit.commodity, signed: !entry.isBalanceItem),
                style: amountStyle(theme.textTheme.titleSmall?.copyWith(color: amountColorValue)),
              ),
              Text(
                formatAmount(commodities, entry.accountAfter.number, entry.accountAfter.commodity),
                style: amountStyle(theme.textTheme.bodySmall?.copyWith(color: scheme.onSurfaceVariant)),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
