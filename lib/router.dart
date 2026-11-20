import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'core/widgets/app_shell.dart';
import 'data/profiles/profile_providers.dart';
import 'features/accounts/account_detail_screen.dart';
import 'features/accounts/accounts_screen.dart';
import 'features/budgets/budget_detail_screen.dart';
import 'features/budgets/budget_routes.dart';
import 'features/documents/documents_screen.dart';
import 'features/home/home_screen.dart';
import 'features/journals/journal_routes.dart';
import 'features/journals/journals_screen.dart';
import 'features/onboarding/server_setup_screen.dart';
import 'features/settings/profile_edit_screen.dart';
import 'features/settings/settings_screen.dart';
import 'features/stats/reports_screen.dart';
import 'features/transaction_new/entry_mode.dart';
import 'features/transaction_new/new_transaction_screen.dart';

/// Every route path in one place. Use with `context.go` / `context.push`.
abstract final class AppRoutes {
  static const onboarding = '/onboarding';

  // Bottom-nav tabs (StatefulShellRoute branches, in this order).
  static const home = '/home';
  static const journals = '/journals';
  static const reports = '/reports';
  static const accounts = '/accounts';

  // Pages inside a tab.
  static const documents = '/accounts/documents';

  // Full-screen routes on the root navigator (cover the bottom nav).
  static const newTransaction = '/transactions/new';
  static const settings = '/settings';
  static const addProfile = '/settings/profiles/new';
  static String editProfile(String id) => '/settings/profiles/$id/edit';
}

final rootNavigatorKey = GlobalKey<NavigatorState>(debugLabel: 'root');

/// The app router. `LedgerSessionHost` creates one for the app's lifetime
/// (with [createAppRouter]) and hands it to every ledger session, so a
/// profile switch keeps the navigation stack. Without the host (widget tests
/// that pump `ZhangApp` in one container) this default builds its own.
final routerProvider = Provider<GoRouter>((ref) {
  final hasProfile = ValueNotifier<bool>(ref.read(activeProfileProvider) != null);
  ref.listen(
    activeProfileProvider.select((p) => p != null),
    (_, next) => hasProfile.value = next,
  );
  final router = createAppRouter(hasProfile);
  ref.onDispose(() {
    router.dispose();
    hasProfile.dispose();
  });
  return router;
});

/// Builds the app's [GoRouter]. Redirects re-run whenever [hasProfile]
/// changes (no active profile → `/onboarding`).
GoRouter createAppRouter(ValueListenable<bool> hasProfile) {
  return GoRouter(
    navigatorKey: rootNavigatorKey,
    initialLocation: AppRoutes.home,
    refreshListenable: hasProfile,
    redirect: (context, state) {
      final atOnboarding = state.matchedLocation == AppRoutes.onboarding;
      if (!hasProfile.value) return atOnboarding ? null : AppRoutes.onboarding;
      if (atOnboarding) return AppRoutes.home;
      return null;
    },
    routes: [
      GoRoute(path: '/', redirect: (_, _) => AppRoutes.home),
      GoRoute(
        path: AppRoutes.onboarding,
        builder: (context, state) => const ServerSetupScreen(),
      ),
      StatefulShellRoute.indexedStack(
        builder: (context, state, navigationShell) =>
            AppShell(navigationShell: navigationShell),
        branches: [
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: AppRoutes.home,
                builder: (context, state) => const HomeScreen(),
                routes: [JournalRoutes.homeDetailRoute()],
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: AppRoutes.journals,
                builder: (context, state) => const JournalsScreen(),
                routes: [JournalRoutes.journalDetailRoute()],
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: AppRoutes.reports,
                builder: (context, state) => const ReportsScreen(),
                routes: [
                  // Account detail opened from a report row (stays in this tab).
                  GoRoute(
                    path: 'accounts/:name',
                    builder: (context, state) =>
                        AccountDetailScreen(name: state.pathParameters['name']!),
                    routes: [JournalRoutes.accountDetailRoute()],
                  ),
                  // `/reports/budgets/<YYYY-MM>/<name>`, see budgetDetailLocation().
                  GoRoute(
                    path: 'budgets/:month/:name',
                    builder: (context, state) => BudgetDetailScreen(
                      name: state.pathParameters['name']!,
                      month: parseBudgetMonth(state.pathParameters['month']!) ??
                          DateTime(DateTime.now().year, DateTime.now().month),
                    ),
                    routes: [JournalRoutes.accountDetailRoute()],
                  ),
                ],
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: AppRoutes.accounts,
                builder: (context, state) => const AccountsScreen(),
                routes: [
                  // Before `:name` (no account is called `documents`).
                  GoRoute(path: 'documents', builder: (context, state) => const DocumentsScreen()),
                  // `/accounts/<percent-encoded name>`, see accountDetailLocation().
                  GoRoute(
                    path: ':name',
                    builder: (context, state) =>
                        AccountDetailScreen(name: state.pathParameters['name']!),
                    routes: [JournalRoutes.accountDetailRoute()],
                  ),
                ],
              ),
            ],
          ),
        ],
      ),
      GoRoute(
        path: AppRoutes.newTransaction,
        // `?mode=expense|income|transfer` preselects the entry mode.
        builder: (context, state) => NewTransactionScreen(
          initialMode: EntryMode.fromQuery(state.uri.queryParameters['mode']),
        ),
      ),
      GoRoute(
        path: AppRoutes.settings,
        builder: (context, state) => const SettingsScreen(),
        routes: [
          GoRoute(
            path: 'profiles/new',
            builder: (context, state) => const ServerSetupScreen(showWelcome: false),
          ),
          GoRoute(
            path: 'profiles/:id/edit',
            builder: (context, state) =>
                ProfileEditScreen(profileId: state.pathParameters['id']!),
          ),
        ],
      ),
    ],
  );
}
