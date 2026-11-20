import 'dart:io';

import 'package:path_provider/path_provider.dart';

/// Temporary copies of documents handed to the system share sheet.

/// Folder under the app's temporary directory where the app writes the
/// documents it shares (one sub-folder per share, deleted when the share
/// sheet closes).
const sharedDocumentsFolder = 'zhang-share';

/// share_plus's own copy of shared files on Android (`cacheDir/share_plus`;
/// `getTemporaryDirectory()` is the cache directory there).
const sharePlusCacheFolder = 'share_plus';

/// Where temporary files go (`getTemporaryDirectory` from path_provider;
/// replaced in tests).
typedef TemporaryDirectoryLookup = Future<Directory> Function();

/// Deletes every shared-document copy: `<temp>/zhang-share/` and
/// `<temp>/share_plus/` (left behind when the app was killed during a share,
/// or kept by share_plus until the next share). Best effort, never throws.
///
/// Called at startup (`main`) and when a profile is deleted
/// (`ProfilesController.delete`), so one ledger's documents do not outlive
/// it. Not right after a share: the receiving app may still read the file.
Future<void> clearSharedDocuments({TemporaryDirectoryLookup temporaryDirectory = getTemporaryDirectory}) async {
  try {
    final temp = await temporaryDirectory();
    for (final name in const [sharedDocumentsFolder, sharePlusCacheFolder]) {
      final folder = Directory('${temp.path}/$name');
      if (await folder.exists()) await folder.delete(recursive: true);
    }
  } catch (_) {
    // A temporary folder the OS may purge anyway (or no platform in tests).
  }
}
