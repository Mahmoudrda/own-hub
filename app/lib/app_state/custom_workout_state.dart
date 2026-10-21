/// Her own workouts, and the edits she has made to today's session.
///
/// Two different things live here because they answer to the same screen.
///
///  * [workouts] are hers to keep. They are saved in the local snapshot and
///    synced to `users/{uid}/splits/{splitId}`. [deletedIds] remembers what she
///    deleted so a copy still in the cloud is not folded back in.
///  * The [draft] is today's session as she has reshaped it on R03, before she
///    starts. It is never saved on its own: it applies to the day it was made
///    on and to the session it was made from, and it is cleared when she
///    starts, when the date moves on, or when she opens a different session.
library;

import '../domain/clock/app_clock.dart';
import '../domain/format/day_key.dart';
import '../features/train/domain/custom_workout.dart';
import '../features/train/domain/train_repository.dart';
import 'app_changes.dart';

/// Today's session as edited on R03.
class TodayDraft {
  const TodayDraft({
    required this.day,
    required this.dayKey,
    this.baseKey,
    this.customId,
  });

  final WorkoutDay day;

  /// The date it was made on.
  final String dayKey;

  /// What it was edited from. Null when it is pinned: a saved workout she
  /// opened, which stands in for whatever the plan would have offered.
  final String? baseKey;

  /// The saved workout it came from, so "Save" updates it and does not make a
  /// copy.
  final String? customId;
}

class CustomWorkoutState {
  CustomWorkoutState._();

  static final CustomWorkoutState instance = CustomWorkoutState._();

  /// Newest first.
  List<CustomWorkout> workouts = const <CustomWorkout>[];

  /// Ids she deleted, oldest first.
  List<String> deletedIds = const <String>[];

  TodayDraft? draft;

  /// Set by a door that wants Train to open the builder as soon as it shows.
  bool builderRequested = false;

  /// Identifies a session by its own id and what it contains, so an edit made
  /// to one is never applied to another, and a language switch does not lose
  /// the edits (the title is translated, the id is not).
  static String keyOf(WorkoutDay day) =>
      '${day.id}|${day.moves.map((m) => m.exerciseId).join(',')}';

  CustomWorkout? byId(String id) {
    for (final workout in workouts) {
      if (workout.id == id) return workout;
    }
    return null;
  }

  /// A fresh id for a workout: sortable, and accepted by the rules.
  String newId() {
    final base = AppClock.now().microsecondsSinceEpoch;
    var n = 0;
    while (true) {
      final id = 'w${(base + n).toRadixString(36)}';
      if (byId(id) == null && !deletedIds.contains(id)) return id;
      n++;
    }
  }

  /// Whether a workout with a new id has room to be kept.
  bool get isFull => workouts.length >= kMaxCustomWorkouts;

  /// Adds [workout] or replaces the one with its id. A workout she had deleted
  /// and now saves again is no longer deleted. False, and nothing changes,
  /// when she already keeps the most she can and this one is new.
  bool save(CustomWorkout workout) {
    if (byId(workout.id) == null && isFull) return false;
    final stamped = workout.copyWith(updatedAt: AppClock.now());
    workouts = <CustomWorkout>[
      stamped,
      for (final other in workouts)
        if (other.id != workout.id) other,
    ];
    deletedIds = [
      for (final id in deletedIds)
        if (id != workout.id) id,
    ];
    AppChanges.bump();
    return true;
  }

  /// Takes [id] out and remembers it as deleted. Returns it, with where it
  /// was, so Undo can put it back.
  ({CustomWorkout workout, int index})? remove(String id) {
    final index = workouts.indexWhere((w) => w.id == id);
    if (index < 0) return null;
    final removed = workouts[index];
    workouts = [
      for (final w in workouts)
        if (w.id != id) w,
    ];
    deletedIds = [
      ...deletedIds.where((other) => other != id),
      id,
    ].reversed.take(kMaxDeletedWorkouts).toList().reversed.toList();
    if (draft?.customId == id) draft = null;
    AppChanges.bump();
    return (workout: removed, index: index);
  }

  /// Undo of [remove].
  void restore(CustomWorkout workout, int index) {
    if (byId(workout.id) != null) return;
    final next = [...workouts];
    next.insert(index.clamp(0, next.length), workout);
    workouts = next.take(kMaxCustomWorkouts).toList();
    deletedIds = [
      for (final id in deletedIds)
        if (id != workout.id) id,
    ];
    AppChanges.bump();
  }

