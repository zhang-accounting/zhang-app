import 'json_utils.dart';

/// `GET /api/for-new-transaction`: suggestions for the entry form.
class ForNewTransaction {
  const ForNewTransaction({required this.payees, required this.accountNames});

  /// Synthetic payees the server mixes into the list.
  static const syntheticPayees = {'Balance Check', 'Balance Pad'};

  /// Payees are filtered (no `Balance Check` / `Balance Pad`, no blanks) and
  /// both lists are sorted, since the server returns them unordered.
  factory ForNewTransaction.fromJson(Object? json) {
    final m = asMap(json, 'for-new-transaction');
    final payees = stringList(m['payee'])
        .where((p) => p.trim().isNotEmpty && !syntheticPayees.contains(p))
        .toSet()
        .toList()
      ..sort();
    final accounts = stringList(m['account_name']).toSet().toList()..sort();
    return ForNewTransaction(payees: payees, accountNames: accounts);
  }

  final List<String> payees;

  /// Names of all **open** accounts.
  final List<String> accountNames;
}
