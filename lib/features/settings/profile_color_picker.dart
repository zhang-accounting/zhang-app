import 'package:flutter/material.dart';

import '../../l10n/l10n.dart';

/// Colours offered for tagging a ledger (ARGB). `null` = theme primary.
const List<int> kProfilePalette = [
  0xFF1F6F8B, // teal blue
  0xFF3949AB, // indigo
  0xFF00897B, // teal
  0xFF2E7D32, // green
  0xFFF9A825, // amber
  0xFFEF6C00, // orange
  0xFFC62828, // red
  0xFF8E24AA, // purple
];

/// A row of colour swatches (theme default + [kProfilePalette]).
class ProfileColorPicker extends StatelessWidget {
  const ProfileColorPicker({super.key, required this.selected, required this.onChanged, this.size = 32});

  final int? selected;
  final ValueChanged<int?> onChanged;
  final double size;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    Widget swatch(int? value) {
      final color = value == null ? scheme.primary : Color(value);
      final isSelected = selected == value;
      return Semantics(
        selected: isSelected,
        button: true,
        label: value == null ? context.l10n.colorDefault : '#${value.toRadixString(16)}',
        child: InkResponse(
          key: Key('colorPicker.${value?.toRadixString(16) ?? 'default'}'),
          onTap: () => onChanged(value),
          radius: size * 0.7,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 150),
            width: size,
            height: size,
            decoration: BoxDecoration(
              color: color,
              shape: BoxShape.circle,
              border: Border.all(
                color: isSelected ? scheme.onSurface : Colors.transparent,
                width: 2.5,
              ),
            ),
            child: value == null
                ? Icon(Icons.auto_awesome, size: size / 2, color: scheme.onPrimary)
                : (isSelected ? Icon(Icons.check, size: size * 0.56, color: Colors.white) : null),
          ),
        ),
      );
    }

    return Wrap(
      spacing: 10,
      runSpacing: 10,
      children: [swatch(null), for (final c in kProfilePalette) swatch(c)],
    );
  }
}
