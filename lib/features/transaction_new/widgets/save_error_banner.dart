import 'package:flutter/material.dart';

import '../../../core/utils/money.dart';
import '../../../core/widgets/error_view.dart';
import '../../../data/api/api_exception.dart';
import '../../../data/models/transaction_preview.dart';
import '../../../l10n/l10n.dart';

/// Save failure, blocking preview problems, or preview warnings with a
/// "Save anyway" action ([onSaveAnyway]).
class SaveErrorBanner extends StatelessWidget {
  const SaveErrorBanner({super.key, required this.error, required this.onClose, this.onSaveAnyway, this.editing = false});

  final Object error;
  final VoidCallback onClose;
  final VoidCallback? onSaveAnyway;

  /// Saving an edit: a 404 means the transaction's id is out of date.
  final bool editing;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final scheme = Theme.of(context).colorScheme;
    final warning = error is TransactionNeedsConfirmation;
    final background = warning ? scheme.tertiaryContainer : scheme.errorContainer;
    final foreground = warning ? scheme.onTertiaryContainer : scheme.onErrorContainer;
    return Container(
      key: Key(warning ? 'add.warning' : 'add.error'),
      width: double.infinity,
      color: background,
      padding: const EdgeInsets.fromLTRB(16, 8, 4, 8),
      child: Row(
        children: [
          Icon(
            switch (error) {
              TransactionNeedsConfirmation() => Icons.warning_amber,
              TransactionRejected() => Icons.rule,
              _ => iconForApiError(error),
            },
            color: foreground,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  switch (error) {
                    final TransactionRejected r =>
                      '${l10n.addPreviewRejected}\n${previewProblems(l10n, r.preview).join('\n')}',
                    final TransactionNeedsConfirmation c =>
                      '${l10n.addPreviewWarning}\n${[for (final e in c.preview.warnings) previewErrorText(l10n, e)].join('\n')}',
                    ApiNotFound(isMissingRoute: false) when editing => '${l10n.addSaveFailed}: ${l10n.editStale}',
                    _ => '${l10n.addSaveFailed}: ${describeApiError(l10n, error)}',
                  },
                  style: TextStyle(color: foreground),
                ),
                if (onSaveAnyway != null)
                  TextButton(
                    key: const Key('add.saveAnyway'),
                    onPressed: onSaveAnyway,
                    style: TextButton.styleFrom(foregroundColor: foreground, padding: EdgeInsets.zero),
                    child: Text(l10n.addSaveAnyway),
                  ),
              ],
            ),
          ),
          IconButton(
            tooltip: l10n.addClose,
            icon: Icon(Icons.close, color: foreground),
            onPressed: onClose,
          ),
        ],
      ),
    );
  }
}

/// One line per problem of a [TransactionPreview] (the server's message for
/// refused fields, localised text for the rest).
List<String> previewProblems(AppLocalizations l10n, TransactionPreview preview) => [
  for (final f in preview.fieldErrors) f.message.isEmpty ? '${f.field}: ${f.kind}' : f.message,
  if (preview.isUnbalanced)
    l10n.addPreviewUnbalanced(preview.unbalanced!.map((a) => formatMoney(a.number, a.commodity, signed: true)).join(', ')),
  for (final e in preview.errors)
    // The unbalanced amounts are already listed above.
    if (!(e.type == 'UnbalancedTransaction' && preview.isUnbalanced)) previewErrorText(l10n, e),
];

/// One ledger error of a preview (localised for the common kinds, else the
/// kind and its account).
String previewErrorText(AppLocalizations l10n, PreviewLedgerError e) => switch (e.type) {
  'AccountDoesNotExist' => l10n.addPreviewAccountMissing(e.account ?? ''),
  'AccountClosed' => l10n.addPreviewAccountClosed(e.account ?? ''),
  'CommodityDoesNotDefine' => l10n.addPreviewCommodityUndeclared(e.commodity ?? ''),
  'CommodityNotAllowed' => l10n.addPreviewCommodityNotAllowed(e.account ?? '', e.commodity ?? ''),
  _ => e.account == null ? e.type : '${e.type}: ${e.account}',
};
