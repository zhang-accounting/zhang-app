import 'package:flutter/material.dart';

import '../../core/widgets/ledger_widgets.dart';
import '../../l10n/l10n.dart';

/// Accounts tab – PLACEHOLDER (to be replaced by the accounts feature).
class AccountsScreen extends StatelessWidget {
  const AccountsScreen({super.key});

  @override
  Widget build(BuildContext context) => PlaceholderScreen(
    title: context.l10n.tabAccounts,
    icon: Icons.account_balance_wallet_outlined,
  );
}
