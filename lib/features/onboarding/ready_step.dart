import 'package:flutter/material.dart';

import '../../core/widgets/notice_card.dart';
import '../../data/api/zhang_api_client.dart';
import '../../l10n/l10n.dart';
import '../settings/profile_color_picker.dart';
import 'setup_controller.dart';
import 'setup_layout.dart';

/// Step 3: what the app connected to (ledger, currency, accounts, zhang
/// version, user), the name and colour of the profile, and "Start".
class ReadyStep extends StatelessWidget {
  const ReadyStep({super.key, required this.controller, required this.saving, required this.onStart});

  final ServerSetupController controller;
  final bool saving;
  final VoidCallback onStart;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final theme = Theme.of(context);
    final c = controller;
    return SetupLayout(
      content: [
        SetupHeading(title: l10n.setupReadyTitle, body: l10n.setupReadyBody),
        const SizedBox(height: 24),
        _LedgerCard(controller: c),
        if (c.isDemo) ...[
          const SizedBox(height: 12),
          NoticeCard(
            key: const Key('setup.demoNote'),
            tone: NoticeTone.info,
            icon: Icons.visibility_outlined,
            title: l10n.setupDemoNote,
          ),
        ],
        const SizedBox(height: 28),
        TextField(
          key: const Key('setup.name'),
          controller: c.name,
          textCapitalization: TextCapitalization.sentences,
          textInputAction: TextInputAction.done,
          onChanged: (_) => c.nameChanged(),
          decoration: InputDecoration(labelText: l10n.setupNameLabel, hintText: c.ledgerTitle ?? c.host),
        ),
        const SizedBox(height: 24),
        Text(l10n.colorLabel, style: theme.textTheme.titleSmall),
        const SizedBox(height: 12),
        ProfileColorPicker(selected: c.color, onChanged: c.setColor, size: 30),
      ],
      actions: [
        FilledButton(
          key: const Key('setup.start'),
          style: setupButtonStyle,
          onPressed: saving ? null : onStart,
          child: BusyLabel(busy: saving, label: l10n.setupStart),
        ),
      ],
    );
  }
}

/// Preview of the ledger as the app will show it: avatar in the chosen
/// colour with the name, then the facts read from the server.
class _LedgerCard extends StatelessWidget {
  const _LedgerCard({required this.controller});

  final ServerSetupController controller;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final c = controller;
    final accent = c.color == null ? scheme.primary : Color(c.color!);
    final name = c.name.text.trim().isEmpty ? (c.ledgerTitle ?? c.host) : c.name.text.trim();
    final info = c.verified!.info;
    final user = c.verified!.user;
    return AnimatedContainer(
      key: const Key('setup.ledgerCard'),
      duration: const Duration(milliseconds: 200),
      decoration: BoxDecoration(
        color: Color.alphaBlend(accent.withValues(alpha: 0.06), scheme.surfaceContainerLow),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: accent.withValues(alpha: 0.35)),
      ),
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                width: 44,
                height: 44,
                alignment: Alignment.center,
                decoration: BoxDecoration(color: accent, shape: BoxShape.circle),
                child: Text(
                  name.characters.first.toUpperCase(),
                  style: theme.textTheme.titleMedium?.copyWith(
                    color: ThemeData.estimateBrightnessForColor(accent) == Brightness.dark
                        ? Colors.white
                        : Colors.black87,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      name,
                      key: const Key('setup.ledgerCard.name'),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w600),
                    ),
                    Text(
                      c.host,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.bodySmall?.copyWith(color: scheme.onSurfaceVariant),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Divider(height: 1, color: accent.withValues(alpha: 0.2)),
          const SizedBox(height: 4),
          FutureBuilder<LedgerOverview>(
            future: c.overview,
            builder: (context, snapshot) {
              if (snapshot.hasError) {
                return Padding(
                  padding: const EdgeInsets.symmetric(vertical: 10),
                  child: Text(
                    l10n.setupFactUnavailable,
                    key: const Key('setup.overviewError'),
                    style: theme.textTheme.bodyMedium?.copyWith(color: scheme.onSurfaceVariant),
                  ),
                );
              }
              final overview = snapshot.data;
              return Column(
                children: [
                  _Fact(
                    icon: Icons.payments_outlined,
                    label: l10n.setupFactCurrency,
                    value: overview?.operatingCurrency,
                    valueKey: const Key('setup.fact.currency'),
                  ),
                  _Fact(
                    icon: Icons.account_tree_outlined,
                    label: l10n.setupFactAccounts,
                    value: overview == null ? null : l10n.setupFactAccountsValue(overview.openAccounts),
                    valueKey: const Key('setup.fact.accounts'),
                  ),
                ],
              );
            },
          ),
          _Fact(
            icon: Icons.dns_outlined,
            label: l10n.setupFactServer,
            value: 'zhang ${info.version}',
            valueKey: const Key('setup.fact.server'),
          ),
          if (user != null && user.isNotEmpty)
            _Fact(
              icon: Icons.person_outline,
              label: l10n.setupFactSignedIn,
              value: user,
              valueKey: const Key('setup.fact.user'),
            )
          else if (c.verified!.profile.authHeaders().isEmpty)
            _Fact(icon: Icons.lock_open_outlined, label: l10n.setupFactSignIn, value: l10n.setupFactNoSignIn),
        ],
      ),
    );
  }
}

/// One label / value line of the ledger card; a small spinner while
/// [value] is loading.
class _Fact extends StatelessWidget {
  const _Fact({required this.icon, required this.label, required this.value, this.valueKey});

  final IconData icon;
  final String label;
  final String? value;
  final Key? valueKey;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final muted = theme.colorScheme.onSurfaceVariant;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 9),
      child: Row(
        children: [
          Icon(icon, size: 20, color: muted),
          const SizedBox(width: 12),
          Text(label, style: theme.textTheme.bodyMedium?.copyWith(color: muted)),
          const SizedBox(width: 16),
          Expanded(
            child: value == null
                ? const Align(
                    alignment: AlignmentDirectional.centerEnd,
                    child: SizedBox.square(dimension: 14, child: CircularProgressIndicator(strokeWidth: 2)),
                  )
                : Text(
                    value!,
                    key: valueKey,
                    textAlign: TextAlign.end,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w600),
                  ),
          ),
        ],
      ),
    );
  }
}
