import 'package:flutter/material.dart';

import '../../core/widgets/error_view.dart';
import '../../core/widgets/notice_card.dart';
import '../../l10n/l10n.dart';
import 'setup_controller.dart';
import 'setup_layout.dart';
import 'setup_links.dart';

/// Step 2: only the sign-in the server supports (from `/api/auth/status`):
/// the browser (passkey or password) as the main path, username and password,
/// an explanation for passkey-only servers the app cannot use, or reverse
/// proxy credentials. Every sign-in is verified at once and the result shown
/// inline.
class SignInStep extends StatefulWidget {
  const SignInStep({super.key, required this.controller});

  final ServerSetupController controller;

  @override
  State<SignInStep> createState() => _SignInStepState();
}

class _SignInStepState extends State<SignInStep> {
  bool _obscure = true;

  ServerSetupController get c => widget.controller;

  Widget _visibilityToggle(AppLocalizations l10n) => IconButton(
    tooltip: _obscure ? l10n.showSecret : l10n.hideSecret,
    icon: Icon(_obscure ? Icons.visibility_outlined : Icons.visibility_off_outlined),
    onPressed: () => setState(() => _obscure = !_obscure),
  );

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final theme = Theme.of(context);
    final title = c.probe?.title;
    final verified = c.verified;
    return SetupLayout(
      content: [
        SetupHeading(
          title: title == null ? l10n.setupSignInTitleUntitled : l10n.setupSignInTitle(title),
          body: l10n.setupSignInBody(c.host),
        ),
        const SizedBox(height: 28),
        ...switch (c.mode) {
          SignInMode.browser => _browser(l10n),
          SignInMode.password => _password(l10n),
          SignInMode.unsupported => _unsupported(l10n),
          SignInMode.proxy => [
            Text(
              c.probe?.gateway ?? false ? l10n.setupGatewayBody : l10n.setupCredentialsUnknown,
              style: theme.textTheme.bodyMedium?.copyWith(color: theme.colorScheme.onSurfaceVariant),
            ),
            const SizedBox(height: 16),
            ..._proxyFields(l10n),
          ],
        },
        if (c.signInError != null) ...[
          const SizedBox(height: 16),
          NoticeCard(
            key: const Key('setup.result.error'),
            tone: NoticeTone.error,
            icon: iconForApiError(c.signInError!),
            title: describeApiError(l10n, c.signInError!),
          ),
        ],
        if (verified != null) ...[
          const SizedBox(height: 16),
          _VerifiedCard(verified: verified),
        ],
        if (c.mode != SignInMode.proxy) ...[
          const SizedBox(height: 20),
          _advanced(l10n),
        ],
      ],
      actions: _actions(l10n),
    );
  }

  List<Widget> _actions(AppLocalizations l10n) {
    if (c.verified != null) {
      return [
        FilledButton(
          key: const Key('setup.continue'),
          style: setupButtonStyle,
          onPressed: c.continueToReady,
          child: Text(l10n.setupContinue),
        ),
      ];
    }
    return switch (c.mode) {
      SignInMode.browser => [
        FilledButton.icon(
          key: const Key('setup.signInBrowser'),
          style: setupButtonStyle,
          onPressed: c.busy ? null : c.signInWithBrowser,
          icon: c.busy ? null : const Icon(Icons.open_in_browser),
          label: BusyLabel(busy: c.busy, label: l10n.signInWithBrowser, busyLabel: l10n.setupWaitingBrowser),
        ),
        if (c.canSwitchToPassword)
          TextButton(
            key: const Key('setup.usePassword'),
            style: setupButtonStyle,
            onPressed: c.busy ? null : () => c.setMode(SignInMode.password),
            child: Text(l10n.setupUsePassword),
          ),
      ],
      SignInMode.password => [
        FilledButton(
          key: const Key('setup.signIn'),
          style: setupButtonStyle,
          onPressed: c.busy ? null : c.signInWithPassword,
          child: BusyLabel(busy: c.busy, label: l10n.setupSignIn, busyLabel: l10n.signingIn),
        ),
        if (c.canSwitchToBrowser)
          TextButton(
            key: const Key('setup.useBrowser'),
            style: setupButtonStyle,
            onPressed: c.busy ? null : () => c.setMode(SignInMode.browser),
            child: Text(l10n.setupUseBrowser),
          ),
      ],
      SignInMode.unsupported => [
        FilledButton.tonal(
          key: const Key('setup.checkAgain'),
          style: setupButtonStyle,
          onPressed: c.busy ? null : c.recheck,
          child: BusyLabel(busy: c.busy, label: l10n.setupCheckAgain, busyLabel: l10n.setupChecking),
        ),
      ],
      SignInMode.proxy => [
        FilledButton(
          key: const Key('setup.connect'),
          style: setupButtonStyle,
          onPressed: c.busy ? null : c.connectProxy,
          child: BusyLabel(busy: c.busy, label: l10n.setupConnect, busyLabel: l10n.setupChecking),
        ),
      ],
    };
  }

  List<Widget> _browser(AppLocalizations l10n) => [
    _HowItWorks(
      key: const Key('setup.browserExplainer'),
      rows: [
        (Icons.open_in_browser, l10n.setupBrowserStep1),
        (Icons.key_rounded, l10n.setupBrowserStep2),
      ],
    ),
  ];

  List<Widget> _password(AppLocalizations l10n) => [
    TextField(
      key: const Key('setup.username'),
      controller: c.username,
      autofocus: c.username.text.isEmpty,
      autocorrect: false,
      enableSuggestions: false,
      textInputAction: TextInputAction.next,
      autofillHints: const [AutofillHints.username],
      enabled: !c.busy,
      onChanged: (_) => c.credentialsChanged(),
      decoration: InputDecoration(labelText: l10n.usernameLabel, prefixIcon: const Icon(Icons.person_outline)),
    ),
    const SizedBox(height: 16),
    TextField(
      key: const Key('setup.password'),
      controller: c.password,
      obscureText: _obscure,
      autocorrect: false,
      enableSuggestions: false,
      textInputAction: TextInputAction.go,
      autofillHints: const [AutofillHints.password],
      enabled: !c.busy,
      onChanged: (_) => c.credentialsChanged(),
      onSubmitted: (_) => c.signInWithPassword(),
      decoration: InputDecoration(
        labelText: l10n.passwordLabel,
        prefixIcon: const Icon(Icons.lock_outline),
        suffixIcon: _visibilityToggle(l10n),
      ),
    ),
  ];

  List<Widget> _unsupported(AppLocalizations l10n) => [
    NoticeCard(
      key: const Key('setup.passkeyUnsupported'),
      tone: NoticeTone.warning,
      icon: Icons.key_off_outlined,
      title: l10n.setupPasskeyOnlyTitle,
      body: l10n.setupPasskeyOnlyBody,
      actions: [
        TextButton.icon(
          onPressed: () => openExternalUrl(ZhangDocs.appSignIn(context)),
          icon: const Icon(Icons.open_in_new, size: 18),
          label: Text(l10n.setupHowToUpgrade),
        ),
      ],
    ),
  ];

  /// "Reverse proxy or gateway": collapsed below the main sign-in.
  Widget _advanced(AppLocalizations l10n) {
    final theme = Theme.of(context);
    return Theme(
      data: theme.copyWith(dividerColor: Colors.transparent),
      child: ExpansionTile(
        key: const Key('setup.advanced'),
        tilePadding: EdgeInsets.zero,
        childrenPadding: const EdgeInsets.only(bottom: 8),
        shape: const Border(),
        collapsedShape: const Border(),
        leading: Icon(Icons.vpn_lock_outlined, color: theme.colorScheme.onSurfaceVariant),
        title: Text(l10n.setupAdvancedTitle, style: theme.textTheme.titleSmall),
        subtitle: Text(
          l10n.setupAdvancedSubtitle,
          style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.onSurfaceVariant),
        ),
        children: [
          const SizedBox(height: 8),
          ..._proxyFields(l10n),
          const SizedBox(height: 16),
          FilledButton.tonal(
            key: const Key('setup.connectAdvanced'),
            onPressed: c.busy ? null : c.connectProxy,
            child: BusyLabel(busy: c.busy, label: l10n.setupConnect, busyLabel: l10n.setupChecking),
          ),
          if (c.proxyError != null) ...[
            const SizedBox(height: 12),
            NoticeCard(
              key: const Key('setup.proxyError'),
              tone: NoticeTone.error,
              icon: iconForApiError(c.proxyError!),
              title: describeApiError(l10n, c.proxyError!),
            ),
          ],
        ],
      ),
    );
  }

  List<Widget> _proxyFields(AppLocalizations l10n) => [
    SegmentedButton<ProxyAuth>(
      key: const Key('setup.proxyAuth'),
      showSelectedIcon: false,
      segments: [
        ButtonSegment(value: ProxyAuth.bearer, label: Text(l10n.tokenLabel)),
        ButtonSegment(value: ProxyAuth.headers, label: Text(l10n.setupProxyHeaders)),
      ],
      selected: {c.proxyAuth},
      onSelectionChanged: c.busy ? null : (s) => c.setProxyAuth(s.first),
    ),
    const SizedBox(height: 16),
    if (c.proxyAuth == ProxyAuth.bearer)
      TextField(
        key: const Key('setup.token'),
        controller: c.token,
        obscureText: _obscure,
        autocorrect: false,
        enableSuggestions: false,
        enabled: !c.busy,
        onChanged: (_) => c.credentialsChanged(),
        decoration: InputDecoration(labelText: l10n.tokenLabel, suffixIcon: _visibilityToggle(l10n)),
      )
    else ...[
      for (var i = 0; i < c.headers.length; i++) ...[
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: TextField(
                key: Key('setup.headerName.$i'),
                controller: c.headers[i].name,
                autocorrect: false,
                enabled: !c.busy,
                onChanged: (_) => c.credentialsChanged(),
                decoration: InputDecoration(labelText: l10n.headerNameLabel),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: TextField(
                key: Key('setup.headerValue.$i'),
                controller: c.headers[i].value,
                obscureText: _obscure,
                autocorrect: false,
                enableSuggestions: false,
                enabled: !c.busy,
                onChanged: (_) => c.credentialsChanged(),
                decoration: InputDecoration(labelText: l10n.headerValueLabel),
              ),
            ),
            IconButton(
              tooltip: l10n.removeHeader,
              icon: const Icon(Icons.remove_circle_outline),
              onPressed: c.headers.length == 1 || c.busy ? null : () => c.removeHeader(i),
            ),
          ],
        ),
        const SizedBox(height: 8),
      ],
      Row(
        children: [
          TextButton.icon(
            onPressed: c.busy ? null : c.addHeader,
            icon: const Icon(Icons.add),
            label: Text(l10n.addHeader),
          ),
          const Spacer(),
          _visibilityToggle(l10n),
        ],
      ),
    ],
  ];
}

