import 'amount.dart';

/// Body of `POST /api/accounts/{name}/balances` and an element of
/// `POST /api/accounts/batch-balances`. Both are dated "now" by the server
/// and answer `201` with an empty body.
///
/// Avoid pads on commodities held at cost (can make the ledger unloadable,
/// docs §1.7).
sealed class BalanceRequest {
  const BalanceRequest({required this.amount, this.accountName});

  /// Asserted/target balance (number serialised as a string).
  final Amount amount;

  /// Required for batch requests; ignored by the single-account endpoint.
  final String? accountName;

  Map<String, Object?> toJson();
}

/// `{"type":"Check","amount":…}` – assert the balance. A mismatch is still
/// written and reported in `/api/errors` (`AccountBalanceCheckError`).
final class BalanceCheckRequest extends BalanceRequest {
  const BalanceCheckRequest({required super.amount, super.accountName});

  @override
  Map<String, Object?> toJson() => {
    'type': 'Check',
    if (accountName != null) 'account_name': accountName,
    'amount': amount.toJson(),
  };
}

/// `{"type":"Pad","amount":…,"pad":"Equity:…"}` – make the account equal
/// [amount] by posting the difference against [pad].
final class BalancePadRequest extends BalanceRequest {
  const BalancePadRequest({required super.amount, required this.pad, super.accountName});

  final String pad;

  @override
  Map<String, Object?> toJson() => {
    'type': 'Pad',
    if (accountName != null) 'account_name': accountName,
    'amount': amount.toJson(),
    'pad': pad,
  };
}
