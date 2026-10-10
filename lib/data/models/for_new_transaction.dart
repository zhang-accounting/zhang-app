import 'query_result.dart';

/// Suggestions for the entry form: the built-in queries `journals.payees`
/// (sorted, without the synthetic `Balance Check` / `Balance Pad`) and
/// `journals.accounts` (accounts open at the ledger's current instant).
class ForNewTransaction {
  const ForNewTransaction({required this.payees, required this.accountNames});

  /// Payees of balance items in `/api/journals` (never real payees).
  static const syntheticPayees = {'Balance Check', 'Balance Pad'};

  factory ForNewTransaction.fromResults(QueryResult payees, QueryResult accounts) {
    final names = <String>{
      for (final r in payees.rows)
        if ((r.stringOrNull('payee') ?? '').trim().isNotEmpty) r.string('payee'),
    };
    return ForNewTransaction(
      payees: names.toList(),
      accountNames: {for (final r in accounts.rows) r.string('account')}.toList(),
    );
  }

  final List<String> payees;

  /// Names of all **open** accounts.
  final List<String> accountNames;
}
