/// A tick that draws on once: the small "that's done" beat that stands where
/// a character used to cheer. With motion off it is simply there.
library;

import 'package:flutter/material.dart';

import 'hand_marks.dart';
import 'spring_pop.dart';

class Moment extends StatelessWidget {
  const Moment({super.key, this.size = 48, this.delay = Duration.zero});

  final double size;
  final Duration delay;

  @override
  Widget build(BuildContext context) => ExcludeSemantics(
    child: SpringPop(
      delay: delay,
      child: HandTick(size: size, drawOn: true, delay: delay),
    ),
  );
}
