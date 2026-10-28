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

  /// The logo drawing on at a cold start, from the first frame to gone.
  static const Duration splash = Duration(milliseconds: 700);

  /// One breath on the first-launch screen, in and out.
  static const Duration breath = Duration(seconds: 4);

  /// Gap between one list row starting to arrive and the next.
  static const Duration staggerStep = Duration(milliseconds: 40);

  /// Rows beyond this many arrive with the last one rather than later.
  static const int staggerMax = 8;

  // The guide's vocabulary (emotional redesign, 5.1), by name. D46's three
  // timings above stay as they are, and each sits beside its guide name:
  // [short] is [quick], [medium] is the card timing between [quick] and
  // [base], and [long] is the low end of [emphasis]. New motion uses these.

  /// Any tap's pressed state: 80 to 120 ms. Scale 0.97 or a tint.
  static const Duration press = Duration(milliseconds: 100);

  /// Toggles, chips and small reveals: 150 to 200 ms.
  static const Duration quick = short;

  /// Sheets, cards entering, page changes: 250 to 300 ms.
  static const Duration base = Duration(milliseconds: 260);

  /// The one hero moment of a screen: 400 to 500 ms.
  static const Duration emphasis = Duration(milliseconds: 450);

  /// A drawn tick, a count-up. Plays once: 700 to 1200 ms.
  static const Duration moment = Duration(milliseconds: 800);

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
