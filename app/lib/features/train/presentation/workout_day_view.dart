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

import 'dart:async';

import 'package:flutter/material.dart';

import '../../../app_state/honest_notice.dart';
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
import '../../../ui/app_list_item.dart';
import '../../../ui/app_overflow_menu.dart';
import '../../../ui/app_sheet.dart';
import '../../../ui/app_undo_snackbar.dart';
import '../../onboarding/domain/intake.dart' show LifeStage;
import '../../../ui/app_scaffold.dart';
import '../../../ui/hand/hand.dart';
import '../data/exercise_media_store.dart';
import '../domain/custom_workout.dart';
import '../domain/exercise_library.dart';
import '../domain/session_summary.dart' show nextWeightsFor;
import '../domain/weight_label.dart';
import '../domain/train_repository.dart';
import 'authored_workout.dart';
import 'exercise_clip_player.dart';
import 'move_editor.dart';
import 'move_preview_sheet.dart';
import 'swap_move_view.dart' show SwapChoices;
import 'update_saved_sheet.dart';
import 'train_widgets.dart';
import 'exercise_labels.dart';
import 'end_workout_sheet.dart';

export 'update_saved_sheet.dart' show SavedKind;

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
    restSeconds: move.restSeconds,
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
      name: l10n.donkeyKick,
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
      name: l10n.straightLegGluteKickback,
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
      name: l10n.forearmPlank,
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
      name: l10n.heelTouches,
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
    this.onOpenHistory,
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
    this.homeOnly = false,
    this.usesGymMachine,
    this.editedToday = false,
    this.undoBus,
    this.startInEditMode = false,
    this.onEditModeStarted,
    this.savedKind,
    this.onUpdateSaved,
    this.resetMoves,
    this.exerciseFor,
    this.media = const NoExerciseMedia(),
    this.players,
    this.holdLoad = false,
  });

  /// "Very sore" twice running: the weights below stay where they were.
  final bool holdLoad;

  /// Opens with Edit workout already on. Asked for by a door that means
  /// "change this workout" (Home's Edit, the plan editor's Edit).
  final bool startInEditMode;

  /// Told once when the screen has opened in edit mode, so the door's request
  /// is spent.
  final VoidCallback? onEditModeStarted;

  /// What the day is a copy of, when she keeps one. With [onUpdateSaved] it
  /// turns on "Update my saved workout?", asked once after she changes the day.
  final SavedKind? savedKind;

  /// Writes her edits to the workout or plan day this is. Called only when she
  /// answers Update; answers whether anything was kept, so she is told it was
  /// only when it was.
  final bool Function(List<PlannedMove> moves)? onUpdateSaved;

  /// The moves Reset goes back to. Null goes back to how the day was when she
  /// started editing.
  final List<PlannedMove>? resetMoves;

  /// The catalogue entry behind a move, so a swap can show its video before
  /// she chooses. Null swaps without a preview.
  final LibraryExercise? Function(String exerciseId)? exerciseFor;

  /// The clips' store and the player they play with.
  final ExerciseMediaStore media;
  final ExerciseClipPlayerFactory? players;

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

  /// She trains at home only. With [usesGymMachine], a day that holds a gym
  /// machine move says so and offers to swap it.
  final bool homeOnly;

  /// Whether a move is done on a gym machine or cable.
  final bool Function(String exerciseId)? usesGymMachine;

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

  /// Opens a move's history. Null leaves History out of the move's sheet.
  final ValueChanged<PlannedMove>? onOpenHistory;

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

  /// Edit workout is on.
  bool _editing = false;

  /// The moves as they were when she began editing; Reset goes back to them.
  List<PlannedMove>? _baseline;

  /// She has been asked whether to update the saved version.
  bool _asked = false;

  /// Her edits are kept in the saved version, so the note that they are for
  /// today only no longer holds.
  bool _keptInSaved = false;

  final LogCommandBus _ownBus = LogCommandBus();

  LogCommandBus get _bus => widget.undoBus ?? _ownBus;

  bool get _editable => widget.onMovesChanged != null;

  /// A change to a day she keeps that she has not been asked about yet.
  bool get _needsToAsk =>
      widget.onUpdateSaved != null &&
      widget.savedKind != null &&
      _changed &&
      !_asked;

  @override
  void initState() {
    super.initState();
    if (widget.startInEditMode && _editable) {
      _editing = true;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) widget.onEditModeStarted?.call();
      });
    }
  }

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
      _keptInSaved = false;
    });
    widget.onMovesChanged?.call(next);
  }

  void _setEditing(bool on) {
    if (on) {
      setState(() {
        _editing = true;
        _baseline ??= List.of(_list(context));
      });
      return;
    }
    setState(() {
      _editing = false;
      _open = null;
    });
    unawaited(_askToUpdate());
  }

  /// Back to how the day was when she began editing (or to the day the caller
  /// named), and out of any open editor.
  void _reset() {
    final back = widget.resetMoves ?? _baseline;
    if (back == null) return;
    setState(() => _open = null);
    _commit(List.of(back));
    setState(() {
      _changed = false;
      _keptInSaved = false;
    });
  }

  /// "Update my saved workout?", once, after she changed the day. Update writes
  /// her edits to the workout or plan day; Just this time leaves it alone.
  Future<bool> _askToUpdate() async {
    final update = widget.onUpdateSaved;
    final kind = widget.savedKind;
    if (update == null || kind == null || !_changed || _asked) return false;
    _asked = true;
    final l10n = AppL10n.of(context);
    final messenger = ScaffoldMessenger.maybeOf(context);
    final yes = await askUpdateSaved(context, kind);
    if (!yes || !mounted) return false;
    if (!update(_list(context))) return false;
    setState(() {
      _changed = false;
      _keptInSaved = true;
    });
    showHonestNoticeOn(
      messenger,
      kind == SavedKind.plan
          ? l10n.updatedInYourPlan
          : l10n.savedToYourWorkouts,
    );
    return true;
  }

  Future<void> _askThenLeave() async {
    await _askToUpdate();
    if (mounted) Navigator.of(context).pop();
  }

  void _shift(int i, int by) {
    final list = [..._list(context)];
    final j = i + by;
    if (j < 0 || j >= list.length) return;
    list.insert(j, list.removeAt(i));
    setState(() => _open = _open == null ? null : j);
    _commit(list);
  }

  void _reorder(int from, int to) {
    final list = [..._list(context)];
    if (from < 0 || from >= list.length || to < 0 || to >= list.length) return;
    if (from == to) return;
    list.insert(to, list.removeAt(from));
    setState(() => _open = null);
    _commit(list);
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
    final preview = widget.exerciseFor != null && found.isNotEmpty;
    await showAppSheet<void>(
      context: context,
      children: [
        Text(l10n.swapThisMove, style: AppText.titleL),
        if (preview)
          _SwapPreviewList(
            candidates: found,
            exerciseFor: widget.exerciseFor!,
            media: widget.media,
            players: widget.players,
            onClose: () => Navigator.of(context).pop(),
            onChoose: (alternative) {
              Navigator.of(context).pop();
              _applySwap(i, old, alternative);
            },
          )
        else
          SwapChoices(
            candidates: found,
            onClose: () => Navigator.of(context).pop(),
            onConfirm: (alternative) {
              Navigator.of(context).pop();
              _applySwap(i, old, alternative);
            },
          ),
      ],
    );
  }

  void _applySwap(int i, PlannedMove old, MoveAlternative alternative) {
    final l10n = AppL10n.of(context);
    final list = [..._list(context)];
    if (i >= list.length || list[i].exerciseId != old.exerciseId) return;
    list[i] = PlannedMove(
      exerciseId: alternative.exerciseId,
      name: alternative.name,
      prescriptionLabel: old.prescriptionLabel,
      quiet: old.quiet,
      floorOnly: old.floorOnly,
      restSeconds: old.restSeconds,
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
    // Once, if she changed a day she keeps: Update or Just this time.
    await _askToUpdate();
    if (!mounted) return;
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

  /// Every move with the buttons to change it where she can see them: Swap,
  /// Remove, Sets and reps, and a handle to drag it to another place.
  Widget _editList(AppL10n l10n, List<PlannedMove> moves) {
    final seen = <String, int>{};
    final keys = [
      for (final m in moves)
        ValueKey(
          'r03-row-${m.exerciseId}-${seen.update(m.exerciseId, (n) => n + 1, ifAbsent: () => 0)}',
        ),
    ];
    return ReorderableListView.builder(
      key: const ValueKey('r03-edit-list'),
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      buildDefaultDragHandles: false,
      itemCount: moves.length,
      onReorderItem: _reorder,
      itemBuilder: (context, i) {
        final move = moves[i];
        final swappable =
            widget.canSwapMove?.call(move.exerciseId) != false &&
            (widget.alternativesFor != null || widget.repository != null);
        return Padding(
          key: keys[i],
          padding: const EdgeInsets.only(bottom: kStackGap),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            mainAxisSize: MainAxisSize.min,
            spacing: 6,
            children: [
              Row(
                children: [
                  ReorderableDragStartListener(
                    index: i,
                    child: Semantics(
                      label: l10n.dragToReorder,
                      child: Tooltip(
                        message: l10n.dragToReorder,
                        child: SizedBox(
                          key: ValueKey('r03-handle-$i'),
                          width: 48,
                          height: 48,
                          child: const Icon(
                            Icons.drag_handle,
                            color: AppColors.primaryDim,
                          ),
                        ),
                      ),
                    ),
                  ),
                  Expanded(
                    child: MoveRow(
                      name: move.name,
                      detail: move.prescriptionLabel,
                      current: _open == i,
                      note: move.exerciseId == widget.challengeExerciseId
                          ? widget.challengeNote
                          : null,
                      onTap: () =>
                          setState(() => _open = _open == i ? null : i),
                    ),
                  ),
                ],
              ),
              Wrap(
                spacing: 4,
                runSpacing: 0,
                children: [
                  if (swappable)
                    _EditAction(
                      key: ValueKey('r03-swap-$i'),
                      label: l10n.swap,
                      icon: Icons.swap_horiz,
                      onPressed: () => unawaited(_swapMove(i)),
                    ),
                  _EditAction(
                    key: ValueKey('r03-remove-$i'),
                    label: l10n.remove,
                    icon: Icons.delete_outline,
                    onPressed: moves.length > 1 ? () => _removeMove(i) : null,
                  ),
                  _EditAction(
                    key: ValueKey('r03-edit-$i'),
                    label: l10n.setsAndReps,
                    icon: _open == i ? Icons.expand_less : Icons.tune,
                    onPressed: () =>
                        setState(() => _open = _open == i ? null : i),
                  ),
                ],
              ),
              if (_open == i)
                MoveEditor(
                  key: ValueKey('r03-editor-$i'),
                  move: customMoveOf(move),
                  showWeight:
                      move.needsEquipment ||
                      move.sets.any((s) => s.weightKg != null),
                  onChanged: (next) => _editMove(i, next),
                  onEarlier: i > 0 ? () => _shift(i, -1) : null,
                  onLater: i < moves.length - 1 ? () => _shift(i, 1) : null,
                ),
            ],
          ),
        );
      },
    );
  }

  /// What tapping move [i] does. One thing on offer (watching it) does it at
  /// once; more than one opens a sheet: watch, swap, history, edit its sets.
  /// Null when there is nothing to do, so the row is not a dead button.
  VoidCallback? _moveActions(
    AppL10n l10n,
    int i,
    List<PlannedMove> moves,
    bool Function(PlannedMove) canOpen,
  ) {
    final move = moves[i];
    final watch = AppRouter.screenIsOn('R04') && canOpen(move);
    final swappable =
        _editable &&
        widget.canSwapMove?.call(move.exerciseId) != false &&
        (widget.alternativesFor != null || widget.repository != null);
    final actions = <({String label, IconData icon, VoidCallback run})>[
      if (watch)
        (
          label: l10n.watchTheClip,
          icon: Icons.play_circle_outline,
          run: () => widget.onOpenMove?.call(move),
        ),
      if (swappable)
        (
          label: l10n.swap,
          icon: Icons.swap_horiz,
          run: () => unawaited(_swapMove(i)),
        ),
      if (widget.onOpenHistory != null)
        (
          label: l10n.history,
          icon: Icons.show_chart,
          run: () => widget.onOpenHistory!(move),
        ),
      if (_editable)
        (
          label: l10n.setsAndReps,
          icon: Icons.tune,
          run: () => setState(() => _open = _open == i ? null : i),
        ),
    ];
    if (actions.isEmpty) return null;
    if (actions.length == 1) return actions.single.run;
    return () => unawaited(
      showAppSheet<void>(
        context: context,
        gap: 8,
        children: [
          Text(move.name, style: AppText.titleL),
          for (final action in actions)
            Builder(
              builder: (sheet) => AppListItem(
                key: ValueKey('r03-move-${action.label}'),
                title: action.label,
                leading: Icon(action.icon, color: AppColors.onSurface),
                onTap: () {
                  Navigator.of(sheet).pop();
                  action.run();
                },
              ),
            ),
        ],
      ),
    );
  }

  /// What to lift today on up to three loaded moves she has weighed before:
  /// a step up, or the same weight. Never a lower one. Nothing when there is
  /// nothing to say.
  Widget _weightsToday(AppL10n l10n, List<PlannedMove> moves) {
    final weights = nextWeightsFor(
      repository: widget.repository,
      moves: moves,
      difficult: widget.holdLoad,
    );
    if (weights.isEmpty) return const SizedBox.shrink();
    return Column(
      key: const ValueKey('r03-weights-today'),
      crossAxisAlignment: CrossAxisAlignment.stretch,
      spacing: 4,
      children: [
        for (final move in weights)
          Text(
            move.rises
                ? l10n.todayWeightOnName(
                    '${weightLabel(move.kg)} ${l10n.kg}',
                    isolateLtr(l10n, move.name),
                  )
                : l10n.sameWeightOnNameAsLastTime(isolateLtr(l10n, move.name)),
            style: AppText.bodyM.copyWith(color: AppColors.onSurface),
          ),
      ],
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
    final machine = widget.usesGymMachine;
    final gymMove = widget.homeOnly && machine != null
        ? moves.indexWhere((m) => machine(m.exerciseId))
        : -1;
    final caution = switch ((widget.lifeStage, widget.writtenForHerStage)) {
      (LifeStage.pregnant, true) => l10n.writtenForPregnancyCheckWithYourDoctor,
      (LifeStage.postpartum, true) => l10n.writtenForAfterABirthCheckWith,
      (LifeStage.pregnant, false) => l10n.day1WasNotWrittenForPregnancy,
      (LifeStage.postpartum, false) => l10n.day1WasNotWrittenForThe,
      _ => null,
    };

    return PopScope(
      // Leaving with a change she has not been asked about asks first: the
      // change is hers to keep or to leave for today, and going back must not
      // quietly decide.
      canPop: !_needsToAsk,
      onPopInvokedWithResult: (didPop, _) {
        // Another PopScope above (the tour's) can refuse a pop that this one
        // allows; only a change of hers is this screen's to ask about.
        // While a workout is running the End workout question comes first.
        if (!didPop && _needsToAsk && !SessionEndGuard.holdingBack(context)) {
          unawaited(_askThenLeave());
        }
      },
      child: AppScaffold(
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
              )
            else if (_editable)
              AppOverflowMenu(
                items: [
                  if (!_editing)
                    AppOverflowItem(
                      icon: Icons.edit_outlined,
                      label: l10n.editMoves,
                      onTap: () => _setEditing(true),
                    ),
                  if (widget.onSaveAsMine != null && moves.isNotEmpty)
                    AppOverflowItem(
                      icon: Icons.bookmark_add_outlined,
                      label: l10n.saveAsMyWorkout,
                      onTap: () => widget.onSaveAsMine?.call(moves),
                    ),
                ],
              ),
          ],
        ),
        footer: _editing && _editable
            ? [
                // Leaving edit mode: the moves are as she left them, and the
                // day is one tap from Start again.
                AppButton(
                  l10n.done_54ca1,
                  key: const ValueKey('r03-edit-done'),
                  onPressed: () => _setEditing(false),
                ),
                AppButton(
                  l10n.reset,
                  key: const ValueKey('r03-reset'),
                  icon: Icons.restart_alt,
                  variant: AppButtonVariant.outlined,
                  height: 48,
                  fontSize: 15,
                  onPressed: (widget.resetMoves ?? _baseline) == null
                      ? null
                      : _reset,
                ),
              ]
            : [
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
                style: AppText.bodyM.copyWith(
                  color: AppColors.onSurfaceVariant,
                ),
              ),
            ],
          ),
          if (!_editing) _weightsToday(l10n, moves),
          if (_editable && gymMove >= 0)
            AppCard(
              key: const ValueKey('r03-gym-note'),
              variant: AppCardVariant.tonal,
              borderRadius: AppRadius.md,
              padding: const EdgeInsets.fromLTRB(14, 10, 8, 6),
              children: [
                Text(
                  l10n.thisDayUsesGymMachinesSwapA,
                  style: AppText.bodyM.copyWith(
                    color: AppColors.onPrimaryContainer,
                  ),
                ),
                Align(
                  alignment: AlignmentDirectional.centerEnd,
                  child: AppButton(
                    l10n.swap,
                    key: const ValueKey('r03-gym-swap'),
                    icon: Icons.swap_horiz,
                    variant: AppButtonVariant.text,
                    height: 48,
                    fontSize: 15,
                    onPressed: () {
                      if (!_editing) _setEditing(true);
                      unawaited(_swapMove(gymMove));
                    },
                  ),
                ),
              ],
            ),
          // One block, so a different day eases in rather than the list jumping.
          // Keyed by which moves are in it, not by their labels: an edit changes
          // a label on every tap and must not replay the swap.
          if (_editing && _editable)
            _editList(l10n, moves)
          else
            HandSwap(
              child: Column(
                key: ValueKey(moves.map((m) => m.exerciseId).join('|')),
                crossAxisAlignment: CrossAxisAlignment.stretch,
                mainAxisSize: MainAxisSize.min,
                spacing: kStackGap,
                children: [
                  // Flat, so the rows sit side by side as one list.
                  for (var i = 0; i < moves.length; i++) ...[
                    MoveRow(
                      key: ValueKey('r03-move-$i'),
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
                      note: moves[i].exerciseId == widget.challengeExerciseId
                          ? widget.challengeNote
                          : null,
                      hasClip:
                          widget.canOpenMove != null &&
                          AppRouter.screenIsOn('R04') &&
                          canOpen(moves[i]),
                      onTap: _moveActions(l10n, i, moves, canOpen),
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
                ],
              ),
            ),
          if (_editable && _editing)
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
          if (_editable && (_changed || widget.editedToday) && !_keptInSaved)
            Text(
              l10n.changesHereAreForTodayOnly,
              style: AppText.bodyM.copyWith(color: AppColors.onSurfaceVariant),
            ),
          if (AppRouter.screenIsOn('R04') && moves.any(canOpen))
            Text(
              l10n.tapAnyMoveToWatchItOr,
              style: AppText.bodyM.copyWith(color: AppColors.onSurfaceVariant),
            ),
        ],
      ),
    );
  }
}

