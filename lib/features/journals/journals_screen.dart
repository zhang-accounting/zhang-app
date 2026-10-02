import 'package:flutter/material.dart';

import '../../core/widgets/ledger_widgets.dart';
import '../../l10n/l10n.dart';

/// Journal tab – PLACEHOLDER (to be replaced by the journals feature).
class JournalsScreen extends StatelessWidget {
  const JournalsScreen({super.key});

  @override
  Widget build(BuildContext context) =>
      PlaceholderScreen(title: context.l10n.tabJournal, icon: Icons.receipt_long_outlined);
}
