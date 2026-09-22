/// The coach's desk and her planning month — what `K07`/`K09` decide, what
/// `W01`–`W09`, `K16`–`K23` write, and the one published document the coached
/// screens (`G03`–`G16`) read back.
///
/// ## Why one object holds all of it
///
/// `CoachingLinkState` already holds the half of the relationship the
/// marketplace can see: who enquired, who accepted, who paid. The other half —
/// her roster, the month she is planning, the assessment, the thread, the
/// weekly review — was held by nobody, so `W01` was handed `const []`, `W03`
/// built a **new** empty `PlanDraft` on every build and `W08` had no builder at
/// all. Every one of those documents is keyed by the same relationship, and a
/// plan kept in one file with the client it is for kept in another is how a
/// coach publishes a month to a woman who is no longer her client.
///
/// ## Nothing here is seeded
///
/// There is no sample client, no sample plan, no sample review and no sample
/// earnings figure. [clients] is derived from the enquiries the tester actually
/// sent and the coach actually accepted; [draftFor] returns an empty month
/// until she plans one; [earnings] is built from `CoachingLinkState.payments`,
/// which only the test rail writes and only while no account is required. A
/// client's **name** is empty for the reason `_mirrorToCoachDesk` leaves the
/// desk row's empty: an `EnquiryDraft` carries no name, and this file will not
/// invent one.
///
/// ## What it still cannot do
///
///   * **Prescribe a move.** §2.10: "a planner selects, it never generates", so
///     a move must come from the bundled exercise pack — and `AssistantPack` is
///     empty in this build, as its own header says. `W04` therefore edits a
///     session's name, length, rest and note, and `onAddMove` stays unwired
///     rather than minting an exercise id nothing can resolve.
///   * **Offer a library food to a woman with an allergy.** Every food in
///     `eatSampleLibrary` carries `allergens: null` — unknown, not none — so
///     `AllergyGuard` fails closed and `W06` marks the slot blocked. That is
///     the guard working, not a gap.
library;

import '../domain/format/day_key.dart';
import '../domain/safety/client_constraints.dart';
import '../domain/safety/contraindication_tag.dart';
import '../domain/safety/life_stage_safety_policy.dart';
import '../domain/safety/screening_item.dart';
import '../features/account/domain/dietary_profile.dart';
import '../features/coach/domain/coach_chat.dart';
import '../features/coach/domain/enquiry.dart' as coach;
import '../features/coach/domain/payments.dart';
import '../features/coaching/domain/marketplace_stage.dart';
import '../features/coachplan/domain/assessment/assessment_form.dart';
import '../features/coachplan/domain/assessment/assessment_record.dart';
import '../features/coachplan/domain/clients/coach_client.dart';
import '../features/coachplan/domain/meal/coach_meal.dart';
import '../features/coachplan/domain/meal/meal_slot_planner.dart';
import '../features/coachplan/domain/plan/coach_plan_publisher.dart';
import '../features/coachplan/domain/plan/copy_week_planner.dart';
import '../features/coachplan/domain/plan/plan_draft.dart';
import '../features/coachplan/domain/plan/plan_draft_repository.dart';
import '../features/coachplan/domain/prescription.dart';
import '../features/coachplan/domain/review/review_feedback_service.dart';
import '../features/coachplan/domain/split/split.dart';
import '../features/coachplan/domain/split/split_applicator.dart';
import '../features/coachplan/domain/split/split_assignment_guard.dart';
import '../features/coachplan/domain/split/split_validator.dart';
import '../features/eat/domain/food_library.dart';
import '../routing/app_router.dart';
import 'app_changes.dart';
import 'coaching_link_state.dart';

/// One month as it went out, exactly as the publisher built it.
///
/// The draft the coach keeps editing and the document her client reads are two
/// objects on purpose (G14 §3.4): editing `W03` tomorrow must not change what
/// was assigned today. This is the second one, and it is written by
/// [CoachingDeskState.publishPlan] and by nothing else.
class PublishedMonth {
  PublishedMonth({
    required this.plan,
    required this.version,
    required this.publishedAt,
    required this.effectiveFrom,
  });

  /// The draft as it was published — every gap already turned into a stated
  /// free choice, which is what the client's Eat rows render.
  final PlanDraft plan;

  final String version;
  final DateTime publishedAt;

  /// `yyyy-MM-dd`, clamped to today or later by the publisher.
  final String effectiveFrom;

  PlanDay? dayAt(String key) => plan.dayAt(key);

  /// The days she was actually assigned, in date order.
  List<String> get dayKeys => plan.plannedDayKeys;
}

/// What one woman answered on `G12`, and what her coach wrote back on `W09`.
class WeekReview {
  WeekReview({
    required this.weekKey,
    this.manageable = 1,
    Set<int> changes = const <int>{},
    this.worked = '',
    this.weightOptIn = false,
    this.submittedAt,
    this.coachWords,
    this.answeredAt,
  }) : changes = Set<int>.unmodifiable(changes);

  /// The Monday of the week, as `yyyy-MM-dd`.
  final String weekKey;

  /// `G12`'s three chips, by index. Held as the screen's own value because
  /// nothing else reads it: the coach sees the word, not a score.
  final int manageable;

  final Set<int> changes;
  final String worked;
  final bool weightOptIn;

  final DateTime? submittedAt;

  /// `W09`'s answer. Null until the coach has written one.
  final String? coachWords;
  final DateTime? answeredAt;

  bool get isSubmitted => submittedAt != null;
  bool get isAnswered => (coachWords ?? '').trim().isNotEmpty;

