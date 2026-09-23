/// What the Eat feature reads and writes.
///
/// G5 (`6-v2/plans/G5-eat-food-logging.md`) owns three collections and reads
/// everything else from a local content pack:
///
///   * `users/{uid}/meals/{yyyy-MM-dd}` — **one document per day** (spine C3).
///   * `users/{uid}/eatPrefs/current` — the bounded suggestion rollup.
///   * `users/{uid}/mealPlans/{yyyy-Www}` — E07's week plan and E08's list.
///
/// Every access is a document `get` by a deterministic id. There is no
/// `.where()`, no `.orderBy()` and no collection-group query anywhere in this
/// interface, which is what keeps G5 off the index budget entirely (plan §1.3).
///
/// ## The one thing this interface refuses to let you express
///
/// Spine C3, as amended after G5 planning:
///
/// > Two devices offline writing into the **same** slot would have one overwrite
/// > the other's array, losing a log. Same-slot writes must therefore use
/// > `arrayUnion` for items and `FieldValue.increment` for the totals.
///
/// So [applyLog] takes a [MealWrite], and a [MealWrite] **has no field capable
/// of holding "the new contents of this slot"**. It can add items, it can remove
/// named items, and it carries deltas rather than totals. A read-modify-write is
/// not something a caller has to remember to avoid; it is not expressible.
///
/// That is the same technique `DayTotals` uses against a calorie countdown and
/// `WeekKey` uses against a daily streak, and it is why `P0-LOG-11` is a test of
/// a property rather than of an implementation detail.
///
/// ## Why the fake is strict
///
/// [InMemoryMealRepository] enforces the invariants the real backend enforces —
/// the id shape, the slot cap, and above all the merge semantics. A fake that
/// accepted a whole-array write would let `P0-LOG-11` pass here and fail in
/// production, which is precisely the failure `InMemoryTrainRepository` was
/// written strict to avoid.
library;

import 'dart:async';

import 'package:meta/meta.dart';

import '../../../domain/week/week_key.dart';
import 'plate_rollup.dart';

/// The four slots, fixed forever.
///
/// G5 §1.6: Ramadan is a **relabelling**, not a schema. `RamadanSlotLabeller`
/// maps breakfast→suhoor and dinner→iftar for display; adding `suhoor`/`iftar`
/// keys would break C3's field-level merge, G6's reads, and every historical
/// document, so it is not done.
enum MealSlot { breakfast, lunch, dinner, snack }

/// The spine's `source` enum, reproduced **verbatim**.
///
/// Three values, unchanged. G5 needed six provenances and did not widen this —
/// see [MealOrigin] and plan §9 Q12.
enum MealSource { planned, search, voice }

/// The finer provenance E01, E04 and E06 need.
///
/// Kept off [MealSource] so the spine's declared enum is untouched. `nudge` is
/// the lock-screen meal action (T03), which lands on the same guarded path as
/// every other entry point.
enum MealOrigin { plan, suggestion, recipe, search, voice, nudge }

/// Where a planned item came from in the plan. `{assignmentId, slot, idx}`.
///
/// **Dormant in the MVP.** G2 publishes `assignment.meal == null` for the whole
/// cut — there is no coach to plan meals — so nothing writes this field yet. The
/// field, the deterministic id it produces and its correction path are built and
/// tested now regardless, because retrofitting rule 1 onto a shipped logging
/// path is how a prescribed value becomes a result.
@immutable
class PlanRef {
  const PlanRef({
    required this.assignmentId,
    required this.slot,
    required this.idx,
  });

  /// The assignment's `yyyy-MM-dd` key.
  final String assignmentId;
  final MealSlot slot;
  final int idx;

  @override
  bool operator ==(Object other) =>
      other is PlanRef &&
      other.assignmentId == assignmentId &&
      other.slot == slot &&
      other.idx == idx;

  @override
  int get hashCode => Object.hash(assignmentId, slot, idx);

  @override
  String toString() => 'PlanRef($assignmentId/${slot.name}#$idx)';
}

