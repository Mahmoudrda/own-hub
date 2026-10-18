/// The kitten on the page: shows her the next thing to do on the few screens
/// where that is not obvious, then sits still.
///
/// Where it may appear is a short list on purpose: the start of onboarding,
/// the tour, the face check, the waits and the end of onboarding, the first
/// day and the first week on Home, and the end of a session. One per screen. It never speaks, takes no tap and is not read out; the
/// words beside it carry the meaning.
library;

import 'dart:io' show Platform;

import 'package:flutter/foundation.dart' show kIsWeb;

import 'package:flutter/widgets.dart';

import '../../../app_state/kitten_setting.dart';
import '../draw_on.dart';
import 'kitten_painter.dart';

export 'kitten_painter.dart' show KittenPose, KittenProp, KittenTint;

/// Whether the kitten should hold still: the system asks for less motion,
/// the screen is not the one being looked at, or she turned it off.
bool kittenStill(BuildContext context) =>
    handMotionOff(context) ||
    !TickerMode.valuesOf(context).enabled ||
    !KittenSetting.instance.moves;

/// The kitten, doing [pose] once when it first appears and then breathing.
///
/// After its move it runs a slow idle loop: it breathes, floats up a few
/// pixels and blinks every few seconds (D50). The loop is a single repeating
/// controller, drawn by repainting alone with no rebuild per frame. It is off
/// whenever [kittenStill] says so, which holds a still kitten too, and it
/// pauses with the rest of the screen when its route is covered. The box
/// leaves room above the kitten for the float, so nothing paints outside it.
class Kitten extends StatefulWidget {
  const Kitten({
    super.key,
    required this.pose,
    this.size = 56,
    this.moment,
    this.replayKey,
    this.sessionBudget = false,
    this.tint = KittenTint.rose,
    this.holdStill = false,
    this.prop,
    this.blinkOnRevisit = false,
  });

  /// How many animated appearances a run of the app allows (D48). The first
  /// [sessionBudgetLimit] budgeted kittens to arrive move; every budgeted one
  /// after them holds still. One kitten keeps its place when its pose changes
  /// on the same screen, as C12 does while the check goes on. Named moments
  /// still play once each on top of this — the budget is the cap across them.
  static const int sessionBudgetLimit = 3;

  /// Counts against [sessionBudgetLimit].
  final bool sessionBudget;

  /// Drawn on its last frame and never moves, as beside "Checking your code".
  /// Takes nothing from the budget.
  final bool holdStill;

  /// The colour it is drawn in.
  final KittenTint tint;

  /// What it holds, if anything.
  final KittenProp? prop;

  /// A kitten that is otherwise still blinks once, only once, the second time
  /// this [moment] is opened in a run of the app. Needs a [moment].
  final bool blinkOnRevisit;

  final KittenPose pose;
  final double size;

  /// A name for this appearance. A named moment moves the first time it is
  /// seen in a run of the app and is simply there after that, so going back
  /// and forth between two screens does not make it perform again.
  final String? moment;

  /// Change to play the move again, as when the tour moves to the next stop.
  final Object? replayKey;

  /// Moments already played in this run of the app.
  static final Set<String> _played = {};
  static final Map<String, int> _opened = {};
  static int _budgetUsed = 0;

  @visibleForTesting
  static void resetPlayed() {
    _played.clear();
    _opened.clear();
    _budgetUsed = 0;
  }

  @visibleForTesting
  static int get budgetUsed => _budgetUsed;

  /// A widget test that pumps until nothing is scheduled would never settle
  /// beside a loop that never ends, so under `flutter test` the loop stays
  /// off unless a test turns it on here.
  @visibleForTesting
  static bool idleInTests = false;

  static bool get _loopAllowed =>
      idleInTests ||
      kIsWeb ||
      !Platform.environment.containsKey('FLUTTER_TEST');

  @override
  State<Kitten> createState() => _KittenState();
}

class _KittenState extends State<Kitten> with TickerProviderStateMixin {
  late final AnimationController _c = AnimationController(
    vsync: this,
    duration: kittenRunFor(widget.pose),
  );
  // Each kitten starts a different way round the loop, so a screen with
  // two never breathes in step.
  static int _made = 0;
  late final AnimationController _idle = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: kittenIdleMs),
  )..value = (_made++ * 0.618) % 1;
  bool _started = false;
  bool _blinking = false;

  /// This kitten already took one of the budgeted appearances.
  bool _holdsSlot = false;

  @override
  void initState() {
    super.initState();
    KittenSetting.instance.addListener(_settingChanged);
  }

  /// Turned off in Profile while it is on screen: hold still at once.
  void _settingChanged() {
    if (!KittenSetting.instance.moves && _c.isAnimating) _c.value = 1;
    if (mounted) _syncIdle();
  }

  /// Runs the loop when she allows motion, and puts the kitten back at rest
  /// when she does not.
  void _syncIdle() {
    final want = Kitten._loopAllowed && !kittenStill(context);
    if (want && !_idle.isAnimating) {
      _idle.repeat();
    } else if (!want && (_idle.isAnimating || _idle.value != 0)) {
      _idle.stop();
      _idle.value = 0;
    }
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_started) {
      _started = true;
      final moment = widget.moment;
      if (moment != null) {
        Kitten._opened.update(moment, (n) => n + 1, ifAbsent: () => 1);
      }
      _play();
    } else if (kittenStill(context) && _c.isAnimating) {
      // Reduce Motion switched on mid-move.
      _c.value = 1;
    }
    _syncIdle();
  }

  @override
  void didUpdateWidget(Kitten old) {
    super.didUpdateWidget(old);
    if (old.pose != widget.pose || old.replayKey != widget.replayKey) {
      _c.duration = kittenRunFor(widget.pose);
      _play();
    }
  }

  void _play() {
    final moment = widget.moment;
    _blinking = false;
    final seen = moment != null && Kitten._played.contains(moment);
    final overBudget =
        widget.sessionBudget &&
        !_holdsSlot &&
        Kitten._budgetUsed >= Kitten.sessionBudgetLimit;
    if (widget.holdStill || seen || overBudget || kittenStill(context)) {
      _c.value = 1;
      // The second time she is here, a still one blinks once.
      if (widget.blinkOnRevisit &&
          moment != null &&
          Kitten._opened[moment] == 2 &&
          !kittenStill(context)) {
        _blinking = true;
        _c.duration = const Duration(milliseconds: 700);
        _c.forward(from: 0);
      }
      return;
    }
    if (moment != null) Kitten._played.add(moment);
    if (widget.sessionBudget && !_holdsSlot) {
      _holdsSlot = true;
      Kitten._budgetUsed++;
    }
    _c.forward(from: 0);
  }

  @override
  void dispose() {
    KittenSetting.instance.removeListener(_settingChanged);
    _c.dispose();
    _idle.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final rtl = Directionality.maybeOf(context) == TextDirection.rtl;
    return ExcludeSemantics(
      child: RepaintBoundary(
        child: SizedBox(
          width: widget.size,
          height: widget.size + KittenIdle.headroomFor(widget.size),
          child: CustomPaint(
            painter: KittenPainter(
              progress: _c,
              pose: widget.pose,
              rtl: rtl,
              tint: widget.tint,
              prop: widget.prop,
              blinking: _blinking,
              idle: _idle,
              headroom: KittenIdle.headroomFor(widget.size),
            ),
          ),
        ),
      ),
    );
  }
}
