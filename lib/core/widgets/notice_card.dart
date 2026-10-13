import 'package:flutter/material.dart';

import '../theme/app_colors.dart';

/// Meaning of a [NoticeCard]; picks its colours.
enum NoticeTone {
  /// Neutral explanation (surface container, primary icon).
  info,

  /// Something worked (primary container).
  success,

  /// Needs the user's attention but is not a failure (warning icon).
  warning,

  /// Something failed (error container).
  error,
}

/// Inline status block: icon, title, optional body and text-button actions.
/// Used for connection results and hints in the server setup and the
/// server form. Errors and success use M3 roles (not the income / expense
/// colours, which follow the money colour convention).
class NoticeCard extends StatelessWidget {
  const NoticeCard({
    super.key,
    required this.tone,
    required this.icon,
    required this.title,
    this.body,
    this.actions = const [],
  });

  final NoticeTone tone;
  final IconData icon;
  final String title;
  final String? body;

  /// Usually [TextButton]s; they take the card's foreground colour.
  final List<Widget> actions;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final (background, foreground, iconColor) = switch (tone) {
      NoticeTone.info => (scheme.surfaceContainerHigh, scheme.onSurface, scheme.primary),
      NoticeTone.success => (scheme.primaryContainer, scheme.onPrimaryContainer, scheme.onPrimaryContainer),
      NoticeTone.warning => (scheme.surfaceContainerHigh, scheme.onSurface, context.zhangColors.warning),
      NoticeTone.error => (scheme.errorContainer, scheme.onErrorContainer, scheme.onErrorContainer),
    };
    return Material(
      color: background,
      borderRadius: BorderRadius.circular(16),
      child: Padding(
        padding: EdgeInsets.fromLTRB(16, 14, 16, actions.isEmpty ? 14 : 6),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.only(top: 1),
              child: Icon(icon, color: iconColor, size: 22),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: theme.textTheme.titleSmall?.copyWith(color: foreground, height: 1.35),
                  ),
                  if (body != null) ...[
                    const SizedBox(height: 4),
                    Text(
                      body!,
                      style: theme.textTheme.bodyMedium?.copyWith(color: foreground, height: 1.4),
                    ),
                  ],
                  if (actions.isNotEmpty)
                    TextButtonTheme(
                      data: TextButtonThemeData(
                        style: TextButton.styleFrom(
                          foregroundColor: tone == NoticeTone.info ? scheme.primary : foreground,
                          padding: const EdgeInsets.symmetric(horizontal: 8),
                          textStyle: theme.textTheme.labelLarge?.copyWith(fontWeight: FontWeight.w600),
                        ),
                      ),
                      child: Transform.translate(
                        // Align the button text (not its ink) with the body.
                        offset: const Offset(-8, 0),
                        child: Wrap(spacing: 4, children: actions),
                      ),
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
