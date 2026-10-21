/// R03 — Workout day.
///
/// Matches `6-v2/src/screens-train.mjs` → `R03`. The day is a list of moves with
/// the suggested weights already on them, and one way in: start it now. Saying
/// she already did it (`T02`) is offered on Home, so this screen asks for one
/// decision.
///
/// The weights shown here are prescriptions. Nothing on this screen can become a
/// result: starting a session creates it with every outcome null, and the
/// repository refuses to persist one that arrives otherwise.
library;

import 'package:flutter/material.dart';

import '../../../domain/clock/app_clock.dart';
import '../../../domain/logging/log_command_bus.dart';
import '../../../l10n/app_l10n.dart';
import '../../../routing/app_router.dart';
import '../../../theme/app_tokens.dart';
import '../../../domain/format/day_key.dart';
import '../../../domain/format/number_label.dart';
import '../../../domain/training/prescribed_set.dart';
import '../../../ui/app_button.dart';
import '../../../ui/app_card.dart';
import '../../../ui/app_sheet.dart';
import '../../../ui/app_undo_snackbar.dart';
import '../../onboarding/domain/intake.dart' show LifeStage;
import '../../../ui/app_scaffold.dart';
import '../../../ui/hand/hand.dart';
import '../domain/custom_workout.dart';
import '../domain/train_repository.dart';
import 'authored_workout.dart';
import 'move_editor.dart';
import 'swap_move_view.dart' show SwapChoices;
import 'train_widgets.dart';
import 'exercise_labels.dart';

/// [move] with its name and prescription read in the language on screen now.
///
/// A session keeps the moves it was started with, and their strings were read
/// from the dictionary at that moment, so a woman who switched language
/// mid-session saw the old language on R07 while R03 beside it was translated.
/// An authored move is found again by its exercise id, and a prescription by
/// the sets it describes (a swapped move keeps the prescription it replaced).
/// Anything not authored here is shown exactly as stored.
PlannedMove localisedMove(AppL10n l10n, PlannedMove move) {
  String? name;
  String? label;
  for (final authored in sampleWorkoutDay(l10n).moves) {
    if (authored.exerciseId == move.exerciseId) {
      name = authored.name;
      if (_sameLoad(authored.sets, move.sets)) {
        label = authored.prescriptionLabel;
      }
    }
  }
  if (label == null) {
    for (final authored in sampleWorkoutDay(l10n).moves) {
      if (_sameLoad(authored.sets, move.sets)) {
        label = authored.prescriptionLabel;
        break;
      }
    }
  }
  if (name == null && label == null) return move;
  return PlannedMove(
    exerciseId: move.exerciseId,
    name: name ?? move.name,
    prescriptionLabel: label ?? move.prescriptionLabel,
    sets: move.sets,
    cues: move.cues,
    quiet: move.quiet,
    needsEquipment: move.needsEquipment,
    floorOnly: move.floorOnly,
    videoAssetId: move.videoAssetId,
  );
}

bool _sameLoad(List<PrescribedSet> a, List<PrescribedSet> b) {
  if (a.length != b.length || a.isEmpty) return false;
  for (var i = 0; i < a.length; i++) {
    if (a[i].reps != b[i].reps ||
        a[i].holdSeconds != b[i].holdSeconds ||
        a[i].weightKg != b[i].weightKg) {
      return false;
    }
  }
  return true;
}

