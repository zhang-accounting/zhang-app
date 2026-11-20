import '../../router.dart';

/// `YYYY-MM` path segment of a month.
String budgetMonthSegment(DateTime month) =>
    '${month.year.toString().padLeft(4, '0')}-${month.month.toString().padLeft(2, '0')}';

/// The month of a `YYYY-MM` segment (local midnight of the 1st), `null` when
/// malformed.
DateTime? parseBudgetMonth(String segment) {
  final match = RegExp(r'^(\d{4})-(\d{2})$').firstMatch(segment);
  if (match == null) return null;
  final month = int.parse(match.group(2)!);
  if (month < 1 || month > 12) return null;
  return DateTime(int.parse(match.group(1)!), month);
}

/// Location of a budget's detail in a month, inside the Reports tab:
/// `/reports/budgets/<YYYY-MM>/<name>`. The month is part of the path so the
/// transaction detail pushed on top (`…/transactions/<id>`) keeps it.
String budgetDetailLocation(String name, DateTime month) =>
    '${AppRoutes.reports}/budgets/${budgetMonthSegment(month)}/${Uri.encodeComponent(name)}';
