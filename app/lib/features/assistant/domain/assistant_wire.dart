/// Everything that may travel between the app and the model, and nothing else.
///
/// This file is the load-bearing one in G15. Its job is to make the product's
/// two hardest promises **unrepresentable failures** rather than rules someone
/// has to remember:
///
///  * **It never invents a quantity.** Not because a prompt asks it not to, and
///    not because a validator strips one afterwards — but because *there is no
///    field on the wire that can carry a number*. Every type below is built
///    from `String`, `bool` and closed enums. A model that wanted to say "3 × 12"
///    has nowhere to put it. The quantity on screen is read from the local pack
///    by id (`AssistantPack`), so a hallucinated id yields no row, and therefore
///    no gram. G15 D2.
///
///  * **It cannot pivot to another woman's data.** No type here carries a `uid`,
///    and no tool takes one ([AssistantTool] inputs are listed in its doc). The
///    subject is bound from the caller's own authentication
///    ([AssistantSubject.boundToCaller]), never from something a model chose.
///    G15 D4.
///
/// ## Why the day index is a list position and not an `int`
///
/// G15 §7.1 draws `draft_plan` as `days[{dayIndex, kind, exerciseIds[]}]`. An
/// `int dayIndex` would be the single numeric field on the wire, and the guard
/// "no number can ride the wire" would immediately need an exception — at which
/// point it stops being a structural guarantee and becomes a convention. So the
/// position in [PlanDraft.days] *is* the day index, and the number of days is
/// `days.length`: a fact about the structure, computed on the device, that the
/// model never states. Strictly stronger than the plan, and it costs nothing.
///
/// The same applies to `cycleLength`, which is not here either.
///
/// ## What is deliberately absent from the payload
///
/// [AssistantSubject] is an allowlist, not a filter over her document. Her name,
/// photos, weight, measurements, ID result, phone, **allergies** and **cycle
/// data** have no field to travel in — and cycle is absent *whatever the sharing switch says*,
/// because the switch is never consulted by code that cannot express the value.
/// `assistant_payload_test.dart` asserts the serialised body against
/// `kForbiddenPayloadKeys`.
///
/// `lifeStage` is excluded too, and this is the subtle one: it reaches the model
/// only as derived tokens inside [AssistantSubject.avoid] (`high_impact`,
/// `deep_knee_flexion`), so the clinical fact never travels while the constraint
/// it implies still applies. `ClientConstraints.derivedAvoid` already does that
/// derivation.
///
/// Her allergies are health data, and they do not travel either. Food is
/// screened on the phone: `AssistantPack.screenFoods` is `AllergyGuard.screen`,
/// run against her stored answer before anything is ranked, so a dish she
/// cannot eat is not in the candidate set and the model never needs the list.
/// The privacy policy (§3.8) promises a separate agreement before anything of
/// hers reaches a model; an allergy list is not sent even then.
library;

import 'package:meta/meta.dart';

import '../../../domain/safety/contraindication_tag.dart';

// ----------------------------------------------------------------- the tools
//
// Six names, frozen. G15 §7.1.

/// The complete tool registry, and there is no seventh.
///
/// **None of these publishes, and none of them writes.** That is not a property
/// of their implementations — it is a property of this enum: a tool that could
/// publish would have to be added here first, which is a visible, reviewable
/// act that `assistant_product_rules_test.dart` fails on.
///
/// Every input is listed in the doc comment rather than modelled as a class,
/// because the inputs that matter are the ones that are *absent*:
/// **not one tool takes a uid.**
enum AssistantTool {
  /// `{}` — empty by design. The subject is already bound at the caller; a
  /// parameter here is exactly how a model would pivot to another woman.
  getClientContext,

  /// `{equipment[], quiet, maxMinutes, bodyArea, excludeExerciseIds[], limit}`.
  /// The avoid list is applied to the candidate set **before** ranking, by
  /// `ExerciseCandidateFilter` — never by asking the model nicely.
  searchExerciseLibrary,