/// One thing she ate.
///
/// `kcal` and `proteinG` are **frozen at log time** from the pack that produced
/// them, alongside `libVersion` on the day document. G5 §9 Q2: if the library
/// later corrects a food's macros, her history does not silently change
/// underneath her.
@immutable
class MealItem {
  const MealItem({
    required this.itemId,
    required this.foodId,
    required this.servings,
    required this.size,
    required this.loggedAt,
    required this.source,
    required this.origin,
    required this.kcal,
    required this.proteinG,
    this.planRef,
    this.helpingOf,
    this.allergenOverride = const <String>[],
  });

  /// Identity for correction and dedupe.
  ///
  /// Deterministic for a planned item (so re-logging corrects), fresh for a
  /// helping or a free log (so it is a second item). See `item_id.dart`.
  final String itemId;

  final String foodId;
  final num servings;

  /// A size id from the food's own `sizes[]` — "M", or "2" for a count. Never a
  /// gram figure she did not choose: portions are the objects she serves.
  final String size;

  final DateTime loggedAt;
  final MealSource source;
  final MealOrigin origin;

  /// Frozen at log time. See the class note.
  final int kcal;
  final int proteinG;

  final PlanRef? planRef;

  /// The `itemId` of the first helping, when this is a second one.
  ///
  /// HANDOFF rule 3 made structural: an item that carries this is *additional*,
  /// and an item that does not carry it can never become additional by accident.
  final String? helpingOf;

  /// Allergens she explicitly acknowledged on this item.
  ///
  /// Only ever written by an explicit tap. Empty is the normal case and does not
  /// mean "checked and safe" — it means nothing was acknowledged.
  final List<String> allergenOverride;

  /// True when this is a second (or later) helping rather than a first log.
  bool get isHelping => helpingOf != null;

  /// True when this item came from the plan and therefore corrects on re-log.
  bool get isPlanned => planRef != null;

  /// A stable signature of what this item *is*, ignoring its identity.
  ///
  /// Used only to break a tie in [MealDayReader.dedupe] when two entries share
  /// an `itemId` **and** a `loggedAt`, which `arrayUnion` can produce from two
  /// devices correcting the same planned item. Deterministic across devices, so
  /// both of them resolve the tie the same way and render the same day.
  String get contentSignature =>
      '$foodId|$size|$servings|$kcal|$proteinG|${origin.name}';

  MealItem copyWith({
    String? itemId,
    String? size,
    num? servings,
    int? kcal,
    int? proteinG,
    DateTime? loggedAt,
    String? helpingOf,
    List<String>? allergenOverride,
  }) {
    return MealItem(
      itemId: itemId ?? this.itemId,
      foodId: foodId,
      servings: servings ?? this.servings,
      size: size ?? this.size,
      loggedAt: loggedAt ?? this.loggedAt,
      source: source,
      origin: origin,
      kcal: kcal ?? this.kcal,
      proteinG: proteinG ?? this.proteinG,
      planRef: planRef,
      helpingOf: helpingOf ?? this.helpingOf,
      allergenOverride: allergenOverride ?? this.allergenOverride,
    );
  }

  @override
  bool operator ==(Object other) =>
      other is MealItem &&
      other.itemId == itemId &&
      other.contentSignature == contentSignature &&
      other.loggedAt == loggedAt;

  @override
  int get hashCode => Object.hash(itemId, contentSignature, loggedAt);

  @override
  String toString() => 'MealItem($itemId $foodId×$servings $size)';
}

/// One day of eating — the whole `users/{uid}/meals/{yyyy-MM-dd}` document.
@immutable
class MealDay {
  const MealDay({
    required this.dayId,
    this.slots = const <MealSlot, List<MealItem>>{},
    this.firstLogAt,
    this.tz = '',
    this.libVersion = 0,
    this.skipped = const <MealSlot>{},
  });

  /// `yyyy-MM-dd` in her timezone at the moment of the action (plan §9 Q7).
  final String dayId;

