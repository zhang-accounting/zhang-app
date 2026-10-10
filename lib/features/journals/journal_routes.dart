import 'package:flutter/widgets.dart';
import 'package:go_router/go_router.dart';

import '../../data/models/journal.dart';
import 'transaction_detail_screen.dart';

/// Routes of the transaction detail screen (S08). It is registered under
/// every tab that lists transactions so the bottom bar keeps the current
/// tab: `/journals/:id` (Journal tab), `/home/transactions/:id` (Home tab)
/// and `<account detail>/transactions/:id?q=<payee>` (Accounts and Reports
/// tabs). The [JournalItem] is passed as route `extra`; without it the
/// screen looks the id up (searching for `q` when given).
abstract final class JournalRoutes {
  static String journalDetail(String id) => '/journals/${Uri.encodeComponent(id)}';
  static String homeDetail(String id) => '/home/transactions/${Uri.encodeComponent(id)}';

  /// Child of the `/journals` route.
  static GoRoute journalDetailRoute() => GoRoute(path: ':id', builder: _detail);

  /// Child of the `/home` route.
  static GoRoute homeDetailRoute() => GoRoute(path: 'transactions/:id', builder: _detail);

  /// Child of an account detail route.
  static GoRoute accountDetailRoute() => GoRoute(path: 'transactions/:id', builder: _detail);

  static Widget _detail(BuildContext context, GoRouterState state) {
    final extra = state.extra;
    return TransactionDetailScreen(
      id: state.pathParameters['id']!,
      initial: extra is JournalItem ? extra : null,
      searchHint: state.uri.queryParameters['q'],
    );
  }
}

/// Opens the transaction of a posting listed on an account page
/// ([accountLocation] = that page's location); [hint] (payee or narration)
/// speeds up the lookup.
void openAccountPostingDetail(BuildContext context, String accountLocation, String transactionId, String? hint) {
  final query = hint == null || hint.trim().isEmpty ? '' : '?q=${Uri.encodeQueryComponent(hint.trim())}';
  context.push('$accountLocation/transactions/${Uri.encodeComponent(transactionId)}$query');
}

/// Opens the detail of [item] from the Journal tab, passing the item as
/// route `extra` so no request is needed.
void openJournalDetail(BuildContext context, JournalItem item) =>
    context.push(JournalRoutes.journalDetail(item.id), extra: item);

/// Same from the Home tab.
void openHomeJournalDetail(BuildContext context, JournalItem item) =>
    context.push(JournalRoutes.homeDetail(item.id), extra: item);
