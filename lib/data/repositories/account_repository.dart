import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../api/endpoints.dart';
import '../api/zhang_api_client.dart';
import '../models/account.dart';
import '../models/balance_request.dart';
import '../models/document.dart';
import '../models/json_utils.dart';
import 'ledger_revision.dart';

/// Accounts, their postings, balance history, documents and balance writes.
class AccountRepository {
  AccountRepository(this._client, {this._onMutated});

  final ZhangApiClient _client;
  final OnLedgerMutated? _onMutated;

  /// `GET /api/accounts` – all accounts incl. closed ones, sorted by name.
  Future<List<Account>> list() => _client.get(
    ZhangEndpoints.accounts,
    decode: (d) => parseList(d, Account.fromJson, 'accounts')..sort((a, b) => a.name.compareTo(b.name)),
  );

  /// `GET /api/accounts/{name}` (throws `ApiNotFound` for unknown names).
  Future<AccountDetail> get(String name) => _client.get(
    ZhangEndpoints.account(name),
    decode: (d) => AccountDetail.fromJson(asMap(d, 'account')),
  );

  /// `GET /api/accounts/{name}/journals` – all postings, newest first.
  /// Note: `trxId` here is a posting id (server bug).
  Future<List<AccountJournalEntry>> journals(String name) => _client.get(
    ZhangEndpoints.accountJournals(name),
    decode: (d) => parseList(d, AccountJournalEntry.fromJson, 'account journals'),
  );

  /// `GET /api/accounts/{name}/balances` – daily balances per commodity.
  Future<AccountBalanceHistory> balances(String name) =>
      _client.get(ZhangEndpoints.accountBalances(name), decode: AccountBalanceHistory.fromJson);

  /// `GET /api/accounts/{name}/documents`.
  Future<List<DocumentEntity>> documents(String name) => _client.get(
    ZhangEndpoints.accountDocuments(name),
    decode: (d) => parseList(d, DocumentEntity.fromJson, 'documents'),
  );

  /// `POST /api/accounts/{name}/balances` – balance check or pad dated now.
  Future<void> addBalance(String name, BalanceRequest request) async {
    await _client.send('POST', ZhangEndpoints.accountBalances(name), body: request.toJson());
    _onMutated?.call();
  }

  /// `POST /api/accounts/batch-balances` – each request needs `accountName`.
  Future<void> addBalances(List<BalanceRequest> requests) async {
    assert(requests.every((r) => r.accountName != null), 'batch requests need accountName');
    await _client.send(
      'POST',
      ZhangEndpoints.batchBalances,
      body: [for (final r in requests) r.toJson()],
    );
    _onMutated?.call();
  }

}

final accountRepositoryProvider = Provider<AccountRepository>(
  (ref) => AccountRepository(
    ref.watch(zhangApiClientProvider),
    onMutated: () => ref.read(ledgerRevisionProvider.notifier).bumpAfterWrite(),
  ),
);
