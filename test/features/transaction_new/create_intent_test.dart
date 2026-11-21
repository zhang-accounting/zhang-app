import 'dart:convert';

import 'package:decimal/decimal.dart';
import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:zhang_app/data/api/api_exception.dart';
import 'package:zhang_app/data/api/zhang_api_client.dart';
import 'package:zhang_app/data/models/amount.dart';
import 'package:zhang_app/data/models/transaction_preview.dart';
import 'package:zhang_app/data/models/transaction_request.dart';
import 'package:zhang_app/data/models/written_transaction.dart';
import 'package:zhang_app/data/profiles/server_profile.dart';
import 'package:zhang_app/data/repositories/journal_repository.dart';
import 'package:zhang_app/features/transaction_new/create_intent.dart';
import 'package:zhang_app/features/transaction_new/transaction_edit.dart';

import '../../helpers/fake_adapter.dart';

const _profile = ServerProfile(id: 'p', name: 'Test', baseUrl: 'http://127.0.0.1:18011');

CreateTransactionRequest _coffee(String amount, {DateTime? at, List<Meta> metas = const []}) =>
    CreateTransactionRequest(
      datetime: at ?? DateTime(2026, 11, 21, 8, 15),
      payee: 'Coffee Lab',
      postings: [
        PostingRequest(account: 'Assets:Cash', unit: Amount(Decimal.parse('-$amount'), 'CNY')),
        PostingRequest(account: 'Expenses:Food', unit: Amount(Decimal.parse(amount), 'CNY')),
      ],
      metas: metas,
    );

/// `POST /api/transactions` of a zhang server: with [idempotent] (zhang ≥
/// 0.3, PR #831) a known `Idempotency-Key` writes nothing and answers the
/// transaction written with it (`Idempotency-Replayed: true`); without it
/// (older servers) the header is ignored and every create writes.
class _FakeZhang {
  _FakeZhang({this.idempotent = true});

  final bool idempotent;

  /// The transactions written: (key, payee and first amount).
  final written = <(String?, Map<String, Object?>)>[];

  /// The `Idempotency-Key` of every create received.
  final keys = <String?>[];

  /// Write the next create, then lose its answer (a receive timeout).
  bool loseNextAnswer = false;

  /// Refuse the next create with this status (nothing written).
  int? refuseNext;

  late final adapter = FakeAdapter(_handle);

  late final repository = JournalRepository(
    ZhangApiClient(_profile, dio: Dio(BaseOptions(baseUrl: _profile.apiBaseUrl))..httpClientAdapter = adapter),
  );

  ResponseBody _handle(RequestOptions o) {
    expect(o.uri.path, '/api/transactions');
    final key = o.headers['Idempotency-Key'] as String?;
    keys.add(key);
    if (refuseNext case final status?) {
      refuseNext = null;
      return jsonResponse({'message': 'invalid account'}, status: status);
    }
    final known = idempotent && key != null ? written.indexWhere((w) => w.$1 == key) : -1;
    if (known >= 0) {
      return ResponseBody.fromString(
        jsonEncode({
          'data': {'id': 'id-$known', 'version': 'v-$known'},
        }),
        200,
        headers: {
          Headers.contentTypeHeader: [Headers.jsonContentType],
          'Idempotency-Replayed': ['true'],
        },
      );
    }
    written.add((key, (o.data as Map).cast<String, Object?>()));
    final index = written.length - 1;
    if (loseNextAnswer) {
      loseNextAnswer = false;
      throw DioException(requestOptions: o, type: DioExceptionType.receiveTimeout);
    }
    return idempotent
        ? jsonResponse({
            'data': {'id': 'id-$index', 'version': 'v-$index'},
          })
        : jsonResponse({'data': 'Ok'});
  }
}