  /// Absent until her first log in that slot, which is what keeps a prescribed
  /// meal from ever being a result (§2 rule 1).
  final Map<MealSlot, List<MealItem>> slots;

  /// Written once. G6's once-a-day points hook keys off the document, never off
  /// the item count — so there is no reason for her to split a plate.
  final DateTime? firstLogAt;

  final String tz;
  final int libVersion;

  /// Slots she explicitly skipped. Carries no penalty anywhere (§3.1), and a
  /// skip is never final — logging into a skipped slot simply logs.
  final Set<MealSlot> skipped;

  List<MealItem> itemsIn(MealSlot slot) => slots[slot] ?? const <MealItem>[];

  Iterable<MealItem> get allItems => MealSlot.values.expand((s) => itemsIn(s));

  /// True when nothing at all has been logged — E09's branch condition.
  bool get hasNothingLogged => allItems.isEmpty;

  MealDay copyWith({
    Map<MealSlot, List<MealItem>>? slots,
    DateTime? firstLogAt,
    String? tz,
    int? libVersion,
    Set<MealSlot>? skipped,
  }) {
    return MealDay(
      dayId: dayId,
      slots: slots ?? this.slots,
      firstLogAt: firstLogAt ?? this.firstLogAt,
      tz: tz ?? this.tz,
      libVersion: libVersion ?? this.libVersion,
      skipped: skipped ?? this.skipped,
    );
  }

  @override
  String toString() =>
      'MealDay($dayId, ${allItems.length} items, skipped: $skipped)';
}

/// The only shape a write to a meal document can take.
///
/// Three transforms against one document, exactly as G5 §4.5 writes them:
/// `arrayUnion` for [added], `arrayRemove` for [removed], and `increment` for
/// the two deltas. Note what is **not** here: there is no field holding the new
/// contents of a slot, and no field holding an absolute total. A caller cannot
/// express a read-modify-write, so two devices cannot clobber each other.
///
/// The deltas are computed by the factory from [added] and [removed] rather than
/// supplied. That is deliberate: a caller who passed them separately could get
/// them wrong, and a total that disagrees with its items is the defect
/// `PHASE1-FIXES.md` §8 records under "two sources, one of them constant".
@immutable
class MealWrite {
  const MealWrite._({
    required this.dayId,
    required this.slot,
    required this.added,
    required this.removed,
    required this.kcalDelta,
    required this.proteinDelta,
    required this.tz,
    required this.libVersion,
    required this.skip,
  });

  /// A log, a correction, or a helping — whichever the caller built.
  ///
  /// A correction passes the item it replaces in [removed]; a first log and a
  /// helping pass nothing. The deltas follow from the two lists and cannot be
  /// set independently.
  factory MealWrite.transform({
    required String dayId,
    required MealSlot slot,
    required String tz,
    required int libVersion,
    List<MealItem> added = const <MealItem>[],
    List<MealItem> removed = const <MealItem>[],
  }) {
    var kcal = 0;
    var protein = 0;
    for (final item in added) {
      kcal += item.kcal;
      protein += item.proteinG;
    }
    for (final item in removed) {
      kcal -= item.kcal;
      protein -= item.proteinG;
    }
    return MealWrite._(
      dayId: dayId,
      slot: slot,
      added: List<MealItem>.unmodifiable(added),
      removed: List<MealItem>.unmodifiable(removed),
      kcalDelta: kcal,
      proteinDelta: protein,
      tz: tz,
      libVersion: libVersion,
      skip: false,
    );
  }

  /// Marks a slot skipped. Writes an empty slot and a `skippedAt`, and costs her
  /// nothing anywhere in the product (§3.1).
  factory MealWrite.skipSlot({
    required String dayId,
    required MealSlot slot,
    required String tz,
    required int libVersion,
  }) {
    return MealWrite._(
      dayId: dayId,
      slot: slot,
      added: const <MealItem>[],
      removed: const <MealItem>[],
      kcalDelta: 0,
      proteinDelta: 0,
      tz: tz,
      libVersion: libVersion,
      skip: true,
    );
  }

