/// The card viewfinder: the live image cropped to fill a card-shaped frame.
library;

import 'package:flutter/widgets.dart';

/// The width over height of an ID-1 card (85.6mm by 53.98mm).
const double idCardAspectRatio = 1.586;

/// Fills the space it is given with [preview], cropping the overflow.
///
/// [previewSize] is the preview's real upright size, so the image is scaled
/// uniformly and never stretched. The camera still keeps the whole frame: this
/// only chooses which part of it she sees, and that part is always inside the
/// photograph that is taken.
class CoverFitViewfinder extends StatelessWidget {
  const CoverFitViewfinder({
    super.key,
    required this.preview,
    required this.previewSize,
  });

  final Widget preview;
  final Size previewSize;

  @override
  Widget build(BuildContext context) {
    return SizedBox.expand(
      child: FittedBox(
        fit: BoxFit.cover,
        clipBehavior: Clip.hardEdge,
        child: SizedBox(
          width: previewSize.width,
          height: previewSize.height,
          child: preview,
        ),
      ),
    );
  }
}
