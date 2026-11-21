import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:zhang_app/data/api/zhang_api_client.dart';
import 'package:zhang_app/data/profiles/server_profile.dart';

import '../../helpers/builtin_fake.dart';
import '../../helpers/fake_adapter.dart';
import '../../helpers/fixtures.dart';
import 'journal_test_utils.dart';

const testProfile = ServerProfile(id: 'p1', name: 'Family', baseUrl: 'http://127.0.0.1:18030');

/// In-memory zhang v0.2 server for feature tests: serves [journals] with
/// page/size/keyword, the built-in queries ([builtins]: report summary,
/// ledger errors from [errors], …), info / options / commodities fixtures,
/// and records every request in [adapter].
class FakeZhangServer {
  FakeZhangServer({List<Map<String, Object?>>? journals, this.withErrors = false})
    : journals = journals ?? [] {
    builtins.answers['journals.errors'] = (_) {
      final captured = singleResult('errors.json');
      return withErrors ? captured : {'columns': captured['columns'], 'rows': const <Object?>[], 'total': 0};
    };
  }

  final List<Map<String, Object?>> journals;

  /// Report the two captured ledger errors (`errors.json`) instead of none.
  bool withErrors;

  /// Built-in query answers (captured fixtures by default).
  final builtins = FakeBuiltins();

  /// When set, `/journals` requests for these pages fail with HTTP 500.
  Set<int> failingPages = {};

  /// When true every request answers 401.
  bool unauthorized = false;

  /// `/api/info.reload_failure` to report (`{file, message}`), if any.
  Map<String, Object?>? reloadFailure;

  /// Transaction previews and writes: `(method, path, body)`.
  final transactionRequests = <(String, String, Map<String, Object?>)>[];

  /// Answer `PUT /transactions/{id}` without changing anything (a write the
  /// journal never shows).
  bool ignoreWrites = false;

  /// zhang ≥ 0.3: a create answers the id and version of the transaction it
  /// wrote (which the journal then lists with that version) and honours its
  /// `Idempotency-Key`. Otherwise it answers `"Ok"` as older servers do.
  bool writesAnswerIds = false;

  /// The transaction ids written by a create, by `Idempotency-Key`.
  final idempotencyKeys = <String, String>{};

  /// Answer of `POST /api/transactions/preview` and
  /// `POST /api/transactions/{id}/preview` (clean by default).
  Map<String, Object?> previewAnswer = const {
    'text': '2023-09-30 12:00:00 * "Shop" ""\n  Assets:WeChat -10 CNY\n  Expenses:Food',
    'field_errors': [],
    'unbalanced': [],
    'errors': [],
  };

  late final adapter = FakeAdapter(_handle);

  late final client = ZhangApiClient(
    testProfile,
    dio: Dio(BaseOptions(baseUrl: testProfile.apiBaseUrl))..httpClientAdapter = adapter,
  );

  List<RequestOptions> requestsTo(String path) =>
      adapter.requests.where((r) => r.uri.path.endsWith(path)).toList();

  ResponseBody _handle(RequestOptions o) {
    if (unauthorized) return jsonResponse({'message': 'unauthorized'}, status: 401);
    final path = o.uri.path;
    final q = o.uri.queryParameters;
    if (path.endsWith('/journals')) {
      final page = int.parse(q['page'] ?? '1');
      final size = int.parse(q['size'] ?? '100');
      if (failingPages.contains(page)) return jsonResponse({'message': 'boom'}, status: 500);
      final keyword = (q['keyword'] ?? '').toLowerCase();
      final matching = keyword.isEmpty
          ? journals
          : journals.where((j) => '${j['payee']} ${j['narration']}'.toLowerCase().contains(keyword)).toList();
      final start = (page - 1) * size;
      final records = start >= matching.length
          ? <Map<String, Object?>>[]
          : matching.sublist(start, (start + size).clamp(0, matching.length));
      return jsonResponse(pageJson(records, page: page, size: size, total: matching.length));
    }
    if (path.contains('/transactions')) return _transactions(o);
    if (path.endsWith('/accounts')) return jsonResponse(fixture('accounts.json'));
    final builtin = builtins.handle(o);
    if (builtin != null) return builtin;
    if (path.endsWith('/info')) {
      final info = fixture('info.json')! as Map<String, Object?>;
      return jsonResponse({
        'data': {...(info['data']! as Map<String, Object?>), 'reload_failure': reloadFailure},
      });
    }
    if (path.endsWith('/reload') && o.method == 'POST') {
      return reloadFailure == null
          ? jsonResponse({'data': 'Ok'})
          : jsonResponse({'message': 'the ledger failed to reload: ${reloadFailure!['message']}'}, status: 409);
    }
    if (path.endsWith('/options')) return jsonResponse(fixture('options.json'));
    if (path.endsWith('/commodities')) return jsonResponse(fixture('commodities.json'));
    return jsonResponse({'message': 'not found'}, status: 404);
  }
}

