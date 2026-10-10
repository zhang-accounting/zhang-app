import 'package:intl/intl.dart';

/// Date/time helpers that encode the zhang server's conventions
/// (docs/zhang-api.md, "Dates and times").
///
/// * Response `datetime` fields are *naive* ledger-local wall-clock strings
///   (`2023-09-16T21:56:16`, no offset). We parse them into a local
///   (non-UTC) [DateTime] holding the same wall-clock fields, which is what
///   the UI should display. Do not convert them with `toLocal()`/`toUtc()`.
/// * `timestamp` fields are Unix epoch seconds (true instants).
/// * Date-only fields are `YYYY-MM-DD`.
/// * Requests use the same naive ledger wall-clock format
///   (`2026-10-03T09:30:00`, [toNaiveIso]) for datetimes and `YYYY-MM-DD`
///   ([toIsoDate]) for dates; the server reads both in the ledger's
///   timezone (zhang ≥ 0.2).
abstract final class ZhangDates {
  /// Parses a naive ledger-local datetime (`YYYY-MM-DDTHH:MM:SS[.fff]`).
  /// A trailing `Z`/offset, if any, is honoured and converted to local time.
  static DateTime parseNaive(String value) {
    final parsed = DateTime.parse(value.trim());
    return parsed.isUtc ? parsed.toLocal() : parsed;
  }

  /// Nullable variant of [parseNaive].
  static DateTime? tryParseNaive(Object? value) {
    if (value is! String || value.isEmpty) return null;
    try {
      return parseNaive(value);
    } on FormatException {
      return null;
    }
  }

  /// Parses a `YYYY-MM-DD` date into a local midnight [DateTime].
  static DateTime parseDate(String value) {
    final p = DateTime.parse(value.trim());
    return DateTime(p.year, p.month, p.day);
  }

  /// Nullable variant of [parseDate].
  static DateTime? tryParseDate(Object? value) {
    if (value is! String || value.isEmpty) return null;
    try {
      return parseDate(value);
    } on FormatException {
      return null;
    }
  }

  /// Converts epoch seconds (`timestamp` fields) into a UTC [DateTime].
  static DateTime fromEpochSeconds(int seconds) =>
      DateTime.fromMillisecondsSinceEpoch(seconds * 1000, isUtc: true);

  /// `YYYY-MM-DD` of the wall-clock date of [value].
  static String toIsoDate(DateTime value) =>
      '${_d4(value.year)}-${_d2(value.month)}-${_d2(value.day)}';

  /// `YYYY-MM-DDTHH:MM:SS` of the wall-clock time of [value] (naive format,
  /// the same shape the server uses in responses).
  static String toNaiveIso(DateTime value) =>
      '${toIsoDate(value)}T${_d2(value.hour)}:${_d2(value.minute)}:${_d2(value.second)}';

  /// Locale-aware medium date, e.g. `Sep 16, 2023` / `2023年9月16日`.
  static String formatDate(DateTime value, [String? locale]) =>
      DateFormat.yMMMd(locale).format(value);

  /// Locale-aware date + time (hours:minutes).
  static String formatDateTime(DateTime value, [String? locale]) =>
      DateFormat.yMMMd(locale).add_Hm().format(value);

  /// Locale-aware time (hours:minutes).
  static String formatTime(DateTime value, [String? locale]) =>
      DateFormat.Hm(locale).format(value);

  /// Locale-aware year + month, e.g. `September 2023` / `2023年9月`.
  static String formatMonth(DateTime value, [String? locale]) =>
      DateFormat.yMMMM(locale).format(value);

  /// Wall-clock day without time.
  static DateTime dateOnly(DateTime value) =>
      DateTime(value.year, value.month, value.day);

  static bool isSameDay(DateTime a, DateTime b) =>
      a.year == b.year && a.month == b.month && a.day == b.day;

  /// First instant of the month containing [value] (local midnight).
  static DateTime startOfMonth(DateTime value) =>
      DateTime(value.year, value.month);

  /// Last second of the month containing [value] (local 23:59:59).
  static DateTime endOfMonth(DateTime value) =>
      DateTime(value.year, value.month + 1).subtract(const Duration(seconds: 1));

  static String _d2(int v) => v.toString().padLeft(2, '0');
  static String _d4(int v) => v.toString().padLeft(4, '0');
}
