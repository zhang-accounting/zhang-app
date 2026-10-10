import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../data/profiles/profile_providers.dart';
import '../../l10n/l10n.dart';
import 'profile_form.dart';

/// `/settings/profiles/new` and `/settings/profiles/:id/edit`.
class ProfileEditScreen extends ConsumerWidget {
  const ProfileEditScreen({super.key, this.profileId});

  /// `null` → add a new profile.
  final String? profileId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final profile = profileId == null
        ? null
        : ref.watch(profilesProvider.select((s) => s.byId(profileId!)));
    final isEdit = profileId != null;
    return Scaffold(
      appBar: AppBar(title: Text(isEdit ? l10n.editServer : l10n.addServer)),
      body: (isEdit && profile == null)
          ? Center(child: Text(l10n.errorNotFound))
          : SafeArea(
              child: ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  ProfileForm(
                    initial: profile,
                    submitLabel: l10n.save,
                    onSubmit: (p) async {
                      await ref.read(profilesProvider.notifier).save(p);
                      if (context.mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(content: Text(l10n.saved)),
                        );
                        context.pop();
                      }
                    },
                  ),
                ],
              ),
            ),
    );
  }
}
