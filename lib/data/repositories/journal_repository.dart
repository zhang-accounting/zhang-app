import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../api/builtin_query_client.dart';
import '../api/endpoints.dart';
import '../api/idempotency.dart';
import '../api/zhang_api_client.dart';
import '../models/for_new_transaction.dart';
import '../models/journal.dart';
import '../models/pageable.dart';
import '../models/transaction_preview.dart';
import '../models/transaction_request.dart';
import '../models/written_transaction.dart';
import 'ledger_revision.dart';

/// Filters for `GET /api/journals`.
@immutable
class JournalQuery {
  const JournalQuery({
    this.page = 1,
    this.size = 50,
    this.keyword,
    this.tags = const [],
    this.links = const [],
  });

  /// 1-based.
  final int page;

  /// 1–1000 (the server answers 400 otherwise); clamped when sent.
  final int size;

  /// Case-insensitive substring over payee, narration, tags, links and
  /// posting account names.
  final String? keyword;

  /// Match transactions having ANY of these tags (see [JournalRepository.list]).
  final List<String> tags;

  /// Match transactions having ANY of these links.
  final List<String> links;

  JournalQuery copyWith({int? page, int? size, String? keyword, List<String>? tags, List<String>? links}) =>
      JournalQuery(
        page: page ?? this.page,
        size: size ?? this.size,
        keyword: keyword ?? this.keyword,
        tags: tags ?? this.tags,
        links: links ?? this.links,
      );

  /// Hand-built query string. `tags`/`links` need literal brackets
  /// (`tags[0]=x`): the server silently ignores percent-encoded brackets and
  /// rejects `tags=x` (docs/zhang-api.md §4.1), so dio's `queryParameters` cannot be used.
  String toQueryString() {
    final parts = <String>['page=${page < 1 ? 1 : page}', 'size=${size.clamp(1, 1000)}'];
    final kw = keyword;
    if (kw != null && kw.isNotEmpty) parts.add('keyword=${Uri.encodeComponent(kw)}');
    for (var i = 0; i < tags.length; i++) {
      parts.add('tags[$i]=${Uri.encodeComponent(tags[i])}');
    }
    for (var i = 0; i < links.length; i++) {
      parts.add('links[$i]=${Uri.encodeComponent(links[i])}');
    }
    return parts.join('&');
  }

  @override
  bool operator ==(Object other) =>
      other is JournalQuery &&
      other.page == page &&
      other.size == size &&
      other.keyword == keyword &&
      listEquals(other.tags, tags) &&
      listEquals(other.links, links);

  @override
  int get hashCode => Object.hash(page, size, keyword, Object.hashAll(tags), Object.hashAll(links));
}

/// Journals (transactions + balance items) and transaction writes.
class JournalRepository {
  JournalRepository(this._client, {this._onMutated});

  final ZhangApiClient _client;
  final OnLedgerMutated? _onMutated;

  /// `GET /api/journals`, newest first (by `sequence`).
  ///
  /// Known limitation: Dart's `Uri`/`HttpClient` re-encodes `[`/`]` as
  /// `%5B`/`%5D`, which the server silently ignores, so tag/link filtering
  /// cannot reach the server. When [JournalQuery.tags]/[JournalQuery.links]
  /// are set, the returned page is additionally filtered client-side (results
  /// are correct but a page may hold fewer than `size` items, and
  /// `totalCount` is the server's unfiltered count).
  Future<Pageable<JournalItem>> list([JournalQuery query = const JournalQuery()]) async {
    final page = await _client.get(
      '${ZhangEndpoints.journals}?${query.toQueryString()}',
      decode: (d) => Pageable.fromJson(d, JournalItem.fromJson),
    );
    if (query.tags.isEmpty && query.links.isEmpty) return page;
    return page.copyWith(
      records: page.records.where((r) {
        if (r is! JournalTransaction) return false;
        final tagOk = query.tags.isEmpty || r.tags.any(query.tags.contains);
        final linkOk = query.links.isEmpty || r.links.any(query.links.contains);
        return tagOk && linkOk;
      }).toList(),
    );
  }

