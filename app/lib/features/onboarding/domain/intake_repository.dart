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
  InMemoryIntakeRepository([Intake? initial])
    : _intake = initial ?? Intake.defaults;

  Intake _intake;

  /// The field names touched by each [merge], oldest first.
  final List<Set<String>> writes = [];

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
}
