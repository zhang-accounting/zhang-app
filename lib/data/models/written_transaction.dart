import 'package:flutter/foundation.dart';

/// What `POST /api/transactions` (and `PUT /api/transactions/{id}`) answer
/// for the transaction they wrote.
///
/// zhang ≥ 0.3 (PR #818) answers `{"data": {"id", "version"}}` once the
/// ledger has reloaded, so the transaction is listed under [id] right away;
/// [id] is `null` when the reload failed or the load left the transaction
/// out. Older servers answer `"Ok"` / `null`: no [id], no [version].
@immutable
class WrittenTransaction {
  const WrittenTransaction({this.id, this.version, this.replayed = false});

  /// Nothing known about the transaction (an older server).
  static const unknown = WrittenTransaction();

  /// The `data` of the answer: an object with `id` / `version` (either may
  /// be `null`); anything else (`"Ok"` from an older server, `null` for a
  /// body that could not be read) has neither. Never throws: the write is
  /// done whatever its answer says.
  factory WrittenTransaction.fromJson(Object? data, {bool replayed = false}) {
    String? text(Object? value) => value is String ? value : null;
    if (data is! Map) return WrittenTransaction(replayed: replayed);
    return WrittenTransaction(id: text(data['id']), version: text(data['version']), replayed: replayed);
  }

  /// The id the transaction has in the reloaded ledger.
  final String? id;

  /// Its `version`, for `If-Match`.
  final String? version;

  /// The create carried an `Idempotency-Key` the ledger already had
  /// (`Idempotency-Replayed: true`): nothing was written now, and this is
  /// the transaction an earlier request with that key wrote.
  final bool replayed;

  @override
  bool operator ==(Object other) =>
      other is WrittenTransaction && other.id == id && other.version == version && other.replayed == replayed;

  @override
  int get hashCode => Object.hash(id, version, replayed);

  @override
  String toString() => 'WrittenTransaction($id, $version${replayed ? ', replayed' : ''})';
}
