import 'zhang_api_client.dart';

/// Paths relative to `<baseUrl>/api` (the client's base URL). Reports,
/// errors, budgets, documents and form data come from the built-in queries
/// (`builtinQueries`, see `BuiltinQueryClient`).
abstract final class ZhangEndpoints {
  static const info = '/info';
  static const authStatus = '/auth/status';
  static const builtinQueries = '/query/builtins';
  static const options = '/options';
  static const reload = '/reload';
  static const sse = '/sse';
  static const journals = '/journals';
  static const transactions = '/transactions';
  static const transactionPreview = '/transactions/preview';
  static const accounts = '/accounts';
  static const batchBalances = '/accounts/batch-balances';
  static const commodities = '/commodities';
  static const statisticGraph = '/statistic/graph';

  static String builtinQuery(String name) => '$builtinQueries/${_s(name)}';
  static String transaction(String id) => '/transactions/${_s(id)}';
  static String account(String name) => '/accounts/${_s(name)}';
  static String accountJournals(String name) => '${account(name)}/journals';

  /// `POST` only (balance check / pad); the `GET` history is the built-in
  /// `accounts.balance_history`.
  static String accountBalances(String name) => '${account(name)}/balances';
  static String document(String b64Path) => '/documents/$b64Path';
  static String commodity(String name) => '/commodities/${_s(name)}';

  static String _s(String segment) => ZhangApiClient.encodeSegment(segment);
}
