import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../data/api/zhang_api_client.dart';
import '../../data/auth/browser_sign_in.dart';
import '../../data/profiles/profile_providers.dart';
import '../../data/profiles/profile_repository.dart';
import '../../l10n/l10n.dart';
import '../../router.dart';
import 'ready_step.dart';
import 'server_step.dart';
import 'setup_controller.dart';
import 'sign_in_step.dart';
import 'welcome_page.dart';

/// The server setup wizard (design-research S01): welcome (first launch
/// only) → 1 server address → 2 sign-in (skipped when the server needs none)
/// → 3 summary, name and colour. "Start" saves the profile, makes it active
/// and lands on Home.
///
/// Used by `/onboarding` (no profile yet, [showWelcome]) and by Settings →
/// "Add server" (`/settings/profiles/new`, no welcome page).
class ServerSetupScreen extends ConsumerStatefulWidget {
  const ServerSetupScreen({super.key, this.showWelcome = true});

  final bool showWelcome;

  @override
  ConsumerState<ServerSetupScreen> createState() => _ServerSetupScreenState();
}

class _ServerSetupScreenState extends ConsumerState<ServerSetupScreen> {
  late final ServerSetupController _controller = ServerSetupController(
    tester: ref.read(connectionTesterProvider),
    browser: ref.read(browserSignInProvider),
    showWelcome: widget.showWelcome,
  );
  bool _saving = false;

  static const _totalSteps = 3;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _start() async {
    final l10n = context.l10n;
    final messenger = ScaffoldMessenger.of(context);
    final router = GoRouter.of(context);
    final profile = _controller.buildProfile(ProfileRepository.newId());
    setState(() => _saving = true);
    try {
      await ref.read(profilesProvider.notifier).save(profile, activate: true);
      // Onboarding: the router leaves /onboarding by itself once a profile
      // is active. From Settings: show the new ledger.
      if (!widget.showWelcome) {
        messenger
          ..hideCurrentSnackBar()
          ..showSnackBar(SnackBar(content: Text(l10n.switchedTo(profile.name))));
        router.go(AppRoutes.home);
      }
    } catch (e) {
      messenger.showSnackBar(SnackBar(content: Text(l10n.errorUnknown('$e'))));
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  void _back() {
    if (!_controller.back()) Navigator.of(context).maybePop();
  }

  Widget _page(SetupStage stage) => switch (stage) {
    SetupStage.welcome => WelcomePage(controller: _controller),
    SetupStage.server => ServerStep(controller: _controller),
    SetupStage.signIn => SignInStep(controller: _controller),
    SetupStage.ready => ReadyStep(controller: _controller, saving: _saving, onStart: _start),
  };

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final theme = Theme.of(context);
    final reduceMotion = MediaQuery.disableAnimationsOf(context);
    return ListenableBuilder(
      listenable: _controller,
      builder: (context, _) {
        final c = _controller;
        final step = c.stepNumber;
        final welcome = c.stage == SetupStage.welcome;
        final canPopRoute = Navigator.of(context).canPop();
        return PopScope(
          canPop: !c.canGoBack,
          onPopInvokedWithResult: (didPop, _) {
            if (!didPop) c.back();
          },
          child: Scaffold(
            appBar: welcome
                ? null
                : AppBar(
                    automaticallyImplyLeading: false,
                    leading: c.canGoBack || canPopRoute
                        ? BackButton(key: const Key('setup.back'), onPressed: _back)
                        : null,
                    title: step == null
                        ? null
                        : Text(
                            l10n.setupStep(step, _totalSteps),
                            key: const Key('setup.stepLabel'),
                            style: theme.textTheme.titleSmall?.copyWith(color: theme.colorScheme.onSurfaceVariant),
                          ),
                    bottom: step == null ? null : _StepProgress(value: step / _totalSteps),
                  ),
            body: SafeArea(
              top: welcome,
              child: AnimatedSwitcher(
                duration: reduceMotion ? Duration.zero : const Duration(milliseconds: 280),
                switchInCurve: Curves.easeOutCubic,
                switchOutCurve: Curves.easeInCubic,
                transitionBuilder: (child, animation) {
                  // Shared-axis feel: the new page slides in from the side
                  // the user is heading to.
                  final incoming = child.key == ValueKey(c.stage);
                  final dx = 0.06 * c.direction * (incoming ? 1 : -1);
                  return FadeTransition(
                    opacity: animation,
                    child: SlideTransition(
                      position: Tween(begin: Offset(dx, 0), end: Offset.zero).animate(animation),
                      child: child,
                    ),
                  );
                },
                child: KeyedSubtree(key: ValueKey(c.stage), child: _page(c.stage)),
              ),
            ),
          ),
        );
      },
    );
  }
}

/// Thin rounded progress bar under the app bar ("Step n of 3").
class _StepProgress extends StatelessWidget implements PreferredSizeWidget {
  const _StepProgress({required this.value});

  final double value;

  @override
  Size get preferredSize => const Size.fromHeight(12);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 0, 24, 8),
      child: TweenAnimationBuilder<double>(
        tween: Tween(end: value),
        duration: MediaQuery.disableAnimationsOf(context) ? Duration.zero : const Duration(milliseconds: 350),
        curve: Curves.easeOutCubic,
        builder: (context, v, _) => LinearProgressIndicator(
          key: const Key('setup.progress'),
          value: v,
          minHeight: 4,
          borderRadius: BorderRadius.circular(2),
        ),
      ),
    );
  }
}