extension on FakeZhangServer {
  /// `POST /transactions[/preview]`, `POST /transactions/{id}/preview`,
  /// `PUT /transactions/{id}`, `DELETE /transactions/{id}`: an edit replaces
  /// the item in place, keeping its id (as zhang does: the transaction keeps
  /// its place in the file); a delete needs `If-Match` (428) with the
  /// current version (412); an unknown id is a 404.
  ResponseBody _transactions(RequestOptions o) {
    final path = o.uri.path;
    final body = (o.data as Map?)?.cast<String, Object?>() ?? const <String, Object?>{};
    transactionRequests.add((o.method, path, body));
    final byId = RegExp(r'/transactions/([^/]+?)(/preview)?$').firstMatch(path);
    if (byId != null && byId.group(1) != 'preview') {
      final id = Uri.decodeComponent(byId.group(1)!);
      final index = journals.indexWhere((j) => j['id'] == id);
      if (index < 0) return jsonResponse({'message': 'there is no transaction $id in the ledger'}, status: 404);
      // zhang PR #818: `If-Match` must name the current `version`.
      final ifMatch = o.headers['If-Match'];
      final version = journals[index]['version'];
      if (o.method == 'DELETE' && ifMatch == null) {
        return jsonResponse({'message': 'the request needs an If-Match header'}, status: 428);
      }
      if (ifMatch != null && ifMatch != version) {
        return jsonResponse({'message': 'the transaction changed since version $ifMatch'}, status: 412);
      }
      if (o.method == 'DELETE') {
        journals.removeAt(index);
        return jsonResponse({'data': null});
      }
      if (byId.group(2) != null) return jsonResponse({'data': previewAnswer});
      if (ignoreWrites) return jsonResponse({'data': null});
      journals[index] = {
        ...journalFromRequest(id, journals[index]['sequence']! as int, body),
        if (version != null) 'version': '$version+',
      };
      return jsonResponse({'data': null});
    }
    if (path.endsWith('/preview')) return jsonResponse({'data': previewAnswer});
    if (!writesAnswerIds) {
      journals.insert(0, journalFromRequest('new-${journals.length}', journals.length + 1000, body));
      return jsonResponse({'data': 'Ok'});
    }
    final key = o.headers['Idempotency-Key'] as String?;
    final known = key == null ? null : journals.where((j) => j['id'] == idempotencyKeys[key]).firstOrNull;
    if (known != null) {
      return ResponseBody.fromString(
        jsonEncode({
          'data': {'id': known['id'], 'version': known['version']},
        }),
        200,
        headers: {
          Headers.contentTypeHeader: [Headers.jsonContentType],
          'Idempotency-Replayed': ['true'],
        },
      );
    }
    final id = 'new-${journals.length}';
    final written = journalFromRequest(id, journals.length + 1000, body);
    journals.insert(0, {
      ...written,
      'version': 'v-$id',
      // zhang writes the key as the transaction's metadata
      if (key != null)
        'metas': [
          ...(written['metas']! as List),
          {'key': 'idempotency-key', 'value': key},
        ],
    });
    if (key != null) idempotencyKeys[key] = id;
    return jsonResponse({
      'data': {'id': id, 'version': 'v-$id'},
    });
  }
}

/// The journal item zhang would list for a create / update [request].
Map<String, Object?> journalFromRequest(String id, int sequence, Map<String, Object?> request) {
  final postings = (request['postings']! as List).cast<Map<String, Object?>>();
  Map<String, Object?>? unitOf(Map<String, Object?> p) => (p['unit'] as Map?)?.cast<String, Object?>();
  final known = [for (final p in postings) ?unitOf(p)];
  final commodity = known.isEmpty ? 'CNY' : known.first['commodity'];
  final rest = known.fold<double>(0, (sum, u) => sum - double.parse(u['number']! as String));
  return {
    'type': 'Transaction',
    'id': id,
    'sequence': sequence,
    'datetime': request['datetime'],
    'payee': request['payee'],
    'narration': request['narration'],
    'tags': request['tags'],
    'links': request['links'],
    'flag': request['flag'] ?? '*',
    'is_balanced': true,
    'postings': [
      for (final p in postings)
        {
          'account': p['account'],
          'unit': unitOf(p),
          'cost': null,
          'inferred_unit': unitOf(p) ?? {'number': '$rest', 'commodity': commodity},
          'account_before': {'number': '0', 'commodity': commodity},
          'account_after': {'number': '0', 'commodity': commodity},
          'metas': p['metas'] ?? const [],
          'written': {'cost': p['cost'], 'price': p['price'], 'comment': p['comment']},
        },
    ],
    'metas': request['metas'],
    'edit_drops_text': false,
  };
}

/// [count] simple expense transactions, newest first, two per day starting
/// at 2023-09-30 going back (so they span several months).
List<Map<String, Object?>> generateExpenses(int count) {
  final start = DateTime(2023, 9, 30, 20);
  return [
    for (var i = 0; i < count; i++)
      expenseJson(
        'id-$i',
        _naive(start.subtract(Duration(hours: 12 * i))),
        amount: '${i + 1}',
        payee: 'Payee $i',
      ),
  ];
}

String _naive(DateTime d) {
  String two(int v) => v.toString().padLeft(2, '0');
  return '${d.year}-${two(d.month)}-${two(d.day)}T${two(d.hour)}:${two(d.minute)}:${two(d.second)}';
}
