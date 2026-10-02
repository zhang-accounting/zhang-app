import 'package:decimal/decimal.dart';
import 'package:flutter/material.dart';

import '../../../data/models/commodity.dart';
import '../../../l10n/l10n.dart';
import '../account_tree.dart';
import 'amount_format.dart';

/// Net worth hero card: total, Assets / Liabilities split and where the
/// number comes from (sum of account balances in the operating currency).
class NetWorthCard extends StatelessWidget {
  const NetWorthCard({super.key, required this.netWorth, required this.commodities});

  final NetWorth netWorth;
  final Map<String, Commodity> commodities;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final muted = theme.textTheme.bodySmall?.copyWith(color: scheme.onSurfaceVariant);
    String fmt(Decimal value) => formatAmount(commodities, value, netWorth.commodity);

    Widget part(String label, String value, Key key) => Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: theme.textTheme.labelMedium?.copyWith(color: scheme.onSurfaceVariant)),
        Text(value, key: key, style: amountStyle(theme.textTheme.titleMedium)),
      ],
    );

    return Card.filled(
      margin: const EdgeInsets.fromLTRB(16, 8, 16, 8),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              l10n.accountsNetWorth,
              style: theme.textTheme.labelLarge?.copyWith(color: scheme.onSurfaceVariant),
            ),
            const SizedBox(height: 2),
            FittedBox(
              fit: BoxFit.scaleDown,
              alignment: Alignment.centerLeft,
              child: Text(
                fmt(netWorth.net),
                key: const Key('accounts.netWorth'),
                style: amountStyle(theme.textTheme.headlineMedium?.copyWith(fontWeight: FontWeight.w600)),
              ),
            ),
            const SizedBox(height: 10),
            Wrap(
              spacing: 24,
              runSpacing: 8,
              children: [
                part(l10n.accountsAssets, fmt(netWorth.assets), const Key('accounts.netWorth.assets')),
                part(
                  l10n.accountsLiabilities,
                  fmt(netWorth.liabilities),
                  const Key('accounts.netWorth.liabilities'),
                ),
              ],
            ),
            const SizedBox(height: 10),
            Text(l10n.accountsNetWorthSource(netWorth.commodity), style: muted),
            if (netWorth.unconverted.isNotEmpty) ...[
              const SizedBox(height: 4),
              Row(
                children: [
                  Icon(Icons.info_outline, size: 14, color: scheme.onSurfaceVariant),
                  const SizedBox(width: 4),
                  Expanded(
                    child: Text(
                      l10n.accountsNotInTotal(netWorth.unconverted.join(', ')),
                      style: muted,
                    ),
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }
}
