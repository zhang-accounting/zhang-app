import 'dart:typed_data';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../api/endpoints.dart';
import '../api/zhang_api_client.dart';
import '../models/document.dart';
import '../models/json_utils.dart';

/// Documents (listing and download; uploads are not implemented yet).
class DocumentRepository {
  DocumentRepository(this._client);

  final ZhangApiClient _client;

  /// `GET /api/documents` – newest-added first.
  Future<List<DocumentEntity>> list() => _client.get(
    ZhangEndpoints.documents,
    decode: (d) => parseList(d, DocumentEntity.fromJson, 'documents'),
  );

  /// `GET /api/documents/{b64path}` – raw bytes (auth header included).
  /// Check [DocumentEntity.isDownloadable] first; a missing file yields an
  /// empty result.
  Future<Uint8List> download(DocumentEntity document) {
    if (!document.isDownloadable) {
      throw UnsupportedError('document path cannot be addressed by the server API');
    }
    return _client.getBytes(ZhangEndpoints.document(document.b64Path));
  }
}

final documentRepositoryProvider = Provider<DocumentRepository>(
  (ref) => DocumentRepository(ref.watch(zhangApiClientProvider)),
);