  /// Entry-form suggestions: `journals.payees` and the accounts open at the
  /// ledger's current instant (`journals.accounts` at `ledger.now`).
  Future<ForNewTransaction> forNewTransaction() async {
    final queries = _client.builtins;
    final now = await queries.query(const BuiltinQuery('ledger.now'), (r) => r.rows.first);
    return queries.batch(
      [
        const BuiltinQuery('journals.payees'),
        BuiltinQuery('journals.accounts', {'date': now.string('date'), 'time': now.string('time')}),
      ],
      (r) => ForNewTransaction.fromResults(r[0], r[1]),
    );
  }

  /// `POST /api/transactions`. Names the ledger could not read back are
  /// refused with 400; an unbalanced transaction or an unknown / closed
  /// account is still written (it shows up as a ledger error) – check with
  /// [preview] first.
  ///
  /// With [idempotencyKey] (one per user action, the same for every retry
  /// of it, see `CreateIntent`) a zhang ≥ 0.3 server writes the transaction
  /// once: a create sent again answers the transaction written the first
  /// time, [WrittenTransaction.replayed]. Older servers ignore the header
  /// and answer `"Ok"` ([WrittenTransaction.unknown]).
  Future<WrittenTransaction> create(CreateTransactionRequest request, {String? idempotencyKey}) async {
    final answer = await _client.exchange(
      'POST',
      ZhangEndpoints.transactions,
      body: request.toJson(),
      headers: idempotencyKey == null ? null : {Idempotency.keyHeader: idempotencyKey},
      decode: (data) => data,
    );
    final replayed = answer.headers.value(Idempotency.replayedHeader)?.trim().toLowerCase() == 'true';
    _onMutated?.call();
    return WrittenTransaction.fromJson(answer.data, replayed: replayed);
  }

  /// `POST /api/transactions/preview` – validates [request] without writing:
  /// the text that would be written, refused fields, what it is unbalanced
  /// by and the ledger errors it would cause.
  Future<TransactionPreview> preview(CreateTransactionRequest request) =>
      _client.post(ZhangEndpoints.transactionPreview, body: request.toJson(), decode: TransactionPreview.fromJson);

  /// `POST /api/transactions/{id}/preview` – [preview] for an edit: checks
  /// [request] in place of the transaction [id] it would replace (404 when
  /// the id is stale, 400 for a transaction a plugin made, 412 when
  /// [version] no longer matches).
  Future<TransactionPreview> previewUpdate(String id, CreateTransactionRequest request, {String? version}) =>
      _client.post(
        ZhangEndpoints.transactionUpdatePreview(id),
        body: request.toJson(),
        headers: _ifMatch(version),
        decode: TransactionPreview.fromJson,
      );

  /// `PUT /api/transactions/{id}` – replaces the whole transaction (404 when
  /// the id is stale: ids change when the file changes; 412 when [version],
  /// the `version` it was read with, no longer matches). Build [request]
  /// with `CreateTransactionRequest.fromJournal` so tags, links, metas,
  /// posting metadata and the written cost / price / comment are preserved.
  Future<void> update(String id, CreateTransactionRequest request, {String? version}) async {
    await _client.send('PUT', ZhangEndpoints.transaction(id), body: request.toJson(), headers: _ifMatch(version));
    _onMutated?.call();
  }

  static Map<String, String>? _ifMatch(String? version) => version == null ? null : {'If-Match': version};

  /// The journal item [id] as the server lists it now: searched by
  /// [keyword] (payee, narration, …; up to 5 pages of 100), then on page 1.
  /// `null` = not found (ids change when the file changes). Pads come with
  /// their balance check folded in.
  Future<JournalItem?> findById(String id, {String? keyword}) async {
    JournalItem? find(List<JournalItem> records) {
      for (final item in foldBalancePads(records)) {
        if (item.id == id) return item;
      }
      return null;
    }

    final k = keyword?.trim();
    if (k != null && k.isNotEmpty) {
      for (var page = 1; page <= 5; page++) {
        final result = await list(JournalQuery(page: page, size: 100, keyword: k));
        final found = find(result.records);
        if (found != null) return found;
        if (!result.hasNextPage) break;
      }
    }
    return find((await list(const JournalQuery(page: 1, size: 100))).records);
  }
}

final journalRepositoryProvider = Provider<JournalRepository>(
  (ref) => JournalRepository(
    ref.watch(zhangApiClientProvider),
    onMutated: () => ref.read(ledgerRevisionProvider.notifier).bumpAfterWrite(),
  ),
);
