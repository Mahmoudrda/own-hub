/// Being coached — what `G01`–`G17` answer, log and read back.
///
/// The coached screens were the only flow in the app with no data of their own:
/// `G04` fell back to "Full body strength" and a hard-coded day strip, `G05`
/// drew preview days dated 2026-09-08, and `G01`, `G17`, `G02`, `G11` and `G12`
/// had no callbacks at all, so three intake steps and a week's logs went
/// nowhere. This file is where they go.
///
/// ## It reads the coach's document, and writes only her own
///
/// The plan is [CoachingDeskState.published] — the month her coach actually
/// published, with the coach's own titles and her own notes. Nothing here can
/// change it: [markSessionDone] and [logMeal] write **her logs**, and a log is
/// not a plan. That is G2's contract as a shape rather than as a rule, and it
/// is why `G06` shows her the session and `G09` records that she did it without
/// either touching the assignment.
///
/// ## What it still cannot do
///
///   * **Attach a photo or record a voice note.** `pubspec.yaml` carries no
///     picker and no recorder, so `G14`'s paperclip and `G15` stay as they
///     were — the same absence `B13` records.
///   * **Swap an exercise.** `G08` offers alternatives from the bundled pack,
///     and there is no pack in this build. Its list is empty rather than
///     invented.
library;

import '../domain/format/day_key.dart';
import '../l10n/app_l10n.dart';
import '../features/account/domain/dietary_profile.dart';
import '../features/coached/domain/coached_repository.dart' as coached;
import '../features/coached/domain/g2_contract.dart' as g2;
import '../features/coached/domain/intake.dart';
import '../features/coaching/domain/marketplace_stage.dart';
import '../features/coached/presentation/coached_widgets.dart' show StripDay;
import '../features/eat/presentation/eat_sample_library.dart';
import '../features/coachplan/domain/plan/plan_draft.dart';
import 'app_changes.dart';
import 'coaching_desk_state.dart';
import 'coaching_link_state.dart';

/// One meal she logged, kept only long enough to undo it.
class LoggedMeal {
  const LoggedMeal({required this.day, required this.slot, required this.at});

  final String day;
  final PlanMealSlot slot;
  final DateTime at;
}

class CoachedLifeState {
  CoachedLifeState._();

  static final CoachedLifeState instance = CoachedLifeState._();

  CoachingLinkState get link => CoachingLinkState.instance;
  CoachingDeskState get desk => CoachingDeskState.instance;

  String get clientUid => CoachingLinkState.clientUid;

  /// Her relationship, or null when she has no coach.
  ///
  /// The snapshot exists only once she has paid, and the relationship exists
  /// from the moment the coach accepted — which is when the thread opens and
  /// when the intake has somewhere to go. So the accept is enough.
  String? get relId {
    final snapshot = link.myCoachSnapshot;
    if (snapshot != null) return snapshot.relId;
    for (final entry in link.enquiries.entries) {
      final stage = link.stageWith(entry.value.coachUid);
      if (stage == MarketplaceStage.acceptedAwaitingPayment ||
          stage == MarketplaceStage.coached) {
        return entry.key;
      }
    }
    return null;
  }

  /// The coach she is working with, by the same rule.
  String get coachName {
    final snapshot = link.myCoachSnapshot;
    if (snapshot != null) return snapshot.coachName;
    for (final entry in link.enquiries.entries) {
      final stage = link.stageWith(entry.value.coachUid);
      if (stage == MarketplaceStage.acceptedAwaitingPayment ||
          stage == MarketplaceStage.coached) {
        return link.coachNameFor(entry.value.coachUid);
      }
    }
    return '';
  }

  /// The month her coach published, or null while she is still being prepared.
  PublishedMonth? get plan => desk.published[clientUid];

  bool get hasPlan => plan != null;

  // ─────────────────────────────────────────────────────────── her day

  /// The day she is looking at. Null means today.
  String? selectedDay;

  /// Today, unless today falls outside the published month — in which case the
  /// first day of the plan, because a woman on the 2nd of next month should see
  /// the plan she has rather than an empty screen.
  String get today {
    final month = plan;
    final now = dayKey(DateTime.now());
    if (month == null) return now;
    if (month.dayAt(now) != null) return now;
    final days = month.dayKeys;
    return days.isEmpty ? now : days.first;
  }

  String get day => selectedDay ?? today;

  void selectDay(String value) {
    selectedDay = value;
    AppChanges.bump();
  }

  PlanDay? get planDay => plan?.dayAt(day);

  DraftWorkout? get workout => planDay?.workout;

  /// The seven days of the week she is looking at, as they are keyed.
  List<String> get weekDays {
    final month = plan;
    if (month == null) return const <String>[];
    final all = CoachingDeskState.monthDays(month.plan.month);
    if (all.isEmpty) return const <String>[];
    final at = all.indexOf(day);
    final start = at < 0 ? 0 : (at ~/ 7) * 7;
    return all.skip(start).take(7).toList(growable: false);
  }

