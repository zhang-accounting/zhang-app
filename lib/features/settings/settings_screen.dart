import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:package_info_plus/package_info_plus.dart';

import '../../core/widgets/error_view.dart';
import '../../core/widgets/ledger_widgets.dart';
import '../../data/api/zhang_api_client.dart';
import '../../data/models/info.dart';
import '../../data/profiles/profile_providers.dart';
import '../../data/profiles/server_profile.dart';
import '../../data/repositories/ledger_data_providers.dart';
import '../../l10n/l10n.dart';
import '../../router.dart';

/// Installed app version (`1.0.0 (1)`).
final appVersionProvider = FutureProvider<String>((ref) async {
  final info = await PackageInfo.fromPlatform();
  return info.buildNumber.isEmpty ? info.version : '${info.version} (${info.buildNumber})';
});

/// `/settings`: server profiles (switch / add / edit / test / delete) and
/// about information. Feature agents: add entries for other pages
/// (budgets, commodities, errors…) as a new section above "About".
class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final state = ref.watch(profilesProvider);
    return Scaffold(
      appBar: AppBar(title: Text(l10n.settingsTitle)),
      body: ListView(
        children: [
          _SectionHeader(l10n.serversSection),
          for (final p in state.profiles)
            _ProfileTile(profile: p, active: p.id == state.activeId),
          ListTile(
            key: const Key('settings.addServer'),
            leading: const Icon(Icons.add),
            title: Text(l10n.addServer),
            onTap: () => context.push(AppRoutes.addProfile),
          ),
          const Divider(),
          _SectionHeader(l10n.aboutSection),
          const _AboutTiles(),
        ],
      ),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  const _SectionHeader(this.text);

  final String text;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.fromLTRB(16, 16, 16, 4),
    child: Text(
      text,
      style: Theme.of(context).textTheme.titleSmall?.copyWith(
        color: Theme.of(context).colorScheme.primary,
      ),
    ),
  );
}

enum _ProfileAction { edit, test, delete }

class _ProfileTile extends ConsumerWidget {
  const _ProfileTile({required this.profile, required this.active});

  final ServerProfile profile;
  final bool active;

  String _authLabel(AppLocalizations l10n) => switch (profile.authType) {
    AuthType.none => l10n.authNone,
    AuthType.basic => l10n.authBasic,
    AuthType.bearer => l10n.authBearer,
    AuthType.headers => l10n.authHeaders,
  };

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final scheme = Theme.of(context).colorScheme;
    return ListTile(
      key: Key('settings.profile.${profile.id}'),
      leading: Stack(
        alignment: Alignment.center,
        children: [
          LedgerDot(color: profileColor(context, profile), size: 28),
          if (active) Icon(Icons.check, size: 18, color: scheme.surface),
        ],
      ),
      title: Row(
        children: [
          Flexible(child: Text(profile.name, overflow: TextOverflow.ellipsis)),
          if (active) ...[
            const SizedBox(width: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
              decoration: BoxDecoration(
                color: scheme.primaryContainer,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                l10n.activeBadge,
                style: Theme.of(context).textTheme.labelSmall?.copyWith(
                  color: scheme.onPrimaryContainer,
                ),
              ),
            ),
          ],
        ],
      ),
      subtitle: Text('${profile.baseUrl} · ${_authLabel(l10n)}', overflow: TextOverflow.ellipsis),
      selected: active,
      onTap: active
          ? null
          : () async {
              await ref.read(profilesProvider.notifier).activate(profile.id);
              if (context.mounted) {
                ScaffoldMessenger.of(context)
                  ..hideCurrentSnackBar()
                  ..showSnackBar(SnackBar(content: Text(l10n.switchedTo(profile.name))));
              }
            },
      trailing: PopupMenuButton<_ProfileAction>(
        key: Key('settings.profileMenu.${profile.id}'),
        onSelected: (action) => _onAction(context, ref, action),
        itemBuilder: (context) => [
          PopupMenuItem(value: _ProfileAction.edit, child: Text(l10n.edit)),
          PopupMenuItem(value: _ProfileAction.test, child: Text(l10n.testConnection)),
          PopupMenuItem(value: _ProfileAction.delete, child: Text(l10n.delete)),
        ],
      ),
    );
  }

  Future<void> _onAction(BuildContext context, WidgetRef ref, _ProfileAction action) async {
    final l10n = context.l10n;
    switch (action) {
      case _ProfileAction.edit:
        context.push(AppRoutes.editProfile(profile.id));
      case _ProfileAction.test:
        final future = ref.read(connectionTesterProvider).test(profile);
        await showDialog<void>(
          context: context,
          builder: (context) => _TestDialog(future: future, title: profile.name),
        );
      case _ProfileAction.delete:
        final confirmed = await showDialog<bool>(
          context: context,
          builder: (context) => AlertDialog(
            title: Text(l10n.deleteServerTitle),
            content: Text(l10n.deleteServerMessage(profile.name)),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(context).pop(false),
                child: Text(l10n.cancel),
              ),
              FilledButton(
                onPressed: () => Navigator.of(context).pop(true),
                child: Text(l10n.delete),
              ),
            ],
          ),
        );
        if (confirmed == true) {
          await ref.read(profilesProvider.notifier).delete(profile.id);
        }
    }
  }
}

