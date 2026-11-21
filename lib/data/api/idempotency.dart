import 'dart:math';

/// Idempotent creates (zhang ≥ 0.3, PR #831): `POST /api/transactions` with
/// an `Idempotency-Key` header writes the transaction with the key as its
/// `idempotency-key` metadata; a create sent again with a key the ledger
/// already has writes nothing and answers that transaction, with
/// `Idempotency-Replayed: true`, whatever its body. Older servers ignore
/// the header.
abstract final class Idempotency {
  static const keyHeader = 'Idempotency-Key';
  static const replayedHeader = 'Idempotency-Replayed';

  /// The transaction metadata the server keeps the key in. A request that
  /// sends the header must not have it in its own `metas` (400).
  static const metaKey = 'idempotency-key';

  /// A new key: a random UUID v4 (122 random bits from [Random.secure]),
  /// within zhang's 1 to 128 characters of `A-Za-z0-9._~-`.
  static String newKey([Random? random]) {
    final r = random ?? Random.secure();
    final bytes = [for (var i = 0; i < 16; i++) r.nextInt(256)];
    bytes[6] = (bytes[6] & 0x0f) | 0x40; // version 4
    bytes[8] = (bytes[8] & 0x3f) | 0x80; // RFC 4122 variant
    final hex = [for (final b in bytes) b.toRadixString(16).padLeft(2, '0')].join();
    return '${hex.substring(0, 8)}-${hex.substring(8, 12)}-${hex.substring(12, 16)}-'
        '${hex.substring(16, 20)}-${hex.substring(20)}';
  }
}