  final String dayId;
  final MealSlot slot;

  /// `FieldValue.arrayUnion(added)`.
  final List<MealItem> added;

  /// `FieldValue.arrayRemove(removed)` — the whole previous element, which is
  /// what Firestore's transform matches on.
  final List<MealItem> removed;

  /// `FieldValue.increment(...)`. Signed: a correction downward is negative.
  final int kcalDelta;
  final int proteinDelta;

  final String tz;
  final int libVersion;

  /// True only for [MealWrite.skipSlot].
  final bool skip;

  /// True when this write replaces an item rather than appending one.
  bool get isCorrection => removed.isNotEmpty;

  @override
  String toString() =>
      'MealWrite($dayId/${slot.name} +${added.length} -${removed.length} '
      'Δkcal $kcalDelta Δprotein $proteinDelta${skip ? ' skip' : ''})';
}

// ---------------------------------------------------------------- eatPrefs --

/// E01's Ramadan pill. Display-only (§1.6).
enum RamadanMode { auto, on, off }

/// One food within a remembered plate.
@immutable
class PlateItem {
  const PlateItem({
    required this.foodId,
    required this.size,
    this.servings = 1,
  });

  final String foodId;
  final String size;
  final num servings;

  @override
  bool operator ==(Object other) =>
      other is PlateItem &&
      other.foodId == foodId &&
      other.size == size &&
      other.servings == servings;

  @override
  int get hashCode => Object.hash(foodId, size, servings);
}

/// A combination she eats, and how often.
///
/// The counters are **absolute per (plate, date)** rather than incremented. That
/// is what makes the rollup idempotent on replay — spine C4's correction, that
/// commutative is not idempotent — and commutative across devices, because two
/// devices writing different dates touch different map keys.
@immutable
class Plate {
  const Plate({
    required this.plateId,
    required this.items,
    required this.lastAt,
    this.dayCounts = const <String, int>{},
    this.slotCounts = const <MealSlot, int>{},
    this.dowCounts = const <int, int>{},
  });

  final String plateId;
  final List<PlateItem> items;

  /// `yyyy-MM-dd` → times eaten that day. Rolling 28-day window; older keys are
  /// deleted on write, which is what bounds the document regardless of tenure.
  final Map<String, int> dayCounts;

  /// "What she eats at this hour."
  final Map<MealSlot, int> slotCounts;

  /// "Tuesdays." `DateTime.weekday`, 1–7.
  final Map<int, int> dowCounts;

  /// Tie-break and eviction key.
  final DateTime lastAt;

  /// Times eaten inside the retained window.
  int get timesEaten => dayCounts.values.fold(0, (sum, count) => sum + count);

  /// The number of distinct **days** it was eaten on.
  ///
  /// Deliberately a count of a *set of dates*, never a run length. §2 rule 3 is
  /// enforced here by the same absence that enforces it in `WeekKey`: there is
  /// no field, and no method, capable of expressing consecutive days.
  int get daysEatenOn => dayCounts.keys.length;

  Plate copyWith({
    List<PlateItem>? items,
    Map<String, int>? dayCounts,
    Map<MealSlot, int>? slotCounts,
    Map<int, int>? dowCounts,
    DateTime? lastAt,
  }) {
    return Plate(
      plateId: plateId,
      items: items ?? this.items,
      dayCounts: dayCounts ?? this.dayCounts,
      slotCounts: slotCounts ?? this.slotCounts,
      dowCounts: dowCounts ?? this.dowCounts,
      lastAt: lastAt ?? this.lastAt,
    );
  }

  @override
  String toString() => 'Plate($plateId ×$timesEaten)';
}

/// One logging event, folded into the rollup.
@immutable
class PlateObservation {
  const PlateObservation({
    required this.plateId,
    required this.items,
    required this.dayId,
    required this.slot,
    required this.at,
    this.timesToday = 1,
  });

