import 'package:flutter/foundation.dart';

/// "Now" by this device's clock.
///
/// Screens that need *today* or *this month* use the ledger's clock
/// (`ledgerClockProvider`), which is built on this. Code that needs the
/// device's calendar date reads it here instead of calling `DateTime.now()`,
/// so the test suite can run as if it were another day:
/// `flutter test --dart-define=ZHANG_TEST_NOW=2031-01-31T23:58:00`
/// (see `test/flutter_test_config.dart`). Durations and instants (request
/// timing, `Retry-After`, session expiry) keep using `DateTime.now()`.
DateTime deviceNow() {
  final shift = debugDeviceClockShift;
  return shift == Duration.zero ? DateTime.now() : DateTime.now().add(shift);
}

/// Added to the device clock by [deviceNow]. Only tests set it.
@visibleForTesting
Duration debugDeviceClockShift = Duration.zero;