/// The design's day, resolved from the dictionary.
///
/// Public so the router's session state trains the SAME day this screen
/// lists: a second copy of these five moves would be a second idea of what
/// today asks for.
///
/// The id is **today's `yyyy-MM-dd` key**, because [WorkoutDay.id] is
/// documented as "the assignment's `yyyy-MM-dd` key" and `startSession`
/// copies it straight into the session's `dateKey`. It held the mockup slug
/// `day-2`, which meant a personal best set from this screen was stored
/// under `dateKey: 'day-2'` — and P03 sorts bests by that string, where
/// `'day-2'` outranks every real date. One sample id, and her whole history
/// would have rendered in the wrong order with nothing throwing.
///
/// Note the shape of the prescriptions: the glute bridge carries no weight and
/// the hip thrust carries no reps, because a bodyweight move prescribes no load
/// and a hold prescribes no repetitions. Neither is written as a zero — "0 kg"
/// is a number she never lifted.
///
/// ## Why there is no goblet squat in it
///
/// There used to be, at `12 kg × 10` for every woman who opened the app — on a
/// session whose own subtitle reads "Quiet · no equipment · floor", and to a
/// woman the app had never asked whether she owns a dumbbell. Two separate
/// untruths in one move: the session contradicted its own constraints, and the
/// load was the prototype's number wearing her name. R07's progression note
/// then cited "last Tuesday: 10 kg × 10" to justify it, which is a history she
/// does not have.
///
/// A prescribed load has to come from somewhere real — her logged history, or
/// an answer she gave about her equipment. Neither exists in this build (the
/// intake screens `O01` to `O05` are unreachable), so the first session is the
/// four bodyweight floor moves, which is exactly what "quiet, no equipment,
/// floor" promises. The squat comes back with the question that earns it.
WorkoutDay sampleWorkoutDay(AppL10n l10n, {DateTime? now}) {
  final moves = [
    PlannedMove(
      exerciseId: 'donkey_kick',
      name: englishMoveNames.donkeyKick,
      prescriptionLabel: l10n.n312Bodyweight,
      quiet: true,
      floorOnly: true,
      sets: const [
        PrescribedSet(exerciseId: 'donkey_kick', order: 1, reps: 12),
        PrescribedSet(exerciseId: 'donkey_kick', order: 2, reps: 12),
        PrescribedSet(exerciseId: 'donkey_kick', order: 3, reps: 12),
      ],
    ),
    PlannedMove(
      exerciseId: 'straight_leg_glute_kickback',
      name: englishMoveNames.straightLegGluteKickback,
      prescriptionLabel: l10n.n310EachSide,
      // Quiet: a step back has no jump and no impact. Flagged rather than
      // left at the default, because R11's "quiet" filter reads these and a
      // session offered as quiet has to be quiet move by move.
      quiet: true,
      sets: const [
        PrescribedSet(
          exerciseId: 'straight_leg_glute_kickback',
          order: 1,
          reps: 10,
        ),
        PrescribedSet(
          exerciseId: 'straight_leg_glute_kickback',
          order: 2,
          reps: 10,
        ),
        PrescribedSet(
          exerciseId: 'straight_leg_glute_kickback',
          order: 3,
          reps: 10,
        ),
      ],
    ),
    PlannedMove(
      exerciseId: 'forearm_plank',
      name: englishMoveNames.forearmPlank,
      prescriptionLabel: l10n.n330Seconds,
      quiet: true,
      floorOnly: true,
      sets: const [
        PrescribedSet(exerciseId: 'forearm_plank', order: 1, holdSeconds: 30),
        PrescribedSet(exerciseId: 'forearm_plank', order: 2, holdSeconds: 30),
        PrescribedSet(exerciseId: 'forearm_plank', order: 3, holdSeconds: 30),
      ],
    ),
    PlannedMove(
      exerciseId: 'heel_touches',
      name: englishMoveNames.heelTouches,
      prescriptionLabel: l10n.n38EachSide,
      quiet: true,
      floorOnly: true,
      sets: const [
        PrescribedSet(exerciseId: 'heel_touches', order: 1, reps: 8),
        PrescribedSet(exerciseId: 'heel_touches', order: 2, reps: 8),
        PrescribedSet(exerciseId: 'heel_touches', order: 3, reps: 8),
      ],
    ),
  ];

  return WorkoutDay(
    id: dayKey(now ?? AppClock.now()),
    title: l10n.legsAndGlutes,
    // Counted off the moves above rather than written under them. It read
    // "15 minutes, 5 moves" from the dictionary, so the line and the list it
    // introduced could disagree the moment either changed.
    summary: l10n.minutesMinutesMovesMoves(
      countLabel(kSampleWorkoutMinutes),
      countLabel(moves.length),
    ),
    constraints: l10n.quietNoEquipmentFloor,
    moves: moves,
  );
}

/// How long [sampleWorkoutDay] takes. One number, read by the day's own summary
/// and by the library row that offers it, so the two cannot disagree.
const int kSampleWorkoutMinutes = 15;

