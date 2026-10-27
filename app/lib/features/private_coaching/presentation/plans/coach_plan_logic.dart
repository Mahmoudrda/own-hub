/// What the coach's plan builders decide without drawing anything: the edit
/// state the plan editor works on, the checks before a workout goes out, the
/// allergen flags on a meal plan and the day figures worked out from the app's
/// own tables.
///
/// A meal plan never holds a figure. These functions read the food pack and the
/// recipe book, so a number on screen cannot disagree with them.
library;

import 'dart:convert';

import 'package:flutter/foundation.dart' show VoidCallback;

import '../../../../app_state/app_changes.dart';
import '../../../../app_state/my_plan_state.dart';
import '../../../eat/domain/allergy_guard.dart';
import '../../../eat/domain/food_library.dart';
import '../../../eat/domain/recipe.dart';
import '../../../onboarding/domain/intake.dart' show LifeStage;
import '../../../train/domain/custom_workout.dart';
import '../../../train/domain/exercise_library.dart';
import '../../../train/domain/my_plan.dart';
import '../../../train/domain/train_repository.dart' show PlannedMove;
import '../../../train/domain/workout_library.dart';
import '../../domain/coach_plan.dart';
import '../../domain/coaching_contract.dart';

// ------------------------------------------------------------------ workout

/// The state the plan editor works on while a coach builds a plan for a
/// client. It is the editor's own copy: her personal plan in [MyPlanState] is
/// never read or written here.
class CoachPlanEditState implements MyPlanState {
  CoachPlanEditState([this.plan]);

  @override
  MyPlan? plan;

  @override
  MyPlan? pending;

  /// False on purpose: the editor offers "back to the original split" only
  /// for a plan that has one, and a coach's plan has no personal original.
  @override
  bool get hasPlan => false;

  @override
  MyPlan? get current => plan ?? pending;

  @override
  void save(MyPlan next) {
    plan = next;
    pending = null;
    AppChanges.bump();
  }

  @override
  void confirmPending() {}

  @override
  MyPlan preview(
    AuthoredProgramme template,
    LifeStage? stage, {
    VoidCallback? onConfirm,
  }) => plan ??= MyPlan.fork(template, stage: stage);

  @override
  MyPlan previewBlank() => plan ??= const MyPlan.blank();

  @override
  void backToOriginal() {}

  @override
  bool saveDayMoves({
    required AuthoredProgramme template,
    required LifeStage? stage,
    required int slot,
    required List<PlannedMove> moves,
  }) => false;

  @override
  void restore(MyPlan? saved) => plan = saved;

  @override
  void reset() => plan = null;
}

/// A plan taken from one of the three splits, the way the coach wrote it.
MyPlan planFromSplit(AuthoredProgramme split) => MyPlan.fork(split);

/// A plan taken from a template the coach saved, or null when it is not one.
MyPlan? planFromBody(Object? body) => MyPlan.tryParse(body);

/// [plan] named [name], keeping its days.
MyPlan renamedPlan(MyPlan plan, String name) => MyPlan(
  days: plan.days,
  sourceProgrammeId: plan.sourceProgrammeId,
  name: cleanWorkoutName(name),
  revision: plan.revision,
);

AuthoredMove authoredMoveOf(LibraryExercise e, CustomMove m) => AuthoredMove(
  exerciseId: e.id,
  nameEn: e.nameEn,
  nameAr: e.nameAr,
  sets: m.sets,
  reps: m.reps,
  holdSeconds: m.holdSeconds,
  restSeconds: m.timed ? 45 : 60,
  contraindications: <String>[for (final t in e.tags) t.wireName],
  quiet: e.quiet,
  floorOnly: e.floorOnly,
  needsEquipment: !e.equipment.every(
    (q) => q == LibraryEquipment.none || q == LibraryEquipment.mat,
  ),
);

CustomMove _customOf(AuthoredMove m) => CustomMove(
  exerciseId: m.exerciseId,
  sets: m.sets,
  reps: m.holdSeconds == null ? (m.reps ?? 10) : null,
  holdSeconds: m.holdSeconds,
);

AuthoredSession _sessionWith(
  AuthoredSession s, {
  String? title,
  List<AuthoredMove>? moves,
}) {
  final next = moves ?? s.moves;
  return AuthoredSession(
    sessionId: s.sessionId,
    titleEn: title ?? s.titleEn,
    titleAr: title ?? s.titleAr,
    minutes: estimateMinutesOf([for (final m in next) _customOf(m)]),
    lifeStages: s.lifeStages,
    moves: next,
  );
}

