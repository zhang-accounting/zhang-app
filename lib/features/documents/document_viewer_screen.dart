import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/widgets/error_view.dart';
import '../../data/api/api_exception.dart';
import '../../data/models/document.dart';
import '../../data/repositories/document_repository.dart';
import '../../l10n/l10n.dart';
import '../accounts/widgets/amount_format.dart' show accountPathStyle;
import 'document_share.dart';
import 'widgets/document_tile.dart';

/// Hands a downloaded document to the system share sheet, from which it can
/// be opened in another app or saved. [origin] anchors the sheet on iPad.
typedef DocumentSharer = Future<void> Function(DocumentEntity document, Uint8List bytes, Rect? origin);

/// The sharer (overridden in tests: the platform share sheet needs a device).
final documentSharerProvider = Provider<DocumentSharer>((ref) => shareDocumentBytes);

/// Largest document downloaded to the phone (to preview or share); bigger
/// files stop downloading with a message instead of filling the memory.
final documentDownloadLimitProvider = Provider<int>((ref) => 50 * 1024 * 1024);

/// Message for a failed download or share.
String describeDocumentError(AppLocalizations l10n, Object error) => error is ResponseTooLarge
    ? l10n.documentsTooLarge((error.maxBytes / (1024 * 1024)).round())
    : describeApiError(l10n, error);

/// A document (S15, read-only). Images are downloaded through the API client
/// (so the profile's auth applies) and shown with pinch-to-zoom; other files
/// show their details and "Open or share", which downloads the file and
/// opens the system share sheet.
class DocumentViewerScreen extends ConsumerStatefulWidget {
  const DocumentViewerScreen({super.key, required this.document});

  final DocumentEntity document;

  @override
  ConsumerState<DocumentViewerScreen> createState() => _DocumentViewerScreenState();
}

class _DocumentViewerScreenState extends ConsumerState<DocumentViewerScreen> {
  /// The download, started at once for images and on demand otherwise.
  Future<Uint8List>? _bytes;
  bool _sharing = false;

  DocumentEntity get _document => widget.document;

  @override
  void initState() {
    super.initState();
    if (_document.isImage) _bytes = _download();
  }

  Future<Uint8List> _download() =>
      ref.read(documentRepositoryProvider).download(_document, maxBytes: ref.read(documentDownloadLimitProvider));

  void _retry() => setState(() {
    _bytes = _download();
  });