  final String plateId;
  final List<PlateItem> items;
  final String dayId;
  final MealSlot slot;
  final DateTime at;

  /// How many times this plate appears in **that day's document**, in total.
  ///
  /// An absolute count, read off the day rather than counted up here, and that
  /// is what makes the rollup idempotent. Spine C4's correction — "commutative
  /// is not idempotent" — bites hardest on a replayed offline write: an
  /// increment applied twice counts twice, so the same meal logged once would
  /// end up remembered as two. Writing an absolute value per (plate, date) key
  /// means a replay writes the same number again and changes nothing.
  final int timesToday;
}

/// `users/{uid}/eatPrefs/current` — bounded by construction.
@immutable
class EatPrefs {
  const EatPrefs({
    this.plates = const <String, Plate>{},
    this.ramadanMode = RamadanMode.auto,
    this.proteinTargetGOverride,
    this.libVersion = 0,
  });

  /// At most [kPlateCap] entries. See [PlateRollup] for the eviction rule.
  final Map<String, Plate> plates;

  final RamadanMode ramadanMode;

  /// Null normally. The target is unowned (G5 §9 Q1) and this is not a formula —
  /// it is a manual override with nothing writing it yet.
  final int? proteinTargetGOverride;

  final int libVersion;

  EatPrefs copyWith({
    Map<String, Plate>? plates,
    RamadanMode? ramadanMode,
    int? proteinTargetGOverride,
    int? libVersion,
  }) {
    return EatPrefs(
      plates: plates ?? this.plates,
      ramadanMode: ramadanMode ?? this.ramadanMode,
      proteinTargetGOverride:
          proteinTargetGOverride ?? this.proteinTargetGOverride,
      libVersion: libVersion ?? this.libVersion,
    );
  }
}

/// The hard cap on remembered plates (§1.1), asserted in the security rules too.
const int kPlateCap = 40;

/// The rolling window the frequency question is answered over (§9 Q6).
const Duration kPlateWindow = Duration(days: 28);

/// The cap on items in one slot, asserted in the security rules.
const int kSlotItemCap = 24;

/// The cap on grocery lines in one week plan, asserted in the security rules.
const int kGroceryCap = 120;

// --------------------------------------------------------------- mealPlans --

/// A day of the week plan. E07 draws five; the document holds seven.
enum PlanDay { mon, tue, wed, thu, fri, sat, sun }

/// Where a grocery line sits on the list, grouped the way a market trip goes.
enum GroceryGroup { vegetables, protein, cupboard }

/// One line on E08.
///
/// Keyed by [itemKey] = `sha1(ingredientId + ':' + unit)`, so a tick made on two
/// devices converges on one line instead of ticking two.
@immutable
class GroceryLine {
  const GroceryLine({
    required this.itemKey,
    required this.ingredientId,
    required this.group,
    this.ticked = false,
    this.tickedAt,
  });

  final String itemKey;
  final String ingredientId;
  final GroceryGroup group;
  final bool ticked;
  final DateTime? tickedAt;

  GroceryLine copyWith({bool? ticked, DateTime? tickedAt}) => GroceryLine(
    itemKey: itemKey,
    ingredientId: ingredientId,
    group: group,
    ticked: ticked ?? this.ticked,
    tickedAt: tickedAt ?? this.tickedAt,
  );
}

/// `users/{uid}/mealPlans/{yyyy-Www}` — E07 and E08 share one document.
@immutable
class MealPlan {
  const MealPlan({
    required this.weekId,
    this.dinners = const <PlanDay, String>{},
    this.groceries = const <String, GroceryLine>{},
    this.recipeVersion = 0,
  });

  /// ISO week id, `yyyy-Www` — the same shape [WeekKey] produces.
  final String weekId;

  /// Day → `recipeId`, built from recipes she has logged before.
  final Map<PlanDay, String> dinners;

  final Map<String, GroceryLine> groceries;
  final int recipeVersion;