MyPlan _withDay(
  MyPlan plan,
  int i,
  AuthoredSession session, {
  List<double?>? kg,
}) {
  final old = plan.days[i];
  final days = [...plan.days];
  days[i] = MyPlanDay(
    session: session,
    sourceId: old.sourceId,
    targetKg:
        kg ??
        [
          for (var j = 0; j < session.moves.length; j++)
            j < old.targetKg.length ? old.targetKg[j] : null,
        ],
    week: old.week,
  );
  return MyPlan(
    days: List.unmodifiable(days),
    sourceProgrammeId: plan.sourceProgrammeId,
    name: plan.name,
    revision: plan.revision + 1,
  );
}

/// Day [i] called [name], in both languages.
MyPlan renameDay(MyPlan plan, int i, String name) {
  if (i < 0 || i >= plan.days.length) return plan;
  final clean = cleanWorkoutName(name);
  if (clean.isEmpty) return plan;
  return _withDay(plan, i, _sessionWith(plan.days[i].session, title: clean));
}

/// Move [move] of day [i] with new numbers. Reps and a hold are never both.
MyPlan changeMove(
  MyPlan plan,
  int i,
  int move, {
  int? sets,
  int? reps,
  int? holdSeconds,
}) {
  if (i < 0 || i >= plan.days.length) return plan;
  final session = plan.days[i].session;
  if (move < 0 || move >= session.moves.length) return plan;
  final m = session.moves[move];
  final timed = m.holdSeconds != null;
  final next = AuthoredMove(
    exerciseId: m.exerciseId,
    nameEn: m.nameEn,
    nameAr: m.nameAr,
    sets: (sets ?? m.sets).clamp(kMinSets, kMaxSets),
    reps: timed ? null : (reps ?? m.reps ?? 10).clamp(kMinReps, kMaxReps),
    holdSeconds: timed
        ? (holdSeconds ?? m.holdSeconds ?? 30).clamp(
            kMinHoldSeconds,
            kMaxHoldSeconds,
          )
        : null,
    restSeconds: m.restSeconds,
    notesEn: m.notesEn,
    notesAr: m.notesAr,
    safetyEn: m.safetyEn,
    safetyAr: m.safetyAr,
    contraindications: m.contraindications,
    quiet: m.quiet,
    floorOnly: m.floorOnly,
    needsEquipment: m.needsEquipment,
    supersetWithNext: m.supersetWithNext,
  );
  final moves = [...session.moves]..[move] = next;
  return _withDay(plan, i, _sessionWith(session, moves: moves));
}

/// Day [i] without move [move]. The last move stays: a day has at least one.
MyPlan removeMove(MyPlan plan, int i, int move) {
  if (i < 0 || i >= plan.days.length) return plan;
  final session = plan.days[i].session;
  if (session.moves.length < 2 || move < 0 || move >= session.moves.length) {
    return plan;
  }
  final kg = [...plan.days[i].targetKg]..length = session.moves.length;
  final moves = [...session.moves]..removeAt(move);
  kg.removeAt(move);
  return _withDay(plan, i, _sessionWith(session, moves: moves), kg: kg);
}

/// Move [move] of day [i] with a new rest, note, superset flag and target
/// weight. Pass only what changes. [clearKg] says "no target weight"
/// (bodyweight). The note is written in both languages, the way a day name is.
MyPlan changeMoveDetails(
  MyPlan plan,
  int i,
  int move, {
  int? restSeconds,
  String? note,
  bool? superset,
  double? kg,
  bool clearKg = false,
}) {
  if (i < 0 || i >= plan.days.length) return plan;
  final session = plan.days[i].session;
  if (move < 0 || move >= session.moves.length) return plan;
  final clean = note == null ? null : cleanNoteText(note);
  final next = session.moves[move].copyWith(
    restSeconds: restSeconds?.clamp(0, WorkoutLimits.maxRestSeconds),
    notesEn: clean,
    notesAr: clean,
    supersetWithNext: superset,
  );
  final moves = [...session.moves]..[move] = next;
  final targets = [...plan.days[i].targetKg]..length = session.moves.length;
  if (clearKg) {
    targets[move] = null;
  } else if (kg != null && kg >= kMinWeightKg) {
    targets[move] = kg.clamp(kMinWeightKg, kMaxWeightKg).toDouble();
  }
  return _withDay(plan, i, _sessionWith(session, moves: moves), kg: targets);
}

