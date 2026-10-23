/// The route transition: a fade through on Android, or none under reduced
/// motion. iPhone keeps its own slide, because that slide carries the edge
/// swipe back that every iPhone app answers to.
library;

import 'package:animations/animations.dart';
import 'package:flutter/cupertino.dart' show CupertinoPageTransitionsBuilder;
import 'package:flutter/material.dart';

import 'draw_on.dart';

/// [FadeThroughPageTransitionsBuilder], read per route so the system's
/// reduced-motion setting is honoured even if it changes while the app runs.
class HandPageTransitionsBuilder extends PageTransitionsBuilder {
  const HandPageTransitionsBuilder();

  static const _fade = FadeThroughPageTransitionsBuilder();

  @override
  Widget buildTransitions<T>(
    PageRoute<T> route,
    BuildContext context,
    Animation<double> animation,
    Animation<double> secondaryAnimation,
    Widget child,
  ) {
    if (handMotionOff(context)) return child;
    return _fade.buildTransitions<T>(
      route,
      context,
      animation,
      secondaryAnimation,
      child,
    );
  }
}

const PageTransitionsTheme handPageTransitions = PageTransitionsTheme(
  builders: {
    TargetPlatform.android: HandPageTransitionsBuilder(),
    TargetPlatform.iOS: CupertinoPageTransitionsBuilder(),
    TargetPlatform.macOS: HandPageTransitionsBuilder(),
    TargetPlatform.linux: HandPageTransitionsBuilder(),
    TargetPlatform.windows: HandPageTransitionsBuilder(),
    TargetPlatform.fuchsia: HandPageTransitionsBuilder(),
  },
);
