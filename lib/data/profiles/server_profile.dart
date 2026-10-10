import 'dart:convert';

import 'package:flutter/foundation.dart';

/// How requests to a server are authenticated.
enum AuthType {
  /// No auth header.
  none,

  /// `Authorization: Basic base64(user:pass)` (zhang's built-in `--auth`).
  basic,

  /// `Authorization: Bearer <token>` (e.g. a reverse proxy in front of zhang).
  bearer,

  /// Arbitrary headers sent verbatim (e.g. `CF-Access-Client-Id` /
  /// `CF-Access-Client-Secret` for Cloudflare Access).
  headers,

  /// zhang's own session token, obtained by signing in (passkey or password)
  /// on the server's login page in the system browser and sent as
  /// `Authorization: Bearer <token>` (see `BrowserSignIn`, zhang-api.md §1.3).
  session;

  static AuthType fromName(String? name) => AuthType.values.firstWhere(
    (t) => t.name == name,
    orElse: () => AuthType.none,
  );
}

/// A configured zhang server ("ledger") the app can connect to.
///
/// Non-secret fields are persisted in shared_preferences via [toPublicJson];
/// secrets ([basicPassword], [bearerToken], the *values* of [customHeaders],
/// the browser sign-in session: [sessionToken], [sessionExpiresAt],
/// [sessionUser]) live in secure storage via [toSecretJson]. See
/// `ProfileRepository`.
@immutable
class ServerProfile {
  const ServerProfile({
    required this.id,
    required this.name,
    required this.baseUrl,
    this.authType = AuthType.none,
    this.basicUsername,
    this.basicPassword,
    this.bearerToken,
    this.customHeaders = const {},
    this.sessionToken,
    this.sessionExpiresAt,
    this.sessionUser,
    this.allowSelfSigned = false,
    this.color,
  });

  final String id;
  final String name;

  /// Normalised origin (+ optional path prefix) without trailing `/` or
  /// `/api`, e.g. `https://ledger.example.com`. See [normalizeBaseUrl].
  final String baseUrl;
  final AuthType authType;
  final String? basicUsername;
  final String? basicPassword;
  final String? bearerToken;

  /// Header name → value, sent verbatim when [authType] is [AuthType.headers].
  final Map<String, String> customHeaders;

  /// zhang session token from the browser sign-in ([AuthType.session]);
  /// `null` when signed out.
  final String? sessionToken;

  /// When [sessionToken] stops working (UTC, from the server's `expires_at`).
  final DateTime? sessionExpiresAt;

  /// The user the server signed in for [sessionToken].
  final String? sessionUser;

  /// Accept self-signed / invalid TLS certificates for this server's host.
  final bool allowSelfSigned;

  /// Optional ARGB colour used to tag this ledger in the UI (e.g. a dot in the
  /// app bar). `null` = use the theme's primary colour.
  final int? color;

  /// `<baseUrl>/api` – the prefix every API route lives under.
  String get apiBaseUrl => '$baseUrl/api';

  /// Host part of [baseUrl] (empty if unparsable).
  String get host => Uri.tryParse(baseUrl)?.host ?? '';

  /// A browser sign-in profile that currently holds a session token.
  bool get hasSession =>
      authType == AuthType.session && (sessionToken?.isNotEmpty ?? false);

  /// Whether the session ends within [within] of [now] (or already ended).
  /// `false` without a session or a known expiry.
  bool sessionExpiresWithin(Duration within, {DateTime? now}) {
    final expires = sessionExpiresAt;
    if (!hasSession || expires == null) return false;
    return expires.isBefore((now ?? DateTime.now()).add(within));
  }

  /// This profile signed out: session token, expiry and user removed.
  ServerProfile withoutSession() => copyWith(clearSession: true);

  ServerProfile copyWith({
    String? id,
    String? name,
    String? baseUrl,
    AuthType? authType,
    String? basicUsername,
    String? basicPassword,
    String? bearerToken,
    Map<String, String>? customHeaders,
    String? sessionToken,
    DateTime? sessionExpiresAt,
    String? sessionUser,
    bool clearSession = false,
    bool? allowSelfSigned,
    int? color,
    bool clearColor = false,
  }) {
    return ServerProfile(
      id: id ?? this.id,
      name: name ?? this.name,
      baseUrl: baseUrl ?? this.baseUrl,
      authType: authType ?? this.authType,
      basicUsername: basicUsername ?? this.basicUsername,
      basicPassword: basicPassword ?? this.basicPassword,
      bearerToken: bearerToken ?? this.bearerToken,
      customHeaders: customHeaders ?? this.customHeaders,
      sessionToken: clearSession ? null : (sessionToken ?? this.sessionToken),
      sessionExpiresAt: clearSession ? null : (sessionExpiresAt ?? this.sessionExpiresAt),
      sessionUser: clearSession ? null : (sessionUser ?? this.sessionUser),
      allowSelfSigned: allowSelfSigned ?? this.allowSelfSigned,
      color: clearColor ? null : (color ?? this.color),
    );
  }

  /// Non-secret JSON (safe for shared_preferences and logs).
  ///
  /// Custom header *names* are stored here (ordered); their values are secret.
  Map<String, Object?> toPublicJson() => {
    'id': id,
    'name': name,
    'baseUrl': baseUrl,
    'authType': authType.name,
    if (basicUsername != null) 'basicUsername': basicUsername,
    'customHeaderNames': customHeaders.keys.toList(),
    'allowSelfSigned': allowSelfSigned,
    if (color != null) 'color': color,
  };