  /// `G04`'s strip, from her own dates.
  ///
  /// The weekday abbreviations are the dictionary's — the strip is narrow, so
  /// the short forms are the only ones that fit, and they exist for all seven.
  List<StripDay> stripDays(AppL10n l10n) => <StripDay>[
    for (final key in weekDays)
      if (_dateOf(key) case final date?)
        StripDay(
          weekday: switch (date.weekday) {
            DateTime.monday => l10n.mon,
            DateTime.tuesday => l10n.tue,
            DateTime.wednesday => l10n.wed,
            DateTime.thursday => l10n.thu,
            DateTime.friday => l10n.fri,
            DateTime.saturday => l10n.sat,
            _ => l10n.sun,
          },
          dayOfMonth: '${date.day}',
        ),
  ];

  int get selectedIndexInWeek {
    final week = weekDays;
    final at = week.indexOf(day);
    return at < 0 ? 0 : at;
  }

  /// `G05`'s month grid, counted from the plan and from her logs.
  ///
  /// `done` is **her log**, never the plan: a day the plan asked for is not a
  /// day she did.
  List<coached.PlanDay> get calendar {
    final month = plan;
    if (month == null) return const <coached.PlanDay>[];
    final now = dayKey(DateTime.now());
    final days = month.dayKeys;
    return <coached.PlanDay>[
      for (var i = 0; i < days.length; i++)
        if (_dateOf(days[i]) case final date?)
          coached.PlanDay(
            dayNumber: i + 1,
            kind: month.dayAt(days[i])!.isRest
                ? g2.PlanDayKind.rest
                : g2.PlanDayKind.train,
            date: date,
            done: desk.sessionsDone.contains(days[i]),
            isToday: days[i] == now,
          ),
    ];
  }

  /// Which day of the plan she is on — "Day 9 of 30", from her own dates.
  ///
  /// Null before anything is published, so `G04` draws no day pill rather than
  /// the mockup's ninth day.
  ({int day, int total})? get dayNumber {
    final month = plan;
    if (month == null) return null;
    final days = month.dayKeys;
    final at = days.indexOf(day);
    if (at < 0) return null;
    return (day: at + 1, total: days.length);
  }

  // ─────────────────────────────────────────────────────── her sessions

  /// The set she is on, inside `G06`. Reset when she opens a new day.
  int setsCompleted = 0;

  void completeSet() {
    setsCompleted++;
    AppChanges.bump();
  }

  bool get sessionDone => desk.sessionsDone.contains(day);

  /// `G09`. Records that she trained — in her logs, not in the plan.
  void markSessionDone() {
    desk.sessionsDone.add(day);
    AppChanges.bump();
  }

  /// `G09`'s effort chip. Hers, and nothing derives a score from it.
  int effort = 1;

  void setEffort(int value) {
    effort = value;
    AppChanges.bump();
  }

  // ────────────────────────────────────────────────────────── her meals

  /// Slots she has logged, by day.
  final Map<String, Set<PlanMealSlot>> logged = <String, Set<PlanMealSlot>>{};

  /// The slot `G10` has open.
  PlanMealSlot slot = PlanMealSlot.breakfast;

  void openSlot(PlanMealSlot value) {
    slot = value;
    AppChanges.bump();
  }

  /// The last thing she logged, for the five-second undo. One tap, never a
  /// confirm — rule 9.
  LoggedMeal? lastLogged;

  MealSlotAssignment? assignmentFor(PlanMealSlot which) =>
      planDay?.meal?.slots[which];

  /// What one planned slot is called, in her language.
  ///
  /// Null when her coach planned nothing there — an empty row rather than a
  /// dish nobody chose. A stated free choice is an answer and reads as one.
  String? mealTitle(AppL10n l10n, PlanMealSlot which) {
    final assignment = assignmentFor(which);
    if (assignment == null) return null;
    switch (assignment.source) {
      case MealSlotSource.freeChoice:
        return l10n.herChoice;
      case MealSlotSource.coach:
        return desk.meals[assignment.coachMealId]?.name;
      case MealSlotSource.library:
        if (assignment.foodIds.isEmpty) return null;
        // G5's stand-in pack is resolved from the dictionary, so it is built
        // here rather than held — the same thing every Eat screen does.
        desk.useFoods(eatSampleLibrary(l10n));
        final food = desk.foods.byId(assignment.foodIds.first);
        return food == null || food.names.isEmpty ? null : food.names.first;
    }
  }

  /// What is in it, when it is one of her coach's own dishes. Her coach's own
  /// lines, shown verbatim, so the dish stays cookable.
  List<String>? mealIngredients(PlanMealSlot which) {
    final assignment = assignmentFor(which);
    if (assignment?.source != MealSlotSource.coach) return null;
    final meal = desk.meals[assignment!.coachMealId];
    if (meal == null || meal.ingredients.isEmpty) return null;
    return <String>[for (final line in meal.ingredients) line.text];
  }