  /// `{query, slot, dietTags[], maxCostEGP, limit}`. No allergen input: her
  /// allergens are excluded on the phone by `AllergyGuard` before ranking, so
  /// the list never leaves it. Unverified rows are returned without totals
  /// rather than with invented ones.
  searchFoodLibrary,

  /// `{fromExerciseId, toExerciseId, reasonKey}`. **Proposes; does not write.**
  /// G4's `SwapService` performs the swap after her tap — G15 §7.1's named
  /// conflict with HANDOFF, resolved in favour of one writer per collection.
  proposeSwap,

  /// `{days[{kind, exerciseIds[]}]}`. Returns a payload; G2's
  /// `PlanDraftService.create` writes it, after the coach taps.
  draftPlan,

  /// `{days[{slots{breakfast,lunch,dinner,snack}: foodIds[]}]}`. Same: returns,
  /// never writes.
  draftMealWeek;

  /// The wire name, sorted-stable so the cached prefix bytes do not move.
  String get wireName => switch (this) {
    getClientContext => 'get_client_context',
    searchExerciseLibrary => 'search_exercise_library',
    searchFoodLibrary => 'search_food_library',
    proposeSwap => 'propose_swap',
    draftPlan => 'draft_plan',
    draftMealWeek => 'draft_meal_week',
  };

  /// Sorted by name, because an unsorted tool array silently invalidates the
  /// prompt cache on every request (G15 §2.2).
  static List<AssistantTool> get sortedByName =>
      List<AssistantTool>.unmodifiable(
        values.toList()..sort((a, b) => a.wireName.compareTo(b.wireName)),
      );
}

// --------------------------------------------------------------- the payload

/// The only facts about a woman that may leave the phone.
///
/// An allowlist. Constructing one is the only way to address the model, and the
/// constructor is private to this library so nothing can assemble a payload out
/// of whatever it happens to have to hand — the shape `ClientConstraints` uses,
/// for the same reason.
@immutable
class AssistantSubject {
  const AssistantSubject._({
    required this.locale,
    required this.equipment,
    required this.avoid,
    required this.dietary,
    required this.sessionMinutes,
    required this.place,
  });

  /// Binds the subject to the **caller's own** authenticated identity.
  ///
  /// There is no `uid` parameter and no `uid` field, which is the point: this
  /// is a value object describing *the caller*, so "whose data is this?" has
  /// exactly one answer and a model has no way to propose a different one.
  ///
  /// [constraints] is the resolved safety object. Only its tag sets are read —
  /// never `lifeStage`, never `referrals`' free text.
  factory AssistantSubject.boundToCaller({
    required String locale,
    required Set<String> equipment,
    required ClientSafetyFacts constraints,
    String? sessionMinutes,
    String? place,
  }) {
    return AssistantSubject._(
      locale: locale,
      equipment: Set.unmodifiable(equipment),
      avoid: Set.unmodifiable(constraints.avoid),
      dietary: constraints.dietary == null
          ? null
          : Set.unmodifiable(constraints.dietary!),
      sessionMinutes: sessionMinutes,
      place: place,
    );
  }

  /// Her interface language, so the answer template is chosen in it.
  final String locale;

  /// What she can train with. Tokens, never free text.
  final Set<String> equipment;

  /// The resolved avoid set. Carries the *constraint*, never the clinical fact
  /// that produced it.
  final Set<ContraindicationTag> avoid;

  /// Null means unreadable.
  final Set<String>? dietary;

  /// A bucket token like `20` or `45`, supplied by the caller as a label.
  /// Deliberately a `String`: see the file note on numbers.
  final String? sessionMinutes;

  /// `home` | `gym`, or null.
  final String? place;

  /// The body, exactly as it would be serialised.
  ///
  /// A pure function of the allowlisted fields. Nothing here reads a user
  /// document, so there is no path by which an extra field could arrive.
  Map<String, Object?> toWire() => <String, Object?>{
    'locale': locale,
    'equipment': equipment.toList()..sort(),
    'avoid': [for (final tag in avoid) tag.wireName]..sort(),
    if (dietary != null) 'dietary': dietary!.toList()..sort(),
    if (sessionMinutes != null) 'sessionMinutes': sessionMinutes,
    if (place != null) 'place': place,
  };
}

