import 'dart:convert';
import 'dart:math';

import '../../data/api/api_exception.dart';
import '../../data/api/idempotency.dart';
import '../../data/models/transaction_request.dart';
import '../../data/models/written_transaction.dart';
import '../../data/repositories/journal_repository.dart';

/// What [CreateIntent.create] answers: the transaction written and whether
/// it may hold an earlier attempt's request ([CreateIntent.create]).
typedef CreateResult = ({WrittenTransaction written, bool mayDiffer});

/// One save of a new transaction as the user means it, across every
/// attempt to get it written: after a timeout or a dropped connection (the
/// server may have written it without the app hearing so), after "Save
/// anyway" for the preview's warnings, after a fix for what the server
/// refused. Every attempt sends the same [key] as `Idempotency-Key`, so a
/// zhang ≥ 0.3 server writes the transaction once (docs/decisions.md).
///
/// An entry screen starts one intent and a new one after each save that
/// keeps it open ("save and add another"); the simple form hands its
/// intent to the advanced editor it opens.
class CreateIntent {
  CreateIntent({Random? random}) : key = Idempotency.newKey(random);

  /// The `Idempotency-Key` of every attempt.
  final String key;

  /// The requests sent with [key] that the server may have written (all
  /// but those it refused with a 4xx), JSON-encoded.
  final _sent = <String>{};

  DateTime? _sentAt;

  /// The `datetime` of the first request the server may have written. An
  /// entry dated "now" keeps it on later attempts, so that whichever attempt
  /// the server wrote, the transaction is the same.
  DateTime? get sentAt => _sentAt;

  /// `POST /api/transactions` with [key]. On a replay (the server had the
  /// key: an earlier attempt was written, nothing is written now) the
  /// transaction is that earlier one: `mayDiffer` tells that an earlier
  /// attempt sent another request than [request] (the user changed the
  /// entry since), so the changes since may be missing from it.
  ///
  /// A request whose own metadata has `idempotency-key` (typed in the
  /// advanced editor) is sent without the header, which the server would
  /// refuse next to it.
  Future<CreateResult> create(JournalRepository repository, CreateTransactionRequest request) async {
    final body = jsonEncode(request.toJson());
    final ownKey = request.metas.any((m) => m.key == Idempotency.metaKey);
    final WrittenTransaction written;
    try {
      written = await repository.create(request, idempotencyKey: ownKey ? null : key);
    } catch (e) {
      if (!_refused(e)) _remember(request, body);
      rethrow;
    }
    final mayDiffer = written.replayed && _sent.any((sent) => sent != body);
    _remember(request, body);
    return (written: written, mayDiffer: mayDiffer);
  }

  void _remember(CreateTransactionRequest request, String body) {
    _sentAt ??= request.datetime;
    _sent.add(body);
  }

  /// The server answered and wrote nothing (400 invalid, 401, 404, 409, …).
  /// A timeout, a dropped connection or a 5xx may have been written.
  static bool _refused(Object error) {
    final status = error is ZhangApiException ? error.statusCode : null;
    return status != null && status >= 400 && status < 500;
  }
}
