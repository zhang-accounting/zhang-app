import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/widgets/error_view.dart';
import '../../../data/models/journal.dart';
import '../../../l10n/l10n.dart';
import '../document_providers.dart';
import 'document_tile.dart';

/// Section heading in the style of the detail screens.
class _SectionTitle extends StatelessWidget {
  const _SectionTitle(this.text);

  final String text;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.fromLTRB(16, 20, 16, 6),
    child: Text(
      text,
      style: Theme.of(context).textTheme.titleSmall?.copyWith(color: Theme.of(context).colorScheme.primary),
    ),
  );
}

/// One-line error with retry inside a section.
class _InlineError extends StatelessWidget {
  const _InlineError({required this.error, required this.onRetry});

  final Object error;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 8, 0),
      child: Row(
        children: [
          Icon(iconForApiError(error), size: 20, color: theme.colorScheme.error),
          const SizedBox(width: 12),
          Expanded(child: Text(describeApiError(context.l10n, error), style: theme.textTheme.bodySmall)),
          TextButton(onPressed: onRetry, child: Text(context.l10n.retry)),
        ],
      ),
    );
  }
}

/// Documents of an account and its sub-accounts on the account detail page
/// (`accounts.documents`). Nothing is shown while loading or when there is
/// none; the first [collapsedCount] are listed, the rest behind "Show all".
class AccountDocumentsSection extends ConsumerStatefulWidget {
  const AccountDocumentsSection({super.key, required this.account});

  final String account;

  static const collapsedCount = 3;

  @override
  ConsumerState<AccountDocumentsSection> createState() => _AccountDocumentsSectionState();
}

class _AccountDocumentsSectionState extends ConsumerState<AccountDocumentsSection> {
  bool _expanded = false;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final documents = ref.watch(accountDocumentsProvider(widget.account));
    return documents.when(
      data: (list) {
        if (list.isEmpty) return const SizedBox.shrink();
        final shown = _expanded ? list : list.take(AccountDocumentsSection.collapsedCount).toList();
        return Column(
          key: const Key('accountDetail.documents'),
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _SectionTitle(l10n.documentsCount(list.length)),
            for (final d in shown) DocumentTile(document: d, showOwner: d.account != widget.account),
            if (shown.length < list.length)
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 8),
                child: TextButton(
                  key: const Key('accountDetail.documents.showAll'),
                  onPressed: () => setState(() => _expanded = true),
                  child: Text(l10n.documentsShowAll(list.length)),
                ),
              ),
          ],
        );
      },
      loading: () => const SizedBox.shrink(),
      error: (e, _) => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _SectionTitle(l10n.documentsTitle),
          _InlineError(error: e, onRetry: () => ref.invalidate(accountDocumentsProvider(widget.account))),
        ],
      ),
    );
  }
}

/// Documents attached to a transaction (its own or its postings' `document`
/// metadata, read from `journals.documents` by transaction id) on the
/// transaction detail page. A transaction without a `document` meta shows
/// nothing and requests nothing.
class TransactionDocumentsSection extends ConsumerWidget {
  const TransactionDocumentsSection({super.key, required this.transaction});

  final JournalTransaction transaction;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (!transaction.hasDocuments) return const SizedBox.shrink();
    final l10n = context.l10n;
    final documents = ref.watch(transactionDocumentsProvider(transaction.id));
    return documents.when(
      data: (list) => list.isEmpty
          ? const SizedBox.shrink()
          : Column(
              key: const Key('trx.documents'),
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _SectionTitle(l10n.documentsTitle),
                for (final d in list) DocumentTile(document: d, showOwner: false),
              ],
            ),
      loading: () => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _SectionTitle(l10n.documentsTitle),
          const Padding(
            padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: LinearProgressIndicator(minHeight: 2),
          ),
        ],
      ),
      error: (e, _) => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _SectionTitle(l10n.documentsTitle),
          _InlineError(error: e, onRetry: () => ref.invalidate(ledgerDocumentsProvider)),
        ],
      ),
    );
  }
}