/// A labelled button under a move in edit mode: an icon and a word, never the
/// icon alone, and at least 48 high.
class _EditAction extends StatelessWidget {
  const _EditAction({
    super.key,
    required this.label,
    required this.icon,
    required this.onPressed,
  });

  final String label;
  final IconData icon;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) => TextButton.icon(
    onPressed: onPressed,
    style: TextButton.styleFrom(
      minimumSize: const Size(48, 48),
      foregroundColor: AppColors.primaryDim,
      disabledForegroundColor: AppColors.onSurfaceVariant.withValues(
        alpha: 0.5,
      ),
      padding: const EdgeInsets.symmetric(horizontal: 10),
    ),
    icon: Icon(icon, size: 20),
    label: Text(label, style: AppText.label.copyWith(fontSize: 15)),
  );
}

/// The swap candidates, each opening its video before she chooses it.
class _SwapPreviewList extends StatelessWidget {
  const _SwapPreviewList({
    required this.candidates,
    required this.exerciseFor,
    required this.media,
    required this.players,
    required this.onChoose,
    required this.onClose,
  });

  final List<MoveAlternative> candidates;
  final LibraryExercise? Function(String exerciseId) exerciseFor;
  final ExerciseMediaStore media;
  final ExerciseClipPlayerFactory? players;
  final ValueChanged<MoveAlternative> onChoose;
  final VoidCallback onClose;

  Future<void> _open(BuildContext context, MoveAlternative choice) async {
    final exercise = exerciseFor(choice.exerciseId);
    if (exercise == null) {
      onChoose(choice);
      return;
    }
    final use = await showMovePreview(
      context,
      exercise: exercise,
      media: media,
      players: players,
      note: choice.reason,
    );
    if (use) onChoose(choice);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppL10n.of(context);
    return Column(
      key: const ValueKey('r03-swap-previews'),
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      spacing: kStackGap,
      children: [
        for (final choice in candidates)
          MoveRow(
            key: ValueKey('r03-swap-choice-${choice.exerciseId}'),
            name: choice.name,
            detail: choice.reason,
            hasClip: true,
            onTap: () => unawaited(_open(context, choice)),
          ),
        AppButton(
          l10n.close,
          variant: AppButtonVariant.text,
          height: 48,
          fontSize: 15,
          onPressed: onClose,
        ),
      ],
    );
  }
}
