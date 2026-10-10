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
    final builtin = builtins.handle(o);
    if (builtin != null) return builtin;
    if (path.endsWith('/info')) return jsonResponse(fixture('info.json'));
    if (path.endsWith('/options')) return jsonResponse(fixture('options.json'));
    if (path.endsWith('/commodities')) return jsonResponse(fixture('commodities.json'));
    return jsonResponse({'message': 'not found'}, status: 404);
  }
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
