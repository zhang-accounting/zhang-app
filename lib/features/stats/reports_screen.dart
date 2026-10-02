import 'package:flutter/material.dart';

import '../../core/widgets/ledger_widgets.dart';
import '../../l10n/l10n.dart';

/// Reports tab – PLACEHOLDER (to be replaced by the stats feature).
class ReportsScreen extends StatelessWidget {
  const ReportsScreen({super.key});

  @override
  Widget build(BuildContext context) =>
      PlaceholderScreen(title: context.l10n.tabReports, icon: Icons.bar_chart_outlined);
}