  WeekReview copyWith({
    int? manageable,
    Set<int>? changes,
    String? worked,
    bool? weightOptIn,
    DateTime? submittedAt,
    String? coachWords,
    DateTime? answeredAt,
  }) => WeekReview(
    weekKey: weekKey,
    manageable: manageable ?? this.manageable,
    changes: changes ?? this.changes,
    worked: worked ?? this.worked,
    weightOptIn: weightOptIn ?? this.weightOptIn,
    submittedAt: submittedAt ?? this.submittedAt,
    coachWords: coachWords ?? this.coachWords,
    answeredAt: answeredAt ?? this.answeredAt,
  );
}

class CoachingDeskState {
  CoachingDeskState._();

  static final CoachingDeskState instance = CoachingDeskState._();

  CoachingLinkState get link => CoachingLinkState.instance;

  String get coachUid => AppRouter.coachRepository.coachUid;

  /// G5's sample pack, handed in by the screens that hold a dictionary.
  ///
  /// The library is resolved from `AppL10n` — `eat_sample_library.dart` says
  /// why — so it cannot be built here. `W06` passes it in on its way through,
  /// exactly as `TypeItView` and `RecipeView` resolve their own.
  FoodLibrary foods = FoodLibrary.empty;

  void useFoods(FoodLibrary library) => foods = library;

  // ───────────────────────────────────────────────────────── her roster

  /// Every relationship the coach has accepted, in the order they arrived.
  ///
  /// Accepted, not paid: the coach's book is what she has said yes to, and
  /// `W01` is the list of women she owes work. A declined or ended
  /// relationship is not on it.
  List<CoachClient> get clients {
    final out = <CoachClient>[];
    for (final entry in link.enquiries.entries) {
      final draft = entry.value;
      if (draft.coachUid != coachUid) continue;
      final stage = link.stageWith(draft.coachUid);
      if (stage != MarketplaceStage.acceptedAwaitingPayment &&
          stage != MarketplaceStage.coached) {
        continue;
      }
      out.add(_clientFor(entry.key, draft.clientUid));
    }
    return out;
  }

  /// The client every planning screen is about.
  ///
  /// Recorded at the tap on `W01`, `W10` or a desk row. When nothing has been
  /// tapped, it is the **first woman on her roster** — the one who has been
  /// waiting longest, since [clients] is in the order they arrived. A planner
  /// opened without a client refuses every write (`saveDraft` returns false on
  /// an empty `clientUid`), so the minutes chips, the meal slots and the rest
  /// would all be controls that cannot work: a month belonging to nobody. A
  /// roster of one never had that ambiguity; a roster of several resolves it
  /// the same way, and `W01` is one tap away for a different answer.
  ///
  /// An empty client only when she has **no** clients at all, which the
  /// planning screens render as their day-one state rather than as a form.
  CoachClient? openClient;

  CoachClient get client {
    final open = openClient;
    if (open != null) return open;
    final roster = clients;
    return roster.isEmpty
        ? const CoachClient(clientUid: '', displayName: '')
        : roster.first;
  }

  /// The relationship both women derive. Empty when no client is open, which
  /// is a screen with nothing on it rather than a thrown id.
  String relIdFor(String clientUid) => clientUid.isEmpty
      ? ''
      : relationshipIdFor(coachUid: coachUid, clientUid: clientUid);

  String clientUidOf(String relId) => link.enquiries[relId]?.clientUid ?? '';

  /// Whoever has waited longest for a reply. Null when nobody is waiting.
  CoachClient? get longestWaiting {
    final ordered = ClientQueue.longestWaitingFirst(clients);
    return ordered.isEmpty ? null : ordered.first;
  }

  CoachClient? clientFor(String clientUid) {
    for (final client in clients) {
      if (client.clientUid == clientUid) return client;
    }
    return null;
  }

  CoachClient _clientFor(String relId, String clientUid) {
    final accepted = _acceptedAt[relId];
    final review = reviewFor(relId);
    return CoachClient(
      clientUid: clientUid,
      // No name is carried on an enquiry and none is invented — the same
      // decision `_mirrorToCoachDesk` records for the desk row.
      displayName: '',
      queue: ClientQueueState(
        oldestUnansweredAt: _oldestUnansweredAt(relId),
        unreadForCoach: _unansweredCount(relId),
        reviewDueAt: review != null && review.isSubmitted && !review.isAnswered
            ? review.submittedAt
            : null,
        // A woman with nothing published needs a plan, from the moment her
        // coach said yes. Derived, never a flag somebody sets.
        planNeededAt: published.containsKey(clientUid) ? null : accepted,
        assessmentDueAt: assessments.containsKey(clientUid) ? null : accepted,
        latestAssessmentId: assessments[clientUid]?.assessmentId,
      ),
      startedOn: accepted,
    );
  }

  /// When each accept happened, so `W01`'s queue can be ordered by real time
  /// rather than by the order a map happens to iterate in.
  final Map<String, DateTime> _acceptedAt = <String, DateTime>{};

  /// `K09`'s accept. The marketplace half is `CoachingLinkState`'s; this is the
  /// half that puts her on the roster.
  void acceptEnquiry(String relId) {
    if (link.enquiries[relId] == null) return;
    link.acceptEnquiry(relId);
    if (link.enquiries[relId] case final draft?) {
      if (link.stageWith(draft.coachUid) ==
          MarketplaceStage.acceptedAwaitingPayment) {
        _acceptedAt[relId] ??= DateTime.now();
      }
    }
    AppChanges.bump();
  }

  void declineEnquiry(String relId) {
    _acceptedAt.remove(relId);
    link.declineEnquiry(relId);
    AppChanges.bump();
  }

