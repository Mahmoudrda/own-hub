/// What E01, E04 and E09 render — computed without a widget in sight.
///
/// `ARCHITECTURE.md` §1: "A view model may not restate a rule, and a widget may
/// never contain one." So this file *arranges* what the domain decided and
/// decides nothing itself. Every number comes from [MealDayReader] or
/// [DayTotals]; every ordering comes from [PlateRollup]; every exclusion comes
/// from [AllergyGuard].
///
/// It is a pure function of its inputs — day, prefs, clock — so the whole of
/// E01's behaviour is testable without pumping a frame, which is what the Phase
/// 2 build order asks for at step 3.
///
/// ## The one thing to get right about ordering
///
/// [AllergyGuard.screen] runs **before** [PlateRollup.rank], not after. G5 §5.1
/// calls it "filtering at the source, not validating after". Ranking first and
/// filtering second would put a conflicting dish at the top of her suggestions
/// and then remove it — which looks identical in a screenshot and is how the
/// filter later gets "fixed" by being moved.
library;

import 'package:meta/meta.dart';

import '../domain/allergy_guard.dart';
import '../domain/day_totals.dart';
import '../domain/food_library.dart';
import '../domain/meal_day_reader.dart';
import '../domain/meal_repository.dart';
import '../domain/meal_sentence_parser.dart';
import '../domain/meal_slot_state_machine.dart';
import '../domain/plate_rollup.dart';

/// How a slot reads on E01's three-column card.
enum SlotStatus {
  /// Something is logged. "Ful and baladi", with a tick.
  done,

  /// The slot for this hour. "Now", outlined in the product's pink.
  now,

  /// Still ahead. "Later".
  later,
}

/// One column of E01's slot card.
@immutable
class SlotView {
  const SlotView({
    required this.slot,
    required this.status,
    required this.state,
    required this.items,
  });

  final MealSlot slot;
  final SlotStatus status;

  /// The domain's answer, carried through unchanged so the widget never has to
  /// re-derive it.
  final MealSlotState state;

  /// Deduplicated and ordered by [MealDayReader].
  final List<MealItem> items;

  bool get hasAnything => items.isNotEmpty;
}

/// One row she can log in a single tap.
@immutable
class SuggestionView {
  const SuggestionView({
    required this.key,
    required this.entries,
    required this.primary,
    this.plateId,
    this.timesEaten = 0,
  });

  /// Stable identity for the row — a plate id, or a food id for a starter.
  final String key;

  /// Exactly what tapping Log would write. The row and the log read the same
  /// object, so the label and the write cannot drift apart — which is the
  /// defect `PHASE1-FIXES.md` §8 records on R07.
  final List<ParsedItem> entries;

  /// The likeliest answer. One per list, so the eye lands on it.
  final bool primary;

  final String? plateId;

  /// Times inside the 28-day window. E01's note: "ranked by how often, with the
  /// count shown so the guess can be checked."
  final int timesEaten;

  int get kcal => entries.fold(0, (sum, e) => sum + e.kcal);
  int get proteinG => entries.fold(0, (sum, e) => sum + e.proteinG);
}

/// Everything the Eat screen needs for one render.
@immutable
class EatDayView {
  const EatDayView({
    required this.totals,
    required this.slots,
    required this.suggestions,
    required this.starters,
    required this.isDayOne,
    required this.activeSlot,
    required this.ramadanMode,
  });

  final DayTotals totals;

  /// Breakfast, lunch and dinner — the three columns the design draws. Snack is
  /// a real slot in the schema and simply has no column.
  final List<SlotView> slots;

  /// Ranked by her own frequency, already screened.
  final List<SuggestionView> suggestions;

  /// E09's six real Egyptian starters, for a woman with no history at all.
  final List<SuggestionView> starters;

  /// True when nothing has ever been logged today — the E09 branch.
  ///
  /// HANDOFF rule 16: a **state** of the Eat route, never a destination.
  final bool isDayOne;

  /// The slot this hour belongs to, which is the one a one-tap log fills.
  final MealSlot activeSlot;

  final RamadanMode ramadanMode;
}

/// Builds [EatDayView]. Holds no state of its own.
class EatDayViewModel {
  const EatDayViewModel({
    required this.library,
    required this.guard,
    this.reader = const MealDayReader(),
    this.rollup = const PlateRollup(),
    this.machine = const MealSlotStateMachine(),
  });

  final FoodLibrary library;

  /// Required, never defaulted. Whether her allergies are known is a fact about
  /// the product's state that the caller has to state out loud — a default here
  /// would decide it invisibly, and both possible defaults are wrong in a
  /// different way.
  final AllergyGuard guard;

  final MealDayReader reader;
  final PlateRollup rollup;
  final MealSlotStateMachine machine;

  /// The three columns the design draws, in order.
  static const List<MealSlot> columns = [
    MealSlot.breakfast,
    MealSlot.lunch,
    MealSlot.dinner,
  ];

  EatDayView build({
    required MealDay day,
    required EatPrefs prefs,
    required DateTime now,
    int? proteinTargetG,
  }) {
    final active = slotAt(now);

    final slots = [
      for (final slot in columns)
        SlotView(
          slot: slot,
          state: machine.resolve(day: day, slot: slot),
          items: reader.itemsIn(day, slot),
          status: _statusOf(day, slot, active),
        ),
    ];

    return EatDayView(
      totals: reader.totals(
        day,
        proteinTargetG:
            proteinTargetG ??
            prefs.proteinTargetGOverride ??
            kProvisionalProteinTargetG,
      ),
      slots: slots,
      suggestions: _suggestions(prefs: prefs, now: now, slot: active),
      starters: _starters(),
      isDayOne: reader.isFirstDay(day),
      activeSlot: active,
      ramadanMode: prefs.ramadanMode,
    );
  }

