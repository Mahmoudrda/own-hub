/// Where her setup answers are read and written.
///
/// **The only write is a merge, and that is the point.** `DECISIONS.md` D3 says
/// every answer is collected early and stays editable forever, and
/// `6-v2/plans/G2-onboarding-program.md` §2 says each step writes only its own
/// fields to one deterministic document. Both come out the same way: there is no
/// `create`, no `complete`, and no write that replaces the whole intake. A caller
/// can only name the fields it is changing.
///
/// That shape buys three things at once:
///
///  * **Abandonment is a designed path.** Every setup screen carries `Skip` and
///    a close. Four partial merges leave four real answers, not a half-written
///    record that has to be repaired.
///  * **Offline is safe.** Writes to distinct field keys merge commutatively, so
///    two phones finishing setup do not overwrite each other's answers
///    (`SCHEMA-SPINE.md` C3 — last-write-wins loses data for anything two
///    devices can touch).
///  * **My Profile is the same call.** Editing her goal a month later is the
///    identical merge O01 makes, so the "editable forever" half of D3 needs no
///    second path that could behave differently.
///
/// The Firestore implementation belongs in `data/` and writes
/// `users/{uid}.profile` with `SetOptions(merge: true)`. It does not exist yet;
/// [InMemoryIntakeRepository] is what the screens and their tests run against.
library;

import 'intake.dart';

abstract class IntakeRepository {
  /// Her answers so far, with [Intake.defaults] standing in for anything she has
  /// not answered.
  ///
  /// Never null and never empty: a woman who skipped every step still has a
  /// complete, valid intake, which is what lets day one show a real programme.
  Intake read();

  /// Whether she has answered where she trains (`O02`).
  ///
  /// The one-screen "Your week" never asks it, so her place stays the
  /// default, home. Nothing may read that default back to her as her answer:
  /// `herAnswersLine` drops the place when this is false.
  bool get placeAnswered;

  /// Writes **only** the fields named, and returns the merged result.
  ///
  /// An omitted argument is not "set this to null" — it is "do not touch this".
  /// Equipment is passed as a whole set because the set is the answer;
  /// [Intake.toggleEquipment] is how a screen turns one item on or off.
  Future<Intake> merge({
    TrainingGoal? goal,
    TrainingPlace? place,
    Set<Equipment>? equipment,
    int? days,
    int? minutes,
    LifeStage? lifeStage,
  });
}

/// An in-memory implementation, for tests and for building the screens before
/// there is a Firebase project.
///
/// It records which fields each call wrote, because "O03 wrote days and minutes
/// and nothing else" is the assertion that proves the per-step merge is real
/// rather than a whole-object save wearing a merge's name.
class InMemoryIntakeRepository implements IntakeRepository {
  /// An [initial] intake counts as answered unless [placeAnswered] says
  /// otherwise; with none she has answered nothing.
  InMemoryIntakeRepository([Intake? initial, bool? placeAnswered])
    : _intake = initial ?? Intake.defaults,
      _placeAnswered = placeAnswered ?? initial != null;

  Intake _intake;

  bool _placeAnswered;

  @override
  bool get placeAnswered => _placeAnswered;

  /// The field names touched by each [merge], oldest first.
  final List<Set<String>> writes = [];

  bool _setupDone = false;

  /// Whether she has already been through the setup walk, finished **or**
  /// skipped.
  ///
  /// This is what stops `O01` opening on top of Home a second time, so it is
  /// deliberately a fact about the *walk* and not about her answers. Read that
  /// distinction carefully, because the class comment on [Intake] forbids the
  /// other one: nothing here makes an answer permanent, nothing is locked, and
  /// `A02`'s "Your training" row runs the identical four questions whenever she
  /// wants. A woman who skipped every step is done with setup and still has
  /// every answer open to her.
  ///
  /// False until [markSetupDone], and false again after [reset] — deleting
  /// everything is a fresh start, and a fresh start includes being asked.
  bool get setupDone => _setupDone;

  /// Records that the walk is over. Idempotent.
  void markSetupDone() => _setupDone = true;

  @override
  Intake read() => _intake;

  @override
  Future<Intake> merge({
    TrainingGoal? goal,
    TrainingPlace? place,
    Set<Equipment>? equipment,
    int? days,
    int? minutes,
    LifeStage? lifeStage,
  }) async {
    writes.add({
      if (goal != null) 'goal',
      if (place != null) 'place',
      if (equipment != null) 'equipment',
      if (days != null) 'days',
      if (minutes != null) 'minutes',
      if (lifeStage != null) 'lifeStage',
    });

    if (place != null) _placeAnswered = true;
    _intake = _intake.copyWith(
      goal: goal,
      place: place,
      equipment: equipment,
      days: days,
      minutes: minutes,
      lifeStage: lifeStage,
    );
    return _intake;
  }

  /// Puts back the answers she had already given when the app closed.
  ///
  /// The storage layer calls it at launch, before any screen exists, and
  /// [writes] stays empty because nothing was merged — see
  /// `lib/app_state/local_persistence.dart`.
  ///
  /// [setupDone] defaults to false so that a document written by a build from
  /// before the walk existed asks her the four questions once. It is an
  /// argument rather than a separate call because restoring her answers and
  /// forgetting that she had answered them is not a state this app should be
  /// able to reach.
  ///
  /// [placeAnswered] defaults to false for the same reason: a document that
  /// does not say she was asked where she trains is read as not asked.
  void restore(
    Intake intake, {
    bool setupDone = false,
    bool placeAnswered = false,
  }) {
    _intake = intake;
    _setupDone = setupDone;
    _placeAnswered = placeAnswered;
  }

  /// Back to a woman who has answered nothing.
  ///
  /// Account deletion calls it: the intake IS her setup answers, and leaving
  /// them behind would hand a deleted account's goal and equipment to whoever
  /// opened the app next.
  void reset() {
    _intake = Intake.defaults;
    _setupDone = false;
    _placeAnswered = false;
    writes.clear();
  }
}
