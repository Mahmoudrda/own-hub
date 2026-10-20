/// Correcting a log and adding a helping are two different things.
///
/// HANDOFF rule 3, and the sentence G5 §1.4 ends on:
///
/// > There is no code path where re-tapping *Log* silently doubles a serving,
/// > and none where a helping overwrites the first.
///
/// This file is where that is made structurally true. [correctPlannedLog] and
/// [addHelping] are **two methods with no shared entry point**, and neither can
/// express the other:
///
/// | | id | removes | adds | `helpingOf` |
/// |---|---|---|---|---|
/// | [correctPlannedLog] | deterministic, from the [PlanRef] | the entry holding that id | one | never |
/// | [addHelping] | fresh, every call | **nothing, ever** | one | always |
///
/// There is deliberately no `log(item, {bool asCorrection})`. A boolean there is
/// exactly how two intents collapse into one code path, and a caller who passed
/// the wrong value would double a serving silently — which nothing downstream
/// could detect, because a second helping is a perfectly legitimate thing to
/// find in a slot.
///
/// ## Where rule 9 lives, and where it does not
///
/// Not here. The five-second undo is `LogCommandBus`, shared with Train and
/// Today, and G5 conceded its own `PendingLogBuffer` to it (plan §5, §9 Q14).
/// These methods **build a write**; the screen submits an `UndoableLog` whose
/// `commit` closure calls [commit]. So the window runs *before* the write, an
/// undone log produces zero writes, and G6's once-a-day points hook never fires
/// for a meal she cancelled.
///
/// There is no `confirm*` method on this class, and no parameter anywhere that
/// could carry a dialog. That absence is the enforcement, as it is on the bus.
///
/// ## Allergies do not block a log
///
/// A log records what she already ate, so refusing it helps nobody. The guard
/// still decides what is *offered* ([AllergyGuard.screenSuggestions]) and which
/// allergens a logged food is known to contain ([AllergyGuard.knownAllergens]),
/// which the screens show as a "Contains X" note. A refusal now means a day with
/// no context or a food the pack cannot name.
library;

import 'package:meta/meta.dart';

import '../../../domain/week/week_key.dart';
import 'allergy_guard.dart';
import 'food_library.dart';
import 'item_id.dart';
import 'meal_check.dart';
import 'meal_repository.dart';
import 'meal_sentence_parser.dart';
import 'meal_slot_state_machine.dart';

/// The result of asking for a log. Sealed, so a caller must handle the refusal.
@immutable
sealed class MealLogOutcome {
  const MealLogOutcome();
}

/// A write, ready to be handed to the undo bus.
@immutable
class MealLogPrepared extends MealLogOutcome {
  const MealLogPrepared({required this.write, required this.items});

  /// What will be persisted when the five seconds close.
  final MealWrite write;

  /// The items as they will appear, so the row can render immediately and the
  /// snackbar can name what she agreed to.
  final List<MealItem> items;

  int get kcal => write.kcalDelta;
  int get proteinG => write.proteinDelta;
}

/// Nothing will be written, and this is why.
@immutable
class MealLogRefused extends MealLogOutcome {
  const MealLogRefused(this.refusal, {this.dish});

  final LogRefusal refusal;

  /// The dish the refusal is about, in her language.
  ///
  /// Carried because the screen that has to *say* why cannot work it out: a
  /// [LogRefusal] holds a reason and an assessment, and the whole point of
  /// [AllergyBlockReason.unknownAllergenData] is that there is no allergen to
  /// name — only a dish nobody has listed. Null when the refusal is not about
  /// one dish, and the caller then says the less specific sentence rather than
  /// guessing which entry was the problem.
  final String? dish;

  LogRefusalReason get reason => refusal.reason;
  AllergyAssessment? get assessment => refusal.assessment;
}

/// Builds meal writes, and nothing else.
class MealLogService {
  const MealLogService({
    required this.repository,
    required this.library,
    this.guard = const AllergyGuard(DietaryConstraints.unknown),
    this.machine = const MealSlotStateMachine(),
    // A fallback, not a claim — see [WeekKey.fallbackTimezone].
    this.tz = WeekKey.fallbackTimezone,
    this.libVersion = 1,
  });

  final MealRepository repository;
  final FoodLibrary library;

  /// Defaults to the **unknown** constraints, which fail closed. A guard that
  /// defaulted to "no allergies" would be a guard that is off until somebody
  /// remembers to switch it on.
  final AllergyGuard guard;

  final MealSlotStateMachine machine;
  final String tz;
  final int libVersion;

