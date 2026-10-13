import 'package:flutter/widgets.dart';

import '../../data/api/api_exception.dart';
import '../../data/api/zhang_api_client.dart';
import '../../data/auth/browser_sign_in.dart';
import '../../data/models/info.dart';
import '../../data/profiles/server_profile.dart';
import '../settings/header_row.dart';
import 'setup_links.dart';

/// Pages of the server setup wizard, in order.
enum SetupStage {
  /// First launch only: what the app is, "Connect" or "Try the demo".
  welcome,

  /// Step 1: the server address, probed with `/api/auth/status` + `/api/info`.
  server,

  /// Step 2: only what the server supports (skipped for open servers).
  signIn,

  /// Step 3: ledger summary, name and colour, "Start".
  ready,
}

/// The main way step 2 signs in, chosen from `/api/auth/status`.
enum SignInMode {
  /// zhang's login page in the system browser (passkey or password).
  browser,

  /// HTTP Basic with zhang's username and password.
  password,

  /// Passkeys only, without the app handoff: the app cannot sign in.
  unsupported,

  /// zhang has no sign-in but something in front of it refuses the app (or
  /// the server could not tell): Bearer token / custom headers.
  proxy,
}

/// Credentials for a reverse proxy / access gateway.
enum ProxyAuth { bearer, headers }

/// Why the entered address cannot be probed.
enum UrlProblem { empty, invalid }

/// A sign-in that worked: the profile it produced and what `/api/info`
/// answered with it.
@immutable
class SetupVerified {
  const SetupVerified({required this.profile, required this.info, this.user});

  final ServerProfile profile;
  final ServerInfo info;

  /// Who signed in (browser / password), `null` otherwise.
  final String? user;
}

/// State and logic of the server setup wizard (`ServerSetupScreen`). Keeps
/// everything the user entered while moving back and forth between steps.
///
/// Every network call bumps an operation counter; a result that arrives
/// after the user moved on (back button, a newer request) is dropped.
class ServerSetupController extends ChangeNotifier {
  ServerSetupController({required this.tester, required this.browser, bool showWelcome = true})
    : _stage = showWelcome ? SetupStage.welcome : SetupStage.server;

  final ConnectionTester tester;
  final BrowserSignIn browser;

  /// Times a timed-out demo probe is retried (the demo sleeps when idle).
  static const demoTimeoutRetries = 2;

  int _op = 0;
  bool _disposed = false;

  void _notify() {
    if (!_disposed) notifyListeners();
  }

  // ---------------------------------------------------------------- stages

  SetupStage _stage;
  SetupStage get stage => _stage;
  final List<SetupStage> _history = [];

  /// `1` after moving forward, `-1` after going back (page transition).
  int direction = 1;

  /// A previous page exists inside the wizard.
  bool get canGoBack => _history.isNotEmpty;

  /// `1…3` for the numbered steps; `null` on the welcome page and for the
  /// demo (which skips steps 1 and 2).
  int? get stepNumber => switch (_stage) {
    SetupStage.welcome => null,
    _ when isDemo => null,
    SetupStage.server => 1,
    SetupStage.signIn => 2,
    SetupStage.ready => 3,
  };

  void _go(SetupStage next) {
    _history.add(_stage);
    _stage = next;
    direction = 1;
    _notify();
  }

  /// One page back (cancels what is in flight). `false` when this is the
  /// first page; the caller may then close the route.
  bool back() {
    if (_history.isEmpty) return false;
    _op++;
    probing = false;
    demoLoading = false;
    busy = false;
    _stage = _history.removeLast();
    direction = -1;
    if (_stage == SetupStage.welcome && isDemo) {
      isDemo = false;
      url.clear();
      probe = null;
      verified = null;
    }
    _notify();
    return true;
  }

  // ------------------------------------------------------- welcome / demo

  bool isDemo = false;
  bool demoLoading = false;
  Object? demoError;

  /// "Connect to your server".
  void startServerStep() {
    demoError = null;
    _go(SetupStage.server);
  }

