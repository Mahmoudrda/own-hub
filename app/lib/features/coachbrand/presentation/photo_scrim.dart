/// The darkening laid over a photograph so words can sit on it.
///
/// Flat, never a gradient. B04's floor is solved as one alpha over the region
/// under the text box, so a flat scrim is exactly the value that was checked —
/// wherever the words wrap to. A gradient would give the top line less than
/// the floor it was promised.
library;

import 'package:flutter/material.dart';

import '../../../ui/app_card.dart' show handLooseRadius, handTightRadius;
import '../../../ui/hand/hand.dart';

class PhotoScrim extends StatelessWidget {
  const PhotoScrim({
    super.key,
    required this.alpha,
    required this.height,
    required this.borderRadius,
    this.width,
  });

  /// How dark, 0–1. On a cover this is her `overlay`, already held at the
  /// floor by `BlockValidator`; the scrim draws it rather than deciding it.
  final double alpha;

  /// The photo's own size and radius, as passed to its `AppMedia`.
  ///
  /// `AppMedia` seeds its drawn edge from its size, so asking for the same
  /// seed lays the scrim on the photo's own outline — its loose corner
  /// included — instead of a rounded rectangle that misses it.
  final double? width;
  final double height;
  final double borderRadius;

  @override
  Widget build(BuildContext context) {
    return ExcludeSemantics(
      child: HandSurface(
        seed: handSeed(['media', width, height, null]),
        fill: Colors.black.withValues(alpha: alpha),
        radius: handTightRadius(borderRadius),
        looseCorner: handLooseRadius(borderRadius),
        child: const SizedBox.expand(),
      ),
    );
  }
}