  /// Which meal this hour belongs to.
  ///
  /// Deliberately blunt boundaries rather than a learned model: she can log into
  /// any slot she likes, and this only decides which one a *one-tap* suggestion
  /// fills. Getting it slightly wrong costs her one tap; a model that needed
  /// training would cost her a feature that does not work on day one.
  static MealSlot slotAt(DateTime now) {
    final hour = now.hour;
    if (hour < 11) return MealSlot.breakfast;
    if (hour < 17) return MealSlot.lunch;
    if (hour < 22) return MealSlot.dinner;
    return MealSlot.snack;
  }

  SlotStatus _statusOf(MealDay day, MealSlot slot, MealSlot active) {
    if (day.itemsIn(slot).isNotEmpty) return SlotStatus.done;
    if (slot == active) return SlotStatus.now;
    return SlotStatus.later;
  }

  /// Screened first, then ranked. See the file note — the order is the rule.
  List<SuggestionView> _suggestions({
    required EatPrefs prefs,
    required DateTime now,
    required MealSlot slot,
  }) {
    final safe = _safePlates(prefs);

    final ranked = rollup.rank(
      safe,
      now: now,
      slot: slot,
      weekday: now.weekday,
    );

    final views = <SuggestionView>[];
    for (var i = 0; i < ranked.length; i++) {
      final plate = ranked[i];
      final entries = _entriesFor(plate);
      // A plate whose foods have left the pack cannot be logged, so it is not
      // offered. Rule 10: the product does not name a food it no longer has.
      if (entries.length != plate.items.length) continue;

      views.add(
        SuggestionView(
          key: plate.plateId,
          plateId: plate.plateId,
          entries: entries,
          primary: views.isEmpty,
          timesEaten: rollup.timesEatenWithin(plate, now),
        ),
      );
    }
    return views;
  }

  /// Keeps only plates whose every food survives the guard.
  ///
  /// A plate is a combination, so one unsafe food makes the whole row unsafe —
  /// offering "koshari and a salad" minus the salad would be offering her
  /// something she did not ask for.
  EatPrefs _safePlates(EatPrefs prefs) {
    final allowed = guard
        .screenSuggestions(library.foods)
        .map((food) => food.foodId)
        .toSet();

    return prefs.copyWith(
      plates: <String, Plate>{
        for (final entry in prefs.plates.entries)
          if (entry.value.items.every((i) => allowed.contains(i.foodId)))
            entry.key: entry.value,
      },
    );
  }

  /// "Yesterday's lunch again": what she logged for lunch the day before, as
  /// one row she can log in a tap. Null when there was none, or when any part
  /// of it can no longer be offered: a food that fails her allergy guard, has
  /// left the pack, or was logged as less than a whole serving cannot be
  /// repeated as "the same", and a meal minus a food is not the meal she ate.
  SuggestionView? yesterdaysLunch(MealDay? yesterday) {
    if (yesterday == null) return null;
    final items = reader.itemsIn(yesterday, MealSlot.lunch);
    if (items.isEmpty) return null;
    final allowed = guard
        .screenSuggestions(library.foods)
        .map((food) => food.foodId)
        .toSet();
    final entries = <ParsedItem>[];
    for (final item in items) {
      final food = library.byId(item.foodId);
      final size = food?.sizeById(item.size);
      final whole =
          item.servings >= 1 && item.servings == item.servings.toInt();
      if (food == null || size == null || !whole) return null;
      if (!allowed.contains(food.foodId)) return null;
      entries.add(
        ParsedItem(
          food: food,
          size: size,
          servings: item.servings.toInt(),
          sourceText: food.names.first,
        ),
      );
    }
    return SuggestionView(
      key: 'yesterdays-lunch',
      entries: entries,
      primary: false,
    );
  }

  List<ParsedItem> _entriesFor(Plate plate) {
    final entries = <ParsedItem>[];
    for (final item in plate.items) {
      final food = library.byId(item.foodId);
      if (food == null) continue;
      final size = food.sizeById(item.size);
      if (size == null) continue;
      entries.add(
        ParsedItem(
          food: food,
          size: size,
          servings: item.servings.toInt(),
          sourceText: food.names.first,
        ),
      );
    }
    return entries;
  }

  /// E09's starters: the six most popular foods in the pack, screened.
  ///
  /// "An empty box asks her to invent an answer" — the design note. These exist
  /// so that a woman with no history has something real to tap.
  List<SuggestionView> _starters({int take = 6}) {
    final safe = guard
        .screenSuggestions(library.mostPopular(take * 3))
        .take(take);

    var first = true;
    final out = <SuggestionView>[];
    for (final food in safe) {
      out.add(
        SuggestionView(
          key: food.foodId,
          entries: [
            ParsedItem(
              food: food,
              size: food.defaultSize,
              servings: 1,
              sourceText: food.names.first,
            ),
          ],
          primary: first,
        ),
      );
      first = false;
    }
    return out;
  }
}
