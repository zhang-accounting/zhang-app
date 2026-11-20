import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:zhang_app/features/documents/document_viewer_screen.dart';
import 'package:zhang_app/features/documents/documents_screen.dart';
import 'package:zhang_app/features/journals/transaction_detail_screen.dart';
import 'package:zhang_app/router.dart';

import '../../helpers/builtin_fake.dart';
import '../../helpers/fake_adapter.dart';
import '../../helpers/fixtures.dart';
import '../accounts/ledger_app_harness.dart';

/// A 1×1 PNG.
final _png = base64.decode(
  'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAADUlEQVR42mNk+M9QDwADhgGAWjR9awAAAABJRU5ErkJggg==',
);
final _receipt = Uint8List.fromList(utf8.encode('receipt 42.00 USD'));

const _photo = 'attachments/737ef4f0-5c6a-4fb3-b30b-f016283bf3cb/photo.png';
const _trxPhoto = 'attachments/71b1fd90-a3eb-4ad1-ad61-78bd7ae6a733/photo.png';
const _txt = 'attachments/receipt.txt';

String _download(String path) => '/documents/${base64.encode(utf8.encode(path))}';

ResponseBody _route(String path, RequestOptions o) {
  if (path == '/accounts') {
    return data([
      accountJson('Assets:Paypal', {'CNY': '100'}),
    ]);
  }
  if (path.startsWith('/journals')) {
    // One page only: the Journal tab would otherwise keep asking for more.
    final page = (fixtureData('journals.json')! as Map).cast<String, Object?>();
    return data({...page, 'total_page': 1, 'total_count': (page['records']! as List).length});
  }
  if (path.endsWith('/journals')) return jsonResponse(fixture('account_journals.json'));
  if (path.startsWith('/accounts/')) return jsonResponse(fixture('account_detail.json'));
  if (o.path == _download(_photo) || o.path == _download(_trxPhoto)) {
    return ResponseBody.fromBytes(
      _png,
      200,
      headers: {
        Headers.contentTypeHeader: ['image/png'],
      },
    );
  }
  if (o.path == _download(_txt)) {
    return ResponseBody.fromBytes(
      _receipt,
      200,
      headers: {
        Headers.contentTypeHeader: ['text/plain'],
      },
    );
  }
  return jsonResponse({'message': 'not found'}, status: 404);
}

Finder _key(String k) => find.byKey(Key(k));

