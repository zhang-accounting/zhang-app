import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/widgets/error_view.dart';
import '../../data/models/account.dart';
import '../../data/models/journal.dart';
import '../../data/repositories/journal_repository.dart';
import '../../l10n/l10n.dart';
import '../../router.dart';
import '../account_picker/account_picker_data.dart';
import '../transaction_new/advanced_entry_screen.dart';
import '../transaction_new/transaction_edit.dart';
import 'journal_providers.dart';

/// The edit, copy and delete actions of the transaction detail screen (S08).
///
/// Which editor: a transaction that fits a simple mode exactly
/// ([simpleFitFor]: two opposite postings in one commodity, no cost / price,
/// open accounts of the mode's types) opens in the simple form, which keeps
/// whatever else it has; anything else opens in the advanced editor.

/// Localised reason [block] stops an edit.
String editBlockMessage(AppLocalizations l10n, EditBlock block) => switch (block) {
  EditBlock.notTransaction => l10n.trxEditBlockedNotTransaction,
  EditBlock.unknownShape => l10n.trxEditBlockedUnknownShape,
  EditBlock.notWritten => l10n.trxEditBlockedNotWritten,
  EditBlock.dropsText => l10n.trxEditBlockedDropsText,
  EditBlock.postingFlag => l10n.trxEditBlockedPostingFlag,
  EditBlock.unverified => l10n.trxEditBlockedUnverified,
};

/// Checks that [tx] can be edited without losing anything ([checkEditable];
/// [onChecked] once the server answered) and opens it in the matching
/// editor. Returns what the editor saved, or `null` (blocked – explained in
/// a dialog –, failed or left unsaved).
Future<EntrySaved?> editTransaction(
  BuildContext context,
  WidgetRef ref,
  JournalTransaction tx, {
  VoidCallback? onChecked,
}) async {
  final l10n = context.l10n;
  final messenger = ScaffoldMessenger.of(context);
  final EditCheck check;
  try {
    check = await checkEditable(ref.read(journalRepositoryProvider), tx);
  } catch (e) {
    onChecked?.call();
    messenger.showSnackBar(SnackBar(content: Text(isStaleEdit(e) ? l10n.editStale : describeApiError(l10n, e))));
    return null;
  }
  onChecked?.call();
  if (!context.mounted) return null;
  if (check.block case final reason?) {
    await showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        key: const Key('trx.editBlocked'),
        title: Text(l10n.trxEditBlockedTitle),
        content: Text('${editBlockMessage(l10n, reason)}\n\n${l10n.trxEditCopyHint}'),
        actions: [TextButton(onPressed: () => Navigator.of(context).pop(), child: Text(l10n.close))],
      ),
    );
    return null;
  }
  final fit = simpleFitFor(tx, await _accounts(ref));
  if (!context.mounted) return null;
  if (fit != null) {
    return context.push<EntrySaved>(AppRoutes.newTransaction, extra: EntryPrefill.edit(check.target!, fit));
  }
  return pushAdvancedEntry(context, AdvancedEntryArgs.edit(check.target!));
}

/// Opens [tx] as a new transaction dated "now" (everything but its
/// metadata, see [copyBaseOf]) in the matching editor.
Future<void> copyTransaction(BuildContext context, WidgetRef ref, JournalTransaction tx) async {
  final fit = simpleFitFor(tx, await _accounts(ref));
  if (!context.mounted) return;
  if (fit != null) {
    await context.push<EntrySaved>(AppRoutes.newTransaction, extra: EntryPrefill.copy(tx, fit));
    return;
  }
  await pushAdvancedEntry(context, AdvancedEntryArgs.copy(tx));
}

/// Whether the detail offers to delete [item]: a transaction listed with a
/// `version` (zhang ≥ 0.3), which the delete must name in `If-Match`. Ids are
/// places in a file: without the version a stale id could delete the
/// transaction that took its place, so older servers get no delete.
bool canDelete(JournalItem item) => item is JournalTransaction && item.version != null;

/// Asks before deleting the transaction [summary] describes (date, payee,
/// narration, amount). `true` = delete.
Future<bool> confirmDelete(BuildContext context, String summary) async {
  final l10n = context.l10n;
  final scheme = Theme.of(context).colorScheme;
  final go = await showDialog<bool>(
    context: context,
    builder: (context) => AlertDialog(
      key: const Key('trx.deleteDialog'),
      icon: const Icon(Icons.delete_outline),
      title: Text(l10n.trxDeleteTitle),
      content: Text(l10n.trxDeleteMessage(summary)),
      actions: [
        TextButton(onPressed: () => Navigator.of(context).pop(false), child: Text(l10n.cancel)),
        FilledButton(
          key: const Key('trx.deleteConfirm'),
          style: FilledButton.styleFrom(backgroundColor: scheme.error, foregroundColor: scheme.onError),
          onPressed: () => Navigator.of(context).pop(true),
          child: Text(l10n.delete),
        ),
      ],
    ),
  );
  return go ?? false;
}

/// A delete refused because the transaction is no longer the one opened
/// (412: changed, deleted, or another took its id; 404: the id is gone):
/// says that nothing was deleted. `true` = refresh the list.
Future<bool> showDeleteStale(BuildContext context) async {
  final l10n = context.l10n;
  final refresh = await showDialog<bool>(
    context: context,
    builder: (context) => AlertDialog(
      key: const Key('trx.deleteStale'),
      title: Text(l10n.trxDeleteStaleTitle),
      content: Text(l10n.trxDeleteStale),
      actions: [
        TextButton(onPressed: () => Navigator.of(context).pop(false), child: Text(l10n.close)),
        FilledButton(
          key: const Key('trx.deleteRefresh'),
          onPressed: () => Navigator.of(context).pop(true),
          child: Text(l10n.trxRefreshList),
        ),
      ],
    ),
  );
  return refresh ?? false;
}

/// The ledger's accounts, or none when they cannot be loaded (the advanced
/// editor needs none).
Future<List<Account>> _accounts(WidgetRef ref) async {
  try {
    return await ref.read(pickerAccountsProvider.future);
  } catch (_) {
    return const [];
  }
}

/// The transaction [id] read again after an edit, at a ledger revision
/// (`(id, hint, revision)`): [JournalRepository.findById] on the server –
/// never the loaded journal pages, which may still hold the old version.
/// `null` = not found.
final editedTransactionProvider = FutureProvider.autoDispose.family<JournalItem?, (String, String?, int)>((
  ref,
  arg,
) {
  final (id, hint, _) = arg;
  return ref.watch(journalRepositoryProvider).findById(id, keyword: hint);
}, retry: browseRetry);