  /// The enquiry `K09` opens — the real one, read back from the repository the
  /// marketplace mirrored it onto.
  coach.Enquiry? enquiryAt(String relId) {
    final draft = link.enquiries[relId];
    if (draft == null) return null;
    return coach.Enquiry(
      relId: relId,
      coachUid: draft.coachUid,
      clientUid: draft.clientUid,
      status: switch (link.stageWith(draft.coachUid)) {
        MarketplaceStage.enquiryDeclined => coach.EnquiryStatus.declined,
        MarketplaceStage.acceptedAwaitingPayment =>
          coach.EnquiryStatus.accepted,
        MarketplaceStage.coached => coach.EnquiryStatus.active,
        MarketplaceStage.coachingEnded => coach.EnquiryStatus.withdrawn,
        _ => coach.EnquiryStatus.enquiry,
      },
      enquiredAt: _enquiredAt.putIfAbsent(relId, DateTime.now),
      situation: draft.situation,
      herWords: draft.herWords,
    );
  }

  final Map<String, DateTime> _enquiredAt = <String, DateTime>{};

  // ─────────────────────────────────────────────────────────── the month

  final Map<String, PlanDraft> _drafts = <String, PlanDraft>{};

  /// Why the last save was refused, if it was. `null` after a save that took.
  Object? lastRefusal;

  /// This month's draft for [clientUid] — the one every planning screen edits.
  ///
  /// Pure: a route builder runs during a build, so this never writes. An
  /// unstored month is an empty one with the deterministic id, which is what a
  /// coach who has planned nothing actually holds.
  PlanDraft draftFor(String clientUid, {DateTime? now}) {
    final month = monthKey(now ?? DateTime.now());
    return _drafts[planDraftId(clientUid: clientUid, month: month)] ??
        PlanDraft(clientUid: clientUid, coachUid: coachUid, month: month);
  }

  /// Writes a month, through the same assertions the repository runs.
  ///
  /// A refused write leaves the stored month untouched and names the reason on
  /// [lastRefusal], rather than throwing out of a button callback.
  /// [notify] is false while she is typing: the field holds its own text and
  /// redrawing every open screen on each keystroke buys nothing. The screens
  /// behind it read the stored month when she leaves — the same arrangement
  /// `CoachPortfolioState.saveDraft` makes for a block editor.
  bool saveDraft(PlanDraft next, {bool notify = true}) {
    if (next.clientUid.isEmpty) return false;
    try {
      InMemoryPlanDraftRepository.assertWritable(
        next,
        safety: safetyFor(next.clientUid),
      );
    } on Object catch (refusal) {
      lastRefusal = refusal;
      AppChanges.bump();
      return false;
    }
    lastRefusal = null;
    _drafts[next.draftId] = next.withUpdatedAt(DateTime.now());
    if (notify) AppChanges.bump();
    return true;
  }

  /// One day of one month.
  bool setDay(String clientUid, String day, PlanDay? value) =>
      saveDraft(draftFor(clientUid).withDay(day, value));

  /// `W04`. Edits the session on [day], creating one when the day was a gap.
  ///
  /// Every field is optional and only what is passed is changed, so typing a
  /// name cannot clear the minutes she chose a moment earlier.
  bool editSession(
    String clientUid,
    String day, {
    String? title,
    int? minutes,
    int? restBetweenSetsSec,
    String? note,
    bool notify = true,
  }) {
    final draft = draftFor(clientUid);
    final existing = draft.dayAt(day);
    final workout = existing?.workout;
    final next = DraftWorkout(
      title: title ?? workout?.title ?? '',
      minutes: minutes ?? workout?.minutes ?? 0,
      sessionTemplateId: workout?.sessionTemplateId,
      restBetweenSetsSec: restBetweenSetsSec ?? workout?.restBetweenSetsSec,
      note: note ?? workout?.note,
      moves: workout?.moves ?? const <PrescribedMove>[],
      approvedAlternatives:
          workout?.approvedAlternatives ?? const <ApprovedAlternative>[],
    );
    return saveDraft(
      draft.withDay(
        day,
        PlanDay(
          kind: PlanDayKind.workout,
          workout: next,
          meal: existing?.meal,
          fromSplit: existing?.fromSplit,
        ),
      ),
      notify: notify,
    );
  }

  /// A day she decided is a rest day — which is not the same as a day she has
  /// not touched, and `W03` draws the two differently.
  bool setRestDay(String clientUid, String day) {
    final draft = draftFor(clientUid);
    final existing = draft.dayAt(day);
    return saveDraft(draft.withDay(day, PlanDay.rest(meal: existing?.meal)));
  }

  // ─────────────────────────────────────────────────────────── her meals

  /// Her own dishes, by id. Written by `W07` and by nothing else.
  final Map<String, CoachMeal> meals = <String, CoachMeal>{};

  /// The dish `W07` is editing, or null when she is writing a new one.
  String? editingMealId;

  /// `W07`'s fields while she types them. Held here rather than in the screen
  /// because the save happens in the footer and a controller the router cannot
  /// see is a save button with nothing to save.
  String mealName = '';
  String mealIngredients = '';
  int mealServings = 1;
  int? mealPrepMinutes;
  String mealNote = '';

  void startNewMeal() {
    editingMealId = null;
    mealName = '';
    mealIngredients = '';
    mealServings = 1;
    mealPrepMinutes = null;
    mealNote = '';
  }

