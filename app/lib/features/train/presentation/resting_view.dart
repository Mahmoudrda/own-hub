/// R09 — Resting.
///
/// Matches `6-v2/src/screens-train.mjs` → `R09`. **Zero taps required.** The
/// timer starts itself, ends itself, and if she puts the phone down nothing is
/// waiting for her.
///
/// The bar at the top names the same numbers the button on R07 named, with Undo
/// inside it for five seconds. That is §2 rule 9 in its visible form: the set is
/// already hers, and taking it back is one tap rather than a question she had to
/// answer before it counted.
///
/// **Undo here reaches nothing.** The write is held by [LogCommandBus] for the
/// duration of the window, so undoing discards a local draft — there is no
/// request to cancel and nothing queued to resurface when she reconnects. That is
/// the whole reason the window sits ahead of the write rather than after it.
///
/// The next set is stated before she needs it, so the following tap needs no
/// reading.
///
/// # The clock was a picture of a clock
///
/// This screen promised "the timer starts itself, ends itself" in its own first
/// paragraph while being a `StatelessWidget` holding a `const Duration(seconds:
/// 38)`. Nothing ticked. "Add 30 seconds" added nothing — the router passes no
/// `onAddThirtySeconds`, so the button was inert — and rest never ended on its
/// own, so the one screen designed to need no taps required one. Every test
/// passed throughout, because all of them asserted the painted value.
///
/// [autoStart] exists because of how that gets tested. A live one-second tick
/// schedules a frame every second, so `pumpAndSettle()` on a running clock keeps
/// pumping until it times out. The layout tests set it false and assert the
/// static frame; the countdown tests leave it true and drive the clock with
/// explicit `pump(duration)` calls.
///
/// # And then it followed her out of the screen
///
/// R09 is *pushed under* R07 rather than replaced by it, so tapping "I'm ready"
/// leaves this screen mounted with its clock still running. Up to thirty-eight
/// seconds later the clock reached zero and called [onReady] anyway — which
/// pushes the workout player **over whatever she is doing now**. It was caught
/// landing on the cycle check-in and in the middle of `Y02`, which a woman who
/// has never used a fitness app reads as the app breaking.
///
/// So the clock ends itself, but it only ever navigates *from the top*: a tick
/// that reaches zero behind another screen stops and says nothing. The tap path
/// is untouched, because a tap can only come from the screen she is looking at.
library;

import 'dart:async';

import 'package:flutter/material.dart';

import '../../../domain/logging/log_command_bus.dart';
import '../../../l10n/app_l10n.dart';
import '../../../theme/app_tokens.dart';
import '../../../ui/app_button.dart';
import '../../../ui/app_card.dart';
import '../../../ui/app_ring_stat.dart';
import '../../../ui/app_scaffold.dart';
import '../../../ui/app_undo_bar.dart';
import '../../../ui/hand/hand.dart';
import '../domain/clock_label.dart';
import '../domain/weight_label.dart';
import 'set_labels.dart';
import 'train_widgets.dart';

class RestingView extends StatefulWidget {
  const RestingView({
    super.key,
    this.onClose,
    this.onPause,
    this.onReady,
    this.onAddThirtySeconds,
    this.onUndo,
    this.onBackgrounded,
    this.onAlertCancel,
    this.clock,
    this.handle,
    this.remaining = const Duration(seconds: 38),
    this.total = const Duration(seconds: 60),
    this.autoStart = true,
    this.upNext,
    this.upNextPrescription,
    this.moveNumber,
    this.moveCount,
    this.sets,
  });

  /// Sets of today's session behind her, for the bar under the title.
  final ({int done, int total})? sets;

  /// Which move of how many, for the bar at the top.
  ///
  /// Both null renders no count rather than a fixed one. The bar carried
  /// `move2Of5` — "Move 2 of 5" — over the first move of a four-move session.
  final int? moveNumber;
  final int? moveCount;

  final VoidCallback? onClose;
  final VoidCallback? onPause;

  /// Back to R07 for the next set.
  ///
  /// Called by her tap **and** by the clock reaching zero, because "ends itself"
  /// has to mean something.
  final VoidCallback? onReady;

  /// Told that she asked for longer. The extra thirty seconds are applied here
  /// regardless — this is a notification, not a permission.
  final VoidCallback? onAddThirtySeconds;

  /// Runs only when the undo actually landed inside the window.
  final VoidCallback? onUndo;

  /// The app went to the background with the clock running. Told when the
  /// rest will be over, so one "Rest is over" can be left for her.
  final ValueChanged<DateTime>? onBackgrounded;

  /// That alert is no longer wanted: she is back, skipped, asked for longer,
  /// or left.
  final VoidCallback? onAlertCancel;

  /// The wall clock. A phone's timers stop when its screen is off, so the rest
  /// is measured against a deadline on this and not by counting ticks while
  /// the app is away.
  final DateTime Function()? clock;

  /// The log made on R07. Null once the window has closed, at which point the
  /// bar states what was saved without offering an action that would do nothing.
  final LogHandle? handle;

  /// Where the clock starts.
  final Duration remaining;
  final Duration total;