  /// "Try the demo": probes [kDemoServerUrl] (retrying timeouts while it
  /// wakes up) and goes straight to the summary.
  Future<void> startDemo() async {
    final op = ++_op;
    demoLoading = true;
    demoError = null;
    _notify();
    try {
      ServerProbe? result;
      for (var attempt = 0; result == null; attempt++) {
        try {
          result = await tester.probe(kDemoServerUrl);
        } on ApiNetworkError catch (e) {
          if (e.kind != NetworkErrorKind.timeout || attempt >= demoTimeoutRetries || op != _op) rethrow;
        }
      }
      if (op != _op) return;
      url.text = kDemoServerUrl;
      allowSelfSigned = false;
      isDemo = true;
      _accept(result);
    } catch (e) {
      if (op == _op) demoError = e;
    } finally {
      if (op == _op) {
        demoLoading = false;
        _notify();
      }
    }
  }

  // ------------------------------------------------------- step 1: server

  final url = TextEditingController();
  bool allowSelfSigned = false;
  UrlProblem? urlProblem;
  bool probing = false;
  Object? probeError;
  ServerProbe? probe;

  /// What the entered address normalises to.
  String get normalizedUrl => ServerProfile.normalizeBaseUrl(url.text);

  /// The address can be probed.
  bool get urlValid => url.text.trim().isNotEmpty && ServerProfile.isValidBaseUrl(normalizedUrl);

  /// No scheme was typed: normalisation picked one
  /// ([ServerProfile.defaultSchemeFor]).
  bool get schemeDefaulted => !ServerProfile.schemePattern.hasMatch(url.text.trim());

  /// The address with the other scheme (http ↔ https) when the scheme was
  /// picked by normalisation; `null` when the user typed one.
  String? get schemeAlternative {
    if (!schemeDefaulted) return null;
    final normalized = normalizedUrl;
    if (normalized.startsWith('https://')) return 'http://${normalized.substring(8)}';
    if (normalized.startsWith('http://')) return 'https://${normalized.substring(7)}';
    return null;
  }

  /// The probe failed in the TLS handshake because of the certificate (not
  /// because the port speaks plain http).
  bool get certificateRejected {
    final e = probeError;
    return e is ApiNetworkError && e.kind == NetworkErrorKind.certificate && !_plainHttpPort(e);
  }

  /// A TLS handshake with a port that answers plain http.
  static bool _plainHttpPort(ApiNetworkError e) =>
      e.message.toUpperCase().contains('WRONG_VERSION_NUMBER') ||
      e.message.toLowerCase().contains('wrong version number');

  /// Offer "Allow self-signed certificate" only for certificate errors (or
  /// once it is on, so it can be turned off again).
  bool get showSelfSignedSwitch => allowSelfSigned || certificateRejected;

  /// The address was edited: clears the last error and refreshes the
  /// normalisation hint.
  void urlChanged() {
    urlProblem = null;
    probeError = null;
    _notify();
  }

  void setAllowSelfSigned(bool value) {
    allowSelfSigned = value;
    _notify();
  }

  /// "Use http://…" / "Use https://…" after a failed attempt with the
  /// scheme normalisation picked.
  Future<void> useSchemeAlternative() async {
    final alternative = schemeAlternative;
    if (alternative == null) return;
    url.text = alternative;
    url.selection = TextSelection.collapsed(offset: alternative.length);
    await submitUrl();
  }

  /// "Continue" on step 1: validates, probes and routes to step 2 or 3.
  Future<void> submitUrl() async {
    if (url.text.trim().isEmpty) {
      urlProblem = UrlProblem.empty;
      _notify();
      return;
    }
    if (!urlValid) {
      urlProblem = UrlProblem.invalid;
      _notify();
      return;
    }
    final op = ++_op;
    probing = true;
    probeError = null;
    urlProblem = null;
    _notify();
    try {
      final result = await tester.probe(normalizedUrl, allowSelfSigned: allowSelfSigned);
      if (op != _op) return;
      isDemo = false;
      _accept(result);
    } catch (e) {
      if (op == _op) probeError = e;
    } finally {
      if (op == _op) {
        probing = false;
        _notify();
      }
    }
  }

