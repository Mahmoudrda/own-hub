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

import '../../../l10n/app_l10n.dart';
import '../../../theme/app_tokens.dart';
import '../../../domain/format/day_key.dart';
import '../../../domain/training/prescribed_set.dart';
import '../../../ui/app_button.dart';
import '../../../ui/app_scaffold.dart';
import '../../../ui/hand/hand.dart';
import '../domain/train_repository.dart';
import 'train_widgets.dart';

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
WorkoutDay sampleWorkoutDay(AppL10n l10n, {DateTime? now}) => WorkoutDay(
id: dayKey(now ?? DateTime.now()),
  title: l10n.legsAndGlutes,
  summary: l10n.n15Minutes5Moves,
  constraints: l10n.quietNoEquipmentFloor,
  moves: [
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
      exerciseId: 'goblet_squat',
      name: l10n.gobletSquat,
      prescriptionLabel: l10n.n31012KgSuggested,
      needsEquipment: true,
      cues: [
        l10n.heelsFlatKneesOutOverYourToes,
        l10n.chestUpWeightHeldAtYourChest,
        l10n.standUpStrongSqueezeAtTheTop,
      ],
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
    ),
    PlannedMove(
      exerciseId: 'step_back_lunge',
      name: l10n.stepBackLunge,
      prescriptionLabel: l10n.n310EachSide,
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
      floorOnly: true,
      sets: const [
        PrescribedSet(
          exerciseId: 'hip_thrust_hold',
          order: 1,
          holdSeconds: 30,
        ),
        PrescribedSet(
          exerciseId: 'hip_thrust_hold',
          order: 2,
          holdSeconds: 30,
        ),
        PrescribedSet(
          exerciseId: 'hip_thrust_hold',
          order: 3,
          holdSeconds: 30,
        ),
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
  ],
);

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
  });

  final VoidCallback? onBack;

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

    return AppScaffold(
      appBar: AppTopBar(
        title: day.title,
        onBack: widget.onBack,
        actions: [
          IconButton(
            onPressed: widget.onMore,
            iconSize: 24,
            color: AppColors.onSurfaceVariant,
            icon: const Icon(Icons.more_vert),
          ),
        ],
      ),
      footer: [
        AppButton(
          l10n.startEverythingsReady,
          icon: Icons.play_arrow,
          onPressed: () => _start(day),
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
            // The second move is the one she is on, as the design has it.
            current: i == 1,
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