  Future<void> _share(BuildContext anchor) async {
    final box = anchor.findRenderObject();
    final origin = box is RenderBox && box.hasSize ? box.localToGlobal(Offset.zero) & box.size : null;
    final messenger = ScaffoldMessenger.of(context);
    final l10n = context.l10n;
    final share = ref.read(documentSharerProvider);
    setState(() => _sharing = true);
    try {
      final bytes = await (_bytes ??= _download());
      await share(_document, bytes, origin);
    } catch (e) {
      // Download again next time.
      if (mounted && !_document.isImage) _bytes = null;
      messenger
        ..hideCurrentSnackBar()
        ..showSnackBar(SnackBar(content: Text(describeDocumentError(l10n, e))));
    } finally {
      if (mounted) setState(() => _sharing = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final d = _document;
    return Scaffold(
      appBar: AppBar(
        title: Text(d.filename, overflow: TextOverflow.ellipsis),
        actions: [
          Builder(
            builder: (anchor) => IconButton(
              key: const Key('document.share'),
              tooltip: l10n.documentsShare,
              icon: const Icon(Icons.share_outlined),
              onPressed: _sharing ? null : () => _share(anchor),
            ),
          ),
        ],
      ),
      body: d.isImage ? _imageBody(context) : _fileBody(context),
    );
  }

  Widget _imageBody(BuildContext context) {
    final l10n = context.l10n;
    final scheme = Theme.of(context).colorScheme;
    return Column(
      children: [
        if (_sharing) const LinearProgressIndicator(minHeight: 2),
        Expanded(
          child: ColoredBox(
            color: scheme.surfaceContainerLowest,
            child: FutureBuilder<Uint8List>(
              future: _bytes,
              builder: (context, snapshot) {
                final error = snapshot.error;
                if (error is ResponseTooLarge) {
                  return Center(
                    child: _NoPreview(document: _document, message: describeDocumentError(l10n, error)),
                  );
                }
                if (error != null) return ErrorView(error: error, onRetry: _retry);
                final bytes = snapshot.data;
                if (bytes == null) return const Center(child: CircularProgressIndicator());
                return LayoutBuilder(
                  builder: (context, constraints) => InteractiveViewer(
                    key: const Key('document.zoom'),
                    maxScale: 8,
                    child: Center(
                      child: Image.memory(
                        bytes,
                        key: const Key('document.image'),
                        fit: BoxFit.contain,
                        // Decode at twice the screen width (enough detail to
                        // zoom into a receipt), not at the photo's full size;
                        // smaller images are not upscaled.
                        cacheWidth: (constraints.maxWidth * MediaQuery.devicePixelRatioOf(context) * 2).round(),
                        errorBuilder: (context, _, _) => _NoPreview(document: _document),
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
        ),
        SafeArea(top: false, child: _DocumentDetails(document: _document, dense: true)),
      ],
    );
  }

  Widget _fileBody(BuildContext context) {
    final l10n = context.l10n;
    final theme = Theme.of(context);
    return ListView(
      padding: const EdgeInsets.only(bottom: 32),
      children: [
        if (_sharing) const LinearProgressIndicator(minHeight: 2) else const SizedBox(height: 2),
        _NoPreview(document: _document),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Builder(
            builder: (anchor) => FilledButton.tonalIcon(
              key: const Key('document.open'),
              onPressed: _sharing ? null : () => _share(anchor),
              icon: const Icon(Icons.open_in_new),
              label: Text(l10n.documentsOpenOrShare),
            ),
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
          child: Text(
            l10n.documentsOpenHint,
            textAlign: TextAlign.center,
            style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.onSurfaceVariant),
          ),
        ),
        _DocumentDetails(document: _document),
      ],
    );
  }
}

/// Large file icon, name and type (non-images, or an image that cannot be
/// decoded).
class _NoPreview extends StatelessWidget {
  const _NoPreview({required this.document, this.message});

  final DocumentEntity document;

  /// Replaces "no preview for this file type".
  final String? message;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      key: const Key('document.noPreview'),
      padding: const EdgeInsets.fromLTRB(24, 32, 24, 16),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(documentIcon(document), size: 64, color: theme.colorScheme.primary),
          const SizedBox(height: 12),
          Text(document.filename, style: theme.textTheme.titleMedium, textAlign: TextAlign.center),
          const SizedBox(height: 4),
          Text(
            message ?? context.l10n.documentsNoPreview,
            style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.onSurfaceVariant),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
}

/// Type, date, owner (account / transaction) and path of a document.
class _DocumentDetails extends StatelessWidget {
  const _DocumentDetails({required this.document, this.dense = false});

  final DocumentEntity document;
  final bool dense;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final d = document;
    final account = d.account;
    final ext = d.filename.contains('.') ? d.filename.split('.').last.toUpperCase() : null;
    final rows = <(String, Widget)>[
      if (!dense) (l10n.documentsType, Text(d.mimeType ?? ext ?? l10n.documentsUnknownType)),
      (l10n.documentsDate, Text(documentDate(d))),
      if (account != null && account.isNotEmpty) (l10n.documentsAccount, SelectableText(account)),
      if (d.trxId != null && d.trxId!.isNotEmpty) (l10n.documentsAttachedTo, Text(l10n.documentsOfTransaction)),
      (l10n.documentsPath, SelectableText(d.path, key: const Key('document.path'), style: accountPathStyle(context))),
    ];
    final theme = Theme.of(context);
    return Padding(
      padding: EdgeInsets.fromLTRB(16, dense ? 8 : 16, 16, 8),
      child: Column(
        children: [
          for (final (label, value) in rows)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 3),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  SizedBox(
                    width: 96,
                    child: Text(
                      label,
                      style: theme.textTheme.bodyMedium?.copyWith(color: theme.colorScheme.onSurfaceVariant),
                    ),
                  ),
                  Expanded(
                    child: DefaultTextStyle.merge(style: theme.textTheme.bodyMedium, child: value),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}
