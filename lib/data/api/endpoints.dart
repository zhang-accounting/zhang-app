import 'zhang_api_client.dart';

/// Paths relative to `<baseUrl>/api` (the client's base URL).
abstract final class ZhangEndpoints {
  static const info = '/info';
  static const options = '/options';
  static const errors = '/errors';
  static const reload = '/reload';
  static const sse = '/sse';
  static const forNewTransaction = '/for-new-transaction';
  static const journals = '/journals';
  static const transactions = '/transactions';
  static const accounts = '/accounts';
  static const batchBalances = '/accounts/batch-balances';
  static const documents = '/documents';
  static const commodities = '/commodities';
  static const statisticSummary = '/statistic/summary';
  static const statisticGraph = '/statistic/graph';
  static const budgets = '/budgets';

  static String transaction(String id) => '/transactions/${_s(id)}';
  static String account(String name) => '/accounts/${_s(name)}';
  static String accountJournals(String name) => '${account(name)}/journals';
  static String accountBalances(String name) => '${account(name)}/balances';
  static String accountDocuments(String name) => '${account(name)}/documents';
  static String document(String b64Path) => '/documents/$b64Path';
  static String commodity(String name) => '/commodities/${_s(name)}';

  /// `account_type` must be the exact wire name (`Expenses`, …).
  static String statisticRank(String accountType) => '/statistic/${_s(accountType)}';
  static String budget(String name) => '/budgets/${_s(name)}';
  static String budgetInterval(String name, int year, int month) =>
      '${budget(name)}/interval/$year/$month';

  static String _s(String segment) => ZhangApiClient.encodeSegment(segment);
}
