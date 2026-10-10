import 'package:flutter/material.dart';

import '../../data/api/api_exception.dart';
import '../../l10n/l10n.dart';

/// Localised, user-facing description of any error thrown by the data layer.
String describeApiError(AppLocalizations l10n, Object error) {
  return switch (error) {
    ApiServerTooOld() => l10n.errorServerTooOld,
    ApiPasskeyOnly() => l10n.errorPasskeyOnly,
    ZhangApiException(isMissingRoute: true, :final message) => l10n.errorApiMismatch(message),
    ApiUnauthorized() => l10n.errorUnauthorized,
    ApiNotFound() => l10n.errorNotFound,
    ApiServerError(:final status, :final message) => l10n.errorServer(status, message),
    ApiNetworkError(kind: NetworkErrorKind.timeout) => l10n.errorTimeout,
    ApiNetworkError(kind: NetworkErrorKind.certificate) => l10n.errorCertificate,
    ApiNetworkError() => l10n.errorNetwork,
    ApiParseError() => l10n.errorParse,
    _ => l10n.errorUnknown('$error'),
  };
}

/// Icon matching an error (lock for 401, cloud-off for network, …).
IconData iconForApiError(Object error) => switch (error) {
  ApiServerTooOld() => Icons.update,
  ZhangApiException(isMissingRoute: true) => Icons.update,
  ApiUnauthorized() || ApiPasskeyOnly() => Icons.lock_outline,
  ApiNetworkError(kind: NetworkErrorKind.certificate) => Icons.gpp_maybe_outlined,
  ApiNetworkError() => Icons.cloud_off_outlined,
  ApiParseError() => Icons.help_outline,
  _ => Icons.error_outline,
};

/// Centered error message with an optional retry button. Use it in the
/// `error:` branch of `AsyncValue.when`.
class ErrorView extends StatelessWidget {
  const ErrorView({super.key, required this.error, this.onRetry});

  final Object error;
  final VoidCallback? onRetry;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final theme = Theme.of(context);
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(iconForApiError(error), size: 48, color: theme.colorScheme.error),
            const SizedBox(height: 12),
            Text(
              describeApiError(l10n, error),
              textAlign: TextAlign.center,
              style: theme.textTheme.bodyLarge,
            ),
            if (onRetry != null) ...[
              const SizedBox(height: 16),
              FilledButton.tonalIcon(
                onPressed: onRetry,
                icon: const Icon(Icons.refresh),
                label: Text(l10n.retry),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