/// A note as one tidy line of at most the server's limit.
String cleanNoteText(String text) {
  final one = text.replaceAll(RegExp(r'\s+'), ' ').trim();
  return one.length > WorkoutLimits.maxText
      ? one.substring(0, WorkoutLimits.maxText).trim()
      : one;
}

MyPlan shiftMove(MyPlan plan, int i, int from, int to) {
  if (i < 0 || i >= plan.days.length) return plan;
  final session = plan.days[i].session;
  final n = session.moves.length;
  if (from < 0 || from >= n || to < 0 || to >= n) return plan;
  final kg = [...plan.days[i].targetKg]..length = n;
  final moves = [...session.moves];
  moves.insert(to, moves.removeAt(from));
  kg.insert(to, kg.removeAt(from));
  return _withDay(plan, i, _sessionWith(session, moves: moves), kg: kg);
}

/// Day [i] with [picked] added at the end, up to the most a day holds.
MyPlan addMoves(MyPlan plan, int i, Iterable<LibraryExercise> picked) {
  if (i < 0 || i >= plan.days.length) return plan;
  final session = plan.days[i].session;
  final moves = [...session.moves];
  for (final e in picked) {
    if (moves.length >= kMaxCustomMoves) break;
    moves.add(authoredMoveOf(e, CustomMove.starter(e)));
  }
  return _withDay(plan, i, _sessionWith(session, moves: moves));
}

/// [plan] with the library's safety tags written onto every move that carries
/// none, so the client's phone has them even for moves picked in the editor.
MyPlan stampSafetyTags(MyPlan plan, LibraryExercise? Function(String) byId) {
  var changed = false;
  final days = <MyPlanDay>[];
  for (final day in plan.days) {
    final moves = <AuthoredMove>[];
    for (final m in day.session.moves) {
      final e = byId(m.exerciseId);
      if (m.contraindications.isNotEmpty || e == null || e.tags.isEmpty) {
        moves.add(m);
        continue;
      }
      changed = true;
      moves.add(
        AuthoredMove(
          exerciseId: m.exerciseId,
          nameEn: m.nameEn,
          nameAr: m.nameAr,
          sets: m.sets,
          reps: m.reps,
          holdSeconds: m.holdSeconds,
          restSeconds: m.restSeconds,
          notesEn: m.notesEn,
          notesAr: m.notesAr,
          safetyEn: m.safetyEn,
          safetyAr: m.safetyAr,
          contraindications: <String>[for (final t in e.tags) t.wireName],
          quiet: m.quiet,
          floorOnly: m.floorOnly,
          needsEquipment: m.needsEquipment,
          supersetWithNext: m.supersetWithNext,
        ),
      );
    }
    days.add(
      MyPlanDay(
        session: AuthoredSession(
          sessionId: day.session.sessionId,
          titleEn: day.session.titleEn,
          titleAr: day.session.titleAr,
          minutes: day.session.minutes,
          lifeStages: day.session.lifeStages,
          moves: moves,
        ),
        sourceId: day.sourceId,
        targetKg: day.targetKg,
        week: day.week,
      ),
    );
  }
  if (!changed) return plan;
  return MyPlan(
    days: List.unmodifiable(days),
    sourceProgrammeId: plan.sourceProgrammeId,
    name: plan.name,
    revision: plan.revision,
  );
}

/// Why a workout cannot go out yet, as keys the screen words.
enum PlanProblem { noName, noDays, tooManyDays, tooBig, unknownMove }