  bool isLogged(String onDay, PlanMealSlot which) =>
      logged[onDay]?.contains(which) ?? false;

  void logMeal() {
    logged.putIfAbsent(day, () => <PlanMealSlot>{}).add(slot);
    desk.mealDays.add(day);
    lastLogged = LoggedMeal(day: day, slot: slot, at: DateTime.now());
    AppChanges.bump();
  }

  /// `G11`'s undo. Takes the log back out, and the day with it when it was the
  /// only thing logged that day.
  void undoLastMeal() {
    final last = lastLogged;
    if (last == null) return;
    logged[last.day]?.remove(last.slot);
    if (logged[last.day]?.isEmpty ?? false) {
      logged.remove(last.day);
      desk.mealDays.remove(last.day);
    }
    lastLogged = null;
    AppChanges.bump();
  }

  /// How many portions she said she ate. `G11`'s chips.
  int portion = 1;

  void setPortion(int value) {
    portion = value;
    AppChanges.bump();
  }

  // ─────────────────────────────────────────────────────────── the intake

  late final InMemoryDietaryProfileRepository dietary =
      InMemoryDietaryProfileRepository();

  late final InMemoryCoachingIntakeRepository intake =
      InMemoryCoachingIntakeRepository(profile: dietary);

  /// `G01`'s four answers, held as the screen's own indices.
  int goal = 0;
  Set<int> trainingDays = <int>{1};
  int sessionLength = 1;
  Set<int> places = <int>{};

  /// `G17`. Empty is an answer — "she was asked and named nothing" — and null
  /// is nobody having asked, which is why these start empty only once she has
  /// opened the step.
  Set<AllergenTag> allergens = <AllergenTag>{};
  Set<DietaryTag> diets = <DietaryTag>{};
  int cookMinutes = 1;
  bool familyPot = true;

  /// `G02`.
  bool dailyCheckin = true;

  void setGoal(int value) {
    goal = value;
    AppChanges.bump();
  }

  void toggleTrainingDay(int value) {
    if (!trainingDays.remove(value)) trainingDays.add(value);
    AppChanges.bump();
  }

  void setSessionLength(int value) {
    sessionLength = value;
    AppChanges.bump();
  }

  void togglePlace(int value) {
    if (!places.remove(value)) places.add(value);
    AppChanges.bump();
  }

  void toggleAllergen(int index) {
    final tag = AllergenTag.values[index];
    if (!allergens.remove(tag)) allergens.add(tag);
    AppChanges.bump();
  }

  void setDiet(int index) {
    diets = <DietaryTag>{DietaryTag.values[index]};
    AppChanges.bump();
  }

  void setCookMinutes(int value) {
    cookMinutes = value;
    AppChanges.bump();
  }

  void setFamilyPot(bool value) {
    familyPot = value;
    AppChanges.bump();
  }

  void setDailyCheckin(bool value) {
    dailyCheckin = value;
    AppChanges.bump();
  }

  /// `G01` → `G17`. Writes only the training fields.
  void saveTraining() {
    final id = relId;
    if (id == null) return;
    intake.mergeTraining(relId: id);
    AppChanges.bump();
  }

  /// `G17` → `G02`. Her allergies go to her **profile**, which is the one place
  /// they live, and the coach's planner reads them from there.
  void saveFood() {
    final id = relId;
    if (id == null) return;
    intake.mergeFood(
      relId: id,
      cookMinutes: cookMinutes,
      familyPot: familyPot,
      allergies: allergens,
      dietary: diets,
    );
    desk.declareDiet(allergies: allergens, dietary: diets);
    AppChanges.bump();
  }

  /// `G02`'s send. Completes the intake; her coach can now plan.
  void submitIntake() {
    final id = relId;
    if (id == null) return;
    intake.mergeSupport(relId: id, dailyCheckin: dailyCheckin);
    intake.submit(relId: id, at: DateTime.now());
    AppChanges.bump();
  }

  static DateTime? _dateOf(String key) {
    final parts = key.split('-');
    if (parts.length != 3) return null;
    final year = int.tryParse(parts[0]);
    final month = int.tryParse(parts[1]);
    final day = int.tryParse(parts[2]);
    if (year == null || month == null || day == null) return null;
    return DateTime(year, month, day);
  }

  // ─────────────────────────────────────────────────────────────── tests

  /// Back to a woman who has never been coached.
  void reset() {
    selectedDay = null;
    setsCompleted = 0;
    effort = 1;
    logged.clear();
    lastLogged = null;
    slot = PlanMealSlot.breakfast;
    portion = 1;
    goal = 0;
    trainingDays = <int>{1};
    sessionLength = 1;
    places = <int>{};
    allergens = <AllergenTag>{};
    diets = <DietaryTag>{};
    cookMinutes = 1;
    familyPot = true;
    dailyCheckin = true;
  }
}
