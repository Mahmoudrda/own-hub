/// R07 — Mid-set. The screen this whole group exists for.
///
/// Matches `6-v2/src/screens-train.mjs` → `R07`. **One tap logs a set.** The
/// numbers are a sentence she agrees with, not two steppers to fight, and the
/// button states exactly what it will save — so confirming and logging are one
/// action rather than two.
///
/// ## Rule 1, precisely
///
/// The large "12 kg × 10" on this screen is the **prescription**: what the plan
/// asked for. There is no field anywhere on it holding what she did, empty or
/// otherwise, and nothing is pre-filled — which is the failure `P1-RULE-01`
/// exists to catch.
///
/// When she taps "Done · 12 kg × 10", the outcome is built from the numbers *the
/// button itself names*, at the moment of an explicit gesture. That is the one
/// permitted way a prescription becomes a result, and it is permitted precisely
/// because she read those numbers and agreed to them. What is forbidden — and
/// impossible here — is a "what did you do?" box that arrives already filled in
/// with the answer. If she did something else, R08 is two taps away.
///
/// ## Rule 9, mechanically
///
/// The tap goes through [LogCommandBus] and nothing else. The set is hers
/// immediately, the five seconds run *before* the write, and there is no dialog
/// on this path — there is no parameter on this screen that could produce one.
library;

import 'dart:async';

import 'package:flutter/material.dart';

import '../../../app_state/haptics.dart';

import '../../../domain/format/number_label.dart';
import '../../../domain/logging/log_command_bus.dart';
import '../../../domain/rewards/stated_figure.dart';
import '../../../domain/training/prescribed_set.dart';
import '../../../l10n/app_l10n.dart';
import '../../../theme/app_tokens.dart';
import '../../../ui/app_big_button.dart';
import '../../../ui/app_button.dart';
import '../../../ui/app_card.dart';
import '../../../ui/app_sage_note.dart';
import '../../../ui/app_scaffold.dart';
import '../../../ui/hand/hand.dart';
import '../domain/train_repository.dart';
import '../domain/weight_label.dart';
import 'set_labels.dart';
import 'train_widgets.dart';
import 'workout_day_view.dart' show localisedMove;

class MidSetView extends StatefulWidget {
  const MidSetView({
    super.key,
    this.onClose,
    this.onPause,
    this.onChange,
    this.onSetLogged,
    this.onMoveLogged,
    this.move,
    this.sessionId = 'session',
    this.setIndex = 1,
    this.repository,
    this.bus,
    this.lastLogged,
    this.moveNumber,
    this.moveCount,
    this.sets,
    this.onAttach,
    this.onDetach,
    this.progressionLine,
  });

  final VoidCallback? onClose;

  /// Why the weight is what it is, for a loaded move she has trained before:
  /// the next weight up, or why it is not going up yet. Read from her own
  /// history by `loadAdviceFor`, and null for a move that has none.
  final String? progressionLine;

  /// Null draws no pause control. A pause icon that did nothing was on this
  /// screen, R09 and R13 for every woman.
  final VoidCallback? onPause;

  /// Sets of today's session behind her, for the bar under the title.
  final ({int done, int total})? sets;

  /// Told when this screen opens and closes, so the session's one log bus is
  /// committed when the last training screen goes, never dropped with it.
  final VoidCallback? onAttach;
  final VoidCallback? onDetach;

  /// R08 — she did something other than what was asked.
  final VoidCallback? onChange;

  /// R09. The handle carries the five-second window, so the rest screen can
  /// offer Undo on the very log that was just made.
  final ValueChanged<LogHandle>? onSetLogged;

  /// R13. Logs every remaining set of this move at once and returns to the move
  /// list — **the session does not end.**
  final ValueChanged<LogHandle>? onMoveLogged;

  final PlannedMove? move;
  final String sessionId;

  /// Zero-based. The design shows set 2 of 3, so set 1 is already done.
  final int setIndex;

  final TrainRepository? repository;
  final LogCommandBus? bus;

  /// The last set she logged for this move, in an earlier session.
  ///
  /// Null when she has never logged one, which is the case for every woman on
  /// her first session — and the reason the progression note below is drawn
  /// from this rather than from the prescription. See `domain/set_history.dart`
  /// for where a caller gets it.
  final SetOutcome? lastLogged;

  /// Which move of how many, for the bar at the top.
  ///
  /// Both null renders no count rather than a fixed one. The bar said
  /// "Move 2 of 5" to a woman on the first move of four.
  final int? moveNumber;
  final int? moveCount;

  @override
  State<MidSetView> createState() => _MidSetViewState();
}

