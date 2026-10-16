/// A card or block changing state without a hard swap: the old one fades out
/// as the new one fades in, and the space between them eases to its new size.
///
/// Give each state its own key. Instant under reduced motion.
library;

import 'package:flutter/widgets.dart';

import 'draw_on.dart';
import 'motion.dart';

class HandSwap extends StatelessWidget {
  const HandSwap({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    final d = handMotionOff(context) ? Duration.zero : HandTiming.medium;
    return AnimatedSize(
      duration: d,
      curve: HandTiming.standard,
      alignment: Alignment.topCenter,
      child: AnimatedSwitcher(
        duration: d,
        switchInCurve: HandTiming.standard,
        switchOutCurve: HandTiming.exit,
        // Passthrough, so a child stretched by its column stays stretched.
        layoutBuilder: (current, previous) => Stack(
          alignment: Alignment.topCenter,
          fit: StackFit.passthrough,
          children: [...previous, ?current],
        ),
        child: child,
      ),
    );
  }
}
