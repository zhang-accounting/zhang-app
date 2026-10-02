import 'package:flutter/material.dart';

import '../../../core/category_icons.dart';
import '../../../l10n/l10n.dart';
import '../category_tree.dart';

/// Grid of second-level categories (fixed order, nothing pre-selected) and,
/// below it, the sub-category chips of the selected tile.
class CategoryGrid extends StatelessWidget {
  const CategoryGrid({
    super.key,
    required this.tree,
    required this.selected,
    required this.selectedSub,
    required this.onSelect,
    required this.onSelectSub,
  });

  final CategoryTree tree;
  final String? selected;
  final String? selectedSub;
  final ValueChanged<CategoryNode> onSelect;
  final ValueChanged<String> onSelectSub;

  @override
  Widget build(BuildContext context) {
    final selectedNode = selected == null ? null : tree.byName(selected!);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          padding: const EdgeInsets.symmetric(horizontal: 8),
          gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
            maxCrossAxisExtent: 84,
            mainAxisExtent: 82,
            crossAxisSpacing: 4,
            mainAxisSpacing: 4,
          ),
          itemCount: tree.categories.length,
          itemBuilder: (context, i) {
            final node = tree.categories[i];
            return _CategoryTile(
              key: Key('add.category.${node.name}'),
              node: node,
              selected: node.name == selected,
              onTap: () => onSelect(node),
            );
          },
        ),
        if (selectedNode != null && selectedNode.children.isNotEmpty)
          _SubcategoryChips(node: selectedNode, selected: selectedSub, onSelect: onSelectSub),
      ],
    );
  }
}

final _camelBoundary = RegExp(r'(?<=[a-z0-9])(?=[A-Z])');

/// Adds zero-width break opportunities at CamelCase boundaries so long
/// account segments wrap between words (`PersonalDiet` → `Personal|Diet`)
/// instead of mid-word.
String softWrapLabel(String label) => label.replaceAll(_camelBoundary, '\u200B');

class _CategoryTile extends StatelessWidget {
  const _CategoryTile({super.key, required this.node, required this.selected, required this.onTap});

  final CategoryNode node;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final icon = categoryIcon(node.name, alias: node.alias, childNames: [for (final c in node.children) c.name]);
    return Semantics(
      selected: selected,
      button: true,
      label: node.label,
      excludeSemantics: true,
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: onTap,
        child: AnimatedScale(
          scale: selected ? 1.0 : 0.97,
          duration: const Duration(milliseconds: 150),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Stack(
                clipBehavior: Clip.none,
                children: [
                  AnimatedContainer(
                    duration: const Duration(milliseconds: 150),
                    width: 46,
                    height: 46,
                    decoration: BoxDecoration(
                      color: selected ? scheme.primary : scheme.surfaceContainerHighest,
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: Icon(icon, color: selected ? scheme.onPrimary : scheme.onSurfaceVariant),
                  ),
                  if (selected)
                    Positioned(
                      right: -4,
                      top: -4,
                      child: Container(
                        decoration: BoxDecoration(color: scheme.surface, shape: BoxShape.circle),
                        child: Icon(Icons.check_circle, size: 16, color: scheme.primary),
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 4),
              Text(
                softWrapLabel(node.label),
                maxLines: 2,
                textAlign: TextAlign.center,
                overflow: TextOverflow.ellipsis,
                style: theme.textTheme.labelSmall?.copyWith(
                  color: selected ? scheme.primary : scheme.onSurface,
                  fontWeight: selected ? FontWeight.w600 : null,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _SubcategoryChips extends StatelessWidget {
  const _SubcategoryChips({required this.node, required this.selected, required this.onSelect});

  final CategoryNode node;
  final String? selected;
  final ValueChanged<String> onSelect;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final theme = Theme.of(context);
    final missing = node.requiresSubcategory && selected == null;
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text.rich(
            TextSpan(
              children: [
                TextSpan(text: '${node.label} › ${l10n.addSubcategory}'),
                if (node.requiresSubcategory)
                  TextSpan(
                    text: ' · ${l10n.addSubcategoryRequired}',
                    style: TextStyle(color: missing ? theme.colorScheme.error : null),
                  ),
              ],
            ),
            style: theme.textTheme.labelMedium?.copyWith(color: theme.colorScheme.onSurfaceVariant),
          ),
          const SizedBox(height: 4),
          Wrap(
            spacing: 8,
            runSpacing: 0,
            children: [
              for (final sub in node.children)
                ChoiceChip(
                  key: Key('add.sub.${sub.name}'),
                  label: Text(sub.label),
                  selected: sub.name == selected,
                  onSelected: (_) => onSelect(sub.name),
                ),
            ],
          ),
        ],
      ),
    );
  }
}