class _TestDialog extends StatelessWidget {
  const _TestDialog({required this.future, required this.title});

  final Future<ServerInfo> future;
  final String title;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return AlertDialog(
      title: Text(title),
      content: FutureBuilder<ServerInfo>(
        future: future,
        builder: (context, snapshot) {
          if (snapshot.connectionState != ConnectionState.done) {
            return Row(
              children: [
                const SizedBox.square(dimension: 20, child: CircularProgressIndicator(strokeWidth: 2)),
                const SizedBox(width: 16),
                Text(l10n.testingConnection),
              ],
            );
          }
          if (snapshot.hasError) return Text(describeApiError(l10n, snapshot.error!));
          final info = snapshot.data!;
          final ledger = (info.title == null || info.title!.isEmpty) ? l10n.untitledLedger : info.title!;
          return Text('${l10n.connectionOk(ledger)}\n${l10n.connectionOkDetail(info.version, info.buildDate)}');
        },
      ),
      actions: [
        TextButton(onPressed: () => Navigator.of(context).pop(), child: Text(MaterialLocalizations.of(context).okButtonLabel)),
      ],
    );
  }
}

class _AboutTiles extends ConsumerWidget {
  const _AboutTiles();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final appVersion = ref.watch(appVersionProvider);
    final hasProfile = ref.watch(activeProfileProvider) != null;
    final info = hasProfile ? ref.watch(serverInfoProvider) : null;
    String serverText(ServerInfo i) => '${i.version} · ${i.buildDate}';
    return Column(
      children: [
        ListTile(
          leading: const Icon(Icons.info_outline),
          title: Text(l10n.appVersion),
          subtitle: Text(appVersion.value ?? '…'),
        ),
        if (info != null) ...[
          ListTile(
            leading: const Icon(Icons.book_outlined),
            title: Text(l10n.ledgerTitle),
            subtitle: Text(
              info.when(
                data: (i) => (i.title == null || i.title!.isEmpty) ? l10n.untitledLedger : i.title!,
                loading: () => '…',
                error: (e, _) => describeApiError(l10n, e),
              ),
            ),
          ),
          ListTile(
            leading: const Icon(Icons.dns_outlined),
            title: Text(l10n.serverVersion),
            subtitle: Text(
              info.when(
                data: serverText,
                loading: () => '…',
                error: (e, _) => describeApiError(l10n, e),
              ),
            ),
            onTap: () => ref.invalidate(serverInfoProvider),
          ),
        ],
      ],
    );
  }
}
