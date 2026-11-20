import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:share_plus/share_plus.dart';
import 'package:zhang_app/core/utils/shared_files.dart';
import 'package:zhang_app/data/models/document.dart';
import 'package:zhang_app/features/documents/document_share.dart';

DocumentEntity _doc(String path) => DocumentEntity(
  datetime: DateTime(2023, 9, 7),
  filename: DocumentEntity.fileNameOf(path),
  path: path,
  mimeType: DocumentEntity.mimeTypeOf(path),
);

void main() {
  late Directory temp;

  setUp(() => temp = Directory.systemTemp.createTempSync('zhang_share_test'));
  tearDown(() => temp.deleteSync(recursive: true));

  Future<Directory> lookup() async => temp;
  List<FileSystemEntity> left() {
    final root = Directory('${temp.path}/$sharedDocumentsFolder');
    return root.existsSync() ? root.listSync(recursive: true) : const [];
  }

  test('writes the file under zhang-share for the share sheet and deletes it afterwards', () async {
    final bytes = Uint8List.fromList(utf8.encode('receipt 42.00 USD'));
    ShareParams? shared;
    await shareDocumentBytes(
      _doc('attachments/receipt.txt'),
      bytes,
      null,
      temporaryDirectory: lookup,
      shareSheet: (params) async {
        shared = params;
        final file = File(params.files!.single.path);
        // While the sheet is open the file exists, named like the document.
        expect(file.existsSync(), isTrue);
        expect(file.readAsBytesSync(), bytes);
        expect(file.uri.pathSegments.last, 'receipt.txt');
        expect(file.path, startsWith('${temp.path}/$sharedDocumentsFolder/'));
        expect(params.files!.single.mimeType, 'text/plain');
      },
    );
    expect(shared, isNotNull);
    expect(left(), isEmpty);
  });

  test('a failing share sheet still deletes the file', () async {
    await expectLater(
      shareDocumentBytes(
        _doc('attachments/photo.png'),
        Uint8List.fromList([1, 2, 3]),
        null,
        temporaryDirectory: lookup,
        shareSheet: (_) async => throw StateError('no share sheet'),
      ),
      throwsStateError,
    );
    expect(left(), isEmpty);
  });

  test('clearSharedDocuments wipes zhang-share and share_plus, nothing else', () async {
    File('${temp.path}/$sharedDocumentsFolder/1/receipt.txt').createSync(recursive: true);
    File('${temp.path}/$sharePlusCacheFolder/photo.png').createSync(recursive: true);
    final other = File('${temp.path}/other/keep.txt')..createSync(recursive: true);
    await clearSharedDocuments(temporaryDirectory: lookup);
    expect(Directory('${temp.path}/$sharedDocumentsFolder').existsSync(), isFalse);
    expect(Directory('${temp.path}/$sharePlusCacheFolder').existsSync(), isFalse);
    expect(other.existsSync(), isTrue);
    // Nothing to delete, or no temporary directory: no error.
    await clearSharedDocuments(temporaryDirectory: lookup);
    await clearSharedDocuments(temporaryDirectory: () async => throw StateError('no platform'));
  });
}