  /// "It is behind a sign-in gateway" (the address answered with a page
  /// that is not zhang's): step 2 with the proxy credentials.
  void useGateway() {
    if (!urlValid) return;
    probeError = null;
    _accept(ServerProbe(baseUrl: normalizedUrl), forceProxy: true);
  }

  void _accept(ServerProbe result, {bool forceProxy = false}) {
    // Credentials entered for this server survive going back and forth.
    final key = '${result.baseUrl}|$allowSelfSigned';
    if (key != _signInFor) _resetSignIn();
    _signInFor = key;
    probe = result;
    if (result.open) {
      verified = SetupVerified(profile: _baseProfile(), info: result.info!);
      _enterReady();
      return;
    }
    mode = forceProxy ? SignInMode.proxy : _modeFor(result);
    _go(SetupStage.signIn);
  }

  static SignInMode _modeFor(ServerProbe probe) {
    final auth = probe.auth;
    if (auth == null || !auth.enabled) return SignInMode.proxy;
    if (auth.supportsAppLogin) return SignInMode.browser;
    if (auth.password) return SignInMode.password;
    return SignInMode.unsupported;
  }

  /// The probed server without credentials.
  ServerProfile _baseProfile() => ServerProfile(
    id: '',
    name: '',
    baseUrl: probe?.baseUrl ?? normalizedUrl,
    allowSelfSigned: allowSelfSigned,
  );

  /// Host (and port) of the probed server, for headings.
  String get host {
    final uri = Uri.tryParse(probe?.baseUrl ?? normalizedUrl);
    if (uri == null || uri.host.isEmpty) return normalizedUrl;
    return uri.hasPort ? '${uri.host}:${uri.port}' : uri.host;
  }

  // ------------------------------------------------------ step 2: sign in

  SignInMode mode = SignInMode.browser;
  ProxyAuth proxyAuth = ProxyAuth.bearer;
  final username = TextEditingController();
  final password = TextEditingController();
  final token = TextEditingController();
  final List<HeaderRow> headers = [HeaderRow()];

  /// Server (URL + certificate policy) the step 2 fields belong to.
  String? _signInFor;

  /// A sign-in or connection attempt is running.
  bool busy = false;

  /// Failure of the main sign-in (browser / password / proxy mode).
  Object? signInError;

  /// Failure of "Connect" in the "Reverse proxy or gateway" section.
  Object? proxyError;

  /// The working credentials (and `/api/info` with them).
  SetupVerified? verified;

  /// Browser and password sign-in both work on this server.
  bool get canSwitchToPassword => mode == SignInMode.browser && (probe?.auth?.password ?? false);
  bool get canSwitchToBrowser => mode == SignInMode.password && (probe?.auth?.supportsAppLogin ?? false);

  void setMode(SignInMode value) {
    mode = value;
    signInError = null;
    _notify();
  }

  void setProxyAuth(ProxyAuth value) {
    proxyAuth = value;
    credentialsChanged();
    _notify();
  }

  void addHeader() {
    headers.add(HeaderRow());
    _notify();
  }

  void removeHeader(int index) {
    if (headers.length == 1) return;
    headers.removeAt(index).dispose();
    credentialsChanged();
    _notify();
  }

  /// Any credential was edited: the last result no longer applies.
  void credentialsChanged() {
    final staleResult = verified != null && _stage == SetupStage.signIn;
    if (signInError == null && proxyError == null && !staleResult) return;
    signInError = null;
    proxyError = null;
    if (_stage == SetupStage.signIn) verified = null;
    _notify();
  }

  void _resetSignIn() {
    verified = null;
    signInError = null;
    proxyError = null;
    username.clear();
    password.clear();
    token.clear();
    for (final h in headers) {
      h.dispose();
    }
    headers
      ..clear()
      ..add(HeaderRow());
    proxyAuth = ProxyAuth.bearer;
  }

