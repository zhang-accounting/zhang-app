import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../data/models/written_transaction.dart';
import '../../../l10n/l10n.dart';
import '../../journals/journal_routes.dart';

/// The snackbar after a save: [message], with a "View" action that opens
/// the transaction a create wrote when the server answered its id ([written],
/// zhang ≥ 0.3): in the Home tab when the entry was recorded from there,
/// else in the Journal tab ([openWrittenTransaction]). It is shown once the
/// entry screen has closed, so the action keeps the app's router, not the
/// screen's context. The id belongs to the ledger it was saved to: a profile
/// switch (a new ledger session) hides the snackbar, and its action does
/// nothing once that session has ended. Without an id (an older server, an
/// edit, a save that keeps the screen open) it is the plain message.
SnackBar savedSnackBar(BuildContext context, String message, {WrittenTransaction? written, String? hint}) {
  final router = GoRouter.maybeOf(context);
  final session = ProviderScope.containerOf(context, listen: false);
  final view = written?.id == null || router == null
      ? null
      : SnackBarAction(
          key: const Key('add.viewSaved'),
          label: context.l10n.addViewSaved,
          onPressed: () {
            final app = router.routerDelegate.navigatorKey.currentContext;
            if (app == null || !identical(ProviderScope.containerOf(app, listen: false), session)) return;
            openWrittenTransaction(router, written!, hint: hint);
          },
        );
  return SnackBar(
    content: view == null ? Text(message) : _SessionBound(session: session, child: Text(message)),
    action: view,
    // The transaction is in the journal anyway: the action is a shortcut,
    // not something to dismiss by hand.
    persist: false,
    duration: view == null ? const Duration(milliseconds: 4000) : const Duration(seconds: 6),
  );
}

/// Hides the snackbar it is in once it is no longer in [session], the ledger
/// session it was shown in: after a profile switch its action would open an
/// id of the other ledger.
class _SessionBound extends StatefulWidget {
  const _SessionBound({required this.session, required this.child});

  final ProviderContainer session;
  final Widget child;

  @override
  State<_SessionBound> createState() => _SessionBoundState();
}

class _SessionBoundState extends State<_SessionBound> {
  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // A switch moves the app into the new session's scope: this runs again.
    if (identical(ProviderScope.containerOf(context), widget.session)) return;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) ScaffoldMessenger.maybeOf(context)?.hideCurrentSnackBar();
    });
  }

  @override
  Widget build(BuildContext context) => widget.child;
}