/// The bundled library, as Train's Explore lists it.
///
/// Derived from [sampleWorkoutDay] rather than written beside it, because a
/// library row is a promise: tap it and you get that session. R11 used to list
/// three rows, every one of them credited to an invented coach ("10 min ·
/// beginner · Nour"), and every one of them opening the same single workout.
/// The app has one authored workout, so the library has one row, and it is the
/// same object the row names.
List<LibraryWorkout> sampleWorkoutLibrary(AppL10n l10n, {DateTime? now}) {
  final day = sampleWorkoutDay(l10n, now: now);
  return [
    LibraryWorkout(
      id: day.id,
      title: day.title,
      detail: l10n.n15MinBeginnerNoEquipment,
      // Read off the moves, not off the row's own copy: a session is quiet
      // when every move in it is, and it needs equipment the moment one move
      // does. The detail line above can then never over-promise.
      quiet: day.moves.every((move) => move.quiet),
      needsEquipment: day.moves.any((move) => move.needsEquipment),
      minutes: kSampleWorkoutMinutes,
      exerciseIds: [for (final move in day.moves) move.exerciseId],
    ),
  ];
}

/// The session behind a library row, or null when the app has none for that id.
///
/// R11's row hands back its id and this turns it back into a workout, so the
/// router can no longer open a screen that has nothing to do with what she
/// tapped. Null is a row the app cannot honour, and the caller opens nothing
/// rather than opening something else.
WorkoutDay? workoutDayFor(AppL10n l10n, String id, {DateTime? now}) {
  final day = sampleWorkoutDay(l10n, now: now);
  return day.id == id ? day : null;
}

class WorkoutDayView extends StatefulWidget {
  const WorkoutDayView({
    super.key,
    this.onBack,
    this.onStart,
    this.onOpenMove,
    this.canOpenMove,
    this.onMore,
    this.day,
    this.repository,
    this.lifeStage,
    this.writtenForHerStage = false,
    this.onNotToday,
    this.challengeExerciseId,
    this.challengeNote,
    this.onMovesChanged,
    this.onPickMoves,
    this.onSaveAsMine,
    this.alternativesFor,
    this.canSwapMove,
    this.needsEquipmentFor,
    this.editedToday = false,
    this.undoBus,
  });

  final VoidCallback? onBack;

  /// Called with the moves as they stand after every edit. Giving it is what
  /// turns the edit controls on: add, remove, swap and the inline sets, reps
  /// (or seconds) and target weight. The edits are today's session only; the
  /// caller keeps them until she starts, and nothing here touches the plan.
  final ValueChanged<List<PlannedMove>>? onMovesChanged;

  /// Opens the catalogue and answers the moves she added, already prescribed.
  final Future<List<PlannedMove>?> Function()? onPickMoves;

  /// "Save as my workout": keeps today's moves as a workout of her own.
  final ValueChanged<List<PlannedMove>>? onSaveAsMine;

  /// What a move can be swapped for. Defaults to the repository's answer.
  final Future<List<MoveAlternative>> Function(String exerciseId)?
  alternativesFor;

  /// Where a removal or a swap offers its five seconds of Undo.
  final LogCommandBus? undoBus;

  /// Whether a move has anything to swap to. Null offers Swap on every move;
  /// a move with no alternatives otherwise opens an empty sheet.
  final bool Function(String exerciseId)? canSwapMove;

  /// Whether a move needs kit, so a swapped-in move is drawn with a weight row
  /// only when it does. Null keeps what the replaced move had.
  final bool Function(String exerciseId)? needsEquipmentFor;

  /// Today's session already carries edits of hers, made earlier in this visit
  /// or before it, so the note that they are for today only is shown.
  final bool editedToday;

  /// What she said the programme has to train around (`O03`/`O04`).
  ///
  /// Pregnant or after a birth, the day is not written for her: nothing in
  /// this build is clinically reviewed for either. So the screen says so in a
  /// card above the moves, and Start becomes "I have my doctor's OK, start",
  /// with "Not today" beside it. Every other answer changes nothing here.
  final LifeStage? lifeStage;

  /// The day is a library session the owner marked for her life stage. The
  /// doctor card stays, saying what the session was written for rather than
  /// that it was not.
  final bool writtenForHerStage;

  /// "Not today", shown only with the card above. Falls back to [onBack].
  final VoidCallback? onNotToday;

