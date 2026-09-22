/// What `K26` and `K27` render, and the one thing neither of them can do.
///
/// A draft is **held**. There is no field, method or state below that means
/// published, and there is no action that could produce one: the coach's two
/// choices are to open the draft in the owning group's planner — which is where
/// the write happens, after her tap — or to discard it. G15 D1 and §3.3.
///
/// ## The unverified dish carries no totals, structurally
///
/// `K27`'s stated rule is that "a dish without verified values is offered
/// without totals, never with invented ones". That is kept here rather than in
/// the widget: [MealDishRow.kcal] and [MealDishRow.proteinG] are **null**
/// whenever the pack row is unverified, so there is no figure for a screen to
/// render even if one tried. A widget-level `if (verified)` would be a check
/// somebody could forget; a null is a compile-time obligation.
///
/// Nothing in this file computes a total from anything but the pack row, and
/// nothing sums across dishes — `P0-ASK-10`: "No total is ever computed by the
/// model", and none is computed here on its behalf either.
library;

import 'package:meta/meta.dart';

import '../../../l10n/app_l10n.dart';
import '../../eat/domain/food_library.dart';
import '../domain/assistant_pack.dart';
import '../domain/assistant_wire.dart';

// ------------------------------------------------------------------ K26

/// One day of the plan draft. Its [position] is its index in the draft.
@immutable
class PlanDayRow {
  const PlanDayRow({
    required this.position,
    required this.kind,
    required this.moves,
  });

  final int position;
  final PlanDayKind kind;

  /// Names read from the pack. An id the pack does not know contributes no
  /// entry, so an invented move is not merely unnamed — it is not there.
  final List<String> moves;

  bool get isRest => kind == PlanDayKind.rest;
}

/// Everything `K26` needs to draw itself.
@immutable
class PlanDraftScreen {
  const PlanDraftScreen({
    required this.days,
    required this.sessionCount,
    required this.restCount,
  });

  static const PlanDraftScreen empty = PlanDraftScreen(
    days: <PlanDayRow>[],
    sessionCount: 0,
    restCount: 0,
  );

  final List<PlanDayRow> days;

  /// Counted here, from the structure. The model never stated a number.
  final int sessionCount;
  final int restCount;

  int get dayCount => days.length;
  bool get isEmpty => days.isEmpty;

  /// Always true, and there is no transition out of it on this screen.
  /// Publishing belongs to G2, and is reachable only from a coach's explicit
  /// publish tap on her own planner.
  bool get isHeldNotPublished => true;

  /// The first week, which is all `K26` shows above the fold.
  List<PlanDayRow> get firstWeek => days.take(7).toList();
}

// ------------------------------------------------------------------ K27

/// One dish in a slot.
@immutable
class MealDishRow {
  const MealDishRow({
    required this.foodId,
    required this.name,
    required this.verified,
    this.kcal,
    this.proteinG,
    this.totals,
  });

  final String foodId;

  /// Read from the pack row.
  final String name;

  /// False when the pack has no verified values for this dish.
  final bool verified;

  /// **Null whenever [verified] is false.** See the file note: the absence of a
  /// figure is enforced by the type, not by the widget.
  final int? kcal;
  final int? proteinG;

  /// The rendered line — *"{kcal} kcal · {protein} g protein"* — built from the
  /// dictionary's **parameterised** message with the pack row's own figures.
  ///
  /// Parameterised, not a fixed string with a number in it. That distinction is
  /// what `baked_in_samples_test.dart` counts: a sentence with a placeholder
  /// takes hers, a sentence with the figure baked in tells every woman the
  /// mockup's. Here the figures come from the pack row this dish resolved to,
  /// so the line is true of the dish on screen or it does not exist.
  ///
  /// **Null whenever [verified] is false**, on the same terms as [kcal].
  final String? totals;

  bool get hasTotals => kcal != null && proteinG != null;
}

/// One slot of one day.
@immutable
class MealSlotRow {
  const MealSlotRow({required this.slot, required this.dishes});

  final MealSlot slot;
  final List<MealDishRow> dishes;
}

/// One day of the meal draft.
@immutable
class MealDayRow {
  const MealDayRow({required this.position, required this.slots});

  final int position;
  final List<MealSlotRow> slots;
}

/// Everything `K27` needs to draw itself.
@immutable
class MealDraftScreen {
  const MealDraftScreen({required this.days});

  static const MealDraftScreen empty = MealDraftScreen(days: <MealDayRow>[]);

  final List<MealDayRow> days;

  int get dayCount => days.length;
  bool get isEmpty => days.isEmpty;
  bool get isHeldNotPublished => true;

  /// The day `K27` shows. A draft with no days shows none.
  MealDayRow? get firstDay => days.isEmpty ? null : days.first;
}

// --------------------------------------------------------------- the builder

/// Resolves draft ids against the pack. Reads; never writes.
class DraftViewModel {
  const DraftViewModel(this.pack, {required this.l10n});

  final AssistantPack pack;

  /// Used for exactly one thing: the **parameterised** totals line on `K27`.
  /// Every other string on both screens is static copy the widget reads
  /// directly, and nothing here composes a sentence.
  final AppL10n l10n;

  PlanDraftScreen plan(PlanDraft draft) {
    final days = <PlanDayRow>[
      for (var i = 0; i < draft.days.length; i++)
        PlanDayRow(
          position: i,
          kind: draft.days[i].kind,
          moves: <String>[
            for (final id in draft.days[i].exerciseIds)
              if (pack.exerciseById(id) case final move?) move.name,
          ],
        ),
    ];

    return PlanDraftScreen(
      days: days,
      sessionCount: draft.sessionCount,
      restCount: draft.restCount,
    );
  }

  MealDraftScreen meal(MealDraft draft) => MealDraftScreen(
    days: <MealDayRow>[
      for (var i = 0; i < draft.days.length; i++)
        MealDayRow(position: i, slots: _slots(draft.days[i])),
    ],
  );

  /// The slots that actually have a dish in them, after resolution.
  ///
  /// Emptiness is tested **after** the ids have been looked up, not before. A
  /// slot whose only dish was a hallucinated id would otherwise render as a
  /// *Dinner* heading with nothing under it — a slot the coach can see was
  /// filled with something, and no way to know what. Nothing found is nothing
  /// shown, on this screen as on `X01`.
  List<MealSlotRow> _slots(MealDraftDay day) {
    final rows = <MealSlotRow>[];
    for (final slot in MealSlot.values) {
      final dishes = <MealDishRow>[
        for (final id in day.idsIn(slot))
          if (pack.foodById(id) case final food?)
            _dish(food.foodId, food.names.first, food),
      ];
      if (dishes.isNotEmpty) rows.add(MealSlotRow(slot: slot, dishes: dishes));
    }
    return rows;
  }

  /// Totals come from the pack's own size row, or not at all.
  MealDishRow _dish(String foodId, String name, Food food) {
    if (!food.verified) {
      // Offered without totals, never with invented ones. There is no figure
      // and no rendered line — not a zero, not a dash, not "about".
      return MealDishRow(foodId: foodId, name: name, verified: false);
    }
    final size = food.defaultSize;
    return MealDishRow(
      foodId: foodId,
      name: name,
      verified: true,
      kcal: size.kcal,
      proteinG: size.proteinG,
      // `{kcal} kcal · {protein} g protein`, filled from this row. Nothing is
      // summed, averaged or estimated here: `P0-ASK-10` — "No total is ever
      // computed by the model", and none is computed on its behalf either.
      totals: l10n.kcalKcalProteinGProtein('${size.kcal}', '${size.proteinG}'),
    );
  }
}
