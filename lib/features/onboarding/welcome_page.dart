import 'package:flutter/material.dart';

import '../../core/widgets/error_view.dart';
import '../../core/widgets/notice_card.dart';
import '../../l10n/l10n.dart';
import 'setup_controller.dart';
import 'setup_layout.dart';
import 'setup_links.dart';

/// First launch: the otter, what the app does, "Connect to your server" and
/// "Try the demo".
class WelcomePage extends StatelessWidget {
  const WelcomePage({super.key, required this.controller});

  final ServerSetupController controller;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final theme = Theme.of(context);
    final c = controller;
    return SetupLayout(
      top: 64,
      content: [
        Center(
          child: DecoratedBox(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(32),
              boxShadow: [
                BoxShadow(
                  color: theme.colorScheme.primary.withValues(alpha: 0.18),
                  blurRadius: 24,
                  offset: const Offset(0, 10),
                ),
              ],
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(32),
              child: Image.asset('assets/images/otter.png', width: 120, height: 120, excludeFromSemantics: true),
            ),
          ),
        ),
        const SizedBox(height: 40),
        Text(
          l10n.appTitle,
          textAlign: TextAlign.center,
          style: theme.textTheme.displaySmall?.copyWith(fontWeight: FontWeight.w700, letterSpacing: -0.8),
        ),
        const SizedBox(height: 8),
        Text(
          l10n.welcomeTagline,
          textAlign: TextAlign.center,
          style: theme.textTheme.headlineSmall?.copyWith(color: theme.colorScheme.primary, height: 1.3),
        ),
        const SizedBox(height: 16),
        Text(
          l10n.welcomeBody,
          textAlign: TextAlign.center,
          style: theme.textTheme.bodyLarge?.copyWith(color: theme.colorScheme.onSurfaceVariant, height: 1.45),
        ),
        const SizedBox(height: 12),
        Center(
          child: TextButton.icon(
            key: const Key('welcome.about'),
            style: TextButton.styleFrom(padding: const EdgeInsets.symmetric(horizontal: 12)),
            onPressed: () => _showAbout(context),
            icon: const Icon(Icons.help_outline, size: 20),
            label: Text(l10n.welcomeWhatIsZhang),
          ),
        ),
        if (c.demoError != null) ...[
          const SizedBox(height: 16),
          NoticeCard(
            key: const Key('welcome.demoError'),
            tone: NoticeTone.error,
            icon: iconForApiError(c.demoError!),
            title: describeApiError(l10n, c.demoError!),
          ),
        ],
      ],
      actions: [
        FilledButton(
          key: const Key('welcome.connect'),
          style: setupButtonStyle,
          onPressed: c.demoLoading ? null : c.startServerStep,
          child: Text(l10n.welcomeConnect),
        ),
        const SizedBox(height: 10),
        OutlinedButton(
          key: const Key('welcome.demo'),
          style: setupButtonStyle,
          onPressed: c.demoLoading ? null : c.startDemo,
          child: BusyLabel(busy: c.demoLoading, label: l10n.welcomeTryDemo),
        ),
        const SizedBox(height: 10),
        Text(
          c.demoLoading ? l10n.welcomeDemoWaking : l10n.welcomeDemoCaption,
          key: const Key('welcome.demoCaption'),
          textAlign: TextAlign.center,
          style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.onSurfaceVariant),
        ),
      ],
    );
  }

  Future<void> _showAbout(BuildContext context) => showModalBottomSheet<void>(
    context: context,
    showDragHandle: true,
    isScrollControlled: true,
    builder: (context) {
      final l10n = context.l10n;
      final theme = Theme.of(context);
      return SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(24, 0, 24, 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(l10n.welcomeWhatIsZhang, style: theme.textTheme.titleLarge),
              const SizedBox(height: 12),
              Text(
                l10n.welcomeAboutBody,
                style: theme.textTheme.bodyLarge?.copyWith(color: theme.colorScheme.onSurfaceVariant, height: 1.45),
              ),
              const SizedBox(height: 24),
              FilledButton.tonalIcon(
                style: setupButtonStyle,
                onPressed: () => openExternalUrl(ZhangDocs.introduction(context)),
                icon: const Icon(Icons.open_in_new, size: 18),
                label: Text(l10n.welcomeReadDocs),
              ),
              const SizedBox(height: 8),
              TextButton(
                style: setupButtonStyle,
                onPressed: () => Navigator.of(context).pop(),
                child: Text(l10n.close),
              ),
            ],
          ),
        ),
      );
    },
  );
}
