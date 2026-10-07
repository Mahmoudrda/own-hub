/// R03 — Workout day.
///
/// Matches `6-v2/src/screens-train.mjs` → `R03`. The day is a list of moves with
/// the suggested weights already on them, and **both ways in are on the same
/// screen**: start it now, or say she already did it. That second route is not a
/// fallback — most women train without the phone in their hand.
///
/// The weights shown here are prescriptions. Nothing on this screen can become a
/// result: starting a session creates it with every outcome null, and the
/// repository refuses to persist one that arrives otherwise.
library;

import 'package:flutter/material.dart';

import '../../../domain/clock/app_clock.dart';
import '../../../l10n/app_l10n.dart';
import '../../../theme/app_tokens.dart';
import '../../../domain/format/day_key.dart';
import '../../../domain/format/number_label.dart';
import '../../../domain/training/prescribed_set.dart';
import '../../../ui/app_button.dart';
import '../../../ui/app_card.dart';
import '../../onboarding/domain/intake.dart' show LifeStage;
import '../../../ui/app_scaffold.dart';
import '../../../ui/hand/hand.dart';
import '../domain/train_repository.dart';
import 'train_widgets.dart';

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
      exerciseId: 'glute_bridge',
      name: l10n.gluteBridge,
      prescriptionLabel: l10n.n312Bodyweight,
      quiet: true,
      floorOnly: true,
      sets: const [
        PrescribedSet(exerciseId: 'glute_bridge', order: 1, reps: 12),
        PrescribedSet(exerciseId: 'glute_bridge', order: 2, reps: 12),
        PrescribedSet(exerciseId: 'glute_bridge', order: 3, reps: 12),
      ],
    ),
    PlannedMove(
      exerciseId: 'step_back_lunge',
      name: l10n.stepBackLunge,
      prescriptionLabel: l10n.n310EachSide,
      // Quiet: a step back has no jump and no impact. Flagged rather than
      // left at the default, because R11's "quiet" filter reads these and a
      // session offered as quiet has to be quiet move by move.
      quiet: true,
      sets: const [
        PrescribedSet(exerciseId: 'step_back_lunge', order: 1, reps: 10),
        PrescribedSet(exerciseId: 'step_back_lunge', order: 2, reps: 10),
        PrescribedSet(exerciseId: 'step_back_lunge', order: 3, reps: 10),
      ],
    ),
    PlannedMove(
      exerciseId: 'hip_thrust_hold',
      name: l10n.hipThrustHold,
      prescriptionLabel: l10n.n330Seconds,
      quiet: true,
      floorOnly: true,
      sets: const [
        PrescribedSet(exerciseId: 'hip_thrust_hold', order: 1, holdSeconds: 30),
        PrescribedSet(exerciseId: 'hip_thrust_hold', order: 2, holdSeconds: 30),
        PrescribedSet(exerciseId: 'hip_thrust_hold', order: 3, holdSeconds: 30),
      ],
    ),
    PlannedMove(
      exerciseId: 'dead_bug',
      name: l10n.deadBug,
      prescriptionLabel: l10n.n38EachSide,
      quiet: true,
      floorOnly: true,
      sets: const [
        PrescribedSet(exerciseId: 'dead_bug', order: 1, reps: 8),
        PrescribedSet(exerciseId: 'dead_bug', order: 2, reps: 8),
        PrescribedSet(exerciseId: 'dead_bug', order: 3, reps: 8),
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

/// The bundled library, as `R11` lists it.
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
    this.onAlreadyDidIt,
    this.onOpenMove,
    this.onMore,
    this.day,
    this.repository,
    this.lifeStage,
    this.writtenForHerStage = false,
    this.onNotToday,
  });

  final VoidCallback? onBack;

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

  /// T02 — she trained without the phone.
  final VoidCallback? onAlreadyDidIt;

  final ValueChanged<PlannedMove>? onOpenMove;
  final VoidCallback? onMore;

  /// Today's assignment. Injectable; defaults to the design's day, built from
  /// the dictionary rather than written into the widget.
  final WorkoutDay? day;

  final TrainRepository? repository;

  @override
  State<WorkoutDayView> createState() => _WorkoutDayViewState();
}

class _WorkoutDayViewState extends State<WorkoutDayView> {
  TrainRepository? _fallbackRepository;

  Future<void> _start(WorkoutDay day) async {
    final repository =
        widget.repository ??
        (_fallbackRepository ??= InMemoryTrainRepository());
    await repository.startSession(day);
    if (!mounted) return;
    widget.onStart?.call();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppL10n.of(context);
    final day = widget.day ?? sampleWorkoutDay(l10n);
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
          onPressed: () => _start(day),
        ),
        if (caution != null)
          AppButton(
            l10n.notToday,
            variant: AppButtonVariant.outlined,
            height: 48,
            fontSize: 15,
            onPressed: widget.onNotToday ?? widget.onBack,
          ),
        AppButton(
          l10n.iAlreadyDidIt,
          variant: AppButtonVariant.text,
          height: 44,
          fontSize: 15,
          onPressed: widget.onAlreadyDidIt,
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
              child: Text(day.summary, style: AppText.titleL),
            ),
            const SizedBox(height: 4),
            Text(
              day.constraints,
              style: AppText.bodyM.copyWith(color: AppColors.onSurfaceVariant),
            ),
          ],
        ),
        for (var i = 0; i < day.moves.length; i++)
          MoveRow(
            name: day.moves[i].name,
            detail: day.moves[i].prescriptionLabel,
            // The first move is the one she is on. The design marked the
            // second, which is a claim that she is already one move into a
            // session she has not started: R03 is the screen with "Start,
            // everything's ready" on it.
            current: i == 0,
            onTap: () => widget.onOpenMove?.call(day.moves[i]),
          ),
        Text(
          l10n.tapAnyMoveToWatchItOr,
          style: AppText.bodyM.copyWith(color: AppColors.onSurfaceVariant),
        ),
      ],
    );
  }
}
