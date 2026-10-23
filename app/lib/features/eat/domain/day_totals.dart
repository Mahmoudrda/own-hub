/// The running total — and the reason a calorie countdown cannot be rendered.
///
/// G5 §1.5, quoted in `PHASE2-ACCEPTANCE.md`:
///
/// > There is **no `kcalRemaining`, no `kcalTarget`, no `deficit`, no `over`
/// > field anywhere in the G5 domain or data model** — the same technique C6
/// > uses against `streak`. A widget cannot render a calorie countdown because
/// > nothing computes one.
///
/// So this type holds her running totals and offers exactly one ratio. There
/// is no arithmetic here that subtracts kcal from anything, and no second type
/// that could hold the result of one. A screen that wanted a countdown would
/// have to add a field, which is a visible change in a diff — the same shape of
/// enforcement `WeekKey` uses against a daily streak.
///
/// `test/product_rules_test.dart` scans `lib/features/` for the banned names, so
/// this folder is already inside the guard.
///
/// ## Protein is the only target, and its denominator is not ours
///
/// kcal renders as prose ("About 1,106 kcal so far today"); protein renders as a
/// bar that fills. That asymmetry is the product rule, not a layout choice.
///
/// [proteinTargetG] is **supplied, never computed here.** G5 §9 Q1 records that
/// the target is unowned: G2 defines no `nutrition` field, and the figure needs
/// body mass, which lives in G6's private `measurements` and must not spread.
/// No group computes it, so this file does not invent a formula for it — it
/// takes the number it is given and says plainly where it came from.
library;

import 'package:meta/meta.dart';

import 'meal_repository.dart';

/// The denominator E01 and E04 draw, until a group owns it.
///
/// This is the mockup's literal "95 g", which the dictionary already ships as
/// finished copy (`n22Of95G`, `n53Of95G`). It is a **placeholder with a name**,
/// not a computed target: G5 §9 Q1 is blocking and unresolved, and the working
/// assumption recorded there is a Remote Config constant until G2 publishes
/// `assignments/{date}.nutrition.proteinTargetG`.
///
/// Named here rather than typed inline on four screens, so that when the target
/// becomes real there is one place to change and one place to search for.
const int kProvisionalProteinTargetG = 95;

/// What she has eaten today, and the one target this product keeps.
@immutable
class DayTotals {
  const DayTotals({
    required this.kcalSoFar,
    required this.proteinSoFar,
    required this.proteinTargetG,
    this.carbsSoFar,
    this.fatSoFar,
    this.fiberSoFar,
  });

  /// A day with nothing logged. Not an error state and not an empty screen —
  /// E09 is what renders here, and it is a branch rather than a failure.
  static const DayTotals empty = DayTotals(
    kcalSoFar: 0,
    proteinSoFar: 0,
    proteinTargetG: kProvisionalProteinTargetG,
  );

  /// Calories eaten so far. Rises; never counts down toward anything.
  final int kcalSoFar;

  /// Protein eaten so far, in grams.
  final int proteinSoFar;

  /// The protein target. See [kProvisionalProteinTargetG] — this number is
  /// supplied from outside and is currently unowned.
  final int proteinTargetG;

  /// Carbs, fat and fibre eaten so far, in grams, over the items that carry
  /// them. Null when no item today does: a food from the pack without them,
  /// or a meal logged before they existed, adds nothing rather than a zero.
  /// There is no target for any of them, and nothing here could hold one.
  final int? carbsSoFar;
  final int? fatSoFar;
  final int? fiberSoFar;

  /// True when any item today carries carbs, fat or fibre.
  bool get hasMoreMacros =>
      carbsSoFar != null || fatSoFar != null || fiberSoFar != null;

  /// Recomputes the totals from the item list, which is the source of truth.
  ///
  /// G5 §4.5: **`totals` is a cache, not truth.** Two devices reconnecting can
  /// leave the stored `totals` disagreeing with the items — a correction that
  /// arrived twice, a read-time dedupe that dropped an entry — and when they
  /// disagree the *items* win. Rendering the recomputed value is what makes the
  /// screen self-healing without a migration or a background job.
  ///
  /// Pass the already-deduplicated list; [MealDayReader.dedupe] is what produces
  /// it, and totalling raw items would double a correction that arrived twice.
  factory DayTotals.recompute(
    Iterable<MealItem> items, {
    int proteinTargetG = kProvisionalProteinTargetG,
  }) {
    var kcal = 0;
    var protein = 0;
    int? carbs;
    int? fat;
    int? fiber;
    int? add(int? sum, int? value) => value == null ? sum : (sum ?? 0) + value;
    for (final item in items) {
      kcal += item.kcal;
      protein += item.proteinG;
      carbs = add(carbs, item.carbsG);
      fat = add(fat, item.fatG);
      fiber = add(fiber, item.fiberG);
    }
    return DayTotals(
      kcalSoFar: kcal,
      proteinSoFar: protein,
      proteinTargetG: proteinTargetG,
      carbsSoFar: carbs,
      fatSoFar: fat,
      fiberSoFar: fiber,
    );
  }

  /// How full the protein bar is, 0–100.
  ///
  /// Clamped at 100 on purpose: past the target the bar is simply full. It does
  /// not turn red, it does not overflow, and there is no "over by" figure for it
  /// to overflow *into* — E01's design note is "no countdown, no red numbers",
  /// and the absence of an `over` field is what keeps that true.
  ///
  /// A zero or negative target yields 0 rather than dividing by zero, because a
  /// missing target must not take her Eat screen down.
  double get proteinPercent {
    if (proteinTargetG <= 0) return 0;
    final ratio = proteinSoFar / proteinTargetG * 100;
    return ratio.clamp(0, 100).toDouble();
  }

  /// True once anything at all has been logged today.
  bool get hasAnything => kcalSoFar > 0 || proteinSoFar > 0;

  @override
  bool operator ==(Object other) =>
      other is DayTotals &&
      other.kcalSoFar == kcalSoFar &&
      other.proteinSoFar == proteinSoFar &&
      other.proteinTargetG == proteinTargetG &&
      other.carbsSoFar == carbsSoFar &&
      other.fatSoFar == fatSoFar &&
      other.fiberSoFar == fiberSoFar;

  @override
  int get hashCode => Object.hash(
    kcalSoFar,
    proteinSoFar,
    proteinTargetG,
    carbsSoFar,
    fatSoFar,
    fiberSoFar,
  );

  @override
  String toString() =>
      'DayTotals(kcal: $kcalSoFar, protein: $proteinSoFar/$proteinTargetG g, '
      'carbs: $carbsSoFar, fat: $fatSoFar, fibre: $fiberSoFar)';
}
