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

/// Asks before credentials go over plain http (a profile saved before the
/// acknowledgement existed). `true` = go ahead.
Future<bool> confirmPlainHttp(BuildContext context) async {
  final l10n = context.l10n;
  final go = await showDialog<bool>(
    context: context,
    builder: (context) => AlertDialog(
      key: const Key('plainHttp.confirm'),
      icon: const Icon(Icons.no_encryption_outlined),
      title: Text(l10n.plainHttpTitle),
      content: Text(l10n.plainHttpBody),
      actions: [
        TextButton(onPressed: () => Navigator.of(context).pop(false), child: Text(l10n.cancel)),
        FilledButton(
          key: const Key('plainHttp.continue'),
          onPressed: () => Navigator.of(context).pop(true),
          child: Text(l10n.plainHttpContinue),
        ),
      ],
    ),
  );
  return go ?? false;
}

/// [profile] sends credentials over plain http without the acknowledgement
/// (saved before it existed): [signInAgain] asks first.
bool needsPlainHttpConfirmation(ServerProfile profile) =>
    profile.sendsCredentialsInClear && !profile.plainHttpAcknowledged;

/// Runs the browser sign-in for an existing [profile] ("Sign in again" on
/// Home / in Settings) and stores the new session. When
/// [needsPlainHttpConfirmation], asks first ([confirmPlainHttp]) unless the
/// caller already did ([plainHttpConfirmed]), and stores the
/// acknowledgement. Shows the outcome in a snackbar (nothing when the user
/// closed the browser). Returns the updated profile, or `null` when no
/// session was obtained.
Future<ServerProfile?> signInAgain(
  BuildContext context,
  WidgetRef ref,
  ServerProfile profile, {
  bool plainHttpConfirmed = false,
}) async {
  final messenger = ScaffoldMessenger.of(context);
  final l10n = context.l10n;
  final askHttp = needsPlainHttpConfirmation(profile);
  if (askHttp && !plainHttpConfirmed && !await confirmPlainHttp(context)) return null;
  try {
    final grant = await ref
        .read(browserSignInProvider)
        .signIn(profile.baseUrl, allowSelfSigned: profile.allowSelfSigned, headers: profile.customHeaders);
    // The profile may have been edited meanwhile; apply to the stored one.
    final current = ref.read(profilesProvider).byId(profile.id) ?? profile;
    var updated = grant.applyTo(current);
    if (askHttp) updated = updated.copyWith(plainHttpAcknowledged: true);
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
