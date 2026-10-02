import 'package:flutter/material.dart';

/// Grey placeholder block used by skeleton loading states (design §2.10).
class SkeletonBox extends StatelessWidget {
  const SkeletonBox({super.key, this.width, this.height = 14, this.radius = 6});

  final double? width;
  final double height;
  final double radius;

  @override
  Widget build(BuildContext context) => Container(
    width: width,
    height: height,
    decoration: BoxDecoration(
      color: Theme.of(context).colorScheme.surfaceContainerHighest,
      borderRadius: BorderRadius.circular(radius),
    ),
  );
}

/// Skeleton of a [JournalItemTile]-shaped row.
class SkeletonTile extends StatelessWidget {
  const SkeletonTile({super.key});

  @override
  Widget build(BuildContext context) => const ListTile(
    leading: SkeletonBox(width: 40, height: 40, radius: 20),
    title: Align(alignment: Alignment.centerLeft, child: SkeletonBox(width: 140)),
    subtitle: Padding(
      padding: EdgeInsets.only(top: 6),
      child: Align(alignment: Alignment.centerLeft, child: SkeletonBox(width: 90, height: 10)),
    ),
    trailing: SkeletonBox(width: 64),
  );
}

/// A column of [count] skeleton rows (not scrollable on its own).
class SkeletonTileList extends StatelessWidget {
  const SkeletonTileList({super.key, this.count = 6});

  final int count;

  @override
  Widget build(BuildContext context) => Semantics(
    label: MaterialLocalizations.of(context).refreshIndicatorSemanticLabel,
    child: Column(children: [for (var i = 0; i < count; i++) const SkeletonTile()]),
  );
}
