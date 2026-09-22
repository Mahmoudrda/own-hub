/// Tells a screen which screen it is.
///
/// Screens are built by the router, and a screen does not otherwise know its own
/// id -- it only knows its widgets. [ScreenScope] carries the id down so shared
/// layout ([AppScaffold]) can look up that screen's illustrations in one table
/// rather than every screen passing them by hand.
///
/// ## Why tests do not see it
///
/// Only the router wraps a screen in a [ScreenScope]. A widget test that pumps a
/// screen directly has no scope, so [of] returns null and no illustration is
/// drawn. That is deliberate: it keeps a change that touches 141 screens out of
/// 3,400 tests that are about something else. `navigation_smoke_test` goes
/// through the real router, so the illustrations are exercised there.
library;

import 'package:flutter/widgets.dart';

class ScreenScope extends InheritedWidget {
  const ScreenScope({super.key, required this.screenId, required super.child});

  final String screenId;

  /// The id of the screen being built, or null outside the router.
  static String? of(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<ScreenScope>()?.screenId;

  @override
  bool updateShouldNotify(ScreenScope old) => old.screenId != screenId;
}