/// The refusals the server would give, found before the call. [known] says
/// whether a move is in the exercise library; pass null while the library has
/// not loaded and the check is skipped.
List<PlanProblem> coachWorkoutProblems(
  MyPlan plan,
  String name, {
  bool Function(String exerciseId)? known,
}) {
  final out = <PlanProblem>[];
  final clean = name.trim();
  if (clean.isEmpty || clean.length > CoachingLimits.planNameMax) {
    out.add(PlanProblem.noName);
  }
  if (plan.days.isEmpty) out.add(PlanProblem.noDays);
  // The server's rule: weeks 1..n with no gap, a week's worth of days in each.
  final inWeek = [
    for (var w = 1; w <= plan.weekCount; w++) plan.daysOfWeek(w).length,
  ];
  if (inWeek.any((n) => n == 0) && !out.contains(PlanProblem.noDays)) {
    out.add(PlanProblem.noDays);
  }
  if (plan.weekCount > CoachingLimits.planMaxWeeks ||
      inWeek.any((n) => n > CoachingLimits.planMaxDays)) {
    out.add(PlanProblem.tooManyDays);
  }
  if (bodyBytes(plan.toJson()) > CoachingLimits.planBodyMaxBytes) {
    out.add(PlanProblem.tooBig);
  }
  if (known != null &&
      plan.days.any((d) => d.session.moves.any((m) => !known(m.exerciseId)))) {
    out.add(PlanProblem.unknownMove);
  }
  return out;
}

/// Bytes the body takes on the wire.
int bodyBytes(Object? body) => utf8.encode(jsonEncode(body)).length;

// --------------------------------------------------------------------- meal

/// The recipe book and the food pack a meal plan reads.
class MealCatalog {
  MealCatalog({
    Iterable<Recipe> recipes = const <Recipe>[],
    this.foods = FoodLibrary.empty,
  }) : recipes = List.unmodifiable(recipes),
       _byId = {for (final r in recipes) r.recipeId: r};

  final List<Recipe> recipes;
  final FoodLibrary foods;
  final Map<String, Recipe> _byId;

  Recipe? recipe(String id) => _byId[id];
  Food? food(String id) => foods.byId(id);

  /// What a line shows for [item].
  String title(MealItem item, String languageCode) {
    switch (item.kind) {
      case MealItemKind.recipe:
        final r = recipe(item.recipeId ?? '');
        if (r == null) return item.recipeId ?? '';
        final ar = r.titleAr;
        return languageCode == 'ar' && ar != null && ar.isNotEmpty
            ? ar
            : r.titleEn;
      case MealItemKind.food:
        final f = food(item.foodId ?? '');
        return f == null || f.names.isEmpty
            ? (item.foodId ?? '')
            : f.names.first;
      case MealItemKind.free:
        return item.text ?? '';
    }
  }
}

/// [servings] of the book recipe [r] as one portion of a food that can be
/// logged, or null when the book states no figures for it: nothing is invented
/// for a recipe whose macros are withheld. Its allergens count only when a
/// person or Own Hub's check stands behind them; otherwise they are unknown and
/// the allergy guard holds the log for a woman who named any.
Food? recipeAsFood(Recipe r, double servings, String title) {
  final kcal = r.kcal;
  final protein = r.proteinG;
  if (r.macroBasis != MacroBasis.computed || kcal == null || protein == null) {
    return null;
  }
  int? scaled(int? v) => v == null ? null : (v * servings).round();
  return Food(
    foodId: 'recipe_${r.recipeId}',
    names: [title],
    sizes: [
      FoodSize(
        id: 'serving',
        label: title,
        kcal: scaled(kcal)!,
        proteinG: scaled(protein)!,
        carbsG: scaled(r.carbsG),
        fatG: scaled(r.fatG),
      ),
    ],
    allergens: r.allergensKnown ? r.allergensFinal : null,
    dietTags: r.dietTags,
    custom: true,
  );
}

/// Whether "Log this" can put [r] in her day.
bool recipeCanBeLogged(Recipe? r) =>
    r != null && recipeAsFood(r, 1, '') != null;

/// The index of [item] among [planned], the plan's own items of one slot. A
/// swapped dish is the planned one it replaces; anything not found gets an
/// index past the end, so logging it never overwrites another row.
int plannedIndexOf(List<MealItem> planned, MealItem item) {
  final exact = planned.indexOf(item);
  if (exact >= 0) return exact;
  final swapped = planned.indexWhere(
    (p) => p.kind == MealItemKind.recipe && p.swaps.contains(item.recipeId),
  );
  return swapped >= 0 ? swapped : planned.length;
}

