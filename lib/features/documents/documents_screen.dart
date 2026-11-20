import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../core/widgets/error_view.dart';
import '../../data/models/document.dart';
import '../../l10n/l10n.dart';
import 'document_providers.dart';
import 'widgets/document_tile.dart';

/// Every document of the ledger (S15, read-only), newest first and grouped
/// by month; opened from the Accounts tab menu. A tap opens the document.
class DocumentsScreen extends ConsumerWidget {
  const DocumentsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final documents = ref.watch(ledgerDocumentsProvider);
    return Scaffold(
      appBar: AppBar(title: Text(l10n.documentsTitle)),
      body: documents.when(
        data: (list) => RefreshIndicator(
          onRefresh: () => ref.refresh(ledgerDocumentsProvider.future),
          child: list.isEmpty ? const _DocumentsEmpty() : _DocumentList(documents: list),
        ),
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => ErrorView(error: e, onRetry: () => ref.invalidate(ledgerDocumentsProvider)),
      ),
    );
  }
}

class _DocumentList extends StatelessWidget {
  const _DocumentList({required this.documents});

  final List<DocumentEntity> documents;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final locale = Localizations.localeOf(context).toLanguageTag();
    // Month headers between the rows (the list is newest first).
    final rows = <Widget>[];
    DateTime? month;
    for (final d in documents) {
      final m = DateTime(d.datetime.year, d.datetime.month);
      if (m != month) {
        month = m;
        rows.add(
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 4),
            child: Text(
              DateFormat.yMMMM(locale).format(m),
              style: theme.textTheme.titleSmall?.copyWith(color: theme.colorScheme.primary),
            ),
          ),
        );
      }
      rows.add(DocumentTile(document: d));
    }
    return ListView(
      key: const Key('documents.list'),
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.only(bottom: 96),
      children: rows,
    );
  }
}

class _DocumentsEmpty extends StatelessWidget {
  const _DocumentsEmpty();

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final theme = Theme.of(context);
    return ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(32, 64, 32, 32),
      children: [
        Icon(Icons.folder_open_outlined, size: 48, color: theme.colorScheme.primary),
        const SizedBox(height: 12),
        Text(
          l10n.documentsEmpty,
          key: const Key('documents.empty'),
          textAlign: TextAlign.center,
          style: theme.textTheme.bodyLarge?.copyWith(color: theme.colorScheme.onSurfaceVariant),
        ),
      ],
    );
  }
}