  /// `W07`'s save, from the fields above — and, when `W06` had a slot open, it
  /// lands in that slot rather than in a library she then has to search.
  CoachMeal? saveMealFromFields(String clientUid) {
    if (mealName.trim().isEmpty) return null;
    final meal = saveMeal(
      name: mealName.trim(),
      ingredientLines: mealIngredients.split('\n'),
      servings: mealServings,
      prepMinutes: mealPrepMinutes,
      note: mealNote.trim().isEmpty ? null : mealNote.trim(),
    );
    final day = openMealDay;
    final slot = openSlot;
    if (day != null && slot != null && clientUid.isNotEmpty) {
      assignSlot(
        clientUid,
        day,
        slot,
        MealSlotAssignment.coachMeal(coachMealId: meal.mealId),
      );
    }
    return meal;
  }

  CoachMeal? get editingMeal => meals[editingMealId];

  String nextMealId() => 'meal-${meals.length + 1}';

  /// `W07`. Saves a dish with its nutrition **derived** — an unresolved
  /// ingredient means no figures at all, which `CoachMeal.compose` enforces.
  CoachMeal saveMeal({
    required String name,
    required List<String> ingredientLines,
    int servings = 1,
    int? prepMinutes,
    String? note,
  }) {
    final id = editingMealId ?? nextMealId();
    final meal = CoachMeal.compose(
      mealId: id,
      name: name,
      ingredients: <MealIngredient>[
        for (final line in ingredientLines)
          if (line.trim().isNotEmpty)
            MealIngredient(
              text: line.trim(),
              // Resolved against G5's pack when the pack knows the line. A
              // line it does not know stays unresolved, and the whole dish
              // then carries no numbers.
              foodId: foods.resolve(line.trim()).firstOrNull?.foodId,
            ),
      ],
      lookup: _ingredientFigures,
      servings: servings,
      prepMinutes: prepMinutes,
      note: note,
    );
    meals[id] = meal;
    editingMealId = id;
    AppChanges.bump();
    return meal;
  }

  IngredientFigures? _ingredientFigures(MealIngredient ingredient) {
    final id = ingredient.foodId;
    if (id == null) return null;
    final food = foods.byId(id);
    final size = food?.sizes.isNotEmpty ?? false ? food!.sizes.first : null;
    if (size == null) return null;
    return (kcal: size.kcal, proteinG: size.proteinG);
  }

  /// The slot `W06` has open, so the dish she writes next lands in it.
  PlanMealSlot? openSlot;
  String? openMealDay;

  /// `W06`. Puts [assignment] in one slot of one day, or clears it.
  bool assignSlot(
    String clientUid,
    String day,
    PlanMealSlot slot,
    MealSlotAssignment? assignment,
  ) {
    final draft = draftFor(clientUid);
    final existing = draft.dayAt(day);
    final meal = (existing?.meal ?? DraftMealDay()).withSlot(slot, assignment);
    final next = existing == null
        ? PlanDay(kind: PlanDayKind.workout, meal: meal)
        : existing.withMeal(meal);
    return saveDraft(draft.withDay(day, next));
  }

  /// What one tap on a `W06` slot does.
  ///
  /// There is no picker screen in this feature and no bottom sheet was added:
  /// the tap cycles the slot through the answers that actually exist — nothing,
  /// *her choice*, then each dish the coach has written — so every tap changes
  /// something on screen and nothing offers content nobody authored.
  bool cycleSlot(String clientUid, String day, PlanMealSlot slot) {
    openMealDay = day;
    openSlot = slot;
    final current = draftFor(clientUid).dayAt(day)?.meal?.slots[slot];
    final dishes = meals.keys.toList(growable: false);

    if (current == null) {
      return assignSlot(
        clientUid,
        day,
        slot,
        const MealSlotAssignment.freeChoice(),
      );
    }
    if (current.isFreeChoice) {
      if (dishes.isEmpty) return assignSlot(clientUid, day, slot, null);
      return assignSlot(
        clientUid,
        day,
        slot,
        MealSlotAssignment.coachMeal(coachMealId: dishes.first),
      );
    }
    final at = dishes.indexOf(current.coachMealId ?? '');
    if (at >= 0 && at + 1 < dishes.length) {
      return assignSlot(
        clientUid,
        day,
        slot,
        MealSlotAssignment.coachMeal(coachMealId: dishes[at + 1]),
      );
    }
    return assignSlot(clientUid, day, slot, null);
  }

  /// `W06`'s "Select app meal": the next food from G5's pack, screened first.
  ///
  /// Every food in the stand-in pack carries unknown allergens, so this is
  /// refused for a woman who named an allergy — by the guard, in the write
  /// path, with the slot marked blocked. That is the interlock, not a bug.
  bool assignAppMeal(String clientUid, String day, PlanMealSlot slot) {
    final offerable = MealSlotPlanner(safetyFor(clientUid))
        .offerable(foods.foods);
    if (offerable.isEmpty) return false;
    final current = draftFor(clientUid).dayAt(day)?.meal?.slots[slot];
    final currentId = current?.foodIds.isNotEmpty ?? false
        ? current!.foodIds.first
        : null;
    final at = offerable.indexWhere((food) => food.foodId == currentId);
    final next = offerable[(at + 1) % offerable.length];
    return assignSlot(
      clientUid,
      day,
      slot,
      MealSlotAssignment.fromLibrary(foodIds: <String>[next.foodId]),
    );
  }

  /// Every slot in her month that may not be written, with the allergen named.
  List<BlockedMealSlot> blockedSlots(String clientUid) =>
      MealSlotPlanner(safetyFor(clientUid)).blockedSlots(draftFor(clientUid));

  MealSafety safetyFor(String clientUid) => MealSafety(
    constraints: constraintsFor(clientUid),
    foods: foods.byId,
    coachMeals: (id) => meals[id],
  );

  // ──────────────────────────────────────────────────────────── W05 copy

