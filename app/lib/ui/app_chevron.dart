/// The mark at the end of a row that says "there is more this way".
///
/// It points **forward**, which is to the right while she is reading English
/// and to the left while she is reading Arabic. Arabic is the primary language
/// of this product, so a chevron that points the wrong way there is wrong on
/// every list row in the app.
///
/// `DESIGN.md`: *"Do pass Directionality to every directional painter so
/// underlines start from the right, arrows point forward and loose corners turn
/// round in Arabic."* This is the same rule applied to the one directional icon
/// the product uses everywhere.
///
/// ## Why this reads the direction itself
///
/// `Icons.chevron_right` carries `matchTextDirection: true`, so the framework
/// already flips the glyph under an RTL [Directionality] — every bare
/// `Icon(Icons.chevron_right)` in this codebase does point the right way today,
/// and the Arabic build was checked. What it does **not** do is say so
/// anywhere: the correctness lives in a flag on a Material constant, three
/// packages away, that no test in this repository asserts and that has been
/// added to and removed from individual icons across Flutter releases. One
/// upstream edit and every list row in Arabic quietly turns round.
///
/// So the direction is resolved here, from the ambient [Directionality], and
/// the glyph is chosen rather than inherited — [Icon.textDirection] is pinned
/// to [TextDirection.ltr] so the framework does not mirror a glyph this widget
/// has already picked. Two mirrors in a row would cancel out, which is the trap
/// waiting for anyone who "fixes" a bare chevron by swapping in
/// `Icons.chevron_left` under RTL and leaves the framework to flip it again.
///
/// The result is identical on screen and provable in a test:
/// `test/ui/app_chevron_test.dart` pins left under RTL, right under LTR, and
/// sweeps the source for bare chevrons that went round it.
library;

import 'package:flutter/material.dart';

import '../theme/app_tokens.dart';

class AppChevron extends StatelessWidget {
  const AppChevron({
    super.key,
    this.size = 22,
    this.color = AppColors.onSurfaceVariant,
  });

  final double size;
  final Color color;

  /// The glyph that points forward in [direction].
  ///
  /// Exposed so a test can state the expectation in one place, and so a caller
  /// that needs the raw [IconData] (a painter, a semantics-free decoration)
  /// gets it from here rather than guessing.
  static IconData forward(TextDirection direction) =>
      direction == TextDirection.rtl ? Icons.chevron_left : Icons.chevron_right;

  @override
  Widget build(BuildContext context) {
    return Icon(
      forward(Directionality.of(context)),
      // The glyph above is already the one that points forward. Left to the
      // ambient direction, the framework would mirror it a second time and
      // send it back where it started.
      textDirection: TextDirection.ltr,
      size: size,
      color: color,
    );
  }
}
