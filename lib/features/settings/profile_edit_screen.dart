import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../data/profiles/profile_providers.dart';
import '../../l10n/l10n.dart';
import 'profile_form.dart';

/// `/settings/profiles/:id/edit` (new servers: the setup wizard,
/// `ServerSetupScreen`).
class ProfileEditScreen extends ConsumerWidget {
  const ProfileEditScreen({super.key, required this.profileId});

  final String profileId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final profile = ref.watch(profilesProvider.select((s) => s.byId(profileId)));
    return Scaffold(
      appBar: AppBar(title: Text(l10n.editServer)),
      body: profile == null
          ? Center(child: Text(l10n.errorNotFound))
          : SafeArea(
              child: ListView(
                padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
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
