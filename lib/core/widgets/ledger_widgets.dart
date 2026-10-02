import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../data/profiles/profile_providers.dart';
import '../../data/profiles/server_profile.dart';
import '../../l10n/l10n.dart';
import '../../router.dart';

/// Colour of a profile's ledger dot (its own colour or the theme primary).
Color profileColor(BuildContext context, ServerProfile? profile) {
  final c = profile?.color;
  return c == null ? Theme.of(context).colorScheme.primary : Color(c);
}

/// Small filled circle in the profile's colour.
class LedgerDot extends StatelessWidget {
  const LedgerDot({super.key, required this.color, this.size = 10});

  final Color color;
  final double size;

  @override
  Widget build(BuildContext context) => Container(
    width: size,
    height: size,
    decoration: BoxDecoration(color: color, shape: BoxShape.circle),
  );
}

/// App-bar title showing the active ledger: coloured dot + profile name.
/// Use as `AppBar(title: const ActiveLedgerTitle())`.
class ActiveLedgerTitle extends ConsumerWidget {
  const ActiveLedgerTitle({super.key, this.subtitle});

  /// Optional smaller line under the name (e.g. the screen name).
  final String? subtitle;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final profile = ref.watch(activeProfileProvider);
    final theme = Theme.of(context);
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        LedgerDot(color: profileColor(context, profile)),
        const SizedBox(width: 8),
        Flexible(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(profile?.name ?? '', overflow: TextOverflow.ellipsis),
              if (subtitle != null)
                Text(
                  subtitle!,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
            ],
          ),
        ),
      ],
    );
  }
}

/// Gear button that opens `/settings` (put it in the Home app bar actions).
class SettingsButton extends StatelessWidget {
  const SettingsButton({super.key});

  @override
  Widget build(BuildContext context) => IconButton(
    tooltip: context.l10n.settingsTitle,
    icon: const Icon(Icons.settings_outlined),
    onPressed: () => context.push(AppRoutes.settings),
  );
}

/// Placeholder scaffold used by the feature screens that are not built yet.
class PlaceholderScreen extends StatelessWidget {
  const PlaceholderScreen({super.key, required this.title, required this.icon, this.actions});

  final String title;
  final IconData icon;
  final List<Widget>? actions;

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: Text(title), actions: actions),
    body: PlaceholderBody(title: title, icon: icon),
  );
}

/// Placeholder content: icon, title, active ledger name, "coming soon".
class PlaceholderBody extends ConsumerWidget {
  const PlaceholderBody({super.key, required this.title, required this.icon});

  final String title;
  final IconData icon;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final profile = ref.watch(activeProfileProvider);
    final theme = Theme.of(context);
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 56, color: theme.colorScheme.primary),
          const SizedBox(height: 12),
          Text(title, style: theme.textTheme.headlineSmall),
          const SizedBox(height: 8),
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              LedgerDot(color: profileColor(context, profile)),
              const SizedBox(width: 6),
              Text(context.l10n.activeLedger(profile?.name ?? '-')),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            context.l10n.comingSoon,
            style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.onSurfaceVariant),
          ),
        ],
      ),
    );
  }
}
