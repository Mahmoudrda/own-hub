/// E07 — "This week" — and E08 — "Grocery list". One document, two screens.
///
/// G5 §2: E08 reads the **same** `mealPlans/{yyyy-Www}` document E07 already
/// loaded, so opening the list from the plan costs zero reads. That is why both
/// screens are built from one view model rather than two.
///
/// ## The week plan is recognisable, not aspirational
///
/// E07's design note: "built from recipes you have logged before". The candidate
/// dinners come from her own rollup, so the plan is made of food she already
/// cooks. A plan she has never cooked is a plan she will not follow, and it is
/// also the fastest way to make the feature feel like it is for somebody else.
///
/// ## Ticks are local-first
///
/// [tick] returns a new view immediately; the flush to the document is debounced
/// by the screen (2 s idle, screen exit, or backgrounding). E08's whole promise
/// is that it "survives being closed mid-shop", and a tick that waited for a
/// round-trip in a market with no signal would fail exactly when it is used.
///
/// Ticked lines keep their position rather than moving to the bottom. A list
/// that reorders itself under her thumb while she is shopping is harder to read
/// than one that does not.
library;

import 'package:meta/meta.dart';

import '../domain/meal_repository.dart';

/// One row of E07 — a weekday and the recipe planned for it.
@immutable
class DinnerRow {
  const DinnerRow({required this.day, this.recipeId});

  final PlanDay day;

  /// Null when that day has nothing planned yet. Rendered as an empty row she
  /// can fill, never as an error.
  final String? recipeId;

  bool get isPlanned => recipeId != null;
}

/// One section of E08, grouped the way a market trip actually goes.
@immutable
class GroceryGroupView {
  const GroceryGroupView({required this.group, required this.lines});

  final GroceryGroup group;
  final List<GroceryLine> lines;

  int get tickedCount => lines.where((l) => l.ticked).length;
}

/// What E07 and E08 render.
@immutable
class WeekPlanView {
  const WeekPlanView({
    required this.weekId,
    required this.dinners,
    required this.groups,
  });

  final String weekId;

  /// The five the design draws, Monday to Friday, always in that order and
  /// always all five — a missing day is an empty row, not an absent one.
  final List<DinnerRow> dinners;

  final List<GroceryGroupView> groups;

  /// True once anything has been planned. Before that E07 offers to build one
  /// rather than showing five blank rows with no explanation.
  bool get hasPlan => dinners.any((d) => d.isPlanned);

  int get itemCount => groups.fold(0, (sum, group) => sum + group.lines.length);

  int get tickedCount =>
      groups.fold(0, (sum, group) => sum + group.tickedCount);

  /// Every line ticked — the end of the shop.
  bool get isComplete => itemCount > 0 && tickedCount == itemCount;

  WeekPlanView _withGroups(List<GroceryGroupView> next) =>
      WeekPlanView(weekId: weekId, dinners: dinners, groups: next);
}

/// Builds [WeekPlanView] and applies her ticks.
class WeekPlanViewModel {
  const WeekPlanViewModel();

  /// The five days E07 draws. The document holds seven; the screen shows five,
  /// which is the design's choice and not a limit of the schema.
  static const List<PlanDay> plannedDays = [
    PlanDay.mon,
    PlanDay.tue,
    PlanDay.wed,
    PlanDay.thu,
    PlanDay.fri,
  ];

  /// The order the sections appear in, which is the order she shops in.
  static const List<GroceryGroup> groupOrder = [
    GroceryGroup.vegetables,
    GroceryGroup.protein,
    GroceryGroup.cupboard,
  ];

  WeekPlanView build({required String weekId, MealPlan? plan}) {
    return WeekPlanView(
      weekId: weekId,
      dinners: [
        for (final day in plannedDays)
          DinnerRow(day: day, recipeId: plan?.dinners[day]),
      ],
      groups: [
        for (final group in groupOrder)
          if (_linesIn(plan, group).isNotEmpty)
            GroceryGroupView(group: group, lines: _linesIn(plan, group)),
      ],
    );
  }

  /// Ticks or un-ticks one line, in place.
  ///
  /// Returns a new view with that line changed and every other line — and every
  /// position — untouched.
  WeekPlanView tick(WeekPlanView view, String itemKey, bool ticked) {
    return view._withGroups([
      for (final group in view.groups)
        GroceryGroupView(
          group: group.group,
          lines: [
            for (final line in group.lines)
              if (line.itemKey == itemKey)
                line.copyWith(
                  ticked: ticked,
                  tickedAt: ticked ? DateTime.now() : null,
                )
              else
                line,
          ],
        ),
    ]);
  }

  /// Swaps the recipe on one day. E07's "swap, do not rebuild".
  WeekPlanView swap(WeekPlanView view, PlanDay day, String recipeId) {
    return WeekPlanView(
      weekId: view.weekId,
      dinners: [
        for (final row in view.dinners)
          if (row.day == day) DinnerRow(day: day, recipeId: recipeId) else row,
      ],
      groups: view.groups,
    );
  }

  List<GroceryLine> _linesIn(MealPlan? plan, GroceryGroup group) {
    if (plan == null) return const <GroceryLine>[];
    return plan.groceries.values.where((l) => l.group == group).toList();
  }
}
