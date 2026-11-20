import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/painting.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

import '../../core/utils/shared_files.dart';
import '../../data/models/document.dart';

/// Opens the system share sheet with [params] (replaced in tests).
typedef ShareSheet = Future<void> Function(ShareParams params);

Future<void> _systemShareSheet(ShareParams params) async {
  await SharePlus.instance.share(params);
}

/// Shares [bytes] as a file named like [document]; [origin] anchors the
/// sheet on iPad. The file is written to its own folder under
/// `<temp>/zhang-share/` and deleted when the share sheet closes (on Android
/// share_plus copies it into its own cache first); [clearSharedDocuments]
/// removes what a killed app left behind.
Future<void> shareDocumentBytes(
  DocumentEntity document,
  Uint8List bytes,
  Rect? origin, {
  TemporaryDirectoryLookup temporaryDirectory = getTemporaryDirectory,
  ShareSheet shareSheet = _systemShareSheet,
}) async {
  final temp = await temporaryDirectory();
  final folder = Directory('${temp.path}/$sharedDocumentsFolder/${DateTime.now().microsecondsSinceEpoch}');
  await folder.create(recursive: true);
  try {
    final name = document.filename.trim().isEmpty ? 'document' : document.filename;
    final file = File('${folder.path}/$name');
    await file.writeAsBytes(bytes, flush: true);
    await shareSheet(
      ShareParams(
        files: [XFile(file.path, mimeType: document.mimeType)],
        sharePositionOrigin: origin,
      ),
    );
  } finally {
    try {
      await folder.delete(recursive: true);
    } catch (_) {
      // Wiped by clearSharedDocuments() at the next start.
    }
  }
}
