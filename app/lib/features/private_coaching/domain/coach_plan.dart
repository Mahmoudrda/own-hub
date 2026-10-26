/// A plan a coach shared: a workout in `MyPlan` shape, or a meal plan.
///
/// A meal plan holds no nutrition figures. The phone works them out from the
/// food pack and the recipe library, so a figure can never disagree with them.
library;

import '../../train/domain/my_plan.dart';
import 'coaching_contract.dart';
import 'parse.dart';

const int _maxItemsPerSlot = 12;
const int _maxDayLabel = 40;
const int _maxFreeText = 80;
const int _maxItemNote = 120;
const double _servingsMin = 0.25;
const double _servingsMax = 6;
const int _gramsMin = 1;
const int _gramsMax = 2000;

enum MealItemKind with WireEnum {
  recipe('recipe'),
  food('food'),
  free('free');

  const MealItemKind(this.wire);
  @override
  final String wire;

  static MealItemKind? fromWire(Object? value) => enumFromWire(values, value);
}

/// What Rahma wants a client to eat on an ordinary day. Her number, not a food
/// figure; the dish figures still come from the food tables.
class MealGoal {
  const MealGoal({required this.kcalPerDay, required this.proteinGPerDay});

  static const int kcalMin = 1200;
  static const int kcalMax = 4000;
  static const int proteinMin = 30;
  static const int proteinMax = 250;

  final int kcalPerDay;
  final int proteinGPerDay;

  static MealGoal? tryParse(Object? raw) {
    final map = asMap(raw);
    if (map == null) return null;
    final k = map['kcalPerDay'];
    final p = map['proteinGPerDay'];
    if (k is! int || p is! int) return null;
    final g = MealGoal(kcalPerDay: k, proteinGPerDay: p);
    return g.isValid ? g : null;
  }

  bool get isValid =>
      kcalPerDay >= kcalMin &&
      kcalPerDay <= kcalMax &&
      proteinGPerDay >= proteinMin &&
      proteinGPerDay <= proteinMax;

  Json toJson() => <String, Object?>{
    'kcalPerDay': kcalPerDay,
    'proteinGPerDay': proteinGPerDay,
  };
}

class MealItem {
  const MealItem._({
    required this.kind,
    this.recipeId,
    this.foodId,
    this.servings,
    this.grams,
    this.text,
    this.note,
    this.swaps = const <String>[],
  });

  const MealItem.recipe(
    String recipeId,
    double servings, {
    String? note,
    List<String> swaps = const <String>[],
  }) : this._(
         kind: MealItemKind.recipe,
         recipeId: recipeId,
         servings: servings,
         note: note,
         swaps: swaps,
       );

  const MealItem.food(String foodId, int grams, {String? note})
    : this._(kind: MealItemKind.food, foodId: foodId, grams: grams, note: note);

  /// "Her choice": a short line instead of a recipe or a food.
  const MealItem.free(String text, {String? note})
    : this._(kind: MealItemKind.free, text: text, note: note);

  final MealItemKind kind;
  final String? recipeId;
  final String? foodId;
  final double? servings;
  final int? grams;
  final String? text;
  final String? note;

  /// Recipe ids she approved as swaps, at most 3.
  final List<String> swaps;

  /// Null for an item that is not shaped like one.
  static MealItem? fromMap(Object? raw) {
    final map = asMap(raw);
    if (map == null) return null;
    final kind = MealItemKind.fromWire(map['kind']);
    if (kind == null) return null;
    final note = readStringOrNull(map['note']);
    switch (kind) {
      case MealItemKind.recipe:
        final id = readStringOrNull(map['recipeId']);
        final servings = map['servings'];
        if (id == null || servings is! num || !servings.isFinite) return null;
        final swaps = readStrings(map['swaps']).take(3).toList();
        return MealItem.recipe(
          id,
          servings.toDouble(),
          note: note,
          swaps: swaps,
        );
      case MealItemKind.food:
        final id = readStringOrNull(map['foodId']);
        final grams = map['grams'];
        if (id == null || grams is! num || !grams.isFinite) return null;
        return MealItem.food(id, grams.round(), note: note);
      case MealItemKind.free:
        final text = readStringOrNull(map['text']);
        if (text == null) return null;
        return MealItem.free(text, note: note);
    }
  }

  Json toJson() => <String, Object?>{
    'kind': kind.wire,
    ...switch (kind) {
      MealItemKind.recipe => <String, Object?>{
        'recipeId': recipeId,
        'servings': servings,
        if (swaps.isNotEmpty) 'swaps': swaps,
      },
      MealItemKind.food => <String, Object?>{'foodId': foodId, 'grams': grams},
      MealItemKind.free => <String, Object?>{'text': text},
    },
    if (note != null && note!.isNotEmpty) 'note': note,
  };

  bool get isValid {
    if (note != null && note!.length > _maxItemNote) return false;
    return switch (kind) {
      MealItemKind.recipe =>
        (recipeId ?? '').isNotEmpty &&
            servings != null &&
            servings! >= _servingsMin &&
            servings! <= _servingsMax &&
            swaps.length <= 3,
      MealItemKind.food =>
        (foodId ?? '').isNotEmpty &&
            grams != null &&
            grams! >= _gramsMin &&
            grams! <= _gramsMax,
      MealItemKind.free =>
        (text ?? '').trim().isNotEmpty && text!.length <= _maxFreeText,
    };
  }
}

class MealDay {
  const MealDay({required this.label, this.slots = const {}});

  final String label;

  /// Slot name (breakfast, lunch, dinner, snack) to its items.
  final Map<String, List<MealItem>> slots;

  List<MealItem> itemsIn(String slot) => slots[slot] ?? const <MealItem>[];

