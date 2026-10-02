import 'dart:convert';

import 'json_utils.dart';

/// `GET /api/documents` / `GET /api/accounts/{name}/documents` item.
class DocumentEntity {
  const DocumentEntity({
    required this.datetime,
    required this.filename,
    required this.path,
    this.mimeType,
    this.account,
    this.trxId,
  });

  factory DocumentEntity.fromJson(JsonMap m) => DocumentEntity(
    datetime: reqNaiveDateTime(m, 'datetime'),
    filename: reqString(m, 'filename'),
    path: reqString(m, 'path'),
    mimeType: optString(m, 'extension'),
    account: optString(m, 'account'),
    trxId: optString(m, 'trx_id'),
  );

  /// Naive ledger-local datetime.
  final DateTime datetime;
  final String filename;

  /// Path relative to the ledger root (used for download).
  final String path;

  /// The server's `extension` field, which actually holds a guessed MIME type
  /// (`image/png`); always null for account documents.
  final String? mimeType;
  final String? account;

  /// Transaction id for transaction documents.
  final String? trxId;

  /// Standard base64 of [path] used in `/api/documents/{b64path}`.
  String get b64Path => base64.encode(utf8.encode(path));

  /// Downloads are impossible when the base64 contains `/` (server bug).
  bool get isDownloadable => !b64Path.contains('/');

  bool get isImage => mimeType?.startsWith('image/') ?? false;
}
