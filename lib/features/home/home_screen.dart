import 'package:flutter/material.dart';

import '../../core/widgets/ledger_widgets.dart';
import '../../l10n/l10n.dart';

/// Home tab – PLACEHOLDER (to be replaced by the home feature).
/// Keep `ActiveLedgerTitle` + `SettingsButton` in the app bar: settings are
/// only reachable from here.
class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return Scaffold(
      appBar: AppBar(
        title: const ActiveLedgerTitle(),
        actions: const [SettingsButton()],
      ),
      body: PlaceholderBody(title: l10n.tabHome, icon: Icons.home_outlined),
    );
  }
}
