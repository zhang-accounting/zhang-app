import 'package:flutter/material.dart';

import '../../core/widgets/ledger_widgets.dart';
import '../../l10n/l10n.dart';

/// `/transactions/new` – PLACEHOLDER (to be replaced by the new-transaction
/// feature). Opened full-screen from the shell's centre FAB.
class NewTransactionScreen extends StatelessWidget {
  const NewTransactionScreen({super.key});

  @override
  Widget build(BuildContext context) =>
      PlaceholderScreen(title: context.l10n.newTransactionTitle, icon: Icons.edit_note);
}