/// The safety facts the subject is built from.
///
/// A narrow view over `ClientConstraints` so this layer never holds the whole
/// assessment — and so a caller cannot pass the life stage, or her allergies,
/// by accident. Allergies are applied on the phone (see the file note).
@immutable
class ClientSafetyFacts {
  const ClientSafetyFacts({required this.avoid, this.dietary});

  final Set<ContraindicationTag> avoid;

  /// Null means unreadable — never "she has none".
  final Set<String>? dietary;
}

/// One question, and the caller it is being asked on behalf of.
///
/// No uid. See the file note.
@immutable
class AssistantRequest {
  const AssistantRequest({required this.question, required this.subject});

  /// Her words. Held in memory for the lifetime of the route and discarded on
  /// pop — G15 §1.1 stores no transcript anywhere.
  final String question;

  final AssistantSubject subject;

  Map<String, Object?> toWire() => <String, Object?>{
    'question': question,
    ...subject.toWire(),
  };
}

// -------------------------------------------------------------- the response

/// What kind of thing a pick refers to.
enum PickKind { exercise, food }

/// Where a pick came from. Rendered as the source chip X01 requires — "an
/// assistant that cannot show its source is indistinguishable from one that
/// guessed".
enum PickSource { herPlan, moveLibrary, foodLibrary }

/// One selected row. An **id and a provenance**, and nothing else.
///
/// Note what is missing: no name, no description, no sets, no reps, no grams,
/// no kcal. The device renders all of those from the local pack row keyed by
/// [id]. That is what makes an invented quantity unrenderable rather than
/// merely wrong.
@immutable
class AssistantPick {
  const AssistantPick({
    required this.kind,
    required this.id,
    required this.source,
  });

  final PickKind kind;

  /// Must exist in the versioned pack. `AssistantResponseValidator` drops it if
  /// it does not, and zero survivors become [AnswerKey.nothingFound].
  final String id;

  final PickSource source;

  @override
  bool operator ==(Object other) =>
      other is AssistantPick &&
      other.kind == kind &&
      other.id == id &&
      other.source == source;

  @override
  int get hashCode => Object.hash(kind, id, source);

  @override
  String toString() => 'AssistantPick(${kind.name}:$id)';
}

/// The sentence the answer is allowed to be.
///
/// An enum of dictionary template keys, so every answer is localised by
/// construction and no un-localised English can re-enter through a free `note`
/// field. G15 §10 Q6 records the trade: templates only at launch.
enum AnswerKey {
  /// "Two moves in your session work the same muscles…" — the grounded answer.
  groundedAlternatives,

  /// "It returns nothing and says so." No move is described, named or
  /// approximated. Reached whenever zero picks survive validation.
  nothingFound,

  /// The swap changes today only; her plan is untouched.
  swapChangesTodayOnly,
}

/// `propose_swap`'s payload: put this move in place of that one, today.
///
/// **It proposes; it does not write.** G4's `SwapService.apply()` performs the
/// swap after her tap, which is G15 §7.1's named resolution of the conflict with
/// `HANDOFF.md` — one writer per collection, and no model token on the path to
/// her log.
///
/// ## "Today only" is structural, not a promise in the copy
///
/// `P0-ASK-03` asks that an accepted swap land in today's session and leave
/// `plans/**` byte-identical. Note what this class has no room for: **no date,
/// no date range, no weekday, no repeat flag and no plan version.** There is
/// nothing here that could express "and every Tuesday", "from now on" or "in
/// week 3", so a swap cannot reach beyond the session it was proposed against
/// even if a caller wanted it to. The scope is the absence of a field, the way
/// the absence of a numeric field is what stops an invented quantity.
@immutable
class SwapProposal {
  const SwapProposal({
    required this.fromExerciseId,
    required this.toExerciseId,
    required this.reasonKey,
  });

  /// The move in today's session that is being stood down.
  final String fromExerciseId;

  /// What replaces it. Must exist in the pack, or the validator drops it.
  final String toExerciseId;