class _MidSetViewState extends State<MidSetView> {
  TrainRepository? _fallbackRepository;
  LogCommandBus? _fallbackBus;

  /// Whether the sets other than the current one are drawn.
  bool _allSets = false;

  TrainRepository get _repository =>
      widget.repository ?? (_fallbackRepository ??= InMemoryTrainRepository());

  LogCommandBus get _bus => widget.bus ?? (_fallbackBus ??= LogCommandBus());

  @override
  void initState() {
    super.initState();
    widget.onAttach?.call();
  }

  @override
  void dispose() {
    // Only the one this screen created. A bus passed in belongs to the caller,
    // and disposing it would drop a log the caller is still holding.
    _fallbackBus?.dispose();
    widget.onDetach?.call();
    super.dispose();
  }

  /// The move a caller that named none is shown.
  ///
  /// A fixture, and only a fixture: every route into R07 passes the move she is
  /// actually on, and the router falls back to the first move of the one
  /// authored session when there is no live one. Nothing a woman can reach
  /// renders this, which is why a 12 kg goblet squat here is not the
  /// twelve-kilogram prescription round one found inside a no-equipment
  /// session. That one came from the router passing nothing.
  PlannedMove _defaultMove(AppL10n l10n) => PlannedMove(
    exerciseId: 'goblet_squat',
    name: l10n.gobletSquat,
    prescriptionLabel: l10n.n12Kg10,
    sets: const [
      PrescribedSet(
        exerciseId: 'goblet_squat',
        order: 1,
        weightKg: 12,
        reps: 10,
      ),
      PrescribedSet(
        exerciseId: 'goblet_squat',
        order: 2,
        weightKg: 12,
        reps: 10,
      ),
      PrescribedSet(
        exerciseId: 'goblet_squat',
        order: 3,
        weightKg: 12,
        reps: 10,
      ),
    ],
  );

  /// Builds the outcome from the numbers the button named.
  ///
  /// Takes them as arguments rather than reading the prescription itself, so the
  /// gesture is what supplies the values — there is no path here that copies a
  /// prescription into a result without one.
  LoggedSet _recordAgreed(PrescribedSet prescribed) =>
      LoggedSet(prescribed: prescribed).recording(
        SetOutcome(
          weightKg: prescribed.weightKg,
          reps: prescribed.reps,
          holdSeconds: prescribed.holdSeconds,
        ),
      );

  /// The set this screen is about.
  ///
  /// The button label and the log read the **same** set through this. They used
  /// to be independent — a fixed label beside an indexed log — which is how a
  /// button can name one set and save another. That is what R08 did, and it is
  /// not a class of bug worth leaving a second door open to.
  ///
  /// Bounds-checked rather than indexed blind: an out-of-range index would
  /// throw during *build*, taking the whole workout player down mid-session. A
  /// crash on tap is recoverable; a crash on render is not. (Written out rather
  /// than with `clamp`, whose static type is `num` and cannot index a list.)
  PrescribedSet? _prescribedOf(PlannedMove move) {
    if (move.sets.isEmpty) return null;
    final last = move.sets.length - 1;
    final index = widget.setIndex < 0
        ? 0
        : (widget.setIndex > last ? last : widget.setIndex);
    return move.sets[index];
  }

  /// The 1-based number of the set this screen is about.
  ///
  /// Bounds-checked exactly as [_prescribedOf] is, and for the same reason: the
  /// heading and the row list must name the set the button is going to write.
  int _setNumberOf(PlannedMove move) {
    if (move.sets.isEmpty) return 0;
    final last = move.sets.length - 1;
    final index = widget.setIndex < 0
        ? 0
        : (widget.setIndex > last ? last : widget.setIndex);
    return index + 1;
  }

  void _logOneSet(PlannedMove move) {
    final l10n = AppL10n.of(context);
    final prescribed = _prescribedOf(move);
    // The button that calls this is disabled in the same case. Belt and braces.
    if (prescribed == null) return;

    final handle = _bus.submit(
      UndoableLog(
        // Names the same numbers the button named — read off the prescription
        // she just agreed to, never off a hardcoded string that would keep
        // saying "12 kg × 10" for a woman who was asked for something else.
        //
        // Through `setSavedLabel`, so a bodyweight set reads "12 reps" and a
        // hold reads "30 seconds". It used to force the loaded form with
        // `weightKg ?? 0`, which announced a glute bridge as "0 kg × 12" — a
        // weight she never lifted, in the sentence that offers her the undo.
        describe: setSavedLabel(
          l10n,
          setNumber: prescribed.order,
          weightKg: prescribed.weightKg,
          reps: prescribed.reps,
          holdSeconds: prescribed.holdSeconds,
        ),
        commit: () => _repository.flushMove(
          sessionId: widget.sessionId,
          exerciseId: move.exerciseId,
          sets: [_recordAgreed(prescribed)],
        ),
      ),
    );
    unawaited(AppHaptics.play(HapticMoment.setLogged));
    widget.onSetLogged?.call(handle);
  }

