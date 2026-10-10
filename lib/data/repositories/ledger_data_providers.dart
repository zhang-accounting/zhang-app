import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../api/zhang_api_client.dart';
import '../models/commodity.dart';
import '../models/info.dart';
import '../models/options.dart';
import 'commodity_repository.dart';
import 'ledger_repository.dart';
import 'ledger_revision.dart';

/// Shared, cached server data most screens need. All of them refetch when the
/// active profile changes or `ledgerRevisionProvider` is bumped.

/// The version gate of the active server: `GET /api/info` once per profile
/// (not refetched on revision bumps). Its [ServerInfo.isSupported] decides
/// whether the main shell may query the server at all; `AppShell` shows
/// "server too old" instead of the tabs when it is `false`. When it failed
/// (server unreachable), `ledgerEventsProvider` re-checks it once the event
/// stream connects.
final serverGateProvider = FutureProvider<ServerInfo>((ref) => ref.watch(zhangApiClientProvider).info());

/// `GET /api/info` of the active server (refetched with the ledger
/// revision: it carries `reload_failure`).
final serverInfoProvider = FutureProvider<ServerInfo>((ref) {
  ref.watch(ledgerRevisionProvider);
  return ref.watch(ledgerRepositoryProvider).info();
});

/// `GET /api/options` (operating currency, timezone, …).
final ledgerOptionsProvider = FutureProvider<LedgerOptions>((ref) {
  ref.watch(ledgerRevisionProvider);
  return ref.watch(ledgerRepositoryProvider).options();
});

/// Offset of the ledger's wall clock (built-in `ledger.now`, in the ledger's
/// timezone) from this device's clock, rounded to 15 minutes; fetched once
/// per profile. Zero while unknown or when the request fails.
final ledgerClockOffsetProvider = FutureProvider<Duration>((ref) async {
  final ledgerNow = await ref.watch(ledgerRepositoryProvider).now();
  return roundClockOffset(ledgerNow.difference(DateTime.now()));
}, retry: (_, _) => null);

/// Rounds a clock offset to the nearest 15 minutes (timezone offsets are
/// multiples of 15 minutes; the rest is request latency and clock skew).
Duration roundClockOffset(Duration offset) {
  const step = 15;
  final minutes = (offset.inSeconds / 60 / step).round() * step;
  return Duration(minutes: minutes);
}

/// "Now" by the ledger's wall clock: today, the current month and the
/// default time of a new entry follow the ledger's timezone, not the
/// device's. Falls back to the device clock until [ledgerClockOffsetProvider]
/// is known.
final ledgerClockProvider = Provider<DateTime Function()>((ref) {
  final offset = ref.watch(ledgerClockOffsetProvider).value ?? Duration.zero;
  if (offset == Duration.zero) return DateTime.now;
  return () => DateTime.now().add(offset);
});

/// Commodities by name – use `commodities[code]?.format(amount)` to format
/// amounts with the right precision and symbol.
final commoditiesProvider = FutureProvider<Map<String, Commodity>>((ref) async {
  ref.watch(ledgerRevisionProvider);
  final list = await ref.watch(commodityRepositoryProvider).list();
  return {for (final c in list) c.name: c};
});