void main() {
  testWidgets('documents: ledger list from the Accounts menu, image preview and share, file open', (tester) async {
    final shared = <(String, int)>[];
    final builtins = FakeBuiltins();
    final (_, adapter) = await pumpLedgerApp(
      tester,
      _route,
      builtins: builtins,
      overrides: [
        documentSharerProvider.overrideWithValue((d, bytes, _) async => shared.add((d.filename, bytes.length))),
      ],
    );
    await tester.tap(find.text('Accounts'));
    await tester.pumpAndSettle();
    await tester.tap(_key('accounts.menu'));
    await tester.pumpAndSettle();
    await tester.tap(_key('accounts.documents'));
    await tester.pumpAndSettle();

    // Newest first, by month, with what each document belongs to.
    expect(find.byType(DocumentsScreen), findsOneWidget);
    expect(builtins.callsTo('journals.documents'), isNotEmpty);
    expect(find.text('October 2026'), findsOneWidget);
    expect(find.text('September 2023'), findsOneWidget);
    expect(
      find.descendant(of: _key('document.$_photo'), matching: find.text('2026-10-10 12:07 · WeChat')),
      findsOneWidget,
    );
    expect(
      find.descendant(
        of: _key('document.$_trxPhoto'),
        matching: find.text('2026-10-02 18:30 · Transaction attachment'),
      ),
      findsOneWidget,
    );
    expect(find.descendant(of: _key('document.$_txt'), matching: find.text('2023-09-07 · Paypal')), findsOneWidget);

    // An image is downloaded through the API client and shown.
    await tester.tap(_key('document.$_photo'));
    await tester.pumpAndSettle();
    expect(find.byType(DocumentViewerScreen), findsOneWidget);
    expect(adapter.requests.where((r) => r.path == _download(_photo)), hasLength(1));
    expect(_key('document.image'), findsOneWidget);
    expect(_key('document.zoom'), findsOneWidget);
    expect(find.text('Assets:WeChat'), findsOneWidget);
    expect(find.text(_photo), findsOneWidget);

    // Share hands the downloaded bytes over (no second download).
    await tester.tap(_key('document.share'));
    await tester.pumpAndSettle();
    expect(shared, [('photo.png', _png.length)]);
    expect(adapter.requests.where((r) => r.path == _download(_photo)), hasLength(1));
    await tester.pageBack();
    await tester.pumpAndSettle();

    // Other files: details first, downloaded only for "Open or share".
    await tester.tap(_key('document.$_txt'));
    await tester.pumpAndSettle();
    expect(_key('document.noPreview'), findsOneWidget);
    expect(_key('document.image'), findsNothing);
    expect(find.text('text/plain'), findsOneWidget);
    expect(adapter.requests.where((r) => r.path == _download(_txt)), isEmpty);
    await tester.tap(_key('document.open'));
    await tester.pumpAndSettle();
    expect(adapter.requests.where((r) => r.path == _download(_txt)), hasLength(1));
    expect(shared.last, ('receipt.txt', _receipt.length));
  });

  testWidgets('documents: a failed download shows the error with retry', (tester) async {
    var fail = true;
    await pumpLedgerApp(tester, (path, o) {
      if (fail && o.path == _download(_photo)) return jsonResponse({'message': 'not found'}, status: 404);
      return _route(path, o);
    });
    await tester.tap(find.text('Accounts'));
    await tester.pumpAndSettle();
    await tester.tap(_key('accounts.menu'));
    await tester.pumpAndSettle();
    await tester.tap(_key('accounts.documents'));
    await tester.pumpAndSettle();
    await tester.tap(_key('document.$_photo'));
    await tester.pumpAndSettle();
    expect(find.text('Not found (404).'), findsOneWidget);
    fail = false;
    await tester.tap(find.text('Retry'));
    await tester.pumpAndSettle();
    expect(_key('document.image'), findsOneWidget);
  });

  testWidgets('documents: files over the download limit are not downloaded', (tester) async {
    final shared = <String>[];
    await pumpLedgerApp(
      tester,
      _route,
      overrides: [
        documentDownloadLimitProvider.overrideWithValue(10),
        documentSharerProvider.overrideWithValue((d, _, _) async => shared.add(d.filename)),
      ],
    );
    await tester.tap(find.text('Accounts'));
    await tester.pumpAndSettle();
    await tester.tap(_key('accounts.menu'));
    await tester.pumpAndSettle();
    await tester.tap(_key('accounts.documents'));
    await tester.pumpAndSettle();

    await tester.tap(_key('document.$_photo'));
    await tester.pumpAndSettle();
    expect(_key('document.image'), findsNothing);
    expect(find.textContaining('too large to download'), findsOneWidget);
    await tester.pageBack();
    await tester.pumpAndSettle();

    await tester.tap(_key('document.$_txt'));
    await tester.pumpAndSettle();
    await tester.tap(_key('document.open'));
    await tester.pumpAndSettle();
    expect(find.textContaining('too large to download'), findsOneWidget); // snack bar
    expect(shared, isEmpty);
  });

  testWidgets('documents: account detail section and transaction attachments', (tester) async {
    final builtins = FakeBuiltins();
    final (container, _) = await pumpLedgerApp(tester, _route, builtins: builtins);

    // Account detail lists the account's document directives.
    container.read(routerProvider).go('/accounts/${Uri.encodeComponent('Assets:Paypal')}');
    await tester.pumpAndSettle();
    expect(builtins.callsTo('accounts.documents').last.params, {'account': 'Assets:Paypal'});
    final section = _key('accountDetail.documents');
    expect(find.descendant(of: section, matching: find.text('1 document')), findsOneWidget);
    expect(find.descendant(of: section, matching: find.text('receipt.txt')), findsOneWidget);
    // Its own account is not repeated.
    expect(find.descendant(of: section, matching: find.text('2023-09-07')), findsOneWidget);
    await tester.tap(find.descendant(of: section, matching: find.text('receipt.txt')));
    await tester.pumpAndSettle();
    expect(find.byType(DocumentViewerScreen), findsOneWidget);
    await tester.pageBack();
    await tester.pumpAndSettle();

    // A transaction with a document shows it; one without shows no section.
    await tester.tap(find.text('Journal'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Mobile Test Cafe'));
    await tester.pumpAndSettle();
    expect(find.byType(TransactionDetailScreen), findsOneWidget);
    final body = find.descendant(of: _key('trx.body'), matching: find.byType(Scrollable)).first;
    await tester.scrollUntilVisible(_key('trx.documents'), 200, scrollable: body);
    expect(find.descendant(of: _key('trx.documents'), matching: find.text('photo.png')), findsOneWidget);
    await tester.tap(find.descendant(of: _key('trx.documents'), matching: find.text('photo.png')));
    await tester.pumpAndSettle();
    expect(_key('document.image'), findsOneWidget);
    await tester.pageBack();
    await tester.pumpAndSettle();
    await tester.pageBack();
    await tester.pumpAndSettle();
    expect(builtins.callsTo('journals.documents'), hasLength(1));

    // The ledger's documents are kept for the revision: opening it again
    // does not refetch them.
    await tester.tap(find.text('Mobile Test Cafe'));
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(
      _key('trx.documents'),
      200,
      scrollable: find.descendant(of: _key('trx.body'), matching: find.byType(Scrollable)).first,
    );
    expect(builtins.callsTo('journals.documents'), hasLength(1));
    await tester.pageBack();
    await tester.pumpAndSettle();
    builtins.calls.clear();

    final list = find
        .descendant(of: find.byKey(const PageStorageKey<String>('journal.list')), matching: find.byType(Scrollable))
        .first;
    final supermarket = find.byKey(const ValueKey('journal.item.3bcdbf6a-ae47-0f9d-679a-3c4257b87b17'));
    await tester.scrollUntilVisible(supermarket, 300, scrollable: list);
    await tester.tap(supermarket);
    await tester.pumpAndSettle();
    expect(find.byType(TransactionDetailScreen), findsOneWidget);
    expect(_key('trx.documents'), findsNothing);
    // No `document` meta: nothing is requested.
    expect(builtins.callsTo('journals.documents'), isEmpty);
  });
}