  /// The sage note under the prescription: what she did last time. Null when
  /// there is no last time.
  ///
  /// Every figure in it comes from [MidSetView.lastLogged], which is a set she
  /// logged. Nothing here reads a prescription for a number, so there is no
  /// path by which this line can state a session that did not happen.
  Widget? _progressionNote(AppL10n l10n, PrescribedSet? prescribed) {
    final line = widget.progressionLine;
    if (line != null) return AppSageNote(line);
    final last = widget.lastLogged;
    // No history, nothing to say: an empty note is not worth a line mid-set.
    if (last == null) return null;

    final was = setFigure(
      l10n,
      weightKg: last.weightKg,
      reps: last.reps,
      holdSeconds: last.holdSeconds,
    );
    // A logged set with nothing in it to state. Nothing is claimed about it.
    if (was.isEmpty) return null;

    final lastKg = last.weightKg;
    final nowKg = prescribed?.weightKg;
    final added = (lastKg != null && nowKg != null) ? nowKg - lastKg : null;
    // The step is stated only when there is one. "So we added 0 kg" is not a
    // reason, and a lighter day is not something to announce as progress.
    if (added != null && added > 0) {
      return AppSageNote(
        l10n.lastTimeLastSoWeAddedAdded(was, weightLabel(added)),
      );
    }
    return AppSageNote(l10n.lastTimeLast(was));
  }

