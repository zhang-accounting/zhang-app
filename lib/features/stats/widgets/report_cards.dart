import 'package:flutter/material.dart';

import '../../../core/widgets/error_view.dart';
import '../../../l10n/l10n.dart';

/// Loading state of one report card (each card loads on its own).
class ReportCardPlaceholder extends StatelessWidget {
  const ReportCardPlaceholder({super.key, required this.height});

  final double height;

  @override
  Widget build(BuildContext context) => Card.outlined(
    margin: const EdgeInsets.fromLTRB(16, 8, 16, 8),
    child: SizedBox(
      height: height,
      child: const Center(child: SizedBox(width: 24, height: 24, child: CircularProgressIndicator(strokeWidth: 2))),
    ),
  );
}

/// Card-level error: message + retry, without taking over the screen.
class ReportCardError extends StatelessWidget {
  const ReportCardError({super.key, required this.error, required this.onRetry});

  final Object error;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Card.outlined(
      margin: const EdgeInsets.fromLTRB(16, 8, 16, 8),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 8, 8, 8),
        child: Row(
          children: [
            Icon(iconForApiError(error), color: theme.colorScheme.error),
            const SizedBox(width: 12),
            Expanded(child: Text(describeApiError(context.l10n, error), style: theme.textTheme.bodyMedium)),
            TextButton(onPressed: onRetry, child: Text(context.l10n.retry)),
          ],
        ),
      ),
    );
  }
}
