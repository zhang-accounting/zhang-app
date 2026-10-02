import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../l10n/l10n.dart';
import '../amount_expression.dart';

/// 4×4 calculator keypad (docs/design-research.md §2.5, phone layout):
///
/// ```
/// 1 2 3 ⌫
/// 4 5 6 +
/// 7 8 9 −
/// . 0 再记 保存/=
/// ```
class AmountKeypad extends StatelessWidget {
  const AmountKeypad({
    super.key,
    required this.onDigit,
    required this.onDot,
    required this.onOperator,
    required this.onBackspace,
    required this.onClear,
    required this.onSave,
    required this.onSaveAndAnother,
    required this.showEquals,
    required this.submitting,
    this.keyHeight = 52,
  });

  final ValueChanged<int> onDigit;
  final VoidCallback onDot;
  final ValueChanged<AmountOperator> onOperator;
  final VoidCallback onBackspace;
  final VoidCallback onClear;

  /// `null` disables the key.
  final VoidCallback? onSave;
  final VoidCallback? onSaveAndAnother;

  /// An unfinished expression: the save key evaluates it (`=`).
  final bool showEquals;
  final bool submitting;
  final double keyHeight;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final scheme = Theme.of(context).colorScheme;
    Widget digit(int d) => _Key(
      key: Key('add.key.$d'),
      label: '$d',
      semantics: '$d',
      onTap: () => onDigit(d),
    );
    Widget row(List<Widget> keys) => Row(
      children: [
        for (var i = 0; i < keys.length; i++) ...[
          if (i > 0) const SizedBox(width: 6),
          Expanded(child: SizedBox(height: keyHeight, child: keys[i])),
        ],
      ],
    );
    return Padding(
      padding: const EdgeInsets.fromLTRB(8, 4, 8, 8),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          row([
            digit(1),
            digit(2),
            digit(3),
            _Key(
              key: const Key('add.key.backspace'),
              icon: Icons.backspace_outlined,
              semantics: l10n.addBackspace,
              onTap: onBackspace,
              onLongPress: () {
                HapticFeedback.heavyImpact();
                onClear();
              },
              tonal: true,
            ),
          ]),
          const SizedBox(height: 6),
          row([
            digit(4),
            digit(5),
            digit(6),
            _Key(
              key: const Key('add.key.plus'),
              label: AmountOperator.plus.symbol,
              semantics: l10n.addPlus,
              onTap: () => onOperator(AmountOperator.plus),
              tonal: true,
            ),
          ]),
          const SizedBox(height: 6),
          row([
            digit(7),
            digit(8),
            digit(9),
            _Key(
              key: const Key('add.key.minus'),
              label: AmountOperator.minus.symbol,
              semantics: l10n.addMinus,
              onTap: () => onOperator(AmountOperator.minus),
              tonal: true,
            ),
          ]),
          const SizedBox(height: 6),
          row([
            _Key(key: const Key('add.key.dot'), label: '.', semantics: l10n.addDecimalPoint, onTap: onDot),
            digit(0),
            _Key(
              key: const Key('add.key.again'),
              label: l10n.addSaveAndAnother,
              semantics: l10n.addSaveAndAnotherLabel,
              onTap: onSaveAndAnother,
              tonal: true,
              small: true,
            ),
            _Key(
              key: const Key('add.key.save'),
              label: showEquals ? '=' : l10n.save,
              semantics: showEquals ? l10n.addEvaluate : l10n.save,
              onTap: onSave,
              background: scheme.primary,
              foreground: scheme.onPrimary,
              busy: submitting,
              small: !showEquals,
            ),
          ]),
        ],
      ),
    );
  }
}

class _Key extends StatelessWidget {
  const _Key({
    super.key,
    this.label,
    this.icon,
    required this.semantics,
    required this.onTap,
    this.onLongPress,
    this.tonal = false,
    this.small = false,
    this.busy = false,
    this.background,
    this.foreground,
  });

  final String? label;
  final IconData? icon;
  final String semantics;
  final VoidCallback? onTap;
  final VoidCallback? onLongPress;
  final bool tonal;
  final bool small;
  final bool busy;
  final Color? background;
  final Color? foreground;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final enabled = onTap != null && !busy;
    var bg = background ?? (tonal ? scheme.secondaryContainer : scheme.surfaceContainerHigh);
    var fg = foreground ?? (tonal ? scheme.onSecondaryContainer : scheme.onSurface);
    if (!enabled && !busy) {
      bg = scheme.onSurface.withValues(alpha: 0.08);
      fg = scheme.onSurface.withValues(alpha: 0.38);
    }
    final style = (small ? theme.textTheme.titleMedium : theme.textTheme.headlineSmall)?.copyWith(
      color: fg,
      fontFeatures: const [FontFeature.tabularFigures()],
    );
    final Widget child;
    if (busy) {
      child = SizedBox.square(dimension: 22, child: CircularProgressIndicator(strokeWidth: 2.5, color: fg));
    } else if (icon != null) {
      child = Icon(icon, color: fg);
    } else {
      child = Text(label ?? '', style: style, maxLines: 1, overflow: TextOverflow.fade, softWrap: false);
    }
    return Semantics(
      button: true,
      enabled: enabled,
      label: semantics,
      excludeSemantics: true,
      child: Material(
        color: bg,
        borderRadius: BorderRadius.circular(14),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: enabled
              ? () {
                  HapticFeedback.selectionClick();
                  onTap!();
                }
              : null,
          onLongPress: enabled ? onLongPress : null,
          child: Center(
            child: Padding(padding: const EdgeInsets.symmetric(horizontal: 4), child: FittedBox(child: child)),
          ),
        ),
      ),
    );
  }
}
