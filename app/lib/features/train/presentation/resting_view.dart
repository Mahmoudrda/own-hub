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
import 'train_widgets.dart';

class RestingView extends StatefulWidget {
  const RestingView({
    super.key,
    this.onClose,
    this.onPause,
    this.onReady,
    this.onAddThirtySeconds,
    this.onUndo,
    this.handle,
    this.remaining = const Duration(seconds: 38),
    this.total = const Duration(seconds: 60),
    this.autoStart = true,
    this.upNext,
    this.upNextPrescription,
  });

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

class _RestingViewState extends State<RestingView> {
  Timer? _tick;
  late Duration _remaining = widget.remaining;
  late Duration _total = widget.total;

  @override
  void initState() {
    super.initState();
    if (widget.autoStart) _start();
  }

  @override
  void didUpdateWidget(covariant RestingView oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.remaining != oldWidget.remaining) _remaining = widget.remaining;
    if (widget.total != oldWidget.total) _total = widget.total;
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
    _stop();
    super.dispose();
  }

  void _start() {
    _stop();
    if (_remaining <= Duration.zero) return;
    _tick = Timer.periodic(const Duration(seconds: 1), (_) {
      if (!mounted) return;
      final next = _remaining - const Duration(seconds: 1);
      if (next <= Duration.zero) {
        setState(() => _remaining = Duration.zero);
        _stop();
        // Rest is over and she was not asked to say so. This is the whole
        // promise of the screen.
        widget.onReady?.call();
        return;
      }
      setState(() => _remaining = next);
    });
  }

  void _stop() {
    _tick?.cancel();
    _tick = null;
  }

  void _addThirtySeconds() {
    setState(() {
      _remaining += const Duration(seconds: 30);
      // The ring reads remaining against total, so total grows with it.
      // Otherwise asking for longer would drive the fraction past full and the
      // ring would appear to run backwards.
      _total += const Duration(seconds: 30);
    });
    // She may have asked for longer after it already ran out.
    if (widget.autoStart && _tick == null) _start();
    widget.onAddThirtySeconds?.call();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppL10n.of(context);

    final elapsed = _total.inSeconds == 0
        ? 0.0
        : ((_total.inSeconds - _remaining.inSeconds) / _total.inSeconds).clamp(
            0.0,
            1.0,
          );

    return AppScaffold(
      // Deliberately a scrolling body, with fixed gaps around the ring rather
      // than Spacers. Spacers would centre it optically, but they only work
      // inside the non-scrolling scaffold, whose IntrinsicHeight cannot hold a
      // 210px ring plus the up-next card plus the footer on a short viewport —
      // it overflows, and an overflow here hides the rest timer she is watching.
      appBar: TrainTopBar(
        title: l10n.move2Of5,
        onClose: widget.onClose,
        actions: [
          IconButton(
            onPressed: widget.onPause,
            iconSize: 24,
            color: AppColors.onSurfaceVariant,
            icon: const Icon(Icons.pause),
          ),
        ],
      ),
      footer: [
        AppButton(l10n.imReadyNextSet, onPressed: widget.onReady),
        AppButton(
          l10n.add30Seconds,
          variant: AppButtonVariant.text,
          height: 44,
          fontSize: 15,
          // Bound to the handler, not to the callback. The router passes no
          // onAddThirtySeconds, so binding to it left the button disabled —
          // which is exactly why "Add 30 seconds" added nothing.
          onPressed: _addThirtySeconds,
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
          child: AppRingStat(
            fraction: elapsed,
            big: clockLabel(_remaining),
            small: l10n.rest,
            size: 210,
            thickness: 14,
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
                    Text(widget.upNextPrescription!, style: AppText.titleM),
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
