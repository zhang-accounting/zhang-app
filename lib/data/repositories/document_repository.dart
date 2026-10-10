import 'dart:typed_data';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../api/builtin_query_client.dart';
import '../api/endpoints.dart';
import '../api/zhang_api_client.dart';
import '../models/document.dart';

/// Documents (listing and download; uploads are not implemented yet).
class DocumentRepository {
  DocumentRepository(this._client);

  final ZhangApiClient _client;

  /// All documents, newest first (built-in `journals.documents`).
  Future<List<DocumentEntity>> list() => _client.builtins.query(
    const BuiltinQuery('journals.documents'),
    (r) => [for (final row in r.rows) DocumentEntity.fromQueryRow(row)],
  );

  /// `GET /api/documents/{b64path}` – raw bytes (auth header included). A
  /// missing file is `ApiNotFound`; a path outside the ledger is refused
  /// with 403 (`ApiUnauthorized`).
  Future<Uint8List> download(DocumentEntity document) =>
      _client.getBytes(ZhangEndpoints.document(document.b64Path));
}

final documentRepositoryProvider = Provider<DocumentRepository>(
  (ref) => DocumentRepository(ref.watch(zhangApiClientProvider)),
);
