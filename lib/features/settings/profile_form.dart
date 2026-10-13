import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/widgets/error_view.dart';
import '../../core/widgets/notice_card.dart';
import '../../data/api/zhang_api_client.dart';
import '../../data/auth/browser_sign_in.dart';
import '../../data/models/info.dart';
import '../../data/profiles/profile_repository.dart';
import '../../data/profiles/server_profile.dart';
import '../../l10n/l10n.dart';
import 'header_row.dart';
import 'profile_color_picker.dart';
import 'session_actions.dart';

/// Compact form for editing a [ServerProfile] (Settings → Edit server), in
/// three sections: Server (name, URL, self-signed certificate), Sign-in
/// (method chooser with matching fields, "Test connection") and Appearance
/// (colour). New servers go through the setup wizard instead
/// (`ServerSetupScreen`).
///
/// The "Browser" auth type ([AuthType.session]) has no credential fields: a
/// "Sign in with browser" button runs [BrowserSignIn.signIn] and the form
/// keeps the session it returns; saving is only possible with a session for
/// the URL currently entered.
class ProfileForm extends ConsumerStatefulWidget {
  const ProfileForm({
    super.key,
    this.initial,
    required this.submitLabel,
    required this.onSubmit,
  });

  /// Profile being edited, or `null` for a new one.
  final ServerProfile? initial;
  final String submitLabel;

  /// Persists the built profile. Errors are shown in a snackbar.
  final Future<void> Function(ServerProfile profile) onSubmit;

  @override
  ConsumerState<ProfileForm> createState() => _ProfileFormState();
}

