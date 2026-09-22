/// What she tells the app about herself in the setup flow, O01–O05.
///
/// **`DECISIONS.md` D3 — ask early, editable forever.** Every answer here is
/// collected at setup and must stay editable in My Profile afterwards. That is a
/// property of the *type*, not a promise in a comment: [Intake] is an immutable
/// value with a [copyWith], there is no `completedAt`, no `locked`, no `frozen`
/// and no "first write wins" anywhere in this file, and the repository that
/// stores it exposes a merge rather than a create. Nothing collected once can be
/// made permanent by accident, because nothing in this file can express
/// permanence.
///
/// **§2 rule 3 — weeks, not days.** [days] is a *quantity per week*, never a run
/// of days and never a list of weekdays. There is no counter here that could
/// grow by one each morning, and `lib/domain/week/week_key.dart` holds the only
/// unit of time this product counts progress in. A daily tally would have to add
/// a type to hold it, which is a visible decision in a diff.
///
/// **§2 rule 11 — nothing is ranked by weight.** `loseSteadily` is a goal, not a
/// number. There is no target weight, no current weight, and no numeric input to
/// programme selection that could become a sort key.
///
/// Field names and enum wire values are `6-v2/plans/G2-onboarding-program.md`
/// §1.1 verbatim, so what this class holds and what `users/{uid}.profile` stores
/// cannot drift apart.
library;

import 'package:meta/meta.dart';

/// What she wants most. O01.
enum TrainingGoal {
  stronger('stronger'),
  feelBetter('feel_better'),
  loseSteadily('lose_steadily'),
  backIntoIt('back_into_it');

  const TrainingGoal(this.wireName);

  /// The string stored in `profile.goal`. Never the Dart enum name — a rename
  /// would otherwise silently rewrite everybody's profile.
  final String wireName;
}

/// Where she will train. O02.
enum TrainingPlace {
  home('home'),
  ladiesGym('ladies_gym'),
  both('both');

  const TrainingPlace(this.wireName);

  final String wireName;
}

/// What she has to train with. O02.
enum Equipment {
  none('none'),
  mat('mat'),
  dumbbells('dumbbells'),
  bands('bands');

  const Equipment(this.wireName);

  final String wireName;
}

/// What the programme has to train around. O04.
///
/// **This is safety-critical and it is not a diagnosis.** It selects what the
/// programme avoids; it never names a condition, never infers one, and never
/// tells her what is wrong with her. O04's copy — "we avoid what hurts, we do
/// not diagnose" — is the promise this enum has to keep.
///
/// What a pregnancy or postpartum programme may actually contain has no
/// authored, clinically-reviewed source yet (G2 §9 Q5), and the filter that acts
/// on this value is server-side (G2 §5). This enum records her answer and passes
/// it on; it decides nothing on its own.
enum LifeStage {
  none('none'),
  postpartum('postpartum'),
  pregnant('pregnant'),
  painInjury('pain_injury');

  const LifeStage(this.wireName);

  final String wireName;
}

/// Her answers to O01–O04.
///
/// The defaults are the options the design preselects, which is what makes
/// skipping every step safe: a skipped intake is a valid intake (G2 §3.2
/// `DEFAULTED`), so day one still has a real programme on it rather than a tour.
@immutable
class Intake {
  const Intake({
    this.goal = TrainingGoal.stronger,
    this.place = TrainingPlace.home,
    this.equipment = const {Equipment.none},
    this.days = 3,
    this.minutes = 15,
    this.lifeStage = LifeStage.none,
  }) : assert(days >= 2 && days <= 5, 'days a week runs 2–5'),
       assert(
         minutes == 10 || minutes == 15 || minutes == 20 || minutes == 30,
         'a session is 10, 15, 20 or 30 minutes',
       );

  /// What she gets if she skips every step. The design preselects each of these.
  static const Intake defaults = Intake();

  /// O01.
  final TrainingGoal goal;

  /// O02.
  final TrainingPlace place;

  /// O02. Always at least one entry — [Equipment.none] is an answer, not an
  /// absence of one.
  ///
  /// That invariant is upheld by [toggleEquipment] rather than by a constructor
  /// assert, because `Set.length` cannot be evaluated in a constant expression
  /// and [defaults] is a `const`. The rule lives in the one function that
  /// changes this set, which is also the only way a screen may change it.
  final Set<Equipment> equipment;

  /// O03. **Sessions per week**, and the origin of her weekly goal.
  ///
  /// Not a streak, not a run, not a set of weekdays. G6 derives
  /// `weeklyGoal.sessionsTarget` from this; a bad week never writes back here
  /// (G2 §9 Q7), so one quiet week cannot permanently shrink her programme.
  final int days;

  /// O03. Minutes per session.
  final int minutes;

  /// O04.
  final LifeStage lifeStage;

  /// The days a week she may choose. Order is the design's.
  static const List<int> allowedDays = [2, 3, 4, 5];

  /// The session lengths she may choose, in minutes.
  static const List<int> allowedMinutes = [10, 15, 20, 30];

  /// Turning one piece of equipment on or off.
  ///
  /// "Nothing" is exclusive in both directions: choosing it clears the rest,
  /// and choosing anything else clears it. This is a rule about the answer, so
  /// it lives here rather than in the widget that draws the chips — O02 is not
  /// the only screen that will ever edit equipment (D3 puts the same control in
  /// My Profile).
  ///
  /// Turning off the last remaining item falls back to [Equipment.none], because
  /// "I own nothing" and "I did not say" must not look the same to the
  /// programme builder.
  static Set<Equipment> toggleEquipment(
    Set<Equipment> current,
    Equipment item,
  ) {
    if (item == Equipment.none) return const {Equipment.none};

    final next = {...current, item}..remove(Equipment.none);
    if (current.contains(item)) next.remove(item);
    return next.isEmpty ? const {Equipment.none} : next;
  }

  Intake copyWith({
    TrainingGoal? goal,
    TrainingPlace? place,
    Set<Equipment>? equipment,
    int? days,
    int? minutes,
    LifeStage? lifeStage,
  }) {
    return Intake(
      goal: goal ?? this.goal,
      place: place ?? this.place,
      equipment: equipment ?? this.equipment,
      days: days ?? this.days,
      minutes: minutes ?? this.minutes,
      lifeStage: lifeStage ?? this.lifeStage,
    );
  }

  @override
  bool operator ==(Object other) =>
      other is Intake &&
      other.goal == goal &&
      other.place == place &&
      other.days == days &&
      other.minutes == minutes &&
      other.lifeStage == lifeStage &&
      other.equipment.length == equipment.length &&
      other.equipment.containsAll(equipment);

  @override
  int get hashCode => Object.hash(
    goal,
    place,
    days,
    minutes,
    lifeStage,
    Object.hashAllUnordered(equipment),
  );

  @override
  String toString() =>
      'Intake(${goal.wireName}, ${place.wireName}, '
      '${equipment.map((e) => e.wireName).join("+")}, ${days}d, ${minutes}min, '
      '${lifeStage.wireName})';
}