/// [body] with its days cut or grown to [count] (1 to 7). Days kept are not
/// touched; new ones are called [label] of their number.
MealPlanBody mealPlanWithDays(
  MealPlanBody body,
  int count,
  String Function(int number) label,
) {
  final n = count.clamp(1, CoachingLimits.planMaxDays);
  return MealPlanBody(
    days: [
      for (var i = 0; i < n; i++)
        if (i < body.days.length)
          body.days[i]
        else
          MealDay(label: label(i + 1)),
    ],
    goal: body.goal,
  );
}

MealPlanBody mealPlanWithItem(
  MealPlanBody body,
  int day,
  String slot,
  MealItem item,
) {
  if (day < 0 || day >= body.days.length) return body;
  final d = body.days[day];
  return _replaceDay(body, day, [...d.itemsIn(slot), item], slot);
}

MealPlanBody mealPlanWithoutItem(
  MealPlanBody body,
  int day,
  String slot,
  int index,
) {
  if (day < 0 || day >= body.days.length) return body;
  final items = [...body.days[day].itemsIn(slot)];
  if (index < 0 || index >= items.length) return body;
  items.removeAt(index);
  return _replaceDay(body, day, items, slot);
}

MealPlanBody _replaceDay(
  MealPlanBody body,
  int day,
  List<MealItem> items,
  String slot,
) {
  final d = body.days[day];
  final days = [...body.days];
  days[day] = MealDay(
    label: d.label,
    slots: <String, List<MealItem>>{
      for (final s in CoachingEnums.mealSlots) s: d.itemsIn(s),
      slot: items,
    },
  );
  return MealPlanBody(days: days, goal: body.goal);
}

/// [body] with the target set, or removed with null.
MealPlanBody mealPlanWithGoal(MealPlanBody body, MealGoal? goal) =>
    MealPlanBody(days: body.days, goal: goal);

/// [body] with [item]'s swaps at day/slot/index replaced.
MealPlanBody mealPlanWithSwaps(
  MealPlanBody body,
  int day,
  String slot,
  int index,
  List<String> swaps,
) {
  if (day < 0 || day >= body.days.length) return body;
  final items = [...body.days[day].itemsIn(slot)];
  if (index < 0 || index >= items.length) return body;
  final it = items[index];
  if (it.kind != MealItemKind.recipe) return body;
  items[index] = MealItem.recipe(
    it.recipeId!,
    it.servings!,
    note: it.note,
    swaps: {
      for (final s in swaps)
        if (s != it.recipeId) s,
    }.take(3).toList(),
  );
  return _replaceDay(body, day, items, slot);
}

/// Why a meal plan cannot go out yet.
List<PlanProblem> mealProblems(MealPlanBody body, String name) {
  final out = <PlanProblem>[];
  final clean = name.trim();
  if (clean.isEmpty || clean.length > CoachingLimits.planNameMax) {
    out.add(PlanProblem.noName);
  }
  final items = body.days.fold<int>(
    0,
    (sum, d) => sum + d.slots.values.fold<int>(0, (a, l) => a + l.length),
  );
  if (body.days.isEmpty || items == 0) out.add(PlanProblem.noDays);
  if (body.days.length > CoachingLimits.planMaxDays) {
    out.add(PlanProblem.tooManyDays);
  }
  if (!body.isValid && items > 0) out.add(PlanProblem.tooBig);
  if (bodyBytes(body.toJson()) > CoachingLimits.planBodyMaxBytes) {
    out.add(PlanProblem.tooBig);
  }
  return out;
}

/// Why an item was marked.
enum MealFlagKind {
  /// The dish is known to hold something she avoids.
  contains,

  /// Nobody has checked what is in it, and she avoids something.
  unchecked,
}

class MealFlag {
  const MealFlag({
    required this.day,
    required this.slot,
    required this.index,
    required this.kind,
    this.allergens = const <String>{},
  });

  final int day;
  final String slot;
  final int index;
  final MealFlagKind kind;
  final Set<String> allergens;
}

bool _same(String a, String b) =>
    a.trim().toLowerCase() == b.trim().toLowerCase();

Set<String> _hits(Iterable<String> tags, Set<String> declared) => {
  for (final t in tags)
    if (declared.any((a) => _same(a, t))) t,
};

