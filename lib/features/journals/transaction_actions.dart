import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/widgets/error_view.dart';
import '../../data/api/api_exception.dart';
import '../../data/models/account.dart';
import '../../data/models/journal.dart';
import '../../data/repositories/journal_repository.dart';
import '../../l10n/l10n.dart';
import '../../router.dart';
import '../account_picker/account_picker_data.dart';
import '../transaction_new/advanced_entry_screen.dart';
import '../transaction_new/transaction_edit.dart';
import 'journal_providers.dart';

/// The edit and copy actions of the transaction detail screen (S08).
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
  final EditBlock? block;
  try {
    block = await checkEditable(ref.read(journalRepositoryProvider), tx);
  } catch (e) {
    onChecked?.call();
    final message = e is ApiNotFound && !e.isMissingRoute ? l10n.editStale : describeApiError(l10n, e);
    messenger.showSnackBar(SnackBar(content: Text(message)));
    return null;
  }
  onChecked?.call();
  if (!context.mounted) return null;
  if (block case final reason?) {
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
    return context.push<EntrySaved>(AppRoutes.newTransaction, extra: EntryPrefill.edit(tx, fit));
  }
  return pushAdvancedEntry(context, AdvancedEntryArgs.edit(tx));
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

/// The ledger's accounts, or none when they cannot be loaded (the advanced
/// editor needs none).
Future<List<Account>> _accounts(WidgetRef ref) async {
  try {
    return await ref.read(pickerAccountsProvider.future);
  } catch (_) {
    return const [];
  }
}

/// The transaction [id] read again after an edit, once the ledger revision
/// is past the write (`(id, hint, revision)`): searched on the server by
/// `hint` (up to 5 pages of 100), then on page 1 – never in the loaded
/// journal pages, which may still hold the old version. `null` = not found
/// (the edit kept its place, so its id; a concurrent change elsewhere in the
/// file may have moved it).
final editedTransactionProvider = FutureProvider.autoDispose.family<JournalItem?, (String, String?, int)>((
  ref,
  arg,
) async {
  final (id, hint, _) = arg;
  final repository = ref.watch(journalRepositoryProvider);
  JournalItem? find(List<JournalItem> records) {
    for (final item in foldBalancePads(records)) {
      if (item.id == id) return item;
    }
    return null;
  }

  if (hint != null && hint.trim().isNotEmpty) {
    for (var page = 1; page <= 5; page++) {
      final result = await repository.list(JournalQuery(page: page, size: 100, keyword: hint.trim()));
      final found = find(result.records);
      if (found != null) return found;
      if (!result.hasNextPage) break;
    }
  }
  return find((await repository.list(const JournalQuery(page: 1, size: 100))).records);
}, retry: browseRetry);
