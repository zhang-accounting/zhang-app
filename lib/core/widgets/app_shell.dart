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

/// Main scaffold: four tabs (Home, Journal | Reports, Accounts) around a
/// notched, centre-docked "New" FAB that opens `/transactions/new`.
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
    final half = shellDestinations.length ~/ 2;
    Widget item(int i) => Expanded(
      child: _NavItem(
        destination: shellDestinations[i],
        label: shellDestinations[i].label(l10n),
        selected: navigationShell.currentIndex == i,
        onTap: () => _onTap(i),
      ),
    );
    return Scaffold(
      body: navigationShell,
      floatingActionButton: FloatingActionButton(
        key: const Key('shell.newTransaction'),
        tooltip: l10n.newTransactionTitle,
        shape: const CircleBorder(),
        onPressed: () => context.push(AppRoutes.newTransaction),
        child: const Icon(Icons.add, size: 30),
      ),
      floatingActionButtonLocation: FloatingActionButtonLocation.centerDocked,
      bottomNavigationBar: BottomAppBar(
        shape: const CircularNotchedRectangle(),
        notchMargin: 6,
        padding: const EdgeInsets.symmetric(horizontal: 4),
        height: 68,
        child: Row(
          children: [
            for (var i = 0; i < half; i++) item(i),
            SizedBox(
              width: 72,
              child: Align(
                alignment: Alignment.bottomCenter,
                child: Padding(
                  padding: const EdgeInsets.only(bottom: 6),
                  child: Text(
                    l10n.newTransaction,
                    style: Theme.of(context).textTheme.labelSmall,
                  ),
                ),
              ),
            ),
            for (var i = half; i < shellDestinations.length; i++) item(i),
          ],
        ),
      ),
    );
  }
}

class _NavItem extends StatelessWidget {
  const _NavItem({
    required this.destination,
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final ShellDestination destination;
  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final color = selected ? scheme.primary : scheme.onSurfaceVariant;
    return Semantics(
      selected: selected,
      button: true,
      label: label,
      excludeSemantics: true,
      child: InkResponse(
        onTap: onTap,
        radius: 36,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(selected ? destination.selectedIcon : destination.icon, color: color),
            const SizedBox(height: 2),
            Text(
              label,
              style: Theme.of(context).textTheme.labelSmall?.copyWith(
                color: color,
                fontWeight: selected ? FontWeight.w600 : FontWeight.w400,
              ),
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
      ),
    );
  }
}