  int get tickedCount => groceries.values.where((g) => g.ticked).length;

  MealPlan copyWith({
    Map<PlanDay, String>? dinners,
    Map<String, GroceryLine>? groceries,
  }) {
    return MealPlan(
      weekId: weekId,
      dinners: dinners ?? this.dinners,
      groceries: groceries ?? this.groceries,
      recipeVersion: recipeVersion,
    );
  }
}

// -------------------------------------------------------------- repository --

/// Reads the day, the rollup and the week plan; writes all three.
abstract class MealRepository {
  /// One document `get` by date key. Never a query.
  ///
  /// Returns an empty [MealDay] rather than null when nothing has been logged:
  /// "she has not eaten yet" is a normal day, not an absent one, and E09 is a
  /// branch on the contents rather than on a null.
  Future<MealDay> day(String dayId);

  /// A live view of the same document, for the screen that is open.
  Stream<MealDay> watchDay(String dayId);

  /// The single write path for a meal log.
  ///
  /// Reachable only once a log's undo window has closed — the five seconds live
  /// ahead of this call in [LogCommandBus], so an undone log never reaches the
  /// server and there is nothing queued to resurface on reconnect (§4.2).
  Future<void> applyLog(MealWrite write);

  /// The suggestion rollup. One fixed document id; there is no parameter for it,
  /// because `eatPrefs/other` is a document the rules refuse anyway.
  Future<EatPrefs> prefs();

  /// Folds one logging event into the rollup.
  ///
  /// Debounced by the caller to at most once a day (§2's cost table). Idempotent
  /// under replay, because the counters are absolute per (plate, date).
  Future<void> recordPlate(PlateObservation observation);

  /// E07/E08's document, or null before she has ever opened the week plan.
  Future<MealPlan?> mealPlan(String weekId);

  /// Swaps one dinner. Debounced 2 s by the caller.
  Future<void> swapDinner({
    required String weekId,
    required PlanDay day,
    required String recipeId,
  });

  /// Ticks or un-ticks one grocery line. Local-first; the flush is debounced.
  Future<void> tickGrocery({
    required String weekId,
    required String itemKey,
    required bool ticked,
  });

  Future<void> dispose();
}

/// The documents, shared between the repositories that point at them.
///
/// This is "the server" in an offline test: two [InMemoryMealRepository]
/// instances constructed against one [MealStore] are the same account on two
/// handsets, and what converges here is what would converge in Firestore.
class MealStore {
  final Map<String, MealDay> days = <String, MealDay>{};
  final Map<String, MealPlan> plans = <String, MealPlan>{};
  EatPrefs prefs = const EatPrefs();

  /// Every meal she logged, every plan and her eating preferences. Account
  /// deletion calls it, covering manifest rows 5, 13 and 14.
  void reset() {
    days.clear();
    plans.clear();
    prefs = const EatPrefs();
  }