  /// Called once the session has been created.
  final VoidCallback? onStart;

  final ValueChanged<PlannedMove>? onOpenMove;

  /// Whether a move has a demo to open. Null means every move does; a move
  /// with none is not tappable, and the hint under the list is dropped when no
  /// move has one.
  final bool Function(PlannedMove move)? canOpenMove;
  final VoidCallback? onMore;

  /// The move this week's challenge is about, and what it says (D38).
  final String? challengeExerciseId;
  final String? challengeNote;

  /// Today's assignment. Injectable; defaults to the design's day, built from
  /// the dictionary rather than written into the widget.
  final WorkoutDay? day;

  final TrainRepository? repository;

  @override
  State<WorkoutDayView> createState() => _WorkoutDayViewState();
}

class _WorkoutDayViewState extends State<WorkoutDayView> {
  TrainRepository? _fallbackRepository;

  /// The moves as edited here, or null until she edits. When a caller keeps the
  /// edits it hands them back in [WorkoutDayView.day], and this lets go.
  List<PlannedMove>? _moves;

  /// The move whose editor is open.
  int? _open;

  bool _changed = false;

  final LogCommandBus _ownBus = LogCommandBus();

  LogCommandBus get _bus => widget.undoBus ?? _ownBus;

  bool get _editable => widget.onMovesChanged != null;

  @override
  void didUpdateWidget(WorkoutDayView old) {
    super.didUpdateWidget(old);
    if (_editable) _moves = null;
  }

  List<PlannedMove> _list(BuildContext context) =>
      _moves ?? (widget.day ?? sampleWorkoutDay(AppL10n.of(context))).moves;

  void _commit(List<PlannedMove> next) {
    setState(() {
      _moves = next;
      _changed = true;
    });
    widget.onMovesChanged?.call(next);
  }

  String get _language => Localizations.localeOf(context).languageCode;

  void _editMove(int i, CustomMove next) {
    final list = [..._list(context)];
    list[i] = plannedMoveFromCustom(
      AppL10n.of(context),
      _language,
      next,
      like: list[i],
    );
    _commit(list);
  }

  void _offerUndo(String describe, VoidCallback onUndo) {
    final l10n = AppL10n.of(context);
    final handle = _bus.submit(
      UndoableLog(describe: describe, commit: () async {}),
    );
    showUndoSnackBar(
      context,
      handle: handle,
      undoLabel: l10n.undo,
      onUndo: () {
        if (mounted && (ModalRoute.of(context)?.isCurrent ?? true)) onUndo();
      },
    );
  }

  void _removeMove(int i) {
    final list = [..._list(context)];
    if (list.length <= 1) return;
    final removed = list.removeAt(i);
    setState(() => _open = null);
    _commit(list);
    _offerUndo(AppL10n.of(context).removedName(removed.name), () {
      final back = [..._list(context)];
      back.insert(i.clamp(0, back.length), removed);
      _commit(back);
    });
  }

  Future<void> _swapMove(int i) async {
    final l10n = AppL10n.of(context);
    final old = _list(context)[i];
    final finder =
        widget.alternativesFor ??
        widget.repository?.alternativesFor ??
        (String _) async => const <MoveAlternative>[];
    final found = await finder(old.exerciseId);
    if (!mounted) return;
    await showAppSheet<void>(
      context: context,
      children: [
        Text(l10n.swapThisMove, style: AppText.titleL),
        SwapChoices(
          candidates: found,
          onClose: () => Navigator.of(context).pop(),
          onConfirm: (alternative) {
            Navigator.of(context).pop();
            final list = [..._list(context)];
            if (i >= list.length || list[i].exerciseId != old.exerciseId) {
              return;
            }
            list[i] = PlannedMove(
              exerciseId: alternative.exerciseId,
              name: alternative.name,
              prescriptionLabel: old.prescriptionLabel,
              quiet: old.quiet,
              floorOnly: old.floorOnly,
              needsEquipment:
                  widget.needsEquipmentFor?.call(alternative.exerciseId) ??
                  old.needsEquipment,
              sets: [
                for (final set in old.sets)
                  PrescribedSet(
                    exerciseId: alternative.exerciseId,
                    order: set.order,
                    weightKg: set.weightKg,
                    reps: set.reps,
                    holdSeconds: set.holdSeconds,
                  ),
              ],
            );
            _commit(list);
            _offerUndo(l10n.swappedToNameForToday(alternative.name), () {
              final back = [..._list(context)];
              if (i < back.length) back[i] = old;
              _commit(back);
            });
          },
        ),
      ],
    );
  }

