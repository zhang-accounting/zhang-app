import '../../core/utils/dates.dart';
import '../../core/utils/money.dart';
import '../../data/models/amount.dart';
import '../../data/models/journal.dart';

/// Renders a journal item in zhang / Beancount text syntax (the "copy as
/// text" action of the detail screen):
///
/// ```text
/// 2023-09-16 21:56:16 * "隆江猪脚饭" "Eating Dinner" #food ^receipt-1
///   source: "zhang-app"
///   Assets:CitiBank:9999         -21 CNY
///   Expenses:PersonalDiet:Lunch
/// ```
///
/// Postings use the amount as written (`unit`); implicit postings are left
/// without amount. Balance items become `balance` directives.
String journalItemToText(JournalItem item) => switch (item) {
  JournalTransaction() => transactionToText(item),
  JournalBalance() => balanceToText(item),
  JournalUnknown() => '; ${_date(item.datetime)} ${item.payee} ${item.narration ?? ''}'.trimRight(),
};

String transactionToText(JournalTransaction txn) {
  final header = <String>[
    _date(txn.datetime),
    txn.flag.isEmpty ? '*' : txn.flag,
    if (txn.payee.isNotEmpty) _quote(txn.payee),
    if (txn.payee.isNotEmpty || (txn.narration ?? '').isNotEmpty) _quote(txn.narration ?? ''),
    for (final t in txn.tags) '#$t',
    for (final l in txn.links) '^$l',
  ];
  final width = txn.postings.fold<int>(0, (w, p) => p.account.length > w ? p.account.length : w);
  final lines = <String>[
    header.join(' '),
    for (final m in txn.metas) '  ${m.key}: ${_quote(m.value)}',
    for (final p in txn.postings) _posting(p, width),
  ];
  return lines.join('\n');
}

String balanceToText(JournalBalance item) {
  final amount = item.assertedAmount;
  final asserted = amount == null ? '' : ' ${_amount(amount)}';
  final line = '${_date(item.datetime)} balance ${item.account}$asserted';
  if (!item.isPad) return line;
  final pad = item.padAccount;
  return pad == null ? line : '$line with pad $pad';
}

String _posting(JournalPosting p, int width) {
  final unit = p.unit;
  if (unit == null) return '  ${p.account}';
  final cost = p.cost == null ? '' : ' {${_amount(p.cost!)}}';
  return '  ${p.account.padRight(width)}  ${_amount(unit)}$cost';
}

/// Plain number (no grouping, at least 2 decimals, never exponent notation).
String _amount(Amount a) => '${formatDecimal(a.number, grouping: false)} ${a.commodity}';

/// `YYYY-MM-DD` for date-only directives, else `YYYY-MM-DD HH:MM:SS`.
String _date(DateTime d) {
  final date = ZhangDates.toIsoDate(d);
  if (d.hour == 0 && d.minute == 0 && d.second == 0) return date;
  return ZhangDates.toNaiveIso(d).replaceFirst('T', ' ');
}

String _quote(String s) => '"${s.replaceAll(r'\', r'\\').replaceAll('"', r'\"')}"';
