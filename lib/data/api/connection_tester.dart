import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/account.dart';
import '../models/auth_status.dart';
import '../models/info.dart';
import '../models/json_utils.dart';
import '../models/options.dart';
import '../profiles/server_profile.dart';
import 'api_exception.dart';
import 'endpoints.dart';
import 'zhang_api_client.dart';

/// What a server answers before any sign-in (step 1 of the setup wizard).
@immutable
class ServerProbe {
  const ServerProbe({required this.baseUrl, this.info, this.auth});

  /// The normalised URL that was probed.
  final String baseUrl;

  /// `GET /api/info` without credentials; `null` when the server (or a
  /// gateway in front of it) refused it with 401/403.
  final ServerInfo? info;

  /// `GET /api/auth/status`; `null` when the server could not tell (a
  /// gateway answered, or an older zhang without the route).
  final AuthStatus? auth;

  /// The ledger can be read without credentials: no sign-in step.
  bool get open => info != null;

  /// Something in front of zhang asks for credentials: zhang itself has no
  /// sign-in, yet `/api/info` was refused (reverse proxy / access gateway).
  bool get gateway => info == null && auth != null && !auth!.enabled;

  /// The ledger title, from `/api/info` or `/api/auth/status`.
  String? get title {
    final t = info?.title ?? auth?.title;
    return (t == null || t.trim().isEmpty) ? null : t.trim();
  }
}

/// Ledger facts for the summary of the setup wizard (step 3).
@immutable
class LedgerOverview {
  const LedgerOverview({required this.operatingCurrency, required this.openAccounts});

  /// Option `operating_currency`.
  final String operatingCurrency;

  /// Accounts without a `close` directive.
  final int openAccounts;
}

/// Probes a not-yet-saved profile (setup wizard, Settings "Test connection").
class ConnectionTester {
  const ConnectionTester({this.createClient = ZhangApiClient.new});

  /// Builds the client for the probed profile (tests inject a fake adapter).
  final ZhangApiClient Function(ServerProfile profile) createClient;

  /// Calls `GET /api/info` with [profile]'s URL and credentials and applies
  /// the version gate ([ApiServerTooOld] for zhang < 0.2). When the
  /// credentials are refused, `GET /api/auth/status` tells a passkey-only
  /// server ([ApiPasskeyOnly]) from a wrong password ([ApiUnauthorized]).
  Future<ServerInfo> test(ServerProfile profile) async {
    final client = createClient(profile);
    try {
      return await client.supportedInfo();
    } on ApiUnauthorized {
      // A browser sign-in profile is refused because its session ended (or
      // it is signed out), not because of the sign-in methods.
      if (profile.authType == AuthType.session) rethrow;
      final status = await _authStatus(client);
      if (status != null && status.isPasskeyOnly) {
        throw ApiPasskeyOnly(appLogin: status.supportsAppLogin);
      }
      rethrow;
    } finally {
      client.close();
    }
  }

  /// Step 1 of the setup wizard: what is at [baseUrl] (already normalised)
  /// and how to sign in. No credentials are sent.
  ///
  /// 1. `GET /api/auth/status` (zhang ≥ 0.2, no credentials needed); a
  ///    network failure ends the probe here.
  /// 2. `GET /api/info`: 401/403 means a sign-in is needed
  ///    ([ServerProbe.info] `null`); a server without `format` throws
  ///    [ApiServerTooOld]. Other failures (a page that is not JSON, 404…)
  ///    are thrown as they are.
  Future<ServerProbe> probe(String baseUrl, {bool allowSelfSigned = false}) async {
    final client = createClient(
      ServerProfile(id: 'probe', name: '', baseUrl: baseUrl, allowSelfSigned: allowSelfSigned),
    );
    try {
      AuthStatus? status;
      try {
        status = await client.authStatus();
      } on ApiNetworkError {
        rethrow;
      } on ZhangApiException {
        status = null; // a gateway or an older zhang: decided by /api/info
      }
      ServerInfo? info;
      try {
        info = await client.info();
      } on ApiUnauthorized {
        info = null;
      }
      if (info != null && !info.isSupported) throw ApiServerTooOld(info.version);
      return ServerProbe(baseUrl: baseUrl, info: info, auth: status);
    } finally {
      client.close();
    }
  }

  /// Step 3 of the setup wizard: operating currency and number of open
  /// accounts, read with [profile]'s credentials.
  Future<LedgerOverview> overview(ServerProfile profile) async {
    final client = createClient(profile);
    try {
      final options = client.get(ZhangEndpoints.options, decode: LedgerOptions.fromJson);
      final accounts = client.get(
        ZhangEndpoints.accounts,
        decode: (d) => parseList(d, Account.fromJson, 'accounts'),
      );
      // Future.wait: a failure of one request does not leave the other's
      // error unhandled.
      final results = await Future.wait<Object>([options, accounts]);
      final opened = (results[1] as List<Account>).where((a) => a.status == AccountStatus.open);
      return LedgerOverview(
        operatingCurrency: (results[0] as LedgerOptions).operatingCurrency,
        openAccounts: opened.length,
      );
    } finally {
      client.close();
    }
  }

  /// Best effort: `null` when the server cannot tell (older servers answer
  /// 401 or a text page here).
  static Future<AuthStatus?> _authStatus(ZhangApiClient client) async {
    try {
      return await client.authStatus();
    } on ZhangApiException {
      return null;
    }
  }
}

/// Overridable in widget tests.
final connectionTesterProvider = Provider<ConnectionTester>((ref) => const ConnectionTester());
