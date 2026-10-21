/// R06 — Follow-along move.
///
/// Matches `6-v2/src/screens-train.mjs` → `R06`. **Zero taps to log.** A timed
/// follow-along move logs itself as it finishes: the timer *is* the log, and the
/// "logs itself" pill says so plainly, because silence after a set is otherwise
/// indistinguishable from a missed one.
///
/// This is the one dark screen in the group. It inverts because a video fills it
/// and a pink surface around moving footage is noise — which is also why the ring
/// and the buttons take explicit light colours here rather than the defaults.
///
/// **A hold move counts down here.** Given [holdSeconds], the screen owns one
/// clock: the ring and the figure are read from it, Pause stops it and Resume
/// carries on from where it stopped, and when it reaches zero the set is logged
/// through [LogCommandBus] with the same five-second undo as every other log.
/// The clip, when the library has one, plays beside the clock and never keeps
/// time. Given no [holdSeconds] the screen only draws [remaining] of [total],
/// which is how the design is previewed. Under reduced motion the ring stays
/// as it is and only the clock text changes.
library;

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';

import '../../../app_state/haptics.dart';
import '../../../domain/logging/log_command_bus.dart';
import '../../../domain/training/prescribed_set.dart';
import '../../../l10n/app_l10n.dart';
import '../../../theme/app_tokens.dart';
import '../../../ui/app_undo_bar.dart';
import '../../../ui/app_pill.dart';
import '../../../ui/app_ring_stat.dart';
import '../../../ui/app_white_button.dart';
import '../../../ui/hand/hand.dart';
import '../../../ui/screen_art_strip.dart';
import '../data/exercise_media_store.dart';
import '../domain/clock_label.dart';
import '../domain/exercise_library.dart';
import '../domain/train_repository.dart';
import 'exercise_clip_frame.dart';
import 'exercise_clip_player.dart';
import 'exercise_labels.dart';
import 'set_labels.dart';
import 'session_notice.dart';

/// White at 16% — the prototype's overlay tint on the inverted surface.
const Color _onDarkSoft = Color(0x29FFFFFF);
const Color _onDarkTrack = Color(0x2EFFFFFF);
const Color _onDark = Color(0xFFFFFFFF);
const Color _onDarkMuted = Color(0xB3FFFFFF);

/// White at 45%, for a drawn frame. A thin hand line needs more than the
/// track's 18% to read against the dark.
const Color _onDarkLine = Color(0x73FFFFFF);

class FollowAlongView extends StatefulWidget {
  const FollowAlongView({
    super.key,
    this.onPause,
    this.onSkip,
    this.moveName,
    this.positionLabel,
    this.remaining = const Duration(seconds: 24),
    this.total = const Duration(seconds: 40),
    this.bus,
    this.holdSeconds,
    this.set,
    this.repository,
    this.sessionId = 'session',
    this.onSetLogged,
    this.onAttach,
    this.onDetach,
    this.clip,
    this.media = const NoExerciseMedia(),
    this.players,
    this.notice,
  });

  /// A swap or a skip that brought her here, with its Undo, in the page.
  final SessionNotice? notice;

  /// Told when she pauses. The clock stops here either way.
  final VoidCallback? onPause;

  /// Skipping moves on without logging. A skipped set is not a logged set, and
  /// it is not a failure either.
  final VoidCallback? onSkip;

  final String? moveName;

  /// "Move 3 of 5".
  final String? positionLabel;

  /// What is drawn when there is no [holdSeconds]: a preview of the design.
  final Duration remaining;
  final Duration total;

  /// Every log in this product goes through the bus. Held here so the screen
  /// that logs *without a tap* uses the same five-second undo as the one that
  /// logs with one — there is no second logging path.
  final LogCommandBus? bus;

  /// The hold she is about to do, in seconds. Null draws [remaining] of
  /// [total] and runs no clock.
  final int? holdSeconds;

  /// The prescribed set the hold belongs to; what is logged when time is up.
  final PrescribedSet? set;

  final TrainRepository? repository;
  final String sessionId;

  /// The set was logged by the clock running out.
  final ValueChanged<LogHandle>? onSetLogged;

