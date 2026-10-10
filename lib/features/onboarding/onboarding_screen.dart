import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/profiles/profile_providers.dart';
import '../../l10n/l10n.dart';
import '../settings/profile_form.dart';

/// First-run screen (shown by the router whenever no profile is active).
/// Saving makes the profile active; the router then switches to `/home`.
class OnboardingScreen extends ConsumerWidget {
  const OnboardingScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final theme = Theme.of(context);
    return Scaffold(
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 32, 20, 24),
          children: [
            Icon(Icons.account_balance_outlined, size: 48, color: theme.colorScheme.primary),
            const SizedBox(height: 16),
            Text(l10n.onboardingTitle, style: theme.textTheme.headlineSmall),
            const SizedBox(height: 8),
            Text(
              l10n.onboardingSubtitle,
              style: theme.textTheme.bodyMedium?.copyWith(color: theme.colorScheme.onSurfaceVariant),
            ),
            const SizedBox(height: 24),
            ProfileForm(
              submitLabel: l10n.saveAndContinue,
              onSubmit: (profile) =>
                  ref.read(profilesProvider.notifier).save(profile, activate: true),
            ),
          ],
        ),
      ),
    );
  }
}