  Future<void> _addMoves() async {
    final pick = widget.onPickMoves;
    if (pick == null) return;
    final added = await pick();
    if (!mounted || added == null || added.isEmpty) return;
    final list = [..._list(context), ...added].take(kMaxCustomMoves).toList();
    setState(() => _open = list.length - 1);
    _commit(list);
  }

  /// Starts [day]: through the caller when there is one, here only when this
  /// screen is shown on its own.
  ///
  /// It did both. This started a session and then called the router's
  /// `onStart`, which started another, so every Start left an unfinished
  /// session behind in her history — and anything counting her sessions from
  /// that history counted one that never happened.
  Future<void> _start(WorkoutDay day) async {
    final onStart = widget.onStart;
    if (onStart != null) {
      // An undo offered for an edit must not outlive the screen it edits: once
      // she starts, the edits are the session.
      ScaffoldMessenger.maybeOf(context)?.hideCurrentSnackBar();
      onStart();
      return;
    }
    final repository =
        widget.repository ??
        (_fallbackRepository ??= InMemoryTrainRepository());
    final moves = _moves;
    await repository.startSession(
      moves == null
          ? day
          : WorkoutDay(
              id: day.id,
              title: day.title,
              summary: day.summary,
              constraints: day.constraints,
              moves: moves,
              planVersion: day.planVersion,
            ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppL10n.of(context);
    final day = widget.day ?? sampleWorkoutDay(l10n);
    final moves = _moves ?? day.moves;
    final summary = _moves == null
        ? day.summary
        : l10n.minutesMinutesMovesMoves(
            countLabel(estimateMinutes(moves)),
            countLabel(moves.length),
          );
    final canOpen = widget.canOpenMove ?? (_) => true;
    final caution = switch ((widget.lifeStage, widget.writtenForHerStage)) {
      (LifeStage.pregnant, true) => l10n.writtenForPregnancyCheckWithYourDoctor,
      (LifeStage.postpartum, true) => l10n.writtenForAfterABirthCheckWith,
      (LifeStage.pregnant, false) => l10n.day1WasNotWrittenForPregnancy,
      (LifeStage.postpartum, false) => l10n.day1WasNotWrittenForThe,
      _ => null,
    };

    return AppScaffold(
      appBar: AppTopBar(
        title: day.title,
        onBack: widget.onBack,
        actions: [
          // Drawn only when it does something: a disabled "more" reads as a
          // broken control.
          if (widget.onMore != null)
            IconButton(
              onPressed: widget.onMore,
              iconSize: 24,
              color: AppColors.onSurfaceVariant,
              // An icon with no name is announced as "button" and nothing else.
              tooltip: l10n.more,
              icon: const Icon(Icons.more_vert),
            ),
        ],
      ),
      footer: [
        AppButton(
          caution == null
              ? l10n.startEverythingsReady
              : l10n.iHaveMyDoctorsOkStart,
          icon: Icons.play_arrow,
          onPressed: moves.isEmpty ? null : () => _start(day),
        ),
        if (caution != null)
          AppButton(
            l10n.notToday,
            variant: AppButtonVariant.outlined,
            height: 48,
            fontSize: 15,
            onPressed: widget.onNotToday ?? widget.onBack,
          ),
      ],
      children: [
        if (caution != null)
          AppCard(
            key: const ValueKey('r03-doctor-first'),
            variant: AppCardVariant.amber,
            borderRadius: AppRadius.md,
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            children: [
              Text(
                caution,
                style: AppText.body.copyWith(color: AppColors.amber),
              ),
            ],
          ),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // What the day asks, underlined once in a steady pen. The moves
            // below carry their own marks, so nothing else here is drawn.
            HandUnderline(
              level: HandLevel.crafted,
              color: AppColors.primaryDim,
              gap: 3,
              child: Text(summary, style: AppText.titleL),
            ),
            const SizedBox(height: 4),
            Text(
              day.constraints,
              style: AppText.bodyM.copyWith(color: AppColors.onSurfaceVariant),
            ),
          ],
        ),
        // A long stretch before the moves begin, still; it blinks once the
        // second time she opens the day in a run.
        const Align(
          alignment: AlignmentDirectional.centerStart,
          child: Kitten(
            pose: KittenPose.stretch,
            size: 40,
            moment: 'R03',
            holdStill: true,
            blinkOnRevisit: true,
          ),
        ),
        // One block, so a different day eases in rather than the list jumping.
        // Keyed by which moves are in it, not by their labels: an edit changes
        // a label on every tap and must not replay the swap.
        HandSwap(
          child: Column(
            key: ValueKey(moves.map((m) => m.exerciseId).join('|')),
            crossAxisAlignment: CrossAxisAlignment.stretch,
            mainAxisSize: MainAxisSize.min,
            spacing: kStackGap,
            children: [
              for (var i = 0; i < moves.length; i++)
                Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  mainAxisSize: MainAxisSize.min,
                  spacing: 6,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: MoveRow(
                            name: moves[i].name,
                            detail: moves[i].prescriptionLabel,
                            // The first move is the one she is on. The design
                            // marked the second, which is a claim that she is
                            // already one move into a session she has not
                            // started: R03 is the screen with "Start,
                            // everything's ready" on it.
                            current: i == 0,
                            // This week's challenge, on the move it is about
                            // (D38).
                            note:
                                moves[i].exerciseId ==
                                    widget.challengeExerciseId
                                ? widget.challengeNote
                                : null,
                            hasClip:
                                widget.canOpenMove != null &&
                                AppRouter.screenIsOn('R04') &&
                                canOpen(moves[i]),
                            // Not tappable while the move videos are switched
                            // off.
                            onTap:
                                AppRouter.screenIsOn('R04') && canOpen(moves[i])
                                ? () => widget.onOpenMove?.call(moves[i])
                                : null,
                          ),
                        ),
                        if (_editable)
                          IconButton(
                            key: ValueKey('r03-edit-$i'),
                            tooltip: l10n.editThisMove,
                            onPressed: () =>
                                setState(() => _open = _open == i ? null : i),
                            icon: Icon(
                              _open == i ? Icons.expand_less : Icons.tune,
                              color: AppColors.primaryDim,
                            ),
                          ),
                      ],
                    ),
                    if (_editable && _open == i)
                      MoveEditor(
                        key: ValueKey('r03-editor-$i'),
                        move: customMoveOf(moves[i]),
                        showWeight:
                            moves[i].needsEquipment ||
                            moves[i].sets.any((s) => s.weightKg != null),
                        onChanged: (next) => _editMove(i, next),
                        onSwap:
                            widget.canSwapMove?.call(moves[i].exerciseId) ==
                                false
                            ? null
                            : () => _swapMove(i),
                        onRemove: moves.length > 1
                            ? () => _removeMove(i)
                            : null,
                      ),
                  ],
                ),
            ],
          ),
        ),
        if (_editable) ...[
          AppButton(
            l10n.addAMove,
            key: const ValueKey('r03-add'),
            icon: Icons.add,
            variant: AppButtonVariant.outlined,
            height: 48,
            fontSize: 15,
            onPressed:
                widget.onPickMoves == null || moves.length >= kMaxCustomMoves
                ? null
                : _addMoves,
          ),
          if (widget.onSaveAsMine != null)
            AppButton(
              l10n.saveAsMyWorkout,
              key: const ValueKey('r03-save-mine'),
              variant: AppButtonVariant.text,
              height: 44,
              fontSize: 15,
              onPressed: moves.isEmpty
                  ? null
                  : () => widget.onSaveAsMine?.call(moves),
            ),
          if (_changed || widget.editedToday)
            Text(
              l10n.changesHereAreForTodayOnly,
              style: AppText.bodyM.copyWith(color: AppColors.onSurfaceVariant),
            ),
        ],
        if (AppRouter.screenIsOn('R04') && moves.any(canOpen))
          Text(
            l10n.tapAnyMoveToWatchItOr,
            style: AppText.bodyM.copyWith(color: AppColors.onSurfaceVariant),
          ),
      ],
    );
  }
}
