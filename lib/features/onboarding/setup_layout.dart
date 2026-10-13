import 'package:flutter/material.dart';

/// Page frame of the setup wizard: scrolling content with 24 px gutters and
/// the actions pinned to the bottom (they ride above the keyboard, since the
/// Scaffold resizes for it).
class SetupLayout extends StatelessWidget {
  const SetupLayout({super.key, required this.content, required this.actions, this.top = 8});

  /// Scrolling page content.
  final List<Widget> content;

  /// Bottom actions (full-width buttons).
  final List<Widget> actions;

  /// Space above the content.
  final double top;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Expanded(
          child: SingleChildScrollView(
            keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
            padding: EdgeInsets.fromLTRB(24, top, 24, 24),
            child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: content),
          ),
        ),
        if (actions.isNotEmpty)
          Padding(
            padding: const EdgeInsets.fromLTRB(24, 8, 24, 16),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: actions,
            ),
          ),
      ],
    );
  }
}

/// Headline + supporting line at the top of a step.
class SetupHeading extends StatelessWidget {
  const SetupHeading({super.key, required this.title, this.body});

  final String title;
  final String? body;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: theme.textTheme.headlineMedium?.copyWith(
            fontWeight: FontWeight.w600,
            letterSpacing: -0.3,
            height: 1.2,
          ),
        ),
        if (body != null) ...[
          const SizedBox(height: 10),
          Text(
            body!,
            style: theme.textTheme.bodyLarge?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
              height: 1.45,
            ),
          ),
        ],
      ],
    );
  }
}

/// Tall, full-width button style of the wizard's main actions.
final ButtonStyle setupButtonStyle = ButtonStyle(
  minimumSize: const WidgetStatePropertyAll(Size.fromHeight(52)),
  shape: WidgetStatePropertyAll(RoundedRectangleBorder(borderRadius: BorderRadius.circular(26))),
);

/// Button content: a small spinner next to [label] while [busy].
class BusyLabel extends StatelessWidget {
  const BusyLabel({super.key, required this.busy, required this.label, this.busyLabel});

  final bool busy;
  final String label;
  final String? busyLabel;

  @override
  Widget build(BuildContext context) {
    if (!busy) return Text(label);
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        SizedBox.square(
          dimension: 18,
          child: CircularProgressIndicator(
            strokeWidth: 2,
            color: DefaultTextStyle.of(context).style.color,
          ),
        ),
        const SizedBox(width: 12),
        Flexible(child: Text(busyLabel ?? label, overflow: TextOverflow.ellipsis)),
      ],
    );
  }
}