  /// Whether the clock runs. See the note at the top of this file.
  final bool autoStart;

  /// The move and set she goes back to — "Goblet squat, set 3". Null renders no
  /// "Up next" card at all.
  final String? upNext;

  /// What that next set asks for — "12 × 10". Null renders the card without it.
  final String? upNextPrescription;

  @override
  State<RestingView> createState() => _RestingViewState();
}

class _RestingViewState extends State<RestingView> with WidgetsBindingObserver {
  Timer? _tick;

  /// When the rest ends, held only while the app is in the background.
  DateTime? _deadline;

  /// She moved on (tapped through, or it ran out): nothing more to announce.
  bool _ended = false;

  DateTime _now() => (widget.clock ?? DateTime.now)();

  /// The clock, held where only the ring listens to it. A tick used to call
  /// `setState` on the whole screen every second, rebuilding the app bar, the
  /// footer and the up-next card to change one number.
  late final ValueNotifier<({Duration remaining, Duration total})> _clock =
      ValueNotifier((remaining: widget.remaining, total: widget.total));
  bool _paused = false;

  Duration get _remaining => _clock.value.remaining;
  Duration get _total => _clock.value.total;
  set _remaining(Duration value) =>
      _clock.value = (remaining: value, total: _total);

  void _togglePause() {
    setState(() => _paused = !_paused);
    if (_paused) {
      _stop();
    } else if (widget.autoStart) {
      _start();
    }
    widget.onPause?.call();
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    if (widget.autoStart) _start();
  }

  @override
  void didUpdateWidget(covariant RestingView oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.remaining != oldWidget.remaining ||
        widget.total != oldWidget.total) {
      _clock.value = (remaining: widget.remaining, total: widget.total);
    }
    if (widget.autoStart != oldWidget.autoStart) {
      if (widget.autoStart) {
        _start();
      } else {
        _stop();
      }
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    widget.onAlertCancel?.call();
    _stop();
    _clock.dispose();
    super.dispose();
  }

  /// True while this screen is the one she is actually looking at.
  ///
  /// `mounted` is not enough: a route pushed over this one leaves it mounted,
  /// so the clock kept running underneath and then navigated on top of
  /// whatever had replaced it. `isCurrent` is false for exactly that case.
  /// Defaults to true when there is no route at all, which is how the widget
  /// tests host it.
  bool get _isOnTop => ModalRoute.of(context)?.isCurrent ?? true;

  void _start() {
    _stop();
    if (_remaining <= Duration.zero) return;
    _tick = Timer.periodic(const Duration(seconds: 1), (_) {
      if (!mounted) return;
      final next = _remaining - const Duration(seconds: 1);
      if (next <= Duration.zero) {
        _remaining = Duration.zero;
        _stop();
        // Rest is over and she was not asked to say so. This is the whole
        // promise of the screen — but only when this screen is still the one
        // in front of her. Behind another route, the rest simply ends.
        if (!_isOnTop || _ended) return;
        _ended = true;
        widget.onReady?.call();
        return;
      }
      _remaining = next;
    });
  }

  void _stop() {
    _tick?.cancel();
    _tick = null;
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    switch (state) {
      case AppLifecycleState.hidden:
      case AppLifecycleState.paused:
        _leftForeground();
      case AppLifecycleState.resumed:
        _backInForeground();
      case AppLifecycleState.inactive:
      case AppLifecycleState.detached:
        break;
    }
  }

  /// Only a rest that is actually counting down in front of her is announced:
  /// not one she paused, one she has tapped past, or one behind another
  /// screen.
  void _leftForeground() {
    if (_deadline != null || _ended || _paused || _tick == null) return;
    if (!_isOnTop) return;
    final deadline = _now().add(_remaining);
    _deadline = deadline;
    _stop();
    widget.onBackgrounded?.call(deadline);
  }

  void _backInForeground() {
    final deadline = _deadline;
    if (deadline == null) return;
    _deadline = null;
    widget.onAlertCancel?.call();
    final left = deadline.difference(_now());
    if (left > Duration.zero) {
      // Whole seconds, rounded up, so the ring never reads 0:00 with rest left.
      _remaining = Duration(seconds: (left.inMilliseconds / 1000).ceil());
      if (widget.autoStart && !_paused) _start();
      return;
    }
    _remaining = Duration.zero;
    if (_isOnTop && !_ended) {
      _ended = true;
      widget.onReady?.call();
    }
  }

  void _ready() {
    _ended = true;
    widget.onAlertCancel?.call();
    widget.onReady?.call();
  }

