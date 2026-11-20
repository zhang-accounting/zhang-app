import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:go_router/go_router.dart';

import 'data/profiles/profile_providers.dart';
import 'data/profiles/profile_repository.dart';
import 'data/profiles/server_profile.dart';
import 'router.dart';

/// Runs the app in **ledger sessions**: one [ProviderContainer] per active
/// server profile.
///
/// All provider state lives in the session of the active profile. When the
/// active profile changes (switched, edited, deleted, or the first one added)
/// the host opens a new, empty session and disposes the old one: every
/// provider – those of today and any added later, cached or not – starts
/// from scratch for the new profile, so no screen can show or save the
/// previous ledger's accounts, payees or figures while it loads. Disposing
/// the old session closes its API client (cancelling its requests) and its
/// event stream; nothing is ever sent to the previous server again.
///
/// Inside a session the active profile is fixed ([activeProfileProvider] is
/// overridden), so a switch never makes the old session's providers refetch
/// from the new server either. The new session's client only sends the
/// version probes until `/api/info` has shown a zhang ≥ 0.2 server
/// (`serverGateProvider`, `gatedClient`).
///
/// What outlives a session: the widget tree (the [child] is moved into the
/// new session's scope, so routes, scroll positions and snackbars stay), the
/// [GoRouter] (navigation stack), the profile list (the new session is
/// seeded with the latest [ProfilesState]) and everything the [overrides]
/// provide (shared preferences, secret store…). Other app-wide state that
/// must survive a switch belongs in shared preferences, not in a provider.
class LedgerSessionHost extends StatefulWidget {
  const LedgerSessionHost({
    super.key,
    required this.initialProfiles,
    this.overrides = const [],
    this.retry,
    required this.child,
  });

  /// Profiles loaded before the first frame ([ProfileRepository.load]).
  final ProfilesState initialProfiles;

  /// Applied to every session. Must not override
  /// [initialProfilesStateProvider], [activeProfileProvider] or
  /// [routerProvider] (the host does).
  final List<Override> overrides;

  /// Retry policy of every session's container.
  final Duration? Function(int retryCount, Object error)? retry;

  /// The app (`ZhangApp`).
  final Widget child;

  @override
  State<LedgerSessionHost> createState() => _LedgerSessionHostState();
}

class _LedgerSessionHostState extends State<LedgerSessionHost> {
  late final _hasProfile = ValueNotifier<bool>(widget.initialProfiles.active != null);
  late final GoRouter _router = createAppRouter(_hasProfile);

  /// Moves the app's element tree from one session's scope to the next
  /// instead of rebuilding it.
  final _appKey = GlobalKey(debugLabel: 'ledgerSession.app');

  late _Session _session = _open(widget.initialProfiles);

  _Session _open(ProfilesState profiles) {
    final profile = profiles.active;
    final container = ProviderContainer(
      overrides: [
        ...widget.overrides,
        initialProfilesStateProvider.overrideWithValue(profiles),
        activeProfileProvider.overrideWithValue(profile),
        routerProvider.overrideWithValue(_router),
      ],
      retry: widget.retry,
    );
    final session = _Session(container, profile);
    session.subscription = container.listen<ProfilesState>(profilesProvider, (_, next) {
      if (identical(_session, session) && next.active != session.profile) _switchTo(next);
    });
    return session;
  }

  void _switchTo(ProfilesState profiles) {
    final old = _session;
    old.subscription?.close();
    setState(() => _session = _open(profiles));
    _hasProfile.value = profiles.active != null;
    // The widgets move to the new session while this frame builds; the old
    // one goes once nothing listens to it any more.
    WidgetsBinding.instance.addPostFrameCallback((_) => old.container.dispose());
  }

  @override
  void dispose() {
    _session.subscription?.close();
    _session.container.dispose();
    _router.dispose();
    _hasProfile.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => UncontrolledProviderScope(
    // A new scope per session (it registers with its container); the
    // GlobalKey below re-parents the app into it with its state.
    key: ObjectKey(_session.container),
    container: _session.container,
    child: KeyedSubtree(key: _appKey, child: widget.child),
  );
}

class _Session {
  _Session(this.container, this.profile);

  final ProviderContainer container;

  /// The active profile of this session (`null`: onboarding).
  final ServerProfile? profile;

  ProviderSubscription<ProfilesState>? subscription;
}
