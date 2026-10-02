import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../l10n/l10n.dart';
import '../../router.dart';

/// One bottom-navigation destination. Order must match the
/// `StatefulShellBranch` order in `lib/router.dart`.
class ShellDestination {
  const ShellDestination(this.icon, this.selectedIcon, this.label);

  final IconData icon;
  final IconData selectedIcon;
  final String Function(AppLocalizations l10n) label;
}

final shellDestinations = <ShellDestination>[
  ShellDestination(Icons.home_outlined, Icons.home, (l) => l.tabHome),
  ShellDestination(Icons.receipt_long_outlined, Icons.receipt_long, (l) => l.tabJournal),
  ShellDestination(Icons.bar_chart_outlined, Icons.bar_chart, (l) => l.tabReports),
  ShellDestination(
    Icons.account_balance_wallet_outlined,
    Icons.account_balance_wallet,
    (l) => l.tabAccounts,
  ),
];

/// Main scaffold: a standard Material 3 [NavigationBar] with four tabs
/// (Home, Journal, Reports, Accounts) and a regular FAB above the bar that
/// opens `/transactions/new`.
class AppShell extends StatelessWidget {
  const AppShell({super.key, required this.navigationShell});

  final StatefulNavigationShell navigationShell;

  void _onTap(int index) => navigationShell.goBranch(
    index,
    // Tapping the active tab again pops it back to its root.
    initialLocation: index == navigationShell.currentIndex,
  );

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return Scaffold(
      body: navigationShell,
      floatingActionButton: FloatingActionButton(
        key: const Key('shell.newTransaction'),
        tooltip: l10n.newTransactionTitle,
        onPressed: () => context.push(AppRoutes.newTransaction),
        child: const Icon(Icons.add),
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: navigationShell.currentIndex,
        onDestinationSelected: _onTap,
        labelBehavior: NavigationDestinationLabelBehavior.alwaysShow,
        destinations: [
          for (final d in shellDestinations)
            NavigationDestination(
              icon: Icon(d.icon),
              selectedIcon: Icon(d.selectedIcon),
              label: d.label(l10n),
            ),
        ],
      ),
    );
  }
}