  /// Folds a workout the cloud holds into this phone, never bringing back one
  /// she deleted. One already here is replaced only by a copy stamped newer.
  /// True when something changed.
  bool adoptRemote(CustomWorkout workout) {
    if (deletedIds.contains(workout.id)) return false;
    final local = byId(workout.id);
    if (local != null) {
      final theirs = workout.updatedAt;
      final mine = local.updatedAt;
      if (theirs == null || (mine != null && !theirs.isAfter(mine))) {
        return false;
      }
      workouts = [
        for (final w in workouts)
          if (w.id == workout.id) workout else w,
      ];
      return true;
    }
    if (workouts.length >= kMaxCustomWorkouts) return false;
    workouts = [...workouts, workout];
    return true;
  }

  /// A deletion the cloud recorded, from another install of hers. The copy on
  /// this phone goes too.
  bool adoptRemoteDeletion(String id) {
    final had = byId(id) != null;
    if (!deletedIds.contains(id)) {
      deletedIds = [
        ...deletedIds,
        id,
      ].reversed.take(kMaxDeletedWorkouts).toList().reversed.toList();
    }
    if (had) {
      workouts = [
        for (final w in workouts)
          if (w.id != id) w,
      ];
    }
    return had;
  }

  /// The snapshot's say-so, replacing both lists.
  void restoreSaved({
    required List<CustomWorkout> saved,
    required List<String> deleted,
  }) {
    workouts = saved.take(kMaxCustomWorkouts).toList();
    deletedIds = deleted.take(kMaxDeletedWorkouts).toList();
  }

  // ----------------------------------------------------------------- draft --

  /// Today's edits to [baseKey]'s session, or a pinned saved workout, or null.
  WorkoutDay? draftFor(String baseKey) {
    final current = draft;
    if (current == null) return null;
    if (current.dayKey != dayKey(AppClock.now())) {
      draft = null;
      return null;
    }
    if (current.baseKey != null && current.baseKey != baseKey) return null;
    return current.day;
  }

  /// Records [day] as today's session, edited from the session keyed
  /// [baseKey]. A pinned draft stays pinned.
  void setDraft(WorkoutDay day, {required String baseKey}) {
    final current = draft;
    final today = dayKey(AppClock.now());
    final mine =
        current != null &&
        current.dayKey == today &&
        (current.baseKey == null || current.baseKey == baseKey);
    draft = TodayDraft(
      day: day,
      dayKey: today,
      baseKey: mine && current.baseKey == null ? null : baseKey,
      customId: mine ? current.customId : null,
    );
    AppChanges.bump();
  }

  /// Makes [day] today's session whatever the plan would have offered.
  void pin(WorkoutDay day, {String? customId}) {
    draft = TodayDraft(
      day: day,
      dayKey: dayKey(AppClock.now()),
      customId: customId,
    );
    AppChanges.bump();
  }

  /// Today's session is now the saved workout [id], so a second save updates
  /// it rather than making a copy.
  void linkDraft(String id) {
    final current = draft;
    if (current == null) return;
    draft = TodayDraft(
      day: current.day,
      dayKey: current.dayKey,
      baseKey: current.baseKey,
      customId: id,
    );
  }

  /// Forgets today's edits. Quiet by default: callers that go on to navigate
  /// do not need every open screen redrawn first.
  void clearDraft({bool notify = false}) {
    if (draft == null) return;
    draft = null;
    if (notify) AppChanges.bump();
  }

  /// Puts back the edits [remove] cleared, for Undo, if it is still the day
  /// they were made on and nothing has replaced them.
  void restoreDraft(TodayDraft previous) {
    if (draft != null || previous.dayKey != dayKey(AppClock.now())) return;
    draft = previous;
    AppChanges.bump();
  }

  /// Asks Train to open the builder when it next shows. One use.
  bool takeBuilderRequest() {
    final asked = builderRequested;
    builderRequested = false;
    return asked;
  }

  /// Back to nothing: an account deleted, or a test.
  void reset() {
    workouts = const <CustomWorkout>[];
    deletedIds = const <String>[];
    draft = null;
    builderRequested = false;
  }
}
