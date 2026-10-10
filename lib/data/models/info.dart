import 'json_utils.dart';

/// `GET /api/info`: `{title, version, build_date, format, reload_failure}`.
///
/// [format] (`"zhang"` / `"beancount"`) only exists on zhang ≥ 0.2, the first
/// release with the built-in query API (`POST /api/query/builtins`). The
/// version string cannot tell the two apart (source builds report `0.1.0`),
/// so [isSupported] keys on [format].
class ServerInfo {
  const ServerInfo({
    this.title,
    required this.version,
    required this.buildDate,
    this.format,
    this.reloadFailure,
  });

  factory ServerInfo.fromJson(Object? json) {
    final m = asMap(json, 'info');
    final failure = m['reload_failure'];
    return ServerInfo(
      title: optString(m, 'title'),
      version: reqString(m, 'version'),
      buildDate: optString(m, 'build_date') ?? '',
      format: optString(m, 'format'),
      reloadFailure: failure == null ? null : ReloadFailure.fromJson(asMap(failure, 'reload_failure')),
    );
  }

  /// Ledger title (option `title`), may be null.
  final String? title;

  /// zhang server version, e.g. `0.1.0` (not reliable: source builds of 0.2
  /// still report `0.1.0`).
  final String version;

  /// Build date string as sent (`2026-10-02`).
  final String buildDate;

  /// Ledger dialect, `zhang` or `beancount`; `null` on servers older than 0.2.
  final String? format;

  /// Set while the last reload failed: the server keeps serving the version
  /// it loaded before.
  final ReloadFailure? reloadFailure;

  /// Whether this server speaks the v0.2 API the app needs.
  bool get isSupported => format != null;
}

/// Why the last ledger reload failed (`/api/info.reload_failure`, SSE
/// `ReloadFailed`).
class ReloadFailure {
  const ReloadFailure({this.file, required this.message});

  factory ReloadFailure.fromJson(JsonMap m) =>
      ReloadFailure(file: optString(m, 'file'), message: optString(m, 'message') ?? '');

  /// Path relative to the ledger root, when the failure is tied to a file.
  final String? file;
  final String message;

  @override
  bool operator ==(Object other) => other is ReloadFailure && other.file == file && other.message == message;

  @override
  int get hashCode => Object.hash(file, message);
}
