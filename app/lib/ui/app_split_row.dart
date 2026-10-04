/// A title on one side, a fact on the other — `row()` in `6-v2/src/kit.mjs` with
/// `justify: space-between`, which is how nearly every card in this product
/// heads itself.
///
/// It is a [Wrap] rather than a [Row] for one specific reason. At the largest
/// system text size, in Arabic, "This week, 1 of 3" beside "Two more and the
/// week counts." is wider than a phone, and a Row would throw a RenderFlex
/// overflow — which hides content rather than merely looking wrong. A Wrap puts
/// the second item on its own line instead, and each child is width-capped so a
/// long sentence wraps internally rather than running off the edge.
library;

import 'package:flutter/material.dart';

import 'hand/hand_seed_name.dart';

class AppSplitRow extends StatelessWidget implements HandSeedName {
  @override
  String get handSeedName => 'AppSplitRow';

  const AppSplitRow({
    super.key,
    required this.start,
    required this.end,
    this.spacing = 12,
    this.runSpacing = 4,
    this.crossAxisAlignment = WrapCrossAlignment.center,
  });

  final Widget start;
  final Widget end;
  final double spacing;
  final double runSpacing;
  final WrapCrossAlignment crossAxisAlignment;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final maxWidth = constraints.maxWidth;
        Widget capped(Widget child) => ConstrainedBox(
          constraints: BoxConstraints(maxWidth: maxWidth),
          child: child,
        );

        return Wrap(
          alignment: WrapAlignment.spaceBetween,
          crossAxisAlignment: crossAxisAlignment,
          spacing: spacing,
          runSpacing: runSpacing,
          children: [capped(start), capped(end)],
        );
      },
    );
  }
}
