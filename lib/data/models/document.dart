import 'dart:convert';

import 'query_result.dart';

/// A document: a row of the built-in `journals.documents` /
/// `accounts.documents` queries (`date, time, path, account,
/// transaction_id`; read by column name, the two orders differ).
class DocumentEntity {
  const DocumentEntity({
    required this.datetime,
    required this.filename,
    required this.path,
    this.mimeType,
    this.account,
    this.trxId,
  });

  factory DocumentEntity.fromQueryRow(QueryRow r) {
    final path = r.string('path');
    return DocumentEntity(
      datetime: r.dateTime('date', 'time'),
      filename: fileNameOf(path),
      path: path,
      mimeType: mimeTypeOf(path),
      account: r.stringOrNull('account'),
      trxId: r.stringOrNull('transaction_id'),
    );
  }

  /// Naive ledger-local datetime.
  final DateTime datetime;
  final String filename;

  /// Path relative to the ledger root (used for download).
  final String path;

  /// MIME type guessed from the file extension, `null` when unknown.
  final String? mimeType;

  /// Account of an account document.
  final String? account;

  /// Transaction id of a transaction document.
  final String? trxId;

  /// Standard base64 of [path] used in `/api/documents/{b64path}` (a `/`
  /// inside it is fine on zhang ≥ 0.2).
  String get b64Path => base64.encode(utf8.encode(path));

  bool get isImage => mimeType?.startsWith('image/') ?? false;

  /// Last path segment.
  static String fileNameOf(String path) => path.split('/').where((s) => s.isNotEmpty).lastOrNull ?? path;

  static const _mimeTypes = {
    'png': 'image/png',
    'jpg': 'image/jpeg',
    'jpeg': 'image/jpeg',
    'gif': 'image/gif',
    'webp': 'image/webp',
    'heic': 'image/heic',
    'pdf': 'application/pdf',
    'txt': 'text/plain',
    'csv': 'text/csv',
  };

  /// MIME type by extension (case-insensitive), `null` when unknown.
  static String? mimeTypeOf(String path) {
    final name = fileNameOf(path);
    final dot = name.lastIndexOf('.');
    if (dot < 0 || dot == name.length - 1) return null;
    return _mimeTypes[name.substring(dot + 1).toLowerCase()];
  }
}