/// The flag [item] earns for a woman who avoids [constraints]. Null when it is
/// clear, when she has declared nothing, or for a free line (a line of text
/// is not something the app can read).
({MealFlagKind kind, Set<String> allergens})? flagFor(
  MealItem item,
  DietaryConstraints constraints,
  MealCatalog catalog,
) {
  final declared = constraints.allergies;
  if (declared == null || declared.isEmpty) return null;
  switch (item.kind) {
    case MealItemKind.free:
      return null;
    case MealItemKind.recipe:
      final r = catalog.recipe(item.recipeId ?? '');
      if (r == null) return (kind: MealFlagKind.unchecked, allergens: const {});
      final hit = _hits(r.allergensFinal, declared);
      if (hit.isNotEmpty) return (kind: MealFlagKind.contains, allergens: hit);
      if (!r.allergensKnown) {
        return (kind: MealFlagKind.unchecked, allergens: const {});
      }
      return null;
    case MealItemKind.food:
      final f = catalog.food(item.foodId ?? '');
      if (f == null) return (kind: MealFlagKind.unchecked, allergens: const {});
      final hit = AllergyGuard(constraints).knownAllergens(f);
      if (hit.isNotEmpty) return (kind: MealFlagKind.contains, allergens: hit);
      if (f.allergens == null) {
        return (kind: MealFlagKind.unchecked, allergens: const {});
      }
      return null;
  }
}

/// Every marked item of [body], in order.
List<MealFlag> flagMealPlan(
  MealPlanBody body,
  DietaryConstraints constraints,
  MealCatalog catalog,
) {
  final out = <MealFlag>[];
  for (var d = 0; d < body.days.length; d++) {
    for (final slot in CoachingEnums.mealSlots) {
      final items = body.days[d].itemsIn(slot);
      for (var i = 0; i < items.length; i++) {
        final f = flagFor(items[i], constraints, catalog);
        if (f != null) {
          out.add(
            MealFlag(
              day: d,
              slot: slot,
              index: i,
              kind: f.kind,
              allergens: f.allergens,
            ),
          );
        }
      }
    }
  }
  return out;
}

/// What a day, a slot or an item adds up to. [partial] is true when some item
/// had no figures, so the total is a floor and the screen says so.
class Nutrition {
  const Nutrition({
    this.kcal = 0,
    this.proteinG = 0,
    this.carbsG = 0,
    this.fatG = 0,
    this.partial = false,
  });

  final int kcal;
  final int proteinG;
  final int carbsG;
  final int fatG;
  final bool partial;

  bool get isEmpty => kcal == 0 && proteinG == 0 && carbsG == 0 && fatG == 0;

  Nutrition plus(Nutrition o) => Nutrition(
    kcal: kcal + o.kcal,
    proteinG: proteinG + o.proteinG,
    carbsG: carbsG + o.carbsG,
    fatG: fatG + o.fatG,
    partial: partial || o.partial,
  );
}

/// Null when the tables hold no figures for [item].
Nutrition? itemNutrition(MealItem item, MealCatalog catalog) {
  switch (item.kind) {
    case MealItemKind.free:
      return null;
    case MealItemKind.recipe:
      final r = catalog.recipe(item.recipeId ?? '');
      final servings = item.servings;
      if (r == null ||
          servings == null ||
          r.macroBasis != MacroBasis.computed ||
          r.kcal == null) {
        return null;
      }
      int scale(int? v) => ((v ?? 0) * servings).round();
      return Nutrition(
        kcal: scale(r.kcal),
        proteinG: scale(r.proteinG),
        carbsG: scale(r.carbsG),
        fatG: scale(r.fatG),
      );
    case MealItemKind.food:
      final f = catalog.food(item.foodId ?? '');
      final grams = item.grams;
      if (f == null || grams == null || !f.verified) return null;
      final size = f.sizeForGrams(grams);
      if (size == null) return null;
      return Nutrition(
        kcal: size.kcal,
        proteinG: size.proteinG,
        carbsG: size.carbsG ?? 0,
        fatG: size.fatG ?? 0,
      );
  }
}

/// The sum over [items]; partial when any item has no figures.
Nutrition sumNutrition(Iterable<MealItem> items, MealCatalog catalog) {
  var total = const Nutrition();
  for (final item in items) {
    final n = itemNutrition(item, catalog);
    total = n == null
        ? total.plus(const Nutrition(partial: true))
        : total.plus(n);
  }
  return total;
}

Nutrition dayNutrition(MealDay day, MealCatalog catalog) => sumNutrition([
  for (final s in CoachingEnums.mealSlots) ...day.itemsIn(s),
], catalog);