  void _logWholeMove(PlannedMove move) {
    final l10n = AppL10n.of(context);

    final handle = _bus.submit(
      UndoableLog(
        describe: l10n.moveSavedSetsSets(move.name, move.sets.length),
        commit: () => _repository.flushMove(
          sessionId: widget.sessionId,
          exerciseId: move.exerciseId,
          sets: [for (final set in move.sets) _recordAgreed(set)],
        ),
      ),
    );
    unawaited(AppHaptics.play(HapticMoment.setLogged));
    widget.onMoveLogged?.call(handle);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppL10n.of(context);
    // In the language on screen now, not the one the session started in.
    final move = localisedMove(l10n, widget.move ?? _defaultMove(l10n));
    final prescribed = _prescribedOf(move);

    return AppScaffold(
      footerScrollsWhenLarge: true,
      appBar: TrainTopBar(
        // Which move of how many, when the caller knows. It was the fixed
        // `move2Of5`, so the bar read "Move 2 of 5" above the first move of a
        // four-move session. A caller that does not know says nothing.
        title: moveTitle(l10n, widget.moveNumber, widget.moveCount),
        onClose: widget.onClose,
        sets: widget.sets,
        actions: [
          if (widget.onPause != null)
            IconButton(
              onPressed: widget.onPause,
              iconSize: 24,
              color: AppColors.onSurfaceVariant,
              tooltip: l10n.pause,
              icon: const Icon(Icons.pause),
            ),
        ],
      ),
      footer: [
        AppBigButton(
          // Names the set it is about to save, read from HER prescription.
          //
          // This was the fixed `done12Kg10`, so it read
          // "Done · 12 kg × 10" to every woman whatever her plan asked for —
          // and tapping it logged numbers the screen had never shown her. The
          // agreement between what the button says and what gets written is the
          // whole basis of rule 1's one permitted path from prescription to
          // result.
          //
          // Through `setDoneLabel`, which picks the sentence the set's own
          // shape asks for. Forcing the loaded form put "Done · 0 kg × 12" on
          // the first bodyweight move of the first session.
          prescribed == null
              ? l10n.done_54ca1
              : setDoneLabel(
                  l10n,
                  weightKg: prescribed.weightKg,
                  reps: prescribed.reps,
                  holdSeconds: prescribed.holdSeconds,
                ),
          subtitle: l10n.restStartsItself,
          // A move with no sets has nothing to log, and _logOneSet would have
          // thrown on the index. A button that does nothing is better than one
          // that crashes her session.
          onPressed: prescribed == null ? null : () => _logOneSet(move),
        ),
        // For the woman training with the phone on the floor: the whole move in
        // one tap, and she stays in the session.
        //
        // "I did all 3 sets, log them" names three, and `_logWholeMove` logs
        // `move.sets.length` — so a four-set move offered to log three and
        // wrote four. The named figure is only offered to the woman it is true
        // of; everyone else gets the plain action, which is what the button
        // does either way. The dictionary gap is a `{sets}` form of this label.
        AppButton(
          statesHerFigure(states: 3, hers: move.sets.length)
              ? l10n.iDidAll3Sets
              : l10n.iDidThemAll,
          variant: AppButtonVariant.text,
          height: 44,
          fontSize: 15,
          onPressed: () => _logWholeMove(move),
        ),
      ],
      children: [
        Row(
          children: [
            Expanded(child: Text(move.name, style: AppText.headline)),
            IconButton(
              key: const ValueKey('r07-change'),
              tooltip: l10n.change,
              onPressed: widget.onChange,
              iconSize: 24,
              color: AppColors.onSurfaceVariant,
              icon: const Icon(Icons.tune),
            ),
          ],
        ),
        AppCard(
          padding: const EdgeInsets.all(18),
          children: [
            Builder(
              builder: (context) {
                // The numbers she is agreeing to, underlined once. It is the
                // only mark on this screen: she reads it mid-set, one-handed,
                // and everything else stays plain print.
                //
                // Already display-sized, so it grows with the system text
                // size only so far — past that it would stack one word per
                // line — and at a large size the Change button goes under it.
                final scaler = MediaQuery.textScalerOf(context);
                final figure = HandUnderline(
                  level: HandLevel.crafted,
                  color: AppColors.primaryDim,
                  gap: 2,
                  child: Text(
                    move.prescriptionLabel,
                    textScaler: scaler.clamp(maxScaleFactor: 1.3),
                    style: AppText.display.copyWith(
                      fontSize: 38,
                      height: 46 / 38,
                      color: AppColors.onSurface,
                    ),
                  ),
                );
                return Align(
                  alignment: AlignmentDirectional.centerStart,
                  child: figure,
                );
              },
            ),
            // Why the weight moved. Progression explains itself rather than
            // arriving as a number she did not ask for.
            //
            // This was "Last Tuesday: 10 kg × 10, every set finished. So we
            // added 2 kg." — three figures about a session that had to have
            // happened. It was guarded by `statesHerFigure` against the
            // prescription `(12, 10)`, which is a sound guard defeated by the
            // one workout in the build prescribing exactly 12 kg × 10 to
            // everybody. So the first set a woman was ever asked to do cited a
            // Tuesday she had not trained.
            //
            // The note now reads her history (`lastLogged`) rather than her
            // prescription, so it reaches only a woman who has one. Where she
            // has none, the true thing to say is that this is the first, and
            // that what she logs today is the measure for the next one.
            ?_progressionNote(l10n, prescribed),
          ],
        ),
        // The set she is on, and the rest one tap away.
        _ThisMoveHeading(
          label: l10n.thisMove,
          open: _allSets,
          onTap: () => setState(() => _allSets = !_allSets),
        ),
        // One row per set her move prescribes.
        //
        // These were three fixed rows, each valued `n12Kg10`, so a two-set
        // move grew a third set that did not exist and every row read
        // "12 kg x 10" however little that had to do with her plan.
        for (var i = 0; i < move.sets.length; i++)
          if (_allSets || i == _setNumberOf(move) - 1)
            SetRow(
              label: l10n.countOfTotal(
                countLabel(i + 1),
                countLabel(move.sets.length),
              ),
              value: _setValue(l10n, move, i),
              done: i < _setNumberOf(move) - 1,
              current: i == _setNumberOf(move) - 1,
            ),
      ],
    );
  }

  /// One set's own figure, never the whole move's "3 × 30 seconds" repeated on
  /// every row.
  static String _setValue(AppL10n l10n, PlannedMove move, int i) {
    final set = move.sets[i];
    final figure = setFigure(
      l10n,
      weightKg: set.weightKg,
      reps: set.reps,
      holdSeconds: set.holdSeconds,
    );
    return figure.isEmpty ? move.prescriptionLabel : figure;
  }
}

/// "This move", which opens the other sets when tapped.
class _ThisMoveHeading extends StatelessWidget {
  const _ThisMoveHeading({
    required this.label,
    required this.open,
    required this.onTap,
  });

  final String label;
  final bool open;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      expanded: open,
      child: InkWell(
        key: const ValueKey('r07-all-sets'),
        onTap: onTap,
        child: ConstrainedBox(
          constraints: const BoxConstraints(minHeight: 44),
          child: Row(
            children: [
              Expanded(
                child: Text(
                  label,
                  style: AppText.bodyM.copyWith(
                    color: AppColors.onSurfaceVariant,
                  ),
                ),
              ),
              Icon(
                open ? Icons.expand_less : Icons.expand_more,
                size: 22,
                color: AppColors.onSurfaceVariant,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