void main() {
  test('a retry after a timeout sends the same key: written once, the retry answers it', () async {
    final server = _FakeZhang();
    final intent = CreateIntent();

    server.loseNextAnswer = true;
    await expectLater(
      intent.create(server.repository, _coffee('28')),
      throwsA(isA<ApiNetworkError>().having((e) => e.kind, 'kind', NetworkErrorKind.timeout)),
    );
    expect(server.written, hasLength(1), reason: 'the server wrote it, the app never heard');
    expect(intent.sentAt, DateTime(2026, 11, 21, 8, 15));

    final retry = await intent.create(server.repository, _coffee('28'));
    expect(server.keys, [intent.key, intent.key], reason: 'the fake server sees the same key');
    expect(server.written, hasLength(1), reason: 'not written twice');
    expect(retry.written, const WrittenTransaction(id: 'id-0', version: 'v-0', replayed: true));
    expect(retry.mayDiffer, isFalse);
  });

  test('a replay after the entry changed tells that the changes may be missing', () async {
    final server = _FakeZhang()..loseNextAnswer = true;
    final intent = CreateIntent();
    await expectLater(intent.create(server.repository, _coffee('28')), throwsA(isA<ApiNetworkError>()));

    final retry = await intent.create(server.repository, _coffee('38'));
    expect(server.written, hasLength(1));
    expect(server.written.single.$2['postings'], contains(containsPair('unit', containsPair('number', '-28'))));
    expect(retry.written.replayed, isTrue);
    expect(retry.mayDiffer, isTrue);
  });

  test('an attempt the server refused does not count as possibly written', () async {
    final server = _FakeZhang()..refuseNext = 400;
    final intent = CreateIntent();
    await expectLater(intent.create(server.repository, _coffee('28')), throwsA(isA<ApiServerError>()));
    expect(server.written, isEmpty);
    expect(intent.sentAt, isNull, reason: 'an entry dated "now" takes the time of a later attempt');

    server.loseNextAnswer = true;
    await expectLater(intent.create(server.repository, _coffee('38')), throwsA(isA<ApiNetworkError>()));
    final retry = await intent.create(server.repository, _coffee('38'));
    expect(server.keys, everyElement(intent.key));
    expect(server.written, hasLength(1));
    expect(retry.written.replayed, isTrue);
    expect(retry.mayDiffer, isFalse, reason: 'only the 38 could have been written');
  });

  test('every intent has its own key; a fresh create answers id and version', () async {
    final server = _FakeZhang();
    final first = await CreateIntent().create(server.repository, _coffee('28'));
    final second = await CreateIntent().create(server.repository, _coffee('28'));
    expect(server.keys.toSet(), hasLength(2));
    expect(server.written, hasLength(2), reason: 'two saves of the same entry are two transactions');
    expect(first.written, const WrittenTransaction(id: 'id-0', version: 'v-0'));
    expect(second.written.replayed, isFalse);
  });

  test('older servers ignore the header: nothing depends on it', () async {
    final server = _FakeZhang(idempotent: false);
    final intent = CreateIntent();
    final created = await intent.create(server.repository, _coffee('28'));
    expect(server.keys, [intent.key]);
    expect(created.written, WrittenTransaction.unknown);
    expect(created.mayDiffer, isFalse);
  });

  test('a request with its own idempotency-key metadata is sent without the header', () async {
    final server = _FakeZhang();
    await CreateIntent().create(server.repository, _coffee('28', metas: const [Meta('idempotency-key', 'mine')]));
    expect(server.keys, [null]);
  });

  test('saveEntry creates with the intent\'s key, a new one without an intent', () async {
    final server = _FakeZhang();
    final repository = _Previewed(server.repository);
    final intent = CreateIntent();
    final created = await saveEntry(repository, _coffee('28'), intent: intent);
    expect(server.keys, [intent.key]);
    expect(created!.written.id, 'id-0');

    await saveEntry(repository, _coffee('12'));
    expect(server.keys.last, isNot(intent.key));
    expect(server.keys.last, isNotNull, reason: 'every create sends a key');
  });
}

/// [JournalRepository] whose previews are clean.
class _Previewed extends JournalRepository {
  _Previewed(this._inner) : super(ZhangApiClient(_profile));

  final JournalRepository _inner;

  @override
  Future<TransactionPreview> preview(CreateTransactionRequest request) async =>
      TransactionPreview.fromJson(const {'text': '…', 'field_errors': [], 'unbalanced': [], 'errors': []});

  @override
  Future<WrittenTransaction> create(CreateTransactionRequest request, {String? idempotencyKey}) =>
      _inner.create(request, idempotencyKey: idempotencyKey);
}
