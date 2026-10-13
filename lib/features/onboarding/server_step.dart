import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../core/widgets/error_view.dart';
import '../../core/widgets/notice_card.dart';
import '../../data/api/api_exception.dart';
import '../../l10n/l10n.dart';
import 'setup_controller.dart';
import 'setup_layout.dart';
import 'setup_links.dart';

/// Step 1: the server address. "Continue" probes the server and moves on to
/// the sign-in or the summary; failures stay here with hints.
class ServerStep extends StatelessWidget {
  const ServerStep({super.key, required this.controller});

  final ServerSetupController controller;

  Future<void> _paste() async {
    final data = await Clipboard.getData(Clipboard.kTextPlain);
    final text = data?.text?.trim();
    if (text == null || text.isEmpty) return;
    controller.url
      ..text = text
      ..selection = TextSelection.collapsed(offset: text.length);
    controller.urlChanged();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final c = controller;
    final error = c.probeError;
    final helper = c.urlValid ? l10n.setupUrlNormalized(c.normalizedUrl) : null;
    return SetupLayout(
      content: [
        SetupHeading(title: l10n.setupServerTitle, body: l10n.setupServerBody),
        const SizedBox(height: 28),
        TextField(
          key: const Key('setup.url'),
          controller: c.url,
          autofocus: c.url.text.isEmpty,
          keyboardType: TextInputType.url,
          autocorrect: false,
          enableSuggestions: false,
          textInputAction: TextInputAction.go,
          enabled: !c.probing,
          onChanged: (_) => c.urlChanged(),
          onSubmitted: (_) => c.submitUrl(),
          decoration: InputDecoration(
            labelText: l10n.setupUrlLabel,
            hintText: l10n.setupUrlHint,
            prefixIcon: const Icon(Icons.dns_outlined),
            suffixIcon: IconButton(
              key: const Key('setup.paste'),
              tooltip: l10n.setupPaste,
              icon: const Icon(Icons.content_paste_rounded),
              onPressed: c.probing ? null : _paste,
            ),
            helperText: helper,
            helperMaxLines: 2,
            errorText: switch (c.urlProblem) {
              UrlProblem.empty => l10n.serverUrlRequired,
              UrlProblem.invalid => l10n.serverUrlInvalid,
              null => null,
            },
          ),
        ),
        if (c.showSelfSignedSwitch) ...[
          const SizedBox(height: 8),
          SwitchListTile(
            key: const Key('setup.allowSelfSigned'),
            contentPadding: EdgeInsets.zero,
            title: Text(l10n.allowSelfSignedLabel),
            subtitle: Text(l10n.allowSelfSignedHelp),
            value: c.allowSelfSigned,
            onChanged: c.probing ? null : c.setAllowSelfSigned,
          ),
        ],
        if (error != null) ...[
          const SizedBox(height: 16),
          _ProbeErrorCard(controller: c, error: error),
        ],
      ],
      actions: [
        FilledButton(
          key: const Key('setup.submitUrl'),
          style: setupButtonStyle,
          onPressed: c.probing ? null : c.submitUrl,
          child: BusyLabel(
            busy: c.probing,
            label: error == null ? l10n.setupContinue : l10n.setupTryAgain,
            busyLabel: l10n.setupChecking,
          ),
        ),
      ],
    );
  }
}

/// Why the probe failed and what to try: http instead of https, the
/// self-signed switch (above), a gateway, or upgrading the server.
class _ProbeErrorCard extends StatelessWidget {
  const _ProbeErrorCard({required this.controller, required this.error});

  final ServerSetupController controller;
  final Object error;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final c = controller;
    if (error case ApiServerTooOld(:final version)) {
      return NoticeCard(
        key: const Key('setup.tooOld'),
        tone: NoticeTone.warning,
        icon: Icons.update,
        title: l10n.setupTooOldTitle,
        body: l10n.setupTooOldBody(version),
        actions: [
          TextButton.icon(
            onPressed: () => openExternalUrl(ZhangDocs.upgrading(context)),
            icon: const Icon(Icons.open_in_new, size: 18),
            label: Text(l10n.setupHowToUpgrade),
          ),
        ],
      );
    }
    final http = c.httpAlternative;
    final network = error is ApiNetworkError;
    final notZhang = error is ApiParseError || error is ApiNotFound;
    final hints = <String>[
      if (network && !c.certificateRejected) l10n.setupHintReach,
      if (network && http != null) l10n.setupHttpHint,
      if (notZhang) l10n.setupNotZhang,
    ];
    return NoticeCard(
      key: const Key('setup.probeError'),
      tone: NoticeTone.error,
      icon: iconForApiError(error),
      title: describeApiError(l10n, error),
      body: hints.isEmpty ? null : hints.join('\n\n'),
      actions: [
        if (network && http != null)
          TextButton(
            key: const Key('setup.tryHttp'),
            onPressed: c.useHttp,
            child: Text(l10n.setupTryHttp(http), overflow: TextOverflow.ellipsis),
          ),
        if (notZhang || error is ApiUnauthorized)
          TextButton(
            key: const Key('setup.gateway'),
            onPressed: c.useGateway,
            child: Text(l10n.setupBehindGateway),
          ),
      ],
    );
  }
}