  /// The destination weeks `W05` has ticked.
  final Set<int> copyTargets = <int>{};

  void toggleCopyTarget(int week) {
    if (!copyTargets.remove(week)) copyTargets.add(week);
    AppChanges.bump();
  }

  List<String> _weekDayKeys(PlanDraft draft, int week) {
    final all = monthDays(draft.month);
    return all.skip(week * 7).take(7).toList(growable: false);
  }

  Map<String, PlanDay> copyProjection(String clientUid, int sourceWeek) {
    final draft = draftFor(clientUid);
    final source = _weekDayKeys(draft, sourceWeek);
    if (source.isEmpty) return const <String, PlanDay>{};
    final starts = <DateTime>[];
    for (final week in copyTargets) {
      if (week == sourceWeek) continue;
      final days = _weekDayKeys(draft, week);
      if (days.isEmpty) continue;
      final start = _dateOf(days.first);
      if (start != null) starts.add(start);
    }
    return const CopyWeekPlanner().project(
      draft: draft,
      sourceDayKeys: source,
      targetStarts: starts,
    );
  }

  /// `W05`'s confirm. Names what it replaces first — [copySummary] — and then
  /// merges, which touches only the days it names.
  bool applyCopy(String clientUid, int sourceWeek) {
    final projection = copyProjection(clientUid, sourceWeek);
    if (projection.isEmpty) return false;
    final applied = const CopyWeekPlanner().apply(
      draft: draftFor(clientUid),
      projection: projection,
    );
    final written = saveDraft(applied);
    if (written) copyTargets.clear();
    return written;
  }

  /// How many weeks `W05` offers — the month's, never a fixed four.
  int weekCountFor(String clientUid) {
    final days = monthDays(draftFor(clientUid).month).length;
    return (days / 7).ceil();
  }

  /// Days the copy would write outside this month. Named, because a second
  /// month is a second document and half-applying a week is the defect.
  List<String> copyDaysOutsideMonth(String clientUid, int sourceWeek) =>
      const CopyWeekPlanner().daysOutsideMonth(
        draft: draftFor(clientUid),
        projection: copyProjection(clientUid, sourceWeek),
      );

  OverwriteSummary copySummary(String clientUid, int sourceWeek) =>
      const CopyWeekPlanner().summarise(
        draft: draftFor(clientUid),
        projection: copyProjection(clientUid, sourceWeek),
      );

  // ─────────────────────────────────────────────────────────── her splits

  /// Her templates. `K19` lists them; `K20` writes them.
  final List<Split> splits = <Split>[];

  /// The split `K20` has open, or null when she tapped "build a split".
  Split? openSplit;

  Split get splitInProgress =>
      _editing ??
      openSplit ??
      Split(
        splitId: 'split-${splits.length + 1}',
        name: '',
        cycleLength: 7,
        daySlots: <SplitDaySlot>[
          for (var day = 1; day <= 7; day++) SplitDaySlot.rest(dayIndex: day),
        ],
        ownerKind: SplitOwnerKind.coach,
      );

  Split? _editing;

  void openSplitForEditing(Split? split) {
    openSplit = split;
    _editing = null;
    AppChanges.bump();
  }

  void editSplit(Split next) {
    _editing = next;
    AppChanges.bump();
  }

  void setSplitName(String name) =>
      editSplit(splitInProgress.withChanges(name: name));

  void setSplitCycleLength(int length) {
    final current = splitInProgress;
    editSplit(
      current.withChanges(
        cycleLength: length,
        daySlots: <SplitDaySlot>[
          for (var day = 1; day <= length; day++)
            current.slotFor(day) ?? SplitDaySlot.rest(dayIndex: day),
        ],
      ),
    );
  }

  /// One tap on a `K20` day: rest becomes a training day named after the split,
  /// and a training day becomes rest again.
  ///
  /// The title is **her** split's name rather than a phrase this file made up,
  /// which is also what `SplitValidator` asks for: a session must carry one.
  void toggleSplitSlot(int dayIndex) {
    final current = splitInProgress;
    final slot = current.slotFor(dayIndex);
    final name = current.name.trim();
    final next = slot != null && !slot.isRest
        ? SplitDaySlot.rest(dayIndex: dayIndex)
        : SplitDaySlot(
            dayIndex: dayIndex,
            kind: DaySlotKind.session,
            title: name.isEmpty ? null : name,
          );
    editSplit(
      current.withChanges(
        daySlots: <SplitDaySlot>[
          for (final existing in current.daySlots)
            if (existing.dayIndex == dayIndex) next else existing,
        ],
      ),
    );
  }

  void setSplitCarryApproved(bool value) =>
      editSplit(splitInProgress.withChanges(carryApproved: value));

  List<SplitInvalid> get splitProblems =>
      const SplitValidator().problems(splitInProgress);

  /// `K20`'s save. Refused, with its reasons on screen, when the template is
  /// not yet a template.
  bool saveSplit() {
    final split = splitInProgress;
    if (splitProblems.isNotEmpty) return false;
    final stamped = split.withChanges(updatedAt: DateTime.now());
    final at = splits.indexWhere((s) => s.splitId == split.splitId);
    if (at >= 0) {
      splits[at] = stamped;
    } else {
      splits.add(stamped);
    }
    openSplit = stamped;
    _editing = null;
    AppChanges.bump();
    return true;
  }

