import 'package:shared_preferences/shared_preferences.dart';

/// The servers (by base URL) whose `/api/auth/status` has said
/// `app_login_pkce: true`. Once seen, a browser sign-in to that server never
/// accepts a callback without the state again, even if a later status lacks
/// the flag (a downgraded server, or a status answered by someone else).
///
/// Kept in [SharedPreferences] (not secret; `zhang.auth.pkceServers.v1`), next
/// to the profiles rather than in them: it also covers the setup wizard,
/// before a profile exists, and a profile that is removed and added again.
/// Without [SharedPreferences] (tests) it lives in memory.
class PkceServers {
  PkceServers([this._prefs]);

  static const key = 'zhang.auth.pkceServers.v1';

  /// Bounded so the list cannot grow forever (oldest dropped first).
  static const maxEntries = 100;

  final SharedPreferences? _prefs;
  final _memory = <String>{};

  /// The server a base URL names: scheme and host lower-cased, the default
  /// port of http (80) and https (443) dropped, the path without trailing
  /// slashes (its case kept); no user info, query or fragment.
  static String serverId(String baseUrl) {
    final trimmed = baseUrl.trim();
    final uri = Uri.tryParse(trimmed);
    if (uri == null || !uri.hasScheme || uri.host.isEmpty) return trimmed.replaceFirst(RegExp(r'/+$'), '');
    final scheme = uri.scheme.toLowerCase();
    final host = uri.host.toLowerCase();
    final defaultPort = (scheme == 'http' && uri.port == 80) || (scheme == 'https' && uri.port == 443);
    final port = uri.hasPort && !defaultPort ? ':${uri.port}' : '';
    final path = uri.path.replaceFirst(RegExp(r'/+$'), '');
    return '$scheme://${host.contains(':') ? '[$host]' : host}$port$path';
  }

  List<String> get _stored => _prefs?.getStringList(key) ?? const [];

  /// [baseUrl] has reported `app_login_pkce: true` before.
  bool contains(String baseUrl) {
    final id = serverId(baseUrl);
    return _memory.contains(id) || _stored.contains(id);
  }

  /// Remembers that [baseUrl] reports `app_login_pkce: true`.
  Future<void> remember(String baseUrl) async {
    final id = serverId(baseUrl);
    _memory.add(id);
    final prefs = _prefs;
    if (prefs == null) return;
    final stored = _stored;
    if (stored.contains(id)) return;
    final updated = [...stored, id];
    await prefs.setStringList(key, updated.length > maxEntries ? updated.sublist(updated.length - maxEntries) : updated);
  }
}