class _ProfileFormState extends ConsumerState<ProfileForm> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _name;
  late final TextEditingController _url;
  late final TextEditingController _username;
  late final TextEditingController _password;
  late final TextEditingController _token;
  late final List<HeaderRow> _headers;
  late AuthType _authType;
  late bool _allowSelfSigned;
  int? _color;
  bool _obscure = true;

  bool _testing = false;
  bool _saving = false;
  ServerInfo? _testInfo;
  Object? _testError;

  // Browser sign-in session ([AuthType.session]) and the normalised URL it
  // belongs to: a session is only used while that URL is entered.
  String? _sessionToken;
  DateTime? _sessionExpiresAt;
  String? _sessionUser;
  String? _sessionBaseUrl;
  bool _signingIn = false;
  Object? _signInError;

  @override
  void initState() {
    super.initState();
    final p = widget.initial;
    _name = TextEditingController(text: p?.name ?? '');
    _url = TextEditingController(text: p?.baseUrl ?? '');
    _username = TextEditingController(text: p?.basicUsername ?? '');
    _password = TextEditingController(text: p?.basicPassword ?? '');
    _token = TextEditingController(text: p?.bearerToken ?? '');
    _headers = [
      for (final e in (p?.customHeaders ?? const <String, String>{}).entries)
        HeaderRow(e.key, e.value),
    ];
    if (_headers.isEmpty) _headers.add(HeaderRow());
    _authType = p?.authType ?? AuthType.none;
    _allowSelfSigned = p?.allowSelfSigned ?? false;
    _color = p?.color;
    if (p != null && p.hasSession) {
      _sessionToken = p.sessionToken;
      _sessionExpiresAt = p.sessionExpiresAt;
      _sessionUser = p.sessionUser;
      _sessionBaseUrl = p.baseUrl;
    }
  }

  /// A browser sign-in session for the URL currently entered.
  bool get _hasSession =>
      _sessionToken != null && _sessionBaseUrl == ServerProfile.normalizeBaseUrl(_url.text);

  /// Saving a "Browser" profile needs a session first.
  bool get _needsSignIn => _authType == AuthType.session && !_hasSession;

  @override
  void dispose() {
    for (final c in [_name, _url, _username, _password, _token]) {
      c.dispose();
    }
    for (final h in _headers) {
      h.dispose();
    }
    super.dispose();
  }

  void _resetTest() {
    if (_testInfo != null || _testError != null) {
      setState(() {
        _testInfo = null;
        _testError = null;
      });
    }
  }

  /// Builds a profile from the current field values (only the secrets of the
  /// selected auth type are kept).
  ServerProfile _buildProfile() {
    final baseUrl = ServerProfile.normalizeBaseUrl(_url.text);
    final host = Uri.tryParse(baseUrl)?.host ?? baseUrl;
    final name = _name.text.trim().isEmpty ? host : _name.text.trim();
    final session = _authType == AuthType.session && _hasSession;
    return ServerProfile(
      id: widget.initial?.id ?? ProfileRepository.newId(),
      name: name,
      baseUrl: baseUrl,
      authType: _authType,
      basicUsername: _authType == AuthType.basic ? _username.text.trim() : null,
      basicPassword: _authType == AuthType.basic ? _password.text : null,
      bearerToken: _authType == AuthType.bearer ? _token.text.trim() : null,
      customHeaders: _authType == AuthType.headers ? HeaderRow.toMap(_headers) : const {},
      sessionToken: session ? _sessionToken : null,
      sessionExpiresAt: session ? _sessionExpiresAt : null,
      sessionUser: session ? _sessionUser : null,
      allowSelfSigned: _allowSelfSigned,
      color: _color,
    );
  }

  String? _validateUrl(String? value) {
    final l10n = context.l10n;
    if (value == null || value.trim().isEmpty) return l10n.serverUrlRequired;
    final normalized = ServerProfile.normalizeBaseUrl(value);
    if (!ServerProfile.isValidBaseUrl(normalized)) return l10n.serverUrlInvalid;
    return null;
  }

  Future<void> _test() async {
    final urlError = _validateUrl(_url.text);
    if (urlError != null) {
      _formKey.currentState?.validate();
      return;
    }
    FocusScope.of(context).unfocus();
    setState(() {
      _testing = true;
      _testInfo = null;
      _testError = null;
    });
    try {
      final info = await ref.read(connectionTesterProvider).test(_buildProfile());
      if (mounted) setState(() => _testInfo = info);
    } catch (e) {
      if (mounted) setState(() => _testError = e);
    } finally {
      if (mounted) setState(() => _testing = false);
    }
  }

  /// "Sign in with browser": `/api/auth/status`, then the browser handoff.
  Future<void> _signIn() async {
    final urlError = _validateUrl(_url.text);
    if (urlError != null) {
      _formKey.currentState?.validate();
      return;
    }
    FocusScope.of(context).unfocus();
    final baseUrl = ServerProfile.normalizeBaseUrl(_url.text);
    setState(() {
      _signingIn = true;
      _signInError = null;
      _testInfo = null;
      _testError = null;
    });
    try {
      final grant = await ref
          .read(browserSignInProvider)
          .signIn(baseUrl, allowSelfSigned: _allowSelfSigned);
      if (!mounted) return;
      setState(() {
        _sessionToken = grant.token;
        _sessionExpiresAt = grant.expiresAt;
        _sessionUser = grant.user;
        _sessionBaseUrl = baseUrl;
      });
    } on BrowserSignInException catch (e) {
      if (mounted && e.kind != BrowserSignInFailure.cancelled) setState(() => _signInError = e);
    } catch (e) {
      if (mounted) setState(() => _signInError = e);
    } finally {
      if (mounted) setState(() => _signingIn = false);
    }
  }

  Future<void> _submit() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    if (_needsSignIn) return;
    FocusScope.of(context).unfocus();
    setState(() => _saving = true);
    try {
      await widget.onSubmit(_buildProfile());
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(context.l10n.errorUnknown('$e'))),
        );
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  static String authLabel(AppLocalizations l10n, AuthType type) => switch (type) {
    AuthType.none => l10n.authNoneLong,
    AuthType.basic => l10n.authBasicLong,
    AuthType.session => l10n.authSessionLong,
    AuthType.bearer => l10n.authBearerLong,
    AuthType.headers => l10n.authHeadersLong,
  };

  static IconData _authIcon(AuthType type) => switch (type) {
    AuthType.none => Icons.lock_open_outlined,
    AuthType.basic => Icons.password_outlined,
    AuthType.session => Icons.open_in_browser,
    AuthType.bearer => Icons.token_outlined,
    AuthType.headers => Icons.vpn_lock_outlined,
  };

  /// Menu order: zhang's own sign-ins first, reverse proxy ones last.
  static const _authOrder = [AuthType.none, AuthType.basic, AuthType.session, AuthType.bearer, AuthType.headers];

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    const gap = SizedBox(height: 16);
    return Form(
      key: _formKey,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _FormSection(l10n.profileSectionServer, first: true),
          TextFormField(
            key: const Key('profileForm.name'),
            controller: _name,
            textInputAction: TextInputAction.next,
            decoration: InputDecoration(
              labelText: l10n.profileNameLabel,
              hintText: l10n.profileNameHint,
            ),
          ),
          gap,
          TextFormField(
            key: const Key('profileForm.url'),
            controller: _url,
            keyboardType: TextInputType.url,
            autocorrect: false,
            textInputAction: TextInputAction.next,
            decoration: InputDecoration(
              labelText: l10n.serverUrlLabel,
              hintText: l10n.serverUrlHint,
              helperText: l10n.serverUrlHelper,
            ),
            validator: _validateUrl,
            onChanged: (_) {
              _resetTest();
              // The session belongs to one server: re-evaluate it.
              if (_authType == AuthType.session) {
                setState(() => _signInError = null);
              }
            },
          ),
          SwitchListTile(
            key: const Key('profileForm.allowSelfSigned'),
            contentPadding: EdgeInsets.zero,
            title: Text(l10n.allowSelfSignedLabel),
            subtitle: Text(l10n.allowSelfSignedHelp),
            value: _allowSelfSigned,
            onChanged: (v) {
              setState(() => _allowSelfSigned = v);
              _resetTest();
            },
          ),
          _FormSection(l10n.profileSectionSignIn),
          DropdownMenu<AuthType>(
            key: const Key('profileForm.authType'),
            initialSelection: _authType,
            expandedInsets: EdgeInsets.zero,
            label: Text(l10n.authMethodLabel),
            leadingIcon: Icon(_authIcon(_authType)),
            requestFocusOnTap: false,
            enableSearch: false,
            dropdownMenuEntries: [
              for (final t in _authOrder)
                DropdownMenuEntry(value: t, label: authLabel(l10n, t), leadingIcon: Icon(_authIcon(t))),
            ],
            onSelected: (t) {
              if (t == null || t == _authType) return;
              setState(() {
                _authType = t;
                _signInError = null;
              });
              _resetTest();
            },
          ),
          gap,
          ..._authFields(l10n),
          OutlinedButton.icon(
            key: const Key('profileForm.test'),
            onPressed: _testing || _saving || _signingIn || _needsSignIn ? null : _test,
            icon: _testing
                ? const SizedBox.square(
                    dimension: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.wifi_tethering),
            label: Text(_testing ? l10n.testingConnection : l10n.testConnection),
          ),
          if (_testInfo != null || _testError != null) ...[
            const SizedBox(height: 12),
            _TestResultCard(info: _testInfo, error: _testError),
          ],
          _FormSection(l10n.profileSectionAppearance),
          Text(l10n.colorLabel, style: Theme.of(context).textTheme.labelLarge),
          const SizedBox(height: 12),
          ProfileColorPicker(
            selected: _color,
            onChanged: (c) => setState(() => _color = c),
          ),
          const SizedBox(height: 32),
          FilledButton(
            key: const Key('profileForm.submit'),
            style: FilledButton.styleFrom(minimumSize: const Size.fromHeight(48)),
            onPressed: _saving || _signingIn || _needsSignIn ? null : _submit,
            child: _saving
                ? const SizedBox.square(
                    dimension: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : Text(widget.submitLabel),
          ),
        ],
      ),
    );
  }

  List<Widget> _authFields(AppLocalizations l10n) {
    const gap = SizedBox(height: 16);
    final visibility = IconButton(
      tooltip: _obscure ? l10n.showSecret : l10n.hideSecret,
      icon: Icon(_obscure ? Icons.visibility_outlined : Icons.visibility_off_outlined),
      onPressed: () => setState(() => _obscure = !_obscure),
    );
    switch (_authType) {
      case AuthType.none:
        return const [];
      case AuthType.session:
        return _sessionFields(l10n);
      case AuthType.basic:
        return [
          TextFormField(
            key: const Key('profileForm.username'),
            controller: _username,
            autocorrect: false,
            textInputAction: TextInputAction.next,
            decoration: InputDecoration(labelText: l10n.usernameLabel),
            onChanged: (_) => _resetTest(),
          ),
          gap,
          TextFormField(
            key: const Key('profileForm.password'),
            controller: _password,
            obscureText: _obscure,
            autocorrect: false,
            enableSuggestions: false,
            decoration: InputDecoration(labelText: l10n.passwordLabel, suffixIcon: visibility),
            onChanged: (_) => _resetTest(),
          ),
          gap,
        ];
      case AuthType.bearer:
        return [
          TextFormField(
            key: const Key('profileForm.token'),
            controller: _token,
            obscureText: _obscure,
            autocorrect: false,
            enableSuggestions: false,
            decoration: InputDecoration(labelText: l10n.tokenLabel, suffixIcon: visibility),
            onChanged: (_) => _resetTest(),
          ),
          gap,
        ];
      case AuthType.headers:
        return [
          for (var i = 0; i < _headers.length; i++) ...[
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: TextFormField(
                    key: Key('profileForm.headerName.$i'),
                    controller: _headers[i].name,
                    autocorrect: false,
                    decoration: InputDecoration(labelText: l10n.headerNameLabel),
                    onChanged: (_) => _resetTest(),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: TextFormField(
                    key: Key('profileForm.headerValue.$i'),
                    controller: _headers[i].value,
                    obscureText: _obscure,
                    autocorrect: false,
                    enableSuggestions: false,
                    decoration: InputDecoration(labelText: l10n.headerValueLabel),
                    onChanged: (_) => _resetTest(),
                  ),
                ),
                IconButton(
                  tooltip: l10n.removeHeader,
                  icon: const Icon(Icons.remove_circle_outline),
                  onPressed: _headers.length == 1
                      ? null
                      : () => setState(() => _headers.removeAt(i).dispose()),
                ),
              ],
            ),
            const SizedBox(height: 8),
          ],
          Row(
            children: [
              TextButton.icon(
                onPressed: () => setState(() => _headers.add(HeaderRow())),
                icon: const Icon(Icons.add),
                label: Text(l10n.addHeader),
              ),
              const Spacer(),
              visibility,
            ],
          ),
          gap,
        ];
    }
  }

  List<Widget> _sessionFields(AppLocalizations l10n) {
    final theme = Theme.of(context);
    final signedIn = _hasSession;
    return [
      Text(
        l10n.authSessionHelper,
        style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.onSurfaceVariant),
      ),
      const SizedBox(height: 12),
      FilledButton.tonalIcon(
        key: const Key('profileForm.signIn'),
        onPressed: _signingIn || _saving ? null : _signIn,
        icon: _signingIn
            ? const SizedBox.square(dimension: 18, child: CircularProgressIndicator(strokeWidth: 2))
            : const Icon(Icons.login),
        label: Text(
          _signingIn ? l10n.signingIn : (signedIn ? l10n.signInAgain : l10n.signInWithBrowser),
        ),
      ),
      const SizedBox(height: 12),
      if (_signInError != null)
        _StatusCard(
          key: const Key('profileForm.signInError'),
          ok: false,
          icon: iconForApiError(_signInError!),
          title: describeApiError(l10n, _signInError!),
        )
      else if (signedIn)
        _StatusCard(
          key: const Key('profileForm.signedIn'),
          ok: true,
          icon: Icons.verified_user_outlined,
          title: l10n.signedInAs(
            _sessionUser ?? '',
            _sessionExpiresAt == null ? '—' : formatSessionExpiry(_sessionExpiresAt!),
          ),
        )
      else
        Text(
          l10n.signInFirst,
          key: const Key('profileForm.signInFirst'),
          style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.onSurfaceVariant),
        ),
      const SizedBox(height: 16),
    ];
  }
}