/// Two short lines (icon + text) on what the browser sign-in does.
class _HowItWorks extends StatelessWidget {
  const _HowItWorks({super.key, required this.rows});

  final List<(IconData, String)> rows;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Material(
      color: theme.colorScheme.surfaceContainerLow,
      borderRadius: BorderRadius.circular(16),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
        child: Column(
          children: [
            for (final (icon, text) in rows)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 10),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      width: 36,
                      height: 36,
                      decoration: BoxDecoration(color: theme.colorScheme.secondaryContainer, shape: BoxShape.circle),
                      child: Icon(icon, size: 20, color: theme.colorScheme.onSecondaryContainer),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Padding(
                        padding: const EdgeInsets.only(top: 7),
                        child: Text(text, style: theme.textTheme.bodyMedium?.copyWith(height: 1.4)),
                      ),
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

/// The verified sign-in: who, which ledger, which zhang.
class _VerifiedCard extends StatelessWidget {
  const _VerifiedCard({required this.verified});

  final SetupVerified verified;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final info = verified.info;
    final title = (info.title == null || info.title!.isEmpty) ? l10n.untitledLedger : info.title!;
    final user = verified.user;
    return NoticeCard(
      key: const Key('setup.result.ok'),
      tone: NoticeTone.success,
      icon: Icons.check_circle,
      title: user == null || user.isEmpty ? l10n.setupConnected : l10n.setupSignedInAs(user),
      body: '${l10n.connectionOk(title)}\n${l10n.connectionOkDetail(info.version, info.buildDate)}',
    );
  }
}
