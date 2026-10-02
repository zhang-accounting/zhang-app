import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/models/account.dart';
import '../../data/repositories/account_repository.dart';
import '../../data/repositories/ledger_revision.dart';

/// `GET /api/accounts` (all accounts incl. closed, sorted by name).
final accountsListProvider = FutureProvider<List<Account>>((ref) {
  ref.watch(ledgerRevisionProvider);
  return ref.watch(accountRepositoryProvider).list();
});

/// `GET /api/accounts/{name}`.
final accountDetailProvider = FutureProvider.autoDispose.family<AccountDetail, String>((ref, name) {
  ref.watch(ledgerRevisionProvider);
  return ref.watch(accountRepositoryProvider).get(name);
});

/// `GET /api/accounts/{name}/journals` – newest first, with running balance.
final accountJournalsProvider =
    FutureProvider.autoDispose.family<List<AccountJournalEntry>, String>((ref, name) {
      ref.watch(ledgerRevisionProvider);
      return ref.watch(accountRepositoryProvider).journals(name);
    });

/// `GET /api/accounts/{name}/balances` – daily balances per commodity.
final accountBalanceHistoryProvider =
    FutureProvider.autoDispose.family<AccountBalanceHistory, String>((ref, name) {
      ref.watch(ledgerRevisionProvider);
      return ref.watch(accountRepositoryProvider).balances(name);
    });
