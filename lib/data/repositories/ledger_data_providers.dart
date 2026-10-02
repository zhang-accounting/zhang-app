import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/commodity.dart';
import '../models/info.dart';
import '../models/options.dart';
import 'commodity_repository.dart';
import 'ledger_repository.dart';
import 'ledger_revision.dart';

/// Shared, cached server data most screens need. All of them refetch when the
/// active profile changes or `ledgerRevisionProvider` is bumped.

/// `GET /api/info` of the active server.
final serverInfoProvider = FutureProvider<ServerInfo>((ref) {
  ref.watch(ledgerRevisionProvider);
  return ref.watch(ledgerRepositoryProvider).info();
});

/// `GET /api/options` (operating currency, timezone, …).
final ledgerOptionsProvider = FutureProvider<LedgerOptions>((ref) {
  ref.watch(ledgerRevisionProvider);
  return ref.watch(ledgerRepositoryProvider).options();
});

/// Commodities by name – use `commodities[code]?.format(amount)` to format
/// amounts with the right precision and symbol.
final commoditiesProvider = FutureProvider<Map<String, Commodity>>((ref) async {
  ref.watch(ledgerRevisionProvider);
  final list = await ref.watch(commodityRepositoryProvider).list();
  return {for (final c in list) c.name: c};
});