  /// `K19`/`K20`. Writes the template across this client's month, by value.
  ///
  /// The guard runs first and always: a coach with no live relationship to
  /// this woman is, for this purpose, a stranger.
  bool applySplit(Split split, String clientUid, {DateTime? from}) {
    final draft = draftFor(clientUid);
    final days = monthDays(draft.month);
    final start = from ?? DateTime.now();
    final dates = <DateTime>[
      for (final key in days)
        if (_dateOf(key) case final date?)
          if (!date.isBefore(DateTime(start.year, start.month, start.day)))
            date,
    ];
    if (dates.isEmpty) return false;

    final SplitApplication application;
    try {
      application = const SplitApplicator().materialise(
        split: split,
        clientUid: clientUid,
        dates: dates,
        actor: PlanningActor.coach(coachUid),
        hasActiveRelationship: clientFor(clientUid) != null,
        constraints: constraintsFor(clientUid),
        // Empty in this build: no exercise pack exists, so no move survives
        // screening and every session arrives as its title and its length.
        catalogue: (_) => null,
        coachUid: coachUid,
      );
    } on Object catch (refusal) {
      lastRefusal = refusal;
      AppChanges.bump();
      return false;
    }
    return saveDraft(
      draft
          .withDays(application.days, origin: DraftOrigin.split)
          .withTemplateRef('coaches/$coachUid/splits/${split.splitId}'),
    );
  }

  // ──────────────────────────────────────────────────────── K21/K22/K23

  /// `K21` and `K23` write to ONE form. It moved here from the router so that
  /// saving it has somewhere to put the record.
  AssessmentForm form = AssessmentForm(clientUid: '');

  /// The latest assessment for each client, by uid.
  final Map<String, AssessmentRecord> assessments =
      <String, AssessmentRecord>{};

  /// Everything ever recorded about her, newest last — `K22`'s chain.
  final Map<String, List<AssessmentRecord>> assessmentHistory =
      <String, List<AssessmentRecord>>{};

  /// Opens the form for [clientUid], pre-filled from her last assessment when
  /// there is one. Nothing is overwritten until she saves.
  void openAssessment(String clientUid) {
    final previous = assessments[clientUid];
    form = previous == null
        ? AssessmentForm(clientUid: clientUid, coachUid: coachUid)
        : AssessmentForm.from(previous);
    AppChanges.bump();
  }

  void editForm(AssessmentForm next) {
    form = next;
    AppChanges.bump();
  }

  void setLifeStage(LifeStage stage) =>
      editForm(form.withHealth(lifeStage: stage));

  void setBirthType(BirthType type) =>
      editForm(form.withHealth(birthType: type));

  void setClearance(bool granted) => editForm(
    form.withHealth(
      clearance: Clearance(granted: granted, recordedAt: DateTime.now()),
    ),
  );

  void toggleAvoidTag(ContraindicationTag tag) {
    final next = <ContraindicationTag>{...form.avoid};
    if (!next.remove(tag)) next.add(tag);
    editForm(form.withHealth(avoid: next));
  }

  void setPainNotes(String notes) =>
      editForm(form.withHealth(painNotes: notes));

  /// `K23`. Writes both steps as one document, or nothing at all.
  AssessmentRecord? saveAssessment() {
    if (!form.canSave || form.clientUid.isEmpty) return null;
    final record = form.build(
      takenAt: DateTime.now(),
      carryFrom: assessments[form.clientUid],
    );
    final previous = assessments[form.clientUid];
    assessments[form.clientUid] = record;
    assessmentHistory
        .putIfAbsent(form.clientUid, () => <AssessmentRecord>[])
        .add(previous == null ? record : record);
    AppChanges.bump();
    return record;
  }

  /// The referrals `K22` puts at the top — carried forward from the last
  /// assessment, so one the coach simply omits has not been cleared.
  List<ScreeningItem> activeReferralsFor(String clientUid) =>
      constraintsFor(clientUid).referrals;

  /// Her constraints, from the one source rule 13 allows — her assessment,
  /// plus the allergies she declared herself.
  ///
  /// Fails closed: no assessment means *unresolved*, never an empty set.
  ClientConstraints constraintsFor(String clientUid) {
    final record = assessments[clientUid];
    final history = assessmentHistory[clientUid] ?? const <AssessmentRecord>[];
    final prior = history.length >= 2
        ? history[history.length - 2].assessment
        : null;
    return ClientConstraintResolver.resolve(
      assessment: record?.assessment,
      priorAssessment: prior,
      allergies: declaredAllergies,
      dietary: declaredDietary,
    );
  }

  /// What the woman herself declared on `G17`. Null until she has answered —
  /// unknown, never "she has none".
  Set<String>? declaredAllergies;
  Set<String>? declaredDietary;

  void declareDiet({Set<AllergenTag>? allergies, Set<DietaryTag>? dietary}) {
    if (allergies != null) {
      declaredAllergies = <String>{for (final a in allergies) a.wireName};
    }
    if (dietary != null) {
      declaredDietary = <String>{for (final d in dietary) d.wireName};
    }
    AppChanges.bump();
  }

  // ───────────────────────────────────────────────────────── the thread

  late final InMemoryMessageSink _sink = InMemoryMessageSink();

  late final CoachChatService chat = CoachChatService(
    sink: _sink,
    coachUid: coachUid,
  );

  final Map<String, List<CoachMessage>> threads =
      <String, List<CoachMessage>>{};

  List<CoachMessage> threadFor(String relId) =>
      threads[relId] ?? const <CoachMessage>[];

