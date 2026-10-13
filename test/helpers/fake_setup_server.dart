import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:flutter/services.dart';
import 'package:zhang_app/data/api/zhang_api_client.dart';
import 'package:zhang_app/data/auth/browser_sign_in.dart';
import 'package:zhang_app/data/profiles/server_profile.dart';

import 'fake_adapter.dart';
import 'fixtures.dart';

const setupCode = 'q3Hn0Zx4c0QyX2xJm9Yb8kq1sV7tWw5uRr6pLe-_aBc';

/// One zhang server (any URL) for the setup wizard, answered through
/// [FakeAdapter]: `/api/auth/status`, `/api/info`, the browser sign-in code
/// exchange, `/api/options` and `/api/accounts`. Use [tester] and [signIn]
/// as `connectionTesterProvider` / `browserSignInProvider`.
class FakeSetupServer {
  /// zhang's own sign-in (`ZHANG_AUTH` / `ZHANG_PASSKEY`).
  bool enabled = true;
  bool password = true;
  bool passkey = true;

  /// `/api/auth/status.app_login` (browser sign-in handoff).
  bool appLogin = true;

  /// A gateway in front of zhang refuses everything without
  /// `Authorization: Bearer proxy-token` or `X-Gate: open`.
  bool gateway = false;

  /// `false`: zhang 0.1 (text page for `/api/auth/status`, no `format`).
  bool v02 = true;

  /// The next browser sign-in is closed by the user.
  bool cancelNextSignIn = false;

  /// Requests wait for this before they are answered, while set.
  Future<void>? gate;

  /// Throws this (a [DioException]) instead of answering, while set.
  DioException Function(RequestOptions o)? fail;

  final requests = <RequestOptions>[];
  final launched = <String>[];
  final sessions = <String>{};
  int _exchanges = 0;

  static final basicOk = 'Basic ${base64Encode(utf8.encode('demo:secret'))}';

  bool _authorized(RequestOptions o) {
    final header = o.headers['Authorization'];
    if (gateway) return header == 'Bearer proxy-token' || o.headers['X-Gate'] == 'open';
    if (!enabled) return true;
    if (header is! String) return false;
    if (password && header == basicOk) return true;
    return header.startsWith('Bearer ') && sessions.contains(header.substring(7));
  }

  Future<ResponseBody> handle(RequestOptions o) async {
    requests.add(o);
    if (gate != null) await gate;
    final f = fail;
    if (f != null) throw f(o);
    final path = o.uri.path;
    if (gateway && !_authorized(o)) return textResponse('<html>Sign in to the gateway</html>', status: 401);
    if (path == '/api/auth/status') {
      if (!v02) return textResponse('hello zhang, the frontend is not enabled');
      return jsonResponse({
        'data': {
          'enabled': enabled,
          'authenticated': !enabled,
          'methods': {'password': enabled && password, 'passkey': enabled && passkey},
          'passkey_registered': passkey,
          'user': null,
          'title': 'My Accounting',
          if (appLogin) 'app_login': true,
          if (appLogin) 'app_return_schemes': ['zhang-app'],
        },
      });
    }
    if (path == '/api/auth/app/exchange') {
      final token = 'tok${++_exchanges}.sig';
      sessions.add(token);
      return jsonResponse({
        'data': {'token': token, 'expires_at': '2026-11-09T03:07:29Z', 'user': 'demo'},
      });
    }
    if (!_authorized(o)) return jsonResponse({'message': 'unauthorized'}, status: 401);
    return switch (path) {
      '/api/info' => jsonResponse({
        'data': {
          'title': 'My Accounting',
          'version': '0.1.0',
          'build_date': '2026-10-10',
          if (v02) 'format': 'zhang',
          if (v02) 'reload_failure': null,
        },
      }),
      '/api/options' => jsonResponse(fixture('options.json')),
      '/api/accounts' => jsonResponse(fixture('accounts.json')),
      _ => jsonResponse({'message': 'no route ${o.method} $path'}, status: 404),
    };
  }

  ZhangApiClient _client(ServerProfile profile) =>
      ZhangApiClient(profile)..dio.httpClientAdapter = FakeAdapter(handle);

  ConnectionTester get tester => ConnectionTester(createClient: _client);

  BrowserSignIn get signIn => BrowserSignIn(
    launch: (url, scheme) async {
      launched.add(url);
      if (cancelNextSignIn) {
        cancelNextSignIn = false;
        throw PlatformException(code: 'CANCELED');
      }
      return '$scheme://auth/callback?code=$setupCode';
    },
    createClient: _client,
  );
}