  /// Logs the planned meal — and logging it again **corrects** it.
  ///
  /// The `itemId` is derived from [planRef], so the second call produces the
  /// same id as the first. The write then removes the entry holding that id and
  /// unions the replacement, which is why re-tapping Log cannot double a
  /// serving: the slot holds one item before and one item after.
  ///
  /// There is no parameter here that could add a helping. [entry] replaces; it
  /// never appends.
  MealLogOutcome correctPlannedLog({
    required MealDay day,
    required PlanRef planRef,
    required ParsedItem entry,
    required DateTime at,
    Set<String> acknowledged = const <String>{},
  }) {
    final refusal = _screen(day, entry, acknowledged, enforceGuard: true);
    if (refusal != null) {
      return MealLogRefused(refusal, dish: entry.food.names.first);
    }

    final itemId = plannedItemId(
      assignmentId: planRef.assignmentId,
      slot: planRef.slot.name,
      index: planRef.idx,
    );

    // Whatever is currently holding that id — empty on the first log, one entry
    // on every subsequent one. This is the arrayRemove half.
    final previous = day
        .itemsIn(planRef.slot)
        .where((item) => item.itemId == itemId)
        .toList();

    final item = MealItem(
      itemId: itemId,
      foodId: entry.food.foodId,
      servings: entry.servings,
      size: entry.size.id,
      loggedAt: at,
      source: MealSource.planned,
      origin: MealOrigin.plan,
      kcal: entry.kcal,
      proteinG: entry.proteinG,
      carbsG: entry.carbsG,
      fatG: entry.fatG,
      fiberG: entry.fiberG,
      planRef: planRef,
      allergenOverride: acknowledged.toList(),
    );

    return MealLogPrepared(
      write: MealWrite.transform(
        dayId: day.dayId,
        slot: planRef.slot,
        added: [item],
        removed: previous,
        tz: tz,
        libVersion: libVersion,
      ),
      items: [item],
    );
  }

  /// A second serving of something already logged.
  ///
  /// Mints a **fresh** id and stamps `helpingOf`, so it is an additional item.
  /// [removed] is empty by construction — there is no code path in this method
  /// that could remove anything — which is the half of rule 3 that stops a
  /// helping overwriting the first serving.
  MealLogOutcome addHelping({
    required MealDay day,
    required MealSlot slot,
    required MealItem of,
    required DateTime at,
    Set<String> acknowledged = const <String>{},
  }) {
    final food = library.byId(of.foodId);
    final refusal = machine.refuseLog(
      day: day,
      food: food,
      assessment: AllergyAssessment.clear,
    );
    if (refusal != null) {
      return MealLogRefused(refusal, dish: food?.names.first);
    }

    // A helping of a helping is a helping of the FIRST serving, so the chain
    // never deepens and "how many did she have" is one lookup rather than a
    // walk.
    final root = of.helpingOf ?? of.itemId;

    final item = MealItem(
      itemId: freshItemId(),
      foodId: of.foodId,
      servings: of.servings,
      size: of.size,
      loggedAt: at,
      source: of.source,
      origin: of.origin,
      kcal: of.kcal,
      proteinG: of.proteinG,
      carbsG: of.carbsG,
      fatG: of.fatG,
      fiberG: of.fiberG,
      name: of.name,
      grams: of.grams,
      helpingOf: root,
      allergenOverride: acknowledged.toList(),
    );

    return MealLogPrepared(
      write: MealWrite.transform(
        dayId: day.dayId,
        slot: slot,
        added: [item],
        tz: tz,
        libVersion: libVersion,
      ),
      items: [item],
    );
  }

  /// A free log — a suggestion tapped, a sentence typed, a transcript confirmed,
  /// a recipe cooked.
  ///
  /// Every item gets a fresh id, so two logs of the same dish are two items.
  /// This method has no [PlanRef] parameter and removes nothing, so it can
  /// express neither a correction nor a helping.
  MealLogOutcome logNew({
    required MealDay day,
    required MealSlot slot,
    required List<ParsedItem> entries,
    required MealSource source,
    required MealOrigin origin,
    required DateTime at,
    Set<String> acknowledged = const <String>{},
  }) {
    if (entries.isEmpty) {
      return const MealLogRefused(LogRefusal(LogRefusalReason.foodNotInPack));
    }

    for (final entry in entries) {
      final refusal = _screen(day, entry, acknowledged);
      if (refusal != null) {
        return MealLogRefused(refusal, dish: entry.food.names.first);
      }
    }

    final items = [
      for (final entry in entries)
        MealItem(
          itemId: freshItemId(),
          foodId: entry.food.foodId,
          servings: entry.servings,
          size: entry.size.id,
          loggedAt: at,
          source: source,
          origin: origin,
          kcal: entry.kcal,
          proteinG: entry.proteinG,
          carbsG: entry.carbsG,
          fatG: entry.fatG,
          fiberG: entry.fiberG,
          name: entry.food.custom ? entry.food.names.first : null,
          allergenOverride: acknowledged.toList(),
        ),
    ];

    return MealLogPrepared(
      write: MealWrite.transform(
        dayId: day.dayId,
        slot: slot,
        added: items,
        tz: tz,
        libVersion: libVersion,
      ),
      items: items,
    );
  }