  /// One conversation, written from either side.
  ///
  /// `K16` and `G14` are the same thread: the relationship id is derived from
  /// both parties, so there is one list and both screens read it.
  void sendMessage({
    required String relId,
    required String body,
    required bool fromCoach,
  }) {
    if (body.trim().isEmpty) return;
    final draft = link.enquiries[relId];
    if (draft == null) return;
    final thread = threads.putIfAbsent(relId, () => <CoachMessage>[]);
    thread.add(
      CoachMessage(
        msgId: '$relId-${thread.length + 1}',
        relId: relId,
        senderUid: fromCoach ? coachUid : draft.clientUid,
        coachUid: draft.coachUid,
        clientUid: draft.clientUid,
        body: body.trim(),
        createdAt: DateTime.now(),
        delivery: MessageDelivery.sent,
      ),
    );
    AppChanges.bump();
  }

  DateTime? _oldestUnansweredAt(String relId) {
    final thread = threadFor(relId);
    DateTime? oldest;
    for (final message in thread.reversed) {
      if (message.senderUid == coachUid) break;
      oldest = message.createdAt;
    }
    return oldest;
  }

  int _unansweredCount(String relId) {
    var count = 0;
    for (final message in threadFor(relId).reversed) {
      if (message.senderUid == coachUid) break;
      count++;
    }
    return count;
  }

  // ─────────────────────────────────────────────────────── weekly review

  final Map<String, WeekReview> reviews = <String, WeekReview>{};

  WeekReview? reviewFor(String relId) => reviews[relId];

  /// What the coach has typed on `W09` and not yet saved.
  String replyDraft = '';

  /// The Monday of [moment]'s week. Weeks, never days — rule 4.
  static String weekKeyFor(DateTime moment) {
    final monday = DateTime(
      moment.year,
      moment.month,
      moment.day,
    ).subtract(Duration(days: moment.weekday - DateTime.monday));
    return dayKey(monday);
  }

  WeekReview openReview(String relId) =>
      reviews[relId] ?? WeekReview(weekKey: weekKeyFor(DateTime.now()));

  void editReview(String relId, WeekReview next) {
    reviews[relId] = next;
    AppChanges.bump();
  }

  /// `G12`'s send.
  void submitReview(String relId) {
    reviews[relId] = openReview(relId).copyWith(submittedAt: DateTime.now());
    AppChanges.bump();
  }

  /// `W09`'s *Save feedback*. It publishes nothing — the service it mirrors
  /// cannot, and neither can this.
  void saveFeedback(String relId, String words) {
    replyDraft = '';
    if (words.trim().isEmpty) return;
    reviews[relId] = openReview(relId)
        .copyWith(coachWords: words.trim(), answeredAt: DateTime.now());
    AppChanges.bump();
  }

  /// `W09`'s rollup, from her logs alone.
  WeekReviewSummary summaryFor(String clientUid, {DateTime? now}) {
    final month = published[clientUid];
    if (month == null) return const WeekReviewSummary.unavailable();
    final week = weekKeyFor(now ?? DateTime.now());
    final days = <String>[
      for (var i = 0; i < 7; i++)
        if (_dateOf(week) case final start?)
          dayKey(start.add(Duration(days: i))),
    ];
    var planned = 0;
    for (final day in days) {
      if (month.dayAt(day)?.hasWorkout ?? false) planned++;
    }
    return WeekReviewSummary(
      sessionsPlanned: planned,
      sessionsLogged: sessionsDone.where(days.contains).length,
      mealDaysLogged: days.where(mealDays.contains).length,
      daysInWeek: 7,
    );
  }

  /// The days she finished a session on, and the days she logged food on.
  ///
  /// Held here rather than on the client's own state because `W09` reads them
  /// and a coach may not read a client's documents: this is the projection,
  /// and it carries counts and no figures about her body.
  final Set<String> sessionsDone = <String>{};
  final Set<String> mealDays = <String>{};

  // ────────────────────────────────────────────────────────── publishing

  final Map<String, PublishedMonth> published = <String, PublishedMonth>{};

  /// What the last publish answered. `W08` renders it.
  PublishOutcome? lastPublish;

  late final _DeskPublishGateway _gateway = _DeskPublishGateway();
  final InMemoryPublishIntentQueue _queue = InMemoryPublishIntentQueue();

  /// Everything the gate reads at the moment of publishing.
  ///
  /// The life stage comes from her assessment. With none recorded it is
  /// `LifeStage.none` and `W08` says, in its own words, that nobody screened
  /// her — which is the screen's designed behaviour ("publish anyway, or open
  /// the assessment"), not a stage this file decided she is in.
  PublishContext publishContextFor(String clientUid, {DateTime? now}) =>
      PublishContext(
        lifeStage:
            assessments[clientUid]?.assessment.lifeStage ?? LifeStage.none,
        clearance: assessments[clientUid]?.assessment.clearance,
        today: now ?? DateTime.now(),
        coachVerified:
            AppRouter.coachRepository.profileUnbilled.verification.mayPublish,
        source: draftFor(clientUid).templateRef == null ? 'coach' : 'split',
      );

  bool hasAssessment(String clientUid) => assessments.containsKey(clientUid);

  /// Whether `W03` holds edits that are not in the published version.
  bool draftIsDirty(String clientUid) {
    final month = published[clientUid];
    if (month == null) return draftFor(clientUid).days.isNotEmpty;
    return CoachPlanPublisher.withExplicitFreeChoice(draftFor(clientUid))
            .contentHash !=
        month.plan.contentHash;
  }

  List<String> unreadableMealIds(String clientUid) => CoachPlanPublisher(
    gateway: _gateway,
    queue: _queue,
    coachMeals: (id) => meals[id],
  ).unreadableCoachMeals(draftFor(clientUid));

