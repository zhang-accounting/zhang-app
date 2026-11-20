import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/models/document.dart';
import '../../data/repositories/account_repository.dart';
import '../../data/repositories/document_repository.dart';
import '../../data/repositories/ledger_revision.dart';

/// Every document of the ledger, newest first (`journals.documents`):
/// `document` directives and the `document` metadata of transactions and
/// postings. Kept for the ledger revision (like `commoditiesProvider`), so
/// opening transactions does not refetch it.
final ledgerDocumentsProvider = FutureProvider<List<DocumentEntity>>((ref) {
  ref.watch(ledgerRevisionProvider);
  return ref.watch(documentRepositoryProvider).list();
});

/// The `document` directives of an account and its sub-accounts
/// (`accounts.documents`), newest first.
final accountDocumentsProvider = FutureProvider.autoDispose.family<List<DocumentEntity>, String>((ref, name) async {
  ref.watch(ledgerRevisionProvider);
  final list = await ref.watch(accountRepositoryProvider).documents(name);
  return [...list]..sort((a, b) => b.datetime.compareTo(a.datetime));
});

/// Documents attached to the transaction [id] (its own or its postings'
/// `document` metadata), from [ledgerDocumentsProvider]. Only watch it for
/// a transaction that names a document (`JournalTransaction.hasDocuments`).
final transactionDocumentsProvider = FutureProvider.autoDispose.family<List<DocumentEntity>, String>((ref, id) async {
  final all = await ref.watch(ledgerDocumentsProvider.future);
  return [
    for (final d in all)
      if (d.trxId == id) d,
  ];
});
