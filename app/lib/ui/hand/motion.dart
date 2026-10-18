/// The timings and curves every animation in the app draws from.
///
/// One short, one medium and one long, so a screen never invents its own.
/// Anything that moves still asks [handMotionOff] first.
library;

import 'package:flutter/animation.dart';

abstract final class HandTiming {
  /// A press, a tick, a small state change.
  static const Duration short = Duration(milliseconds: 150);

  /// A card or list changing state, a page element arriving.
  static const Duration medium = Duration(milliseconds: 220);

  /// A bar filling, a reveal, a page-level change.
  static const Duration long = Duration(milliseconds: 400);

  /// A press going down. The release is [pressOut].
  static const Duration pressIn = Duration(milliseconds: 90);

  /// A press coming back up.
  static const Duration pressOut = Duration(milliseconds: 180);

  /// A bar, ring or segment moving from its old value to the new one.
  static const Duration progress = Duration(milliseconds: 600);

  /// One sweep of the loading shimmer.
  static const Duration shimmer = Duration(milliseconds: 1400);

  /// One burst of paper confetti.
  static const Duration confetti = Duration(milliseconds: 900);

  /// Gap between one list row starting to arrive and the next.
  static const Duration staggerStep = Duration(milliseconds: 40);

  /// Rows beyond this many arrive with the last one rather than later.
  static const int staggerMax = 8;

  /// Things settling into place.
  static const Curve standard = Curves.easeOutCubic;

  /// Things leaving, or moving a long way and stopping.
  static const Curve emphasized = Cubic(0.2, 0.0, 0.0, 1.0);

  /// Things leaving the screen.
  static const Curve exit = Curves.easeInCubic;

  /// The press spring on buttons and tappable rows.
  static const SpringDescription spring = SpringDescription(
    mass: 1,
    stiffness: 400,
    damping: 28,
  );

  /// How small a pressed button or row gets.
  static const double pressScale = 0.97;
}