  /// `W08`. The only act that changes a plan.
  Future<PublishOutcome> publishPlan(String clientUid, {DateTime? now}) async {
    final at = now ?? DateTime.now();
    final draft = draftFor(clientUid, now: at);
    final context = publishContextFor(clientUid, now: at);
    final publisher = CoachPlanPublisher(
      gateway: _gateway,
      queue: _queue,
      coachMeals: (id) => meals[id],
    );
    final outcome = await publisher.publish(draft: draft, context: context);
    lastPublish = outcome;

    if (outcome.receipt case final receipt?) {
      final request = publisher.requestFor(draft: draft, context: context);
      published[clientUid] = PublishedMonth(
        plan: CoachPlanPublisher.withExplicitFreeChoice(draft),
        version: receipt.version,
        publishedAt: at,
        effectiveFrom: request.effectiveFrom,
      );
      // The coach's own document records what went out, so `W03` renders the
      // version with no signal and no second read.
      saveDraft(
        draft.withLastPublished(
          LastPublished(
            version: receipt.version,
            at: at,
            dayCount: receipt.assignmentsWritten,
            mealSlotCount: receipt.mealSlotsWritten,
          ),
        ),
      );
    }
    AppChanges.bump();
    return outcome;
  }

  // ───────────────────────────────────────────────────────────── K17

  /// Her month, from the payments the test rail actually settled.
  ///
  /// Unavailable — never zero — when nothing has been paid: a zero is a claim
  /// about her month, and `K17` draws the two differently.
  EarningsState get earnings {
    final records = <String, int>{};
    var gross = 0;
    for (final entry in link.payments.entries) {
      final coachOf = entry.key.split('__').first;
      if (coachOf != coachUid) continue;
      final piastres = entry.value.priced.piastres;
      gross += piastres;
      records.update(
        entry.value.relId,
        (value) => value + piastres,
        ifAbsent: () => piastres,
      );
    }
    if (records.isEmpty) {
      return const EarningsState.unavailable(
        PaymentUnavailableReason.notImplemented,
      );
    }
    // The 80% is the product's promise and the provider applies it; here the
    // same arithmetic is done in one place so the row and the total cannot
    // disagree.
    final share = (gross * 80) ~/ 100;
    final now = DateTime.now();
    return EarningsState.statement(
      EarningsStatement(
        monthKey: monthKey(now),
        grossPiastres: gross,
        sharePiastres: share,
        lines: <EarningsLine>[
          for (final entry in records.entries)
            EarningsLine(
              offerId: entry.key,
              count: 1,
              grossPiastres: entry.value,
              sharePiastres: (entry.value * 80) ~/ 100,
            ),
        ],
        asOf: now,
        payoutState: PayoutState.accruing,
      ),
    );
  }

  // ───────────────────────────────────────────────────────────── helpers

  /// Every `yyyy-MM-dd` in a `yyyy-MM`.
  static List<String> monthDays(String month) {
    final parts = month.split('-');
    if (parts.length != 2) return const <String>[];
    final year = int.tryParse(parts[0]);
    final index = int.tryParse(parts[1]);
    if (year == null || index == null) return const <String>[];
    final length = DateTime(year, index + 1, 0).day;
    return <String>[
      for (var day = 1; day <= length; day++)
        dayKey(DateTime(year, index, day)),
    ];
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

  /// Back to a coach with no clients, no month and no thread.
  void reset() {
    _drafts.clear();
    _acceptedAt.clear();
    _enquiredAt.clear();
    meals.clear();
    editingMealId = null;
    openClient = null;
    replyDraft = '';
    mealName = '';
    mealIngredients = '';
    mealServings = 1;
    mealPrepMinutes = null;
    mealNote = '';
    openSlot = null;
    openMealDay = null;
    copyTargets.clear();
    splits.clear();
    openSplit = null;
    _editing = null;
    form = AssessmentForm(clientUid: '');
    assessments.clear();
    assessmentHistory.clear();
    declaredAllergies = null;
    declaredDietary = null;
    threads.clear();
    reviews.clear();
    sessionsDone.clear();
    mealDays.clear();
    published.clear();
    lastPublish = null;
    lastRefusal = null;
    _queue.clear();
    _gateway.reset();
    foods = FoodLibrary.empty;
  }
}

/// The publish callable, standing in for the Function `W08` would reach.
///
/// It mints the version and counts what it wrote, which is all `PublishReceipt`
/// carries. It cannot refuse: every refusal this feature has is decided by
/// `CoachPlanPublisher` before anything is sent, which is where the rules live.
class _DeskPublishGateway implements PlanPublishGateway {
  int _versions = 0;
  final Map<String, PublishReceipt> _byKey = <String, PublishReceipt>{};

  @override
  Future<PublishReceipt> publishCoachPlan(PublishRequest request) async {
    // Three retries of one publish produce exactly one version — the whole
    // point of the idempotency key.
    final seen = _byKey[request.idempotencyKey];
    if (seen != null) return seen;

    final days = request.payload['days'];
    var assignments = 0;
    var slots = 0;
    if (days is Map<String, Object?>) {
      for (final day in days.values) {
        if (day is! Map<String, Object?>) continue;
        if (day['workout'] != null) assignments++;
        final meal = day['meal'];
        if (meal is! Map<String, Object?>) continue;
        final filled = meal['slots'];
        if (filled is! Map<String, Object?>) continue;
        for (final slot in filled.values) {
          if (slot != null) slots++;
        }
      }
    }
    final receipt = PublishReceipt(
      version: 'v${++_versions}',
      assignmentsWritten: assignments,
      mealSlotsWritten: slots,
      supersededVersion: _versions > 1 ? 'v${_versions - 1}' : null,
    );
    _byKey[request.idempotencyKey] = receipt;
    return receipt;
  }

  void reset() {
    _versions = 0;
    _byKey.clear();
  }
}
