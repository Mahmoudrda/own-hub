/// The tour she takes before she has an account, as the rest of the app sees
/// it.
///
/// `C04` draws the real Home, Train, Eat, My cycle and Progress screens with a
/// sample week in them. Those screens were written for a woman who is signed
/// in: a control with no callback falls through `openScreen` to
/// [AppRouter.goTo], and a write goes to a repository. Both are closed here.
///
///  * **Navigation.** [DemoScope] sits over the sample screens, and
///    `AppRouter.goTo` asks for it first. Under it, every route a control
///    names opens the join sheet instead, so no screen behind the check can be
///    pushed from inside the tour, whatever a screen forgets to wire.
///  * **Writes.** The sample repositories refuse every write and leave their
///    state as it was. A write that has to hand back a result never completes
///    rather than failing: a failed future nobody awaits is an uncaught error,
///    and in a release build an uncaught error is a crash report, which is
///    exactly the kind of thing the tour must not send.
///
/// The exits (join, sign in, leave) are built by the router, above the scope,
/// so they are never caught by it.
library;

import 'package:flutter/widgets.dart';

/// What a sample repository answers a write with, when it has to answer.
class DemoWriteRefused implements Exception {
  const DemoWriteRefused();

  @override
  String toString() => 'DemoWriteRefused: the tour saves nothing';
}

/// Marks a subtree as the tour. See the library note.
class DemoScope extends InheritedWidget {
  const DemoScope({super.key, required this.requestJoin, required super.child});

  /// Raises "Join to make this yours" over the tour. Safe to call more than
  /// once in a frame: the host shows one sheet at a time.
  final void Function(BuildContext context) requestJoin;

  /// The tour this [context] is inside, or null outside it.
  ///
  /// Reads without registering a dependency: it is asked from tap handlers,
  /// not from `build`, and nothing has to redraw when it changes.
  static DemoScope? maybeOf(BuildContext context) =>
      context.getInheritedWidgetOfExactType<DemoScope>();

  @override
  bool updateShouldNotify(DemoScope oldWidget) =>
      requestJoin != oldWidget.requestJoin;
}
