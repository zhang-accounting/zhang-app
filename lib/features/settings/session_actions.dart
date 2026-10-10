import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/utils/dates.dart';
import '../../core/widgets/error_view.dart';
import '../../data/auth/browser_sign_in.dart';
import '../../data/profiles/profile_providers.dart';
import '../../data/profiles/server_profile.dart';
import '../../l10n/l10n.dart';

/// Warn on Home when the session of the active profile ends this soon.
const sessionExpiryWarning = Duration(days: 3);

/// Expiry of a browser sign-in session as a local date (`Nov 9, 2026`).
String formatSessionExpiry(DateTime expiresAt) => ZhangDates.formatDate(expiresAt.toLocal());

/// Runs the browser sign-in for an existing [profile] ("Sign in again" on
/// Home / in Settings) and stores the new session. Shows the outcome in a
/// snackbar (nothing when the user closed the browser). Returns the updated
/// profile, or `null` when no session was obtained.
Future<ServerProfile?> signInAgain(BuildContext context, WidgetRef ref, ServerProfile profile) async {
  final messenger = ScaffoldMessenger.of(context);
  final l10n = context.l10n;
  try {
    final grant = await ref
        .read(browserSignInProvider)
        .signIn(profile.baseUrl, allowSelfSigned: profile.allowSelfSigned);
    // The profile may have been edited meanwhile; apply to the stored one.
    final current = ref.read(profilesProvider).byId(profile.id) ?? profile;
    final updated = grant.applyTo(current);
    await ref.read(profilesProvider.notifier).save(updated);
    messenger
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(l10n.signedInSnack(grant.user))));
    return updated;
  } on BrowserSignInException catch (e) {
    if (e.kind != BrowserSignInFailure.cancelled) {
      messenger
        ..hideCurrentSnackBar()
        ..showSnackBar(SnackBar(content: Text(describeSignInFailure(l10n, e))));
    }
  } catch (e) {
    messenger
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(describeApiError(l10n, e))));
  }
  return null;
}

/// Forgets [profile]'s session locally, then tells the server (best effort:
/// zhang's tokens are stateless, `POST /api/auth/logout` does not revoke
/// them).
Future<void> signOut(BuildContext context, WidgetRef ref, ServerProfile profile) async {
  final messenger = ScaffoldMessenger.of(context);
  final l10n = context.l10n;
  final signIn = ref.read(browserSignInProvider);
  await ref.read(profilesProvider.notifier).save(profile.withoutSession());
  messenger
    ..hideCurrentSnackBar()
    ..showSnackBar(SnackBar(content: Text(l10n.signedOut(profile.name))));
  await signIn.logout(profile);
}