  /// Told when this screen opens and closes, so the session's one log bus is
  /// kept while it is on screen.
  final VoidCallback? onAttach;
  final VoidCallback? onDetach;

  /// The library's row for the move: its clip plays above the clock.
  final LibraryExercise? clip;
  final ExerciseMediaStore media;

  /// Makes the player. Null draws the poster alone, as tests do.
  final ExerciseClipPlayerFactory? players;

  @override
  State<FollowAlongView> createState() => _FollowAlongViewState();
}

class _FollowAlongViewState extends State<FollowAlongView>
    with SingleTickerProviderStateMixin {
  late final Ticker _ticker = createTicker(_onTick);
  TrainRepository? _fallbackRepository;
  LogCommandBus? _fallbackBus;

  /// Time counted before the current run of the ticker began.
  Duration _banked = Duration.zero;
  Duration _elapsed = Duration.zero;
  bool _paused = false;
  bool _logged = false;

  bool get _live => widget.holdSeconds != null && widget.holdSeconds! > 0;
  Duration get _hold => Duration(seconds: widget.holdSeconds ?? 0);

  TrainRepository get _repository =>
      widget.repository ?? (_fallbackRepository ??= InMemoryTrainRepository());

  LogCommandBus get _bus => widget.bus ?? (_fallbackBus ??= LogCommandBus());

  @override
  void initState() {
    super.initState();
    widget.onAttach?.call();
    if (_live) _ticker.start();
  }

  @override
  void dispose() {
    _ticker.dispose();
    _fallbackBus?.dispose();
    widget.onDetach?.call();
    super.dispose();
  }

  void _onTick(Duration run) {
    final elapsed = _banked + run;
    if (elapsed >= _hold) {
      _ticker.stop();
      setState(() => _elapsed = _hold);
      _finish();
      return;
    }
    // Reduced motion: the ring is still, so a frame is only worth drawing
    // when the clock text changes.
    if (handMotionOff(context) && elapsed.inSeconds == _elapsed.inSeconds) {
      _elapsed = elapsed;
      return;
    }
    setState(() => _elapsed = elapsed);
  }

  void _togglePause() {
    if (_live && !_logged) {
      if (_paused) {
        _ticker.start();
      } else {
        _banked = _elapsed;
        _ticker.stop();
      }
    }
    setState(() => _paused = !_paused);
    if (_paused) widget.onPause?.call();
  }

  void _finish() {
    if (_logged) return;
    _logged = true;
    final l10n = AppL10n.of(context);
    final prescribed = widget.set;
    // The set is hers either way: with no prescription to attach it to there
    // is nothing to write, and the clock running out only moves her on.
    if (prescribed == null) {
      widget.onSkip?.call();
      return;
    }
    final handle = _bus.submit(
      UndoableLog(
        describe: setSavedLabel(
          l10n,
          setNumber: prescribed.order,
          weightKg: prescribed.weightKg,
          reps: prescribed.reps,
          holdSeconds: prescribed.holdSeconds,
        ),
        commit: () => _repository.flushMove(
          sessionId: widget.sessionId,
          exerciseId: prescribed.exerciseId,
          sets: [
            LoggedSet(prescribed: prescribed).recording(
              SetOutcome(
                weightKg: prescribed.weightKg,
                reps: prescribed.reps,
                holdSeconds: prescribed.holdSeconds ?? widget.holdSeconds,
              ),
            ),
          ],
        ),
      ),
    );
    unawaited(AppHaptics.play(HapticMoment.setLogged));
    widget.onSetLogged?.call(handle);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppL10n.of(context);

    final Duration total = _live ? _hold : widget.total;
    final Duration remaining = _live ? _hold - _elapsed : widget.remaining;
    // Whole seconds up: a hold of 30 s reads 0:30 on its first frame and 0:00
    // only when the set is logged.
    final shown = Duration(seconds: (remaining.inMilliseconds / 1000).ceil());
    final still = handMotionOff(context);
    final elapsed = total.inSeconds == 0
        ? 0.0
        : _live
        ? (still ? 0.0 : _elapsed.inMilliseconds / total.inMilliseconds)
        : (total.inSeconds - widget.remaining.inSeconds) / total.inSeconds;

    final clip = widget.clip;

    return Scaffold(
      backgroundColor: AppColors.inverseSurface,
      body: SafeArea(
        child: Column(
          children: [
            if (widget.notice case final notice?)
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
                child: AppLiveUndoBar(
                  handle: notice.handle,
                  message: notice.handle.describe,
                  undoLabel: AppL10n.of(context).undo,
                  onUndo: notice.onUndo,
                ),
              ),
            if (clip != null)
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
                child: ExerciseClipFrame(
                  exercise: clip,
                  media: widget.media,
                  players: widget.players,
                  tallest: 0.3,
                ),
              )
            else
              const Padding(
                padding: EdgeInsets.only(top: 8),
                child: ScreenArtStrip(size: 76),
              ),
            Expanded(
              child: Center(
                child: AppRingStat(
                  fraction: elapsed,
                  big: clockLabel(_live ? shown : remaining),
                  small: l10n.left,
                  size: 168,
                  thickness: 14,
                  color: AppColors.primaryContainer,
                  bigColor: _onDark,
                  smallColor: _onDarkMuted,
                  trackColor: _onDarkTrack,
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            // Where she is in the workout, or nothing.
                            //
                            // This read `positionLabel ?? move3Of5`, so
                            // it stated "Move 3 of 5" precisely when the real
                            // position was unknown — a fallback whose only job
                            // was to fill the line, and which filled it with
                            // the prototype's. R06 is given a position or it
                            // says nothing about one.
                            if (widget.positionLabel != null) ...[
                              Text(
                                widget.positionLabel!,
                                style: AppText.bodyM.copyWith(
                                  color: _onDarkMuted,
                                ),
                              ),
                              const SizedBox(height: 2),
                            ],
                            MoveName(
                              widget.moveName ?? englishMoveNames.gluteBridge,
                              style: AppText.titleL.copyWith(
                                fontSize: 24,
                                color: _onDark,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 12),
                      // Says out loud that nothing is expected of her, so the
                      // absence of a log button does not read as a missing one.
                      //
                      // Flexible because a Row hands its non-flex children
                      // unbounded width: at the largest text size the pill would
                      // otherwise take what it liked and overflow the row.
                      Flexible(
                        child: AppPill(
                          l10n.countsItself,
                          icon: Icons.check,
                          background: _onDarkSoft,
                          foreground: _onDark,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: AppWhiteButton(
                          _paused ? l10n.resume : l10n.pause,
                          icon: _paused ? Icons.play_arrow : Icons.pause,
                          onPressed: _logged ? null : _togglePause,
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: _OnDarkOutlinedButton(
                          l10n.skipThisMove,
                          onPressed: widget.onSkip,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// An outlined button on the inverted surface.
///
/// [AppButton]'s outlined variant draws its label in `onSurface`, which is very
/// nearly black and invisible here. Local rather than a sixth shared variant, for
/// the reason `app_white_button.dart` gives: several groups are editing
/// `app_button.dart` at once. Fold both in together.
class _OnDarkOutlinedButton extends StatelessWidget {
  const _OnDarkOutlinedButton(this.label, {this.onPressed});

  final String label;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    // Framed in white pencil with tight corners, beside the white block of
    // Pause — the same cut as that button, only unfilled.
    return ConstrainedBox(
      constraints: const BoxConstraints(minHeight: 56),
      child: HandSurface(
        seed: handSeed(['on-dark', label]),
        frame: _onDarkLine,
        frameWidth: 1.3,
        radius: 7,
        looseCorner: 15,
        onTap: onPressed,
        pressable: true,
        semanticsButton: true,
        child: Container(
          constraints: const BoxConstraints(minHeight: 56),
          alignment: Alignment.center,
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          child: Text(
            label,
            textAlign: TextAlign.center,
            style: AppText.label.copyWith(
              fontSize: 15,
              fontWeight: FontWeight.w600,
              color: _onDark,
            ),
          ),
        ),
      ),
    );
  }
}
