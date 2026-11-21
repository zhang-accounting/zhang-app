import 'package:flutter/widgets.dart';
import 'package:go_router/go_router.dart';

import '../../data/models/journal.dart';
import '../../data/models/written_transaction.dart';
import '../../router.dart';
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
      expectedVersion: state.uri.queryParameters['v'],
    );
  }
}

/// Opens the transaction of a posting listed on an account page
/// ([accountLocation] = that page's location); [hint] (payee or narration)
/// speeds up the lookup; [version] (the row's `trx_version`) tells a
/// transaction that changed since the row was listed.
void openAccountPostingDetail(
  BuildContext context,
  String accountLocation,
  String transactionId,
  String? hint, {
  String? version,
}) {
  context.push('$accountLocation/transactions/${Uri.encodeComponent(transactionId)}${_lookup(hint, version)}');
}

/// The query of a detail route without its item: `q` = [hint] to search
/// for, `v` = the [version] it was listed with.
String _lookup(String? hint, String? version) {
  final query = [
    if (hint != null && hint.trim().isNotEmpty) 'q=${Uri.encodeQueryComponent(hint.trim())}',
    if (version != null && version.isNotEmpty) 'v=${Uri.encodeQueryComponent(version)}',
  ];
  return query.isEmpty ? '' : '?${query.join('&')}';
}

/// Opens the transaction a create just wrote, by the id the server answered
/// ([WrittenTransaction.id], zhang ≥ 0.3): in the Home tab when [router]
/// shows it, else in the Journal tab. [hint] (payee, narration or an
/// account) speeds up the lookup; its version makes the screen say
/// "changed" instead of showing another transaction once the id moved.
void openWrittenTransaction(GoRouter router, WrittenTransaction written, {String? hint}) {
  final id = written.id;
  if (id == null) return;
  final here = router.routerDelegate.currentConfiguration.uri.path;
  final detail = here.startsWith(AppRoutes.home) ? JournalRoutes.homeDetail(id) : JournalRoutes.journalDetail(id);
  router.push('$detail${_lookup(hint, written.version)}');
}

/// Opens the detail of [item] from the Journal tab, passing the item as
/// route `extra` so no request is needed.
void openJournalDetail(BuildContext context, JournalItem item) =>
    context.push(JournalRoutes.journalDetail(item.id), extra: item);

/// Same from the Home tab.
void openHomeJournalDetail(BuildContext context, JournalItem item) =>
    context.push(JournalRoutes.homeDetail(item.id), extra: item);
