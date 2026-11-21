import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../data/models/written_transaction.dart';
import '../../../l10n/l10n.dart';
import '../../journals/journal_routes.dart';

/// The snackbar after a save: [message], with a "View" action that opens
/// the transaction a create wrote when the server answered its id ([written],
/// zhang ≥ 0.3) – shown once the entry screen has closed, so the action
/// keeps the app's router, not the screen's context. Without an id (an
/// older server, an edit, a save that keeps the screen open) it is the
/// plain message.
SnackBar savedSnackBar(BuildContext context, String message, {WrittenTransaction? written, String? hint}) {
  final router = GoRouter.maybeOf(context);
  final view = written?.id == null || router == null
      ? null
      : SnackBarAction(
          key: const Key('add.viewSaved'),
          label: context.l10n.addViewSaved,
          onPressed: () => openWrittenTransaction(router, written!, hint: hint),
        );
  return SnackBar(
    content: Text(message),
    action: view,
    // The transaction is in the journal anyway: the action is a shortcut,
    // not something to dismiss by hand.
    persist: false,
    duration: view == null ? const Duration(milliseconds: 4000) : const Duration(seconds: 6),
  );
}
