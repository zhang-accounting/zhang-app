import 'package:flutter/material.dart';

import '../../../l10n/l10n.dart';
import '../transaction_edit.dart';

/// Asks before saving an edit that rewrites unquoted posting metadata as
/// text ([requotedMetas]: `lot: 8` → `lot: "8"` once the posting's account
/// changed). `true` = save anyway.
Future<bool> confirmRequotedMetas(BuildContext context, EditTarget target, Map<int, List<String>> requoted) async {
  final l10n = context.l10n;
  final lines = [
    for (final MapEntry(key: index, value: metas) in requoted.entries)
      '${target.tx.postings[index].account}: ${metas.join(', ')}',
  ];
  final go = await showDialog<bool>(
    context: context,
    builder: (context) => AlertDialog(
      key: const Key('edit.requote'),
      title: Text(l10n.editRequoteTitle),
      content: Text('${l10n.editRequoteMessage}\n\n${lines.join('\n')}'),
      actions: [
        TextButton(onPressed: () => Navigator.of(context).pop(false), child: Text(l10n.cancel)),
        FilledButton(
          key: const Key('edit.requote.save'),
          onPressed: () => Navigator.of(context).pop(true),
          child: Text(l10n.addSaveAnyway),
        ),
      ],
    ),
  );
  return go ?? false;
}
