import 'json_utils.dart';

/// `GET /api/info`: `{title: string|null, version, build_date}`.
class ServerInfo {
  const ServerInfo({this.title, required this.version, required this.buildDate});

  factory ServerInfo.fromJson(Object? json) {
    final m = asMap(json, 'info');
    return ServerInfo(
      title: optString(m, 'title'),
      version: reqString(m, 'version'),
      buildDate: optString(m, 'build_date') ?? '',
    );
  }

  /// Ledger title (option `title`), may be null.
  final String? title;

  /// zhang server version, e.g. `0.1.0`.
  final String version;

  /// Build date string as sent (`2026-10-02`).
  final String buildDate;
}