  /// Applies a write with the transform semantics Firestore would apply.
  ///
  /// The important line is the merge: [MealWrite.added] is unioned into whatever
  /// is already there, keyed by `itemId`, and the slot list is never replaced.
  /// Change this to an assignment and `P0-LOG-11` fails, which is exactly what
  /// it is for.
  void apply(MealWrite write) {
    _assertIsoDate(write.dayId);

    final existing = days[write.dayId] ?? MealDay(dayId: write.dayId);
    final slotItems = [...existing.itemsIn(write.slot)];

    // arrayRemove first, so a correction's replacement does not collide with the
    // entry it replaces.
    for (final gone in write.removed) {
      final at = slotItems.indexWhere((i) => i.itemId == gone.itemId);
      if (at < 0) {
        throw StateError(
          'MealWrite removes ${gone.itemId} from ${write.slot.name}, which is '
          'not there. A correction that silently no-ops is a correction she '
          'made and the product dropped.',
        );
      }
      slotItems.removeAt(at);
    }

    // arrayUnion. Appends; never assigns.
    for (final added in write.added) {
      final clash = slotItems.indexWhere((i) => i.itemId == added.itemId);
      if (clash >= 0) {
        throw StateError(
          'MealWrite adds ${added.itemId} to ${write.slot.name}, which already '
          'holds that id and is not removing it. Re-logging a planned meal must '
          'CORRECT it (arrayRemove + arrayUnion) and a second helping must mint '
          'a fresh id — HANDOFF rule 3. This write does neither, so it would '
          'double a serving.',
        );
      }
      slotItems.add(added);
    }

    if (slotItems.length > kSlotItemCap) {
      throw StateError(
        '${write.slot.name} would hold ${slotItems.length} items; the rules cap '
        'a slot at $kSlotItemCap.',
      );
    }

    final slots = Map<MealSlot, List<MealItem>>.from(existing.slots);
    if (write.skip) {
      slots[write.slot] = const <MealItem>[];
    } else {
      slots[write.slot] = slotItems;
    }

    final skipped = Set<MealSlot>.from(existing.skipped);
    if (write.skip) {
      skipped.add(write.slot);
    } else if (write.added.isNotEmpty) {
      // "A skip is never final" (§3.1): logging into a skipped slot logs.
      skipped.remove(write.slot);
    }

    days[write.dayId] = existing.copyWith(
      slots: slots,
      skipped: skipped,
      tz: write.tz,
      libVersion: write.libVersion,
      // Written once. A later log on the same day does not move it, because G6's
      // once-a-day hook means "she logged something today".
      firstLogAt:
          existing.firstLogAt ??
          (write.added.isEmpty ? null : write.added.first.loggedAt),
    );
  }

  static void _assertIsoDate(String dayId) {
    if (!RegExp(r'^\d{4}-\d{2}-\d{2}$').hasMatch(dayId)) {
      throw StateError(
        '"$dayId" is not a yyyy-MM-dd document id. Spine C1: a date-keyed id is '
        'what makes an offline retry idempotent, and the security rules refuse '
        'anything else.',
      );
    }
  }
}

/// An in-memory [MealRepository], for tests and for building screens before
/// there is a Firebase project.
///
/// **Strict where the real one is strict**, in the three places that matter:
///
///  1. `applyLog` merges by `itemId` and never replaces a slot (spine C3).
///  2. It refuses an add that would duplicate an id without removing it, and a
///     remove of an id that is not there (HANDOFF rule 3).
///  3. It refuses a document id that is not `yyyy-MM-dd`, a slot over the cap,
///     and a rollup over 40 plates (the security rules' own limits).
///
/// It also models **offline**. While [online] is false, writes are held in
/// [pending] and are visible locally but have not reached [store]; [goOnline]
/// drains them in order. That is how `P0-LOG-11` puts two handsets on one
/// account and brings them back with no signal in between.
class InMemoryMealRepository implements MealRepository {
  InMemoryMealRepository({
    MealStore? store,
    // A fallback, not a claim — see [WeekKey.fallbackTimezone]. This read
    // `'Africa/Cairo'` as a literal, one of three scattered through the app,
    // so every meal document asserted Cairo whoever wrote it.
    this.tz = WeekKey.fallbackTimezone,
    this.libVersion = 1,
    EatPrefs? prefs,
    Map<String, MealPlan>? plans,
  }) : store = store ?? MealStore() {
    if (prefs != null) this.store.prefs = prefs;
    if (plans != null) this.store.plans.addAll(plans);
  }

  /// The shared documents. Two repositories over one store are two devices.
  final MealStore store;

  final String tz;
  final int libVersion;

  /// Deliberately not a constructor parameter, and deliberately private.
  ///
  /// The only ways in and out are [goOffline] and [goOnline], because coming
  /// back online *means* draining the queue. A settable flag would let a caller
  /// flip to online without draining, leaving writes stranded in [pending] while
  /// the repository reported that it had signal — which is the bug this whole
  /// model exists to reason about, reintroduced in the test double.
  bool _online = true;

