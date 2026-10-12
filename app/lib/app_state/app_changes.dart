/// One signal for "something shared changed", and the one widget that listens.
///
/// The router draws most screens from shared, in-memory state that it reads
/// at build time. Without a signal, a screen underneath another keeps what it
/// drew when it was opened: log a check-in on Y04, go back, and Y03 still
/// shows the morning without it. Every routed screen listens to this and
/// redraws when it fires, so "back" always lands on the truth.
///
/// Call [AppChanges.bump] after changing shared state — from a callback,
/// never while a widget is building.
library;

import 'package:flutter/material.dart';
// `SchedulerPhase` — a rebuild asked for during the build phase has to wait a
// frame. See `_coverChanged`.
import 'package:flutter/scheduler.dart';

class AppChanges extends ChangeNotifier {
  AppChanges._();

  static final AppChanges instance = AppChanges._();

  /// Tell every open screen that shared state has changed.
  static void bump() => instance.notifyListeners();
}

/// Draws [builder] again on every [AppChanges.bump] — but only while the route
/// it sits in is one she can see.
///
/// ## Why this is not a `ListenableBuilder`
///
/// It was one, in `app_router.dart`, around every routed screen. A bump then
/// rebuilt and re-laid-out **every screen in the navigator stack**, because a
/// covered route is still mounted and a dirty element is still rebuilt whether
/// or not anything of it reaches the glass. There are 102 bump call sites, and
/// `AppScaffold` is a `SingleChildScrollView` around an eager `Column`, so each
/// of those screens builds all of its rows and not only the visible ones.
///
/// Measured at 375x667 in Arabic, median of twenty bumps
/// (`test/qa/round5/r5_05_rebuild_cost_test.dart`), on the stack Home → R01 →
/// R02 → E01 → E07 → P01:
///
/// | stack depth | `ListenableBuilder` | this |
/// |---|---|---|
/// | 1 | 6.3 ms | 4.7 ms |
/// | 2 (+R01) | 11.2 ms | 6.6 ms |
/// | 3 (+R02) | 7.6 ms | 1.6 ms |
/// | 4 (+E01) | 10.2 ms | 4.1 ms |
/// | 5 (+E07) | 8.4 ms | 2.2 ms |
/// | 6 (+P01) | 11.6 ms | 4.1 ms |
///
/// The curve stops climbing with the stack and becomes the cost of whichever
/// screen is on top — R02 and E07 are cheap screens and now measure as cheap
/// screens, which is the shape the fan-out was hiding. On a budget Android,
/// four to six times slower, six screens deep is roughly 70 ms before and
/// roughly 25 ms after.
///
/// ## "Visible" is one question, asked of the route itself
///
/// A route's `secondaryAnimation` is driven by the route pushed on top of it,
/// and reaches [AnimationStatus.completed] only once that route fully covers
/// it. That is the whole test: `completed` means she is looking at something
/// else, anything else means she can see at least part of this.
///
/// Two consequences, both of them the behaviour we want rather than accidents:
///
///   * **A dialog or a sheet does not count as covering.** `MaterialPageRoute`
///     refuses to hand its train to a `PopupRoute`, so the secondary animation
///     stays dismissed and the screen behind an open sheet keeps redrawing —
///     which it must, because half of it is on screen underneath.
///   * **Catching up starts when the pop starts, not when it ends.** The status
///     leaves `completed` on the first frame of the back gesture, so a screen
///     that missed a bump is rebuilt while it is still sliding into view rather
///     than snapping a frame after it lands.
///
/// Missing a bump is recorded rather than ignored, so nothing is lost: a screen
/// that was covered when her state changed is rebuilt the moment it is
/// uncovered. The contract `app_router.dart` used to state — "a screen
/// underneath another is current again the moment she comes back to it" — is
/// exactly the same contract. Only the arithmetic changed.
///
/// With no route above it at all — a widget test that builds a screen directly,
/// or anything outside a [Navigator] — there is nothing to be covered by, and
/// it behaves as the `ListenableBuilder` did.
class RedrawOnChange extends StatefulWidget {
  const RedrawOnChange({super.key, required this.builder});

  /// The screen. Called on every build, as a `ListenableBuilder`'s builder was.
  final WidgetBuilder builder;

  @override
  State<RedrawOnChange> createState() => _RedrawOnChangeState();
}

class _RedrawOnChangeState extends State<RedrawOnChange> {
  /// How far the route above this one has covered it, or null outside a route.
  ///
  /// Held rather than read from `ModalRoute.of` at bump time because a listener
  /// has to be attached to it, and because `AppChanges` can fire while the
  /// element is being unmounted, when looking up an inherited widget is not
  /// allowed.
  Animation<double>? _covered;

  /// A bump that arrived while something was covering this screen.
  bool _missed = false;

  @override
  void initState() {
    super.initState();
    AppChanges.instance.addListener(_changed);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // `secondaryAnimation` is a proxy the route keeps for its whole life and
    // re-points as the stack above it changes, so this is attached once and the
    // listener sees every covering and uncovering, including the ones that
    // happen with no animation at all.
    final next = ModalRoute.of(context)?.secondaryAnimation;
    if (identical(next, _covered)) return;
    _covered?.removeStatusListener(_coverChanged);
    _covered = next;
    _covered?.addStatusListener(_coverChanged);
  }

  @override
  void dispose() {
    AppChanges.instance.removeListener(_changed);
    _covered?.removeStatusListener(_coverChanged);
    super.dispose();
  }

  /// False only while another full-screen route sits completely over this one.
  bool get _isVisible => _covered?.status != AnimationStatus.completed;

  void _changed() {
    if (!mounted) return;
    if (_isVisible) {
      setState(() {});
    } else {
      _missed = true;
    }
  }

  void _coverChanged(AnimationStatus status) {
    if (!_missed || !mounted || !_isVisible) return;
    _missed = false;
    // The navigator re-points the proxy from inside its own build when a route
    // is removed without an animation, and marking an element dirty during the
    // build phase is an error. The frame after is early enough: the screen is
    // still arriving, and nothing of hers has been drawn stale yet.
    if (SchedulerBinding.instance.schedulerPhase ==
        SchedulerPhase.persistentCallbacks) {
      SchedulerBinding.instance.addPostFrameCallback((_) {
        if (mounted) setState(() {});
      });
      return;
    }
    setState(() {});
  }

  @override
  Widget build(BuildContext context) => widget.builder(context);
}