  /// The plate she checked on E13, item by item, exactly as she approved it.
  ///
  /// A free log like [logNew]: fresh ids, nothing removed, no [PlanRef]. What
  /// differs is where the numbers come from. A food the pack does not hold is
  /// logged under her name for it and the figures she approved, and it is
  /// still put to the guard: as a dish nobody has listed the contents of,
  /// which is exactly what a photographed plate is. So she is refused here
  /// on the same terms as for any dish in the pack, never waved through.
  MealLogOutcome logChecked({
    required MealDay day,
    required MealSlot slot,
    required List<CheckedEntry> entries,
    required DateTime at,
    Set<String> acknowledged = const <String>{},
  }) {
    if (entries.isEmpty) {
      return const MealLogRefused(LogRefusal(LogRefusalReason.foodNotInPack));
    }

    for (final entry in entries) {
      final listed = entry.food;
      // A food from the list must still be in it; one she named is assessed
      // as a dish whose contents nobody has listed.
      final Food? food = listed == null
          ? Food(
              foodId: entry.foodId,
              names: [entry.name ?? ''],
              sizes: const <FoodSize>[],
            )
          : library.byId(listed.foodId);
      final refusal = machine.refuseLog(
        day: day,
        food: food,
        assessment: AllergyAssessment.clear,
      );
      if (refusal != null) {
        return MealLogRefused(refusal, dish: entry.name ?? listed?.names.first);
      }
    }

    final items = [
      for (final entry in entries)
        MealItem(
          itemId: freshItemId(),
          foodId: entry.foodId,
          servings: 1,
          size: entry.sizeId,
          loggedAt: at,
          source: MealSource.search,
          origin: MealOrigin.photo,
          kcal: entry.kcal,
          proteinG: entry.proteinG,
          carbsG: entry.carbsG,
          fatG: entry.fatG,
          fiberG: entry.fiberG,
          name: entry.food == null ? entry.name : null,
          grams: entry.grams == null ? null : _grams(entry.grams!),
          allergenOverride: acknowledged.toList(),
        ),
    ];

    return MealLogPrepared(
      write: MealWrite.transform(
        dayId: day.dayId,
        slot: slot,
        added: items,
        tz: tz,
        libVersion: libVersion,
      ),
      items: items,
    );
  }

  /// A weight as she saw it: whole grams, or one decimal below ten.
  static num _grams(double grams) {
    final whole = grams.roundToDouble();
    if ((grams - whole).abs() < 0.05 || grams >= 10) return whole.toInt();
    return (grams * 10).round() / 10;
  }

  /// Marks a slot skipped. No penalty anywhere, and never final.
  MealWrite skipSlot({required MealDay day, required MealSlot slot}) =>
      MealWrite.skipSlot(
        dayId: day.dayId,
        slot: slot,
        tz: tz,
        libVersion: libVersion,
      );

  /// Hands a prepared write to the repository.
  ///
  /// Called by `LogCommandBus` when the undo window closes, never directly from
  /// a tap handler. An undone log never reaches this method.
  Future<void> commit(MealWrite write) => repository.applyLog(write);

  /// The guard and the state machine, in the one order that is safe.
  ///
  /// [enforceGuard] is true only for a coach-PLANNED row: D53 unblocks logging
  /// food she ate, but a planned row still fails closed on allergies.
  LogRefusal? _screen(
    MealDay day,
    ParsedItem entry,
    Set<String> acknowledged, {
    bool enforceGuard = false,
  }) {
    // Resolved against the pack by id, not trusted from the caller: an entry
    // could have been built from a Food that is no longer in the library after
    // a pack update, and §2 rule 10 forbids logging a food the product cannot
    // name.
    final food = library.byId(entry.food.foodId);
    final assessment = (enforceGuard && food != null)
        ? guard.assess(food, acknowledged: acknowledged)
        : AllergyAssessment.clear;
    return machine.refuseLog(day: day, food: food, assessment: assessment);
  }
}
