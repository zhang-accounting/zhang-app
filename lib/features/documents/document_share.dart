import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/painting.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

import '../../data/models/document.dart';

/// Sharing a downloaded document: it is written to its own folder under
/// `<temp>/zhang-share/`, handed to the system share sheet (from which it can
/// be opened in another app or saved) and deleted once the sheet is done.

/// Folder name under the app's temporary directory.
const shareFolderName = 'zhang-share';

Future<Directory> _shareRoot() async => Directory('${(await getTemporaryDirectory()).path}/$shareFolderName');

/// Deletes everything under `<temp>/zhang-share/` (files left by a share the
/// app was killed during). Best effort, never throws. Runs before the first
/// share of each app run; also call it at startup and when a profile is
/// deleted (documents of one ledger must not outlive it).
Future<void> clearSharedDocuments() async {
  try {
    final root = await _shareRoot();
    if (await root.exists()) await root.delete(recursive: true);
  } catch (_) {
    // A temporary folder the OS may purge anyway.
  }
}

bool _clearedThisRun = false;

/// Shares [bytes] as a file named like [document]; [origin] anchors the
/// sheet on iPad. The file is deleted when the share sheet closes (Android's
/// share_plus copies it into its own cache first).
Future<void> shareDocumentBytes(DocumentEntity document, Uint8List bytes, Rect? origin) async {
  if (!_clearedThisRun) {
    _clearedThisRun = true;
    await clearSharedDocuments();
  }
  final root = await _shareRoot();
  final folder = Directory('${root.path}/${DateTime.now().microsecondsSinceEpoch}');
  await folder.create(recursive: true);
  try {
    final name = document.filename.trim().isEmpty ? 'document' : document.filename;
    final file = File('${folder.path}/$name');
    await file.writeAsBytes(bytes, flush: true);
    await SharePlus.instance.share(
      ShareParams(
        files: [XFile(file.path, mimeType: document.mimeType)],
        sharePositionOrigin: origin,
      ),
    );
  } finally {
    try {
      await folder.delete(recursive: true);
    } catch (_) {
      // Wiped by clearSharedDocuments() next time.
    }
  }
}
