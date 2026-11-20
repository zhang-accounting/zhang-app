import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../../data/models/document.dart';
import '../../../l10n/l10n.dart';
import '../../journals/widgets/amount_format.dart' show accountLabel;
import '../document_viewer_screen.dart';

/// Icon of a document by type: image, PDF, text or any other file.
IconData documentIcon(DocumentEntity d) {
  final mime = d.mimeType;
  if (d.isImage) return Icons.image_outlined;
  if (mime == 'application/pdf') return Icons.picture_as_pdf_outlined;
  if (mime != null && mime.startsWith('text/')) return Icons.description_outlined;
  return Icons.insert_drive_file_outlined;
}

/// Ledger date of a document: `2026-10-02`, with the time when it has one.
String documentDate(DocumentEntity d) {
  final t = d.datetime;
  final hasTime = t.hour != 0 || t.minute != 0 || t.second != 0;
  return DateFormat(hasTime ? 'yyyy-MM-dd HH:mm' : 'yyyy-MM-dd').format(t);
}

/// Opens [document] full screen (above the bottom bar): images are shown,
/// other files offer "open or share".
Future<void> openDocument(BuildContext context, DocumentEntity document) => Navigator.of(
  context,
  rootNavigator: true,
).push(MaterialPageRoute<void>(builder: (_) => DocumentViewerScreen(document: document)));

/// One document: type icon, file name, date and what it belongs to.
class DocumentTile extends StatelessWidget {
  const DocumentTile({super.key, required this.document, this.showOwner = true});

  final DocumentEntity document;

  /// Show the account / "transaction" the document belongs to (off where
  /// that is the page itself).
  final bool showOwner;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final d = document;
    final account = d.account;
    final subtitle = [
      documentDate(d),
      if (showOwner && account != null && account.isNotEmpty) accountLabel(account),
      if (showOwner && d.trxId != null && d.trxId!.isNotEmpty) l10n.documentsOfTransaction,
    ].join(' · ');
    return ListTile(
      key: Key('document.${d.path}'),
      leading: CircleAvatar(
        radius: 18,
        backgroundColor: scheme.secondaryContainer,
        child: Icon(documentIcon(d), size: 20, color: scheme.onSecondaryContainer),
      ),
      title: Text(d.filename, maxLines: 1, overflow: TextOverflow.ellipsis),
      subtitle: Text(subtitle, maxLines: 1, overflow: TextOverflow.ellipsis),
      onTap: () => openDocument(context, d),
    );
  }
}
