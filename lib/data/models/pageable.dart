import 'json_utils.dart';

/// Paged result: `{total_count, total_page, page_size, current_page, records}`.
/// Pages are 1-based.
class Pageable<T> {
  const Pageable({
    required this.totalCount,
    required this.totalPage,
    required this.pageSize,
    required this.currentPage,
    required this.records,
  });

  factory Pageable.fromJson(Object? json, T Function(JsonMap json) item) {
    final m = asMap(json, 'pageable');
    return Pageable(
      totalCount: reqInt(m, 'total_count'),
      totalPage: reqInt(m, 'total_page'),
      pageSize: reqInt(m, 'page_size'),
      currentPage: reqInt(m, 'current_page'),
      records: parseList(m['records'], item, 'records'),
    );
  }

  final int totalCount;
  final int totalPage;
  final int pageSize;
  final int currentPage;
  final List<T> records;

  bool get hasNextPage => currentPage < totalPage;

  Pageable<T> copyWith({List<T>? records}) => Pageable(
    totalCount: totalCount,
    totalPage: totalPage,
    pageSize: pageSize,
    currentPage: currentPage,
    records: records ?? this.records,
  );
}