  /// Secret JSON (secure storage only – never log this).
  Map<String, Object?> toSecretJson() => {
    if (basicPassword != null) 'basicPassword': basicPassword,
    if (bearerToken != null) 'bearerToken': bearerToken,
    if (customHeaders.isNotEmpty) 'customHeaders': customHeaders,
    if (sessionToken != null) 'sessionToken': sessionToken,
    if (sessionExpiresAt != null)
      'sessionExpiresAt': sessionExpiresAt!.toUtc().toIso8601String(),
    if (sessionUser != null) 'sessionUser': sessionUser,
  };

  /// Rebuilds a profile from [toPublicJson] output plus optional
  /// [toSecretJson] output.
  factory ServerProfile.fromJson(
    Map<String, Object?> public, [
    Map<String, Object?>? secret,
  ]) {
    final headerValues = <String, String>{};
    final rawSecretHeaders = secret?['customHeaders'];
    if (rawSecretHeaders is Map) {
      rawSecretHeaders.forEach((k, v) => headerValues['$k'] = '${v ?? ''}');
    }
    final names = public['customHeaderNames'];
    final headers = <String, String>{};
    if (names is List) {
      for (final n in names) {
        headers['$n'] = headerValues['$n'] ?? '';
      }
    }
    // Secret headers whose names were not listed publicly are kept too.
    for (final e in headerValues.entries) {
      headers.putIfAbsent(e.key, () => e.value);
    }
    final color = public['color'];
    final expires = secret?['sessionExpiresAt'];
    return ServerProfile(
      id: public['id'] as String,
      name: (public['name'] as String?) ?? '',
      baseUrl: (public['baseUrl'] as String?) ?? '',
      authType: AuthType.fromName(public['authType'] as String?),
      basicUsername: public['basicUsername'] as String?,
      basicPassword: secret?['basicPassword'] as String?,
      bearerToken: secret?['bearerToken'] as String?,
      customHeaders: headers,
      sessionToken: secret?['sessionToken'] as String?,
      sessionExpiresAt: expires is String ? DateTime.tryParse(expires)?.toUtc() : null,
      sessionUser: secret?['sessionUser'] as String?,
      allowSelfSigned: public['allowSelfSigned'] == true,
      color: color is int ? color : null,
    );
  }

  /// HTTP headers that authenticate requests for this profile.
  Map<String, String> authHeaders() {
    switch (authType) {
      case AuthType.none:
        return const {};
      case AuthType.basic:
        final user = basicUsername ?? '';
        final pass = basicPassword ?? '';
        final token = base64Encode(utf8.encode('$user:$pass'));
        // zhang >= 0.2 accepts any case of the scheme; "Basic" works everywhere.
        return {'Authorization': 'Basic $token'};
      case AuthType.bearer:
        return {'Authorization': 'Bearer ${bearerToken ?? ''}'};
      case AuthType.headers:
        return {
          for (final e in customHeaders.entries)
            if (e.key.trim().isNotEmpty) e.key.trim(): e.value,
        };
      case AuthType.session:
        // Signed out: send nothing, the server answers 401 → "Sign in again".
        final token = sessionToken;
        if (token == null || token.isEmpty) return const {};
        return {'Authorization': 'Bearer $token'};
    }
  }

  /// Normalises user input into a [baseUrl]:
  /// trims, adds `https://` when no scheme is given, lower-cases the scheme,
  /// and strips trailing `/` and a trailing `/api` segment.
  ///
  /// `ledger.example.com/api/` → `https://ledger.example.com`
  /// `http://192.168.1.2:8000/` → `http://192.168.1.2:8000`
  static String normalizeBaseUrl(String input) {
    var url = input.trim();
    if (url.isEmpty) return url;
    final scheme = RegExp(r'^([a-zA-Z][a-zA-Z0-9+.-]*)://').firstMatch(url);
    if (scheme == null) {
      url = 'https://$url';
    } else {
      url = '${scheme.group(1)!.toLowerCase()}${url.substring(scheme.group(1)!.length)}';
    }
    url = _stripTrailingSlashes(url);
    while (url.toLowerCase().endsWith('/api')) {
      url = _stripTrailingSlashes(url.substring(0, url.length - 4));
    }
    return url;
  }

  /// Whether [normalized] (output of [normalizeBaseUrl]) is a usable http(s)
  /// URL with a host.
  static bool isValidBaseUrl(String normalized) {
    final uri = Uri.tryParse(normalized);
    return uri != null &&
        (uri.scheme == 'http' || uri.scheme == 'https') &&
        uri.host.isNotEmpty;
  }

  static String _stripTrailingSlashes(String url) {
    var u = url;
    while (u.endsWith('/') && !u.endsWith('://')) {
      u = u.substring(0, u.length - 1);
    }
    return u;
  }

  @override
  bool operator ==(Object other) =>
      other is ServerProfile &&
      other.id == id &&
      other.name == name &&
      other.baseUrl == baseUrl &&
      other.authType == authType &&
      other.basicUsername == basicUsername &&
      other.basicPassword == basicPassword &&
      other.bearerToken == bearerToken &&
      mapEquals(other.customHeaders, customHeaders) &&
      other.sessionToken == sessionToken &&
      other.sessionExpiresAt == sessionExpiresAt &&
      other.sessionUser == sessionUser &&
      other.allowSelfSigned == allowSelfSigned &&
      other.color == color;

  @override
  int get hashCode => Object.hash(
    id,
    name,
    baseUrl,
    authType,
    basicUsername,
    basicPassword,
    bearerToken,
    Object.hashAllUnordered(
      customHeaders.entries.map((e) => Object.hash(e.key, e.value)),
    ),
    sessionToken,
    sessionExpiresAt,
    sessionUser,
    allowSelfSigned,
    color,
  );

  /// Never includes secrets.
  @override
  String toString() =>
      'ServerProfile(id: $id, name: $name, baseUrl: $baseUrl, auth: ${authType.name})';
}
