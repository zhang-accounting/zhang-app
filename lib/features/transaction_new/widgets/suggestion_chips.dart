import 'package:flutter/material.dart';

/// Horizontally scrolling row of completion chips (S05).
class SuggestionChipsRow extends StatelessWidget {
  const SuggestionChipsRow({
    super.key,
    required this.items,
    required this.onSelected,
    required this.keyPrefix,
    this.icon,
  });

  final List<String> items;
  final ValueChanged<String> onSelected;
  final String keyPrefix;
  final IconData? icon;

  @override
  Widget build(BuildContext context) {
    if (items.isEmpty) return const SizedBox.shrink();
    return SizedBox(
      height: 44,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        itemCount: items.length,
        separatorBuilder: (_, _) => const SizedBox(width: 8),
        itemBuilder: (context, i) => ActionChip(
          key: Key('$keyPrefix${items[i]}'),
          avatar: icon == null ? null : Icon(icon, size: 16),
          label: Text(items[i], maxLines: 1, overflow: TextOverflow.ellipsis),
          visualDensity: VisualDensity.compact,
          onPressed: () => onSelected(items[i]),
        ),
      ),
    );
  }
}