/// Section title of the form ("Server", "Sign-in", "Appearance").
class _FormSection extends StatelessWidget {
  const _FormSection(this.text, {this.first = false});

  final String text;
  final bool first;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: EdgeInsets.only(top: first ? 4 : 28, bottom: 12),
      child: Text(text, style: theme.textTheme.titleSmall?.copyWith(color: theme.colorScheme.primary)),
    );
  }
}

/// Result line under the browser sign-in button.
class _StatusCard extends StatelessWidget {
  const _StatusCard({super.key, required this.ok, required this.icon, required this.title});

  final bool ok;
  final IconData icon;
  final String title;

  @override
  Widget build(BuildContext context) =>
      NoticeCard(tone: ok ? NoticeTone.success : NoticeTone.error, icon: icon, title: title);
}

class _TestResultCard extends StatelessWidget {
  const _TestResultCard({this.info, this.error});

  final ServerInfo? info;
  final Object? error;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final ok = info != null;
    if (!ok) {
      return NoticeCard(
        key: const Key('profileForm.testError'),
        tone: NoticeTone.error,
        icon: iconForApiError(error!),
        title: describeApiError(l10n, error!),
      );
    }
    final title = (info!.title == null || info!.title!.isEmpty) ? l10n.untitledLedger : info!.title!;
    return NoticeCard(
      key: const Key('profileForm.testOk'),
      tone: NoticeTone.success,
      icon: Icons.check_circle,
      title: l10n.connectionOk(title),
      body: l10n.connectionOkDetail(info!.version, info!.buildDate),
    );
  }
}
