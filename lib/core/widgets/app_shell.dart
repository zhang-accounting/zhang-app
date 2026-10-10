import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../data/repositories/ledger_data_providers.dart';
import '../../l10n/l10n.dart';
import '../../router.dart';
import 'ledger_widgets.dart';

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
///
/// Version gate: the tabs are only built once `GET /api/info` of the active
/// server is known ([serverGateProvider]). A server older than zhang 0.2 (no
/// `format` key) gets [ServerTooOldView] instead, and nothing else is
/// requested from it. When `/api/info` itself fails (offline, 401) the tabs
/// are shown and report the error themselves.
class AppShell extends ConsumerWidget {
  const AppShell({super.key, required this.navigationShell});

  final StatefulNavigationShell navigationShell;

  void _onTap(int index) => navigationShell.goBranch(
    index,
    // Tapping the active tab again pops it back to its root.
    initialLocation: index == navigationShell.currentIndex,
  );

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final gate = ref.watch(serverGateProvider);
    // After a profile switch the previous value belongs to the other server.
    final unknown = !gate.hasValue && !gate.hasError || gate.isReloading;
    final tooOld = !unknown && !gate.hasError && !gate.requireValue.isSupported;
    final Widget body;
    if (unknown) {
      body = const _GateLoading();
    } else if (tooOld) {
      body = ServerTooOldView(version: gate.requireValue.version);
    } else {
      body = navigationShell;
    }
    final ready = identical(body, navigationShell);
    return Scaffold(
      body: body,
      floatingActionButton: ready
          ? FloatingActionButton(
              key: const Key('shell.newTransaction'),
              tooltip: l10n.newTransactionTitle,
              onPressed: () => context.push(AppRoutes.newTransaction),
              child: const Icon(Icons.add),
            )
          : null,
      bottomNavigationBar: NavigationBar(
        selectedIndex: navigationShell.currentIndex,
        onDestinationSelected: ready ? _onTap : null,
        labelBehavior: NavigationDestinationLabelBehavior.alwaysShow,
        destinations: [
          for (final d in shellDestinations)
            NavigationDestination(
              icon: Icon(d.icon),
              selectedIcon: Icon(d.selectedIcon),
              label: d.label(l10n),
              enabled: ready,
            ),
        ],
      ),
    );
  }
}

class _GateLoading extends StatelessWidget {
  const _GateLoading();

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const ActiveLedgerTitle(), actions: const [SettingsButton()]),
    body: const Center(child: CircularProgressIndicator(key: Key('shell.gateLoading'))),
  );
}

/// Full-screen "server too old" message (zhang < 0.2): the app reads every
/// figure from the built-in query API that older servers lack.
class ServerTooOldView extends ConsumerWidget {
  const ServerTooOldView({super.key, required this.version});

  /// Version reported by the server.
  final String version;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(title: const ActiveLedgerTitle(), actions: const [SettingsButton()]),
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Column(
            key: const Key('shell.tooOld'),
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.update, size: 56, color: theme.colorScheme.error),
              const SizedBox(height: 16),
              Text(l10n.serverTooOldTitle, style: theme.textTheme.titleLarge, textAlign: TextAlign.center),
              const SizedBox(height: 8),
              Text(l10n.errorServerTooOld, style: theme.textTheme.bodyLarge, textAlign: TextAlign.center),
              const SizedBox(height: 8),
              Text(
                l10n.serverTooOldVersion(version),
                style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.onSurfaceVariant),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 16),
              FilledButton.tonalIcon(
                key: const Key('shell.tooOldRetry'),
                onPressed: () => ref.invalidate(serverGateProvider),
                icon: const Icon(Icons.refresh),
                label: Text(l10n.retry),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