  void _addThirtySeconds() {
    // The ring reads remaining against total, so total grows with it.
    // Otherwise asking for longer would drive the fraction past full and the
    // ring would appear to run backwards.
    _clock.value = (
      remaining: _remaining + const Duration(seconds: 30),
      total: _total + const Duration(seconds: 30),
    );
    // She may have asked for longer after it already ran out.
    _ended = false;
    widget.onAlertCancel?.call();
    if (widget.autoStart && !_paused && _tick == null) _start();
    widget.onAddThirtySeconds?.call();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppL10n.of(context);

    return AppScaffold(
      // Deliberately a scrolling body, with fixed gaps around the ring rather
      // than Spacers. Spacers would centre it optically, but they only work
      // inside the non-scrolling scaffold, whose IntrinsicHeight cannot hold a
      // 210px ring plus the up-next card plus the footer on a short viewport —
      // it overflows, and an overflow here hides the rest timer she is watching.
      appBar: TrainTopBar(
        title: moveTitle(l10n, widget.moveNumber, widget.moveCount),
        onClose: widget.onClose,
        sets: widget.sets,
        actions: [
          // Her rest, held. The clock stops where it is and starts again
          // from there; the icon said pause for every woman and paused
          // nothing.
          IconButton(
            onPressed: _togglePause,
            iconSize: 24,
            color: AppColors.onSurfaceVariant,
            tooltip: _paused ? l10n.resume : l10n.pause,
            icon: Icon(_paused ? Icons.play_arrow : Icons.pause),
          ),
        ],
      ),
      footer: [
        AppButton(
          l10n.imReadyNextSet,
          onPressed: widget.onReady == null ? null : _ready,
        ),
        // Small and secondary: the tooltip is its label for a screen reader.
        // Bound to the handler, not to the callback. The router passes no
        // onAddThirtySeconds, so binding to it left it disabled, which is
        // exactly why "Add 30 seconds" added nothing.
        Center(
          child: IconButton(
            key: const ValueKey('r09-add-30'),
            onPressed: _addThirtySeconds,
            tooltip: l10n.add30Seconds,
            iconSize: 24,
            color: AppColors.onSurfaceVariant,
            icon: const Icon(Icons.more_time),
          ),
        ),
      ],
      children: [
        AppUndoBar(
          // The handle is the truth: R07 and R08 both pass one, and it already
          // names her numbers. The fallback is the standalone-preview state of
          // this screen, so it reproduces the mockup's set rather than invent
          // a claim about a set that was never logged.
          message:
              widget.handle?.describe ??
              l10n.setSetnumberSavedWeightKgReps(2, weightLabel(12), 10),
          undoLabel: l10n.undo,
          onUndo: widget.handle == null
              ? null
              : () {
                  // False when she was a moment late. Nothing is rolled back,
                  // because by then the write has already been made.
                  if (widget.handle!.undo()) widget.onUndo?.call();
                },
        ),
        const SizedBox(height: 24),
        Center(
          // The only part of the screen that changes each second.
          child: ValueListenableBuilder<({Duration remaining, Duration total})>(
            valueListenable: _clock,
            builder: (context, clock, _) {
              // The arc is the rest she has left: full as it starts, giving
              // way second by second. A second's step is eased into a glide,
              // and with motion off it simply moves.
              final left = clock.total.inSeconds == 0
                  ? 0.0
                  : (clock.remaining.inSeconds / clock.total.inSeconds).clamp(
                      0.0,
                      1.0,
                    );
              return TweenAnimationBuilder<double>(
                tween: Tween<double>(end: left),
                duration: handMotionOff(context)
                    ? Duration.zero
                    : const Duration(seconds: 1),
                curve: Curves.linear,
                builder: (context, value, _) => AppRingStat(
                  fraction: value,
                  big: clockLabel(clock.remaining),
                  small: l10n.rest,
                  size: 210,
                  thickness: 14,
                ),
              );
            },
          ),
        ),
        const SizedBox(height: 4),
        Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 300),
            child: Text(
              l10n.catchYourBreathThisStartsAndStops,
              textAlign: TextAlign.center,
              style: AppText.body.copyWith(color: AppColors.onSurfaceVariant),
            ),
          ),
        ),
        const SizedBox(height: 24),
        // What is next, when the caller has said.
        //
        // This card was two fixed strings: `gobletSquatSet3` — "Goblet squat,
        // set 3" — and `n1210` beside it. R09 is raised over whatever set she
        // just logged and is told nothing about the next one, so it named the
        // prototype's move, the prototype's set number and the prototype's
        // prescription to everyone, on the screen she looks at while she gets
        // her breath back. A caller that knows what is next says so; nothing
        // invents it.
        if (widget.upNext != null) ...[
          AppCard(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            gap: 6,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Pencilled above the move, the way she would note
                        // it in the margin. The one hand on this screen: the
                        // clock and the move itself stay in print.
                        HandNote(
                          l10n.upNext,
                          size: 15,
                          color: AppColors.onSurfaceVariant,
                        ),
                        const SizedBox(height: 4),
                        Text(widget.upNext!, style: AppText.titleM),
                      ],
                    ),
                  ),
                  if (widget.upNextPrescription != null) ...[
                    const SizedBox(width: 12),
                    // Flexible: a prescription such as "3 × 8 each side" is
                    // longer than the card has room for beside a long move
                    // name, and it wraps rather than running off the edge.
                    Flexible(
                      child: Text(
                        widget.upNextPrescription!,
                        textAlign: TextAlign.end,
                        style: AppText.titleM,
                      ),
                    ),
                  ],
                ],
              ),
            ],
          ),
        ],
      ],
    );
  }
}