  /// "Sign in with browser": login page → callback → exchange, then
  /// `/api/info` with the new session.
  Future<void> signInWithBrowser() => _verify(
    proxy: false,
    run: () async {
      final grant = await browser.startBrowserSignIn(_baseProfile().baseUrl, allowSelfSigned: allowSelfSigned);
      final profile = grant.applyTo(_baseProfile());
      return SetupVerified(profile: profile, info: await tester.test(profile), user: grant.user);
    },
  );

  /// "Sign in" with username and password (HTTP Basic).
  Future<void> signInWithPassword() => _verify(
    proxy: false,
    run: () async {
      final user = username.text.trim();
      final profile = _baseProfile().copyWith(
        authType: AuthType.basic,
        basicUsername: user,
        basicPassword: password.text,
      );
      return SetupVerified(profile: profile, info: await tester.test(profile), user: user);
    },
  );

  /// "Connect" with the reverse proxy credentials.
  Future<void> connectProxy() => _verify(
    proxy: mode != SignInMode.proxy,
    run: () async {
      final profile = proxyAuth == ProxyAuth.bearer
          ? _baseProfile().copyWith(authType: AuthType.bearer, bearerToken: token.text.trim())
          : _baseProfile().copyWith(authType: AuthType.headers, customHeaders: HeaderRow.toMap(headers));
      return SetupVerified(profile: profile, info: await tester.test(profile));
    },
  );

  Future<void> _verify({required bool proxy, required Future<SetupVerified> Function() run}) async {
    final op = ++_op;
    busy = true;
    signInError = null;
    proxyError = null;
    verified = null;
    _notify();
    try {
      final result = await run();
      if (op == _op) verified = result;
    } on BrowserSignInException catch (e) {
      // Closing the browser is not an error.
      if (op == _op && e.kind != BrowserSignInFailure.cancelled) signInError = e;
    } catch (e) {
      if (op == _op) proxy ? proxyError = e : signInError = e;
    } finally {
      if (op == _op) {
        busy = false;
        _notify();
      }
    }
  }

  /// "Check again" (passkey-only server, after upgrading it).
  Future<void> recheck() async {
    final op = ++_op;
    busy = true;
    signInError = null;
    _notify();
    try {
      final result = await tester.probe(_baseProfile().baseUrl, allowSelfSigned: allowSelfSigned);
      if (op != _op) return;
      probe = result;
      if (result.open) {
        verified = SetupVerified(profile: _baseProfile(), info: result.info!);
        _enterReady();
      } else {
        mode = _modeFor(result);
      }
    } catch (e) {
      if (op == _op) signInError = e;
    } finally {
      if (op == _op) {
        busy = false;
        _notify();
      }
    }
  }

  /// "Continue" after a successful sign-in.
  void continueToReady() {
    if (verified != null) _enterReady();
  }

  // ------------------------------------------------------- step 3: ready

  final name = TextEditingController();
  bool _nameEdited = false;
  int? color;

  /// Currency and account count, loading in the background.
  Future<LedgerOverview>? overview;

  /// The ledger title from the server, if any.
  String? get ledgerTitle {
    final t = verified?.info.title ?? probe?.title;
    return (t == null || t.trim().isEmpty) ? null : t.trim();
  }

  void _enterReady() {
    if (!_nameEdited || name.text.trim().isEmpty) {
      name.text = ledgerTitle ?? host;
      _nameEdited = false;
    }
    // ignore(): FutureBuilder still sees the error; nothing is unhandled
    // before it subscribes.
    overview = tester.overview(verified!.profile)..ignore();
    _go(SetupStage.ready);
  }

  void nameChanged() {
    _nameEdited = true;
    _notify();
  }

  void setColor(int? value) {
    color = value;
    _notify();
  }

  /// The profile to save ("Start").
  ServerProfile buildProfile(String id) {
    final typed = name.text.trim();
    return verified!.profile.copyWith(
      id: id,
      name: typed.isEmpty ? (ledgerTitle ?? host) : typed,
      color: color,
    );
  }

  @override
  void dispose() {
    _disposed = true;
    _op++;
    for (final c in [url, username, password, token, name]) {
      c.dispose();
    }
    for (final h in headers) {
      h.dispose();
    }
    super.dispose();
  }
}