  static MealDay? fromMap(Object? raw) {
    final map = asMap(raw);
    if (map == null) return null;
    final label = readString(map['label']);
    if (label.isEmpty) return null;
    final rawSlots = asMap(map['slots']) ?? const <String, Object?>{};
    return MealDay(
      label: label,
      slots: <String, List<MealItem>>{
        for (final slot in CoachingEnums.mealSlots)
          if (rawSlots[slot] is List)
            slot: <MealItem>[
              for (final item in rawSlots[slot] as List)
                ?MealItem.fromMap(item),
            ],
      },
    );
  }

  Json toJson() => <String, Object?>{
    'label': label,
    'slots': <String, Object?>{
      for (final slot in CoachingEnums.mealSlots)
        slot: <Object?>[for (final item in itemsIn(slot)) item.toJson()],
    },
  };

  bool get isValid =>
      label.trim().isNotEmpty &&
      label.length <= _maxDayLabel &&
      slots.keys.every(CoachingEnums.mealSlots.contains) &&
      slots.values.every(
        (items) =>
            items.length <= _maxItemsPerSlot && items.every((i) => i.isValid),
      );
}

class MealPlanBody {
  const MealPlanBody({this.days = const <MealDay>[], this.goal});

  final List<MealDay> days;
  final MealGoal? goal;

  /// Null for anything that is not a meal body. A bad day costs that day.
  static MealPlanBody? tryParse(Object? raw) {
    final map = asMap(raw);
    if (map == null || map['days'] is! List) return null;
    return MealPlanBody(
      days: <MealDay>[
        for (final day in map['days'] as List) ?MealDay.fromMap(day),
      ].take(CoachingLimits.planMaxDays).toList(),
      goal: MealGoal.tryParse(map['goal']),
    );
  }

  Json toJson() => <String, Object?>{
    'days': <Object?>[for (final day in days) day.toJson()],
    if (goal != null) 'goal': goal!.toJson(),
  };

  bool get isValid =>
      days.isNotEmpty &&
      days.length <= CoachingLimits.planMaxDays &&
      days.every((d) => d.isValid) &&
      (goal == null || goal!.isValid);
}

class CoachPlan {
  const CoachPlan({
    required this.id,
    required this.kind,
    this.coachUid = '',
    this.coachName = '',
    this.subId = '',
    this.name = '',
    this.revision = 1,
    this.workout,
    this.meal,
    this.publishedAt,
    this.startsOn,
  });

  final String id;
  final PlanKind kind;
  final String coachUid;
  final String coachName;
  final String subId;
  final String name;
  final int revision;

  /// Set for a workout plan.
  final MyPlan? workout;

  /// Set for a meal plan.
  final MealPlanBody? meal;
  final DateTime? publishedAt;
  final DateTime? startsOn;

  /// Null when the kind is unknown or the body does not read as that kind.
  static CoachPlan? fromMap(String id, Object? raw) {
    final map = asMap(raw);
    if (map == null || id.isEmpty) return null;
    final kind = PlanKind.fromWire(map['kind']);
    if (kind == null) return null;
    final workout = kind == PlanKind.workout
        ? MyPlan.tryParse(map['body'])
        : null;
    final meal = kind == PlanKind.meal
        ? MealPlanBody.tryParse(map['body'])
        : null;
    if (workout == null && meal == null) return null;
    return CoachPlan(
      id: id,
      kind: kind,
      coachUid: readString(map['coachUid']),
      coachName: readString(map['coachName']),
      subId: readString(map['subId']),
      name: readString(map['name']),
      revision: readInt(map['revision'], 1),
      workout: workout,
      meal: meal,
      startsOn: _dateOnly(map['startsOn']),
      publishedAt: readTime(map['publishedAt']),
    );
  }
}

/// The body of `publish_coach_plan`.
Json publishPlanRequest({
  required String subId,
  required String name,
  MyPlan? workout,
  MealPlanBody? meal,
  String? planId,
  String? startsOn,
}) {
  assert((workout == null) != (meal == null), 'exactly one body');
  return <String, Object?>{
    'subId': subId,
    'kind': workout != null ? PlanKind.workout.wire : PlanKind.meal.wire,
    'name': name.trim(),
    'body': workout != null ? workout.toJson() : meal!.toJson(),
    'planId': ?planId,
    'startsOn': ?startsOn,
  };
}

/// A draft the coach keeps to reuse (`coaches/{uid}/drafts/{id}`).
class CoachDraft {
  const CoachDraft({
    required this.id,
    required this.kind,
    this.name = '',
    this.body = const <String, Object?>{},
    this.updatedAt,
  });

  final String id;
  final PlanKind kind;
  final String name;
  final Json body;
  final DateTime? updatedAt;

  static CoachDraft? fromMap(String id, Object? raw) {
    final map = asMap(raw);
    if (map == null || id.isEmpty) return null;
    final kind = PlanKind.fromWire(map['kind']);
    final body = asMap(map['body']);
    if (kind == null || body == null) return null;
    return CoachDraft(
      id: id,
      kind: kind,
      name: readString(map['name']),
      body: body,
      updatedAt: readTime(map['updatedAt']),
    );
  }

  /// The fields the coach may write (the rules fix this list). `updatedAt` is
  /// added by the repository.
  Json toWrite() => <String, Object?>{
    'kind': kind.wire,
    'name': name,
    'body': body,
  };
}

/// "2026-11-01" as a date-only DateTime, or null.
DateTime? _dateOnly(Object? raw) {
  if (raw is! String || raw.length != 10) return null;
  final d = DateTime.tryParse(raw);
  return d == null ? null : DateTime(d.year, d.month, d.day, 12);
}
