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

import 'package:flutter/material.dart';

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
import 'train_widgets.dart';

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
  });

  final VoidCallback? onClose;
  final VoidCallback? onPause;

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

  @override
  State<MidSetView> createState() => _MidSetViewState();
}

class _MidSetViewState extends State<MidSetView> {
  TrainRepository? _fallbackRepository;
  LogCommandBus? _fallbackBus;

  TrainRepository get _repository =>
      widget.repository ?? (_fallbackRepository ??= InMemoryTrainRepository());

  LogCommandBus get _bus => widget.bus ?? (_fallbackBus ??= LogCommandBus());

  @override
  void dispose() {
    // Only the one this screen created. A bus passed in belongs to the caller,
    // and disposing it would drop a log the caller is still holding.
    _fallbackBus?.dispose();
    super.dispose();
  }

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
        // Names the same numbers the button named — read off the prescription she
        // just agreed to, never off a hardcoded string that would keep saying
        // "12 kg × 10" for a woman who was asked for something else.
        describe: l10n.setSetnumberSavedWeightKgReps(
          prescribed.order,
          weightLabel(prescribed.weightKg ?? 0),
          prescribed.reps ?? 0,
        ),
        commit: () => _repository.flushMove(
          sessionId: widget.sessionId,
          exerciseId: move.exerciseId,
          sets: [_recordAgreed(prescribed)],
        ),
      ),
    );
    widget.onSetLogged?.call(handle);
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
    widget.onMoveLogged?.call(handle);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppL10n.of(context);
    final move = widget.move ?? _defaultMove(l10n);
    final prescribed = _prescribedOf(move);

    return AppScaffold(
      footerScrollsWhenLarge: true,
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
        AppBigButton(
          // Names the set it is about to save, read from HER prescription.
          //
          // This was the fixed `done12Kg10`, so it read
          // "Done · 12 kg × 10" to every woman whatever her plan asked for —
          // and tapping it logged numbers the screen had never shown her. The
          // agreement between what the button says and what gets written is the
          // whole basis of rule 1's one permitted path from prescription to
          // result.
          prescribed == null
              ? l10n.done_54ca1
              : l10n.doneWeightKgReps(
                  weightLabel(prescribed.weightKg ?? 0),
                  prescribed.reps ?? 0,
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
              ? l10n.iDidAll3SetsLogThem
              : l10n.logIt,
          variant: AppButtonVariant.text,
          height: 44,
          fontSize: 15,
          onPressed: () => _logWholeMove(move),
        ),
      ],
      children: [
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(move.name, style: AppText.headline),
            const SizedBox(height: 2),
            Text(
              // Her set, of the sets her move actually has.
              //
              // This was the fixed `set2Of3`, so a woman on the first of four
              // sets read "Set 2 of 3" — and the list below it drew three rows
              // whatever her move prescribed. Both now come off `move.sets`.
              l10n.countOfTotal(
                countLabel(_setNumberOf(move)),
                countLabel(move.sets.length),
              ),
              style: AppText.bodyM.copyWith(color: AppColors.onSurfaceVariant),
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
                final change = AppButton(
                  l10n.change,
                  variant: AppButtonVariant.tonal,
                  height: 44,
                  fontSize: 15,
                  onPressed: widget.onChange,
                );
                if (scaler.scale(1) > 1.3) {
                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      figure,
                      const SizedBox(height: 12),
                      IntrinsicWidth(child: change),
                    ],
                  );
                }
                return Row(
                  children: [
                    Expanded(
                      child: Align(
                        alignment: AlignmentDirectional.centerStart,
                        child: figure,
                      ),
                    ),
                    const SizedBox(width: 12),
                    change,
                  ],
                );
              },
            ),
            // Why the weight moved. Progression explains itself rather than
            // arriving as a number she did not ask for.
            //
            // "Last Tuesday: 10 kg × 10, every set finished. So we added 2 kg."
            // states last week's load, last week's reps and this week's step —
            // three figures, none of which this screen is given. It is true of
            // exactly the woman prescribed 12 kg × 10, so it is shown to her
            // and to nobody else. The dictionary gap is a `{was}`/`{now}` form;
            // the build reports it.
            if (statesHerFigure<(num?, int?)>(
              states: const (12, 10),
              hers: (prescribed?.weightKg, prescribed?.reps),
            ))
              AppSageNote(l10n.lastTuesday10Kg10EverySet),
          ],
        ),
        Text(
          l10n.thisMove,
          style: AppText.bodyM.copyWith(color: AppColors.onSurfaceVariant),
        ),
        // One row per set her move prescribes.
        //
        // These were three fixed rows — `set1`/`set2`/`set3`, each valued
        // `n12Kg10` — so a two-set move grew a third set that did not exist, a
        // four-set move lost one, and every row read "12 kg × 10" however
        // little that had to do with her plan.
        for (var i = 0; i < move.sets.length; i++)
          SetRow(
            label: l10n.countOfTotal(
              countLabel(i + 1),
              countLabel(move.sets.length),
            ),
            value: move.prescriptionLabel,
            done: i < _setNumberOf(move) - 1,
            current: i == _setNumberOf(move) - 1,
          ),
      ],
    );
  }
}
