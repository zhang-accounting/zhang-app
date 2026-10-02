import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/theme/app_colors.dart';
import '../../core/widgets/error_view.dart';
import '../../data/api/zhang_api_client.dart';
import '../../data/models/info.dart';
import '../../data/profiles/profile_repository.dart';
import '../../data/profiles/server_profile.dart';
import '../../l10n/l10n.dart';

/// Colours offered for tagging a ledger (ARGB). `null` = theme primary.
const List<int> kProfilePalette = [
  0xFF1F6F8B, // teal blue
  0xFF3949AB, // indigo
  0xFF00897B, // teal
  0xFF2E7D32, // green
  0xFFF9A825, // amber
  0xFFEF6C00, // orange
  0xFFC62828, // red
  0xFF8E24AA, // purple
];

/// Shared add/edit form for a [ServerProfile] (onboarding + settings):
/// name, URL, auth type with matching fields, self-signed toggle, colour,
/// "Test connection" (GET /api/info) and a submit button.
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

class _HeaderRow {
  _HeaderRow([String name = '', String value = ''])
    : name = TextEditingController(text: name),
      value = TextEditingController(text: value);

  final TextEditingController name;
  final TextEditingController value;

  void dispose() {
    name.dispose();
    value.dispose();
  }
}

class _ProfileFormState extends ConsumerState<ProfileForm> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _name;
  late final TextEditingController _url;
  late final TextEditingController _username;
  late final TextEditingController _password;
  late final TextEditingController _token;
  late final List<_HeaderRow> _headers;
  late AuthType _authType;
  late bool _allowSelfSigned;
  int? _color;
  bool _obscure = true;

  bool _testing = false;
  bool _saving = false;
  ServerInfo? _testInfo;
  Object? _testError;

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
        _HeaderRow(e.key, e.value),
    ];
    if (_headers.isEmpty) _headers.add(_HeaderRow());
    _authType = p?.authType ?? AuthType.none;
    _allowSelfSigned = p?.allowSelfSigned ?? false;
    _color = p?.color;
  }

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
    return ServerProfile(
      id: widget.initial?.id ?? ProfileRepository.newId(),
      name: name,
      baseUrl: baseUrl,
      authType: _authType,
      basicUsername: _authType == AuthType.basic ? _username.text.trim() : null,
      basicPassword: _authType == AuthType.basic ? _password.text : null,
      bearerToken: _authType == AuthType.bearer ? _token.text.trim() : null,
      customHeaders: _authType == AuthType.headers
          ? {
              for (final h in _headers)
                if (h.name.text.trim().isNotEmpty) h.name.text.trim(): h.value.text,
            }
          : const {},
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

  Future<void> _submit() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;
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

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    const gap = SizedBox(height: 16);
    return Form(
      key: _formKey,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
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
            onChanged: (_) => _resetTest(),
          ),
          gap,
          Text(l10n.authTypeLabel, style: Theme.of(context).textTheme.labelLarge),
          const SizedBox(height: 8),
          SegmentedButton<AuthType>(
            key: const Key('profileForm.authType'),
            showSelectedIcon: false,
            segments: [
              ButtonSegment(value: AuthType.none, label: Text(l10n.authNone)),
              ButtonSegment(value: AuthType.basic, label: Text(l10n.authBasic)),
              ButtonSegment(value: AuthType.bearer, label: Text(l10n.authBearer)),
              ButtonSegment(value: AuthType.headers, label: Text(l10n.authHeaders)),
            ],
            selected: {_authType},
            onSelectionChanged: (s) {
              setState(() => _authType = s.first);
              _resetTest();
            },
          ),
          gap,
          ..._authFields(l10n),
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            title: Text(l10n.allowSelfSignedLabel),
            subtitle: Text(l10n.allowSelfSignedHelp),
            value: _allowSelfSigned,
            onChanged: (v) {
              setState(() => _allowSelfSigned = v);
              _resetTest();
            },
          ),
          const SizedBox(height: 8),
          Text(l10n.colorLabel, style: Theme.of(context).textTheme.labelLarge),
          const SizedBox(height: 8),
          _ColorPicker(
            selected: _color,
            onChanged: (c) => setState(() => _color = c),
          ),
          const SizedBox(height: 24),
          OutlinedButton.icon(
            key: const Key('profileForm.test'),
            onPressed: _testing || _saving ? null : _test,
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
          const SizedBox(height: 12),
          FilledButton(
            key: const Key('profileForm.submit'),
            onPressed: _saving ? null : _submit,
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
                onPressed: () => setState(() => _headers.add(_HeaderRow())),
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
}

class _ColorPicker extends StatelessWidget {
  const _ColorPicker({required this.selected, required this.onChanged});

  final int? selected;
  final ValueChanged<int?> onChanged;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    Widget swatch(int? value) {
      final color = value == null ? scheme.primary : Color(value);
      final isSelected = selected == value;
      return Semantics(
        selected: isSelected,
        button: true,
        label: value == null ? context.l10n.colorDefault : '#${value.toRadixString(16)}',
        child: InkResponse(
          onTap: () => onChanged(value),
          radius: 22,
          child: Container(
            width: 32,
            height: 32,
            decoration: BoxDecoration(
              color: color,
              shape: BoxShape.circle,
              border: Border.all(
                color: isSelected ? scheme.onSurface : Colors.transparent,
                width: 2.5,
              ),
            ),
            child: value == null
                ? Icon(Icons.auto_awesome, size: 16, color: scheme.onPrimary)
                : (isSelected ? const Icon(Icons.check, size: 18, color: Colors.white) : null),
          ),
        ),
      );
    }

    return Wrap(
      spacing: 10,
      runSpacing: 10,
      children: [swatch(null), for (final c in kProfilePalette) swatch(c)],
    );
  }
}

class _TestResultCard extends StatelessWidget {
  const _TestResultCard({this.info, this.error});

  final ServerInfo? info;
  final Object? error;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final colors = context.zhangColors;
    final ok = info != null;
    final background = ok ? colors.incomeContainer : colors.expenseContainer;
    final foreground = ok ? colors.onIncomeContainer : colors.onExpenseContainer;
    final title = ok
        ? l10n.connectionOk(
            (info!.title == null || info!.title!.isEmpty) ? l10n.untitledLedger : info!.title!,
          )
        : describeApiError(l10n, error!);
    return Card(
      key: Key(ok ? 'profileForm.testOk' : 'profileForm.testError'),
      color: background,
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(ok ? Icons.check_circle : iconForApiError(error!), color: foreground),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: TextStyle(color: foreground, fontWeight: FontWeight.w600)),
                  if (ok)
                    Text(
                      l10n.connectionOkDetail(info!.version, info!.buildDate),
                      style: TextStyle(color: foreground),
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
