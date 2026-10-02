import 'package:flutter/material.dart';

import '../../../l10n/l10n.dart';
import '../transaction_builder.dart';

/// Bottom sheet to choose tags: known tags (by frecency) as filter chips plus
/// a field to create new ones. Returns the new selection, or `null` when
/// dismissed.
Future<List<String>?> showTagsSheet(
  BuildContext context, {
  required List<String> selected,
  required List<String> known,
}) {
  return showModalBottomSheet<List<String>>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    showDragHandle: true,
    builder: (context) => _TagsSheet(selected: selected, known: known),
  );
}

class _TagsSheet extends StatefulWidget {
  const _TagsSheet({required this.selected, required this.known});

  final List<String> selected;
  final List<String> known;

  @override
  State<_TagsSheet> createState() => _TagsSheetState();
}

class _TagsSheetState extends State<_TagsSheet> {
  late final List<String> _selected = [...widget.selected];
  late final List<String> _all = [
    ...widget.selected,
    ...widget.known.where((t) => !widget.selected.contains(t)).take(30),
  ];
  final _input = TextEditingController();

  @override
  void dispose() {
    _input.dispose();
    super.dispose();
  }

  void _add() {
    final tag = normalizeTag(_input.text);
    if (tag == null) return;
    setState(() {
      if (!_all.contains(tag)) _all.insert(0, tag);
      if (!_selected.contains(tag)) _selected.add(tag);
      _input.clear();
    });
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final theme = Theme.of(context);
    return Padding(
      padding: EdgeInsets.fromLTRB(16, 0, 16, 16 + MediaQuery.viewInsetsOf(context).bottom),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Expanded(child: Text(l10n.addTags, style: theme.textTheme.titleLarge)),
              FilledButton(
                key: const Key('add.tags.done'),
                onPressed: () => Navigator.of(context).pop(_selected),
                child: Text(l10n.addDone),
              ),
            ],
          ),
          const SizedBox(height: 12),
          TextField(
            key: const Key('add.tags.input'),
            controller: _input,
            autofocus: _all.isEmpty,
            textInputAction: TextInputAction.done,
            onSubmitted: (_) => _add(),
            decoration: InputDecoration(
              isDense: true,
              prefixText: '# ',
              hintText: l10n.addTagHint,
              border: const OutlineInputBorder(),
              suffixIcon: IconButton(tooltip: l10n.addTagAdd, icon: const Icon(Icons.add), onPressed: _add),
            ),
          ),
          const SizedBox(height: 12),
          Flexible(
            child: SingleChildScrollView(
              child: Wrap(
                spacing: 8,
                children: [
                  for (final tag in _all)
                    FilterChip(
                      key: Key('add.tags.chip.$tag'),
                      label: Text('#$tag'),
                      selected: _selected.contains(tag),
                      onSelected: (on) => setState(() => on ? _selected.add(tag) : _selected.remove(tag)),
                    ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
