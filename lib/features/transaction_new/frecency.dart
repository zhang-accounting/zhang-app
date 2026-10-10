import 'dart:math' as math;

/// Exponential-decay "frecency" ranking, after Fava's
/// `ExponentialDecayRanker` (fava/core/inventory… `fava.util.ranking`):
/// every use of an item at time `t` adds `exp(rate · t)` to its score, so
///
///     score(item) ∝ Σ exp(−rate · Δdays)
///
/// combines recency and frequency (docs/design-research.md §2.6, P-10). The
/// score is kept in log space, which makes it independent of "now" and
/// avoids overflow. The default [rate] of 1/30 per day gives the
/// `Σ exp(−Δdays / 30)` of the design spec (Fava uses ln 2 / 365).
class ExponentialDecayRanker<T> {
  ExponentialDecayRanker({this.rate = 1 / 30});

  /// Decay per day.
  final double rate;

  final Map<T, double> _scores = {};

  /// Records a use of [item] at [time].
  void update(T item, DateTime time) {
    final t = rate * time.millisecondsSinceEpoch / Duration.millisecondsPerDay;
    final previous = _scores[item];
    if (previous == null) {
      _scores[item] = t;
      return;
    }
    final higher = math.max(previous, t);
    final lower = math.min(previous, t);
    _scores[item] = higher + math.log(1 + math.exp(lower - higher));
  }

  /// Log-space score; `-infinity` for items never seen.
  double score(T item) => _scores[item] ?? double.negativeInfinity;

  /// Every item seen so far.
  Iterable<T> get items => _scores.keys;

  /// [items] sorted by descending score. Stable: equal scores (including
  /// unseen items) keep their input order.
  List<T> sort(Iterable<T> items) {
    final list = items.toList();
    final indexed = [for (var i = 0; i < list.length; i++) (i, list[i], score(list[i]))];
    indexed.sort((a, b) {
      final c = b.$3.compareTo(a.$3);
      return c != 0 ? c : a.$1.compareTo(b.$1);
    });
    return [for (final e in indexed) e.$2];
  }

  /// All seen items, best first.
  List<T> ranked() => sort(_scores.keys);
}