  /// Writes made with no signal, in order, still waiting for [goOnline].
  final List<MealWrite> pending = <MealWrite>[];

  /// Every write this repository accepted, in order — including ones still
  /// pending. A test asserts against this to prove an undone log never arrived.
  final List<MealWrite> writes = <MealWrite>[];

  final Map<String, StreamController<MealDay>> _watchers =
      <String, StreamController<MealDay>>{};

  bool get online => _online;

  /// Cuts the signal. Logging carries on; nothing reaches [store].
  void goOffline() => _online = false;

  /// Restores it and drains the queue in the order the writes were made.
  Future<void> goOnline() async {
    _online = true;
    final queued = [...pending];
    pending.clear();
    for (final write in queued) {
      store.apply(write);
    }
    for (final write in queued) {
      _emit(write.dayId);
    }
  }

  /// The day as this device sees it: what the store holds, plus what this device
  /// has logged and not yet sent. She sees her log immediately, with its real
  /// numbers, whether or not there is signal (§4.3).
  MealDay _localView(String dayId) {
    final base = store.days[dayId] ?? MealDay(dayId: dayId);
    if (pending.isEmpty) return base;

    final projection = MealStore()
      ..days[dayId] = base
      ..prefs = store.prefs;
    for (final write in pending) {
      if (write.dayId == dayId) projection.apply(write);
    }
    return projection.days[dayId] ?? base;
  }

  @override
  Future<MealDay> day(String dayId) async => _localView(dayId);

  @override
  Stream<MealDay> watchDay(String dayId) {
    final controller = _watchers.putIfAbsent(
      dayId,
      () => StreamController<MealDay>.broadcast(),
    );
    return controller.stream;
  }

  void _emit(String dayId) {
    final controller = _watchers[dayId];
    if (controller != null && !controller.isClosed) {
      controller.add(_localView(dayId));
    }
  }

  @override
  Future<void> applyLog(MealWrite write) async {
    writes.add(write);
    if (_online) {
      store.apply(write);
    } else {
      // Validate against the local view now rather than at drain time, so an
      // illegal write fails where it was made instead of hours later.
      final probe = MealStore()..days[write.dayId] = _localView(write.dayId);
      probe.apply(write);
      pending.add(write);
    }
    _emit(write.dayId);
  }

  @override
  Future<EatPrefs> prefs() async => store.prefs;

  @override
  Future<void> recordPlate(PlateObservation observation) async {
    if (store.prefs.plates.length > kPlateCap) {
      throw StateError(
        'eatPrefs holds ${store.prefs.plates.length} plates; the cap is '
        '$kPlateCap and the security rules refuse more.',
      );
    }
    // The fold itself is PlateRollup's, so there is one implementation of the
    // window and the eviction rather than one here and one in the domain.
    store.prefs = const PlateRollup().record(store.prefs, observation);
  }

  @override
  Future<MealPlan?> mealPlan(String weekId) async => store.plans[weekId];

  @override
  Future<void> swapDinner({
    required String weekId,
    required PlanDay day,
    required String recipeId,
  }) async {
    final plan = store.plans[weekId] ?? MealPlan(weekId: weekId);
    store.plans[weekId] = plan.copyWith(
      dinners: {...plan.dinners, day: recipeId},
    );
  }

  @override
  Future<void> tickGrocery({
    required String weekId,
    required String itemKey,
    required bool ticked,
  }) async {
    final plan = store.plans[weekId];
    if (plan == null) return;
    final line = plan.groceries[itemKey];
    if (line == null) return;
    store.plans[weekId] = plan.copyWith(
      groceries: {
        ...plan.groceries,
        // Distinct map keys, last-write-wins per key — so two devices ticking
        // two different lines both survive (§4.4).
        itemKey: line.copyWith(ticked: ticked, tickedAt: DateTime.now()),
      },
    );
  }

  @override
  Future<void> dispose() async {
    for (final controller in _watchers.values) {
      await controller.close();
    }
    _watchers.clear();
  }
}
