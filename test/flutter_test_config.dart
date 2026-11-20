import 'dart:async';

import 'package:zhang_app/core/utils/device_clock.dart';

/// Runs every test as if the device clock read `ZHANG_TEST_NOW` (local
/// wall-clock ISO date-time), e.g. to check that no test depends on the
/// date it runs on:
///
/// ```sh
/// flutter test --dart-define=ZHANG_TEST_NOW=2031-01-31T23:58:00
/// ```
///
/// Only the app's calendar clock (`deviceNow()`) moves, and with it the
/// fake servers' `ledger.now`; durations and instants stay real.
Future<void> testExecutable(FutureOr<void> Function() testMain) async {
  const now = String.fromEnvironment('ZHANG_TEST_NOW');
  if (now.isNotEmpty) debugDeviceClockShift = DateTime.parse(now).difference(DateTime.now());
  await testMain();
}