  /// Why, as a dictionary template key — never prose. The same closed enum the
  /// answer itself uses, so a reason is a sentence somebody wrote and
  /// translated.
  final AnswerKey reasonKey;

  @override
  bool operator ==(Object other) =>
      other is SwapProposal &&
      other.fromExerciseId == fromExerciseId &&
      other.toExerciseId == toExerciseId &&
      other.reasonKey == reasonKey;

  @override
  int get hashCode => Object.hash(fromExerciseId, toExerciseId, reasonKey);

  @override
  String toString() => 'SwapProposal($fromExerciseId → $toExerciseId)';
}

/// A validated answer, ready to render.
@immutable
class AssistantAnswer {
  const AssistantAnswer({
    required this.answerKey,
    this.picks = const <AssistantPick>[],
    this.escalate = false,
    this.swapFromExerciseId,
  });

  /// Nothing was found, and the screen says so rather than approximating.
  static const AssistantAnswer nothingFound = AssistantAnswer(
    answerKey: AnswerKey.nothingFound,
  );

  final AnswerKey answerKey;

  final List<AssistantPick> picks;

  /// True when the answer should also offer the human path prominently.
  final bool escalate;

  /// The move in **today's** session the picks are alternatives to, when the
  /// question was about one.
  ///
  /// Null when the answer is not about a swap, and that is the ordinary case.
  /// One id, not a list: an answer proposes alternatives to a single move in a
  /// single session, so there is no shape here for a bulk edit of her plan.
  final String? swapFromExerciseId;

  bool get isEmpty => picks.isEmpty;

  /// The swap this pick would be, or null when nothing is being replaced.
  ///
  /// Derived rather than carried, so the "from" side can only ever be the one
  /// move the answer was about.
  SwapProposal? swapFor(AssistantPick pick) {
    final from = swapFromExerciseId;
    if (from == null || pick.kind != PickKind.exercise) return null;
    return SwapProposal(
      fromExerciseId: from,
      toExerciseId: pick.id,
      reasonKey: AnswerKey.swapChangesTodayOnly,
    );
  }
}

// ------------------------------------------------------------- draft payloads

/// A training day, or a rest day.
enum PlanDayKind { training, rest }

/// One day of a plan draft. **Its position in [PlanDraft.days] is its index.**
@immutable
class PlanDraftDay {
  const PlanDraftDay({required this.kind, this.exerciseIds = const <String>[]});

  final PlanDayKind kind;

  /// Ids only. The moves, their prescriptions and every figure on screen are
  /// read from the pack.
  final List<String> exerciseIds;
}

/// A plan draft, held on the coach's device. **Nothing is written.**
///
/// There is no transition from here to published: that belongs to G2's
/// `PlanPublisher`, reachable only from a coach's explicit publish tap.
@immutable
class PlanDraft {
  const PlanDraft({required this.days});

  static const PlanDraft empty = PlanDraft(days: <PlanDraftDay>[]);

  final List<PlanDraftDay> days;

  /// Structural, computed here, never stated by the model.
  int get dayCount => days.length;
  int get sessionCount =>
      days.where((d) => d.kind == PlanDayKind.training).length;
  int get restCount => days.where((d) => d.kind == PlanDayKind.rest).length;

  bool get isEmpty => days.isEmpty;
}

/// The four slots a day has.
enum MealSlot { breakfast, lunch, dinner, snack }

/// One day of a meal draft.
@immutable
class MealDraftDay {
  const MealDraftDay({required this.slots});

  /// Slot → food ids. Quantities and totals come from the food pack.
  final Map<MealSlot, List<String>> slots;

  List<String> idsIn(MealSlot slot) => slots[slot] ?? const <String>[];
}

/// A meal-week draft, held on the coach's device. **Nothing is written.**
@immutable
class MealDraft {
  const MealDraft({required this.days});

  static const MealDraft empty = MealDraft(days: <MealDraftDay>[]);

  final List<MealDraftDay> days;

  int get dayCount => days.length;
  bool get isEmpty => days.isEmpty;
}
