/// W08 — **the only act that changes a plan.**
///
/// G14 §5, rule 2's row: this is "the sole caller of G2's `publishCoachPlan`".
/// Every other path in this feature — the draft repository, review feedback, a
/// re-assessment, an assistant handover — can reach `status:'draft'` and
/// nothing else. There is no auto-publish transition, no timer, and no "save
/// implies publish".
///
/// ## What this file deliberately does not import
///
/// `referral_registry.dart`. HANDOFF 14: `refer` is not a failure state and
/// **never blocks a publish**. The cheapest way to keep that true through every
/// later edit is for the publisher not to know referrals exist — a change that
/// made one block a publish would have to add the import, in review. The same
/// technique `LifeStageSafetyPolicy` uses, for the same reason, and both are
/// asserted by test.
///
/// ## Offline is not an error
///
/// `P2-OFF-W08`: the button stays **enabled**, its label changes, the intent is
/// queued idempotently and it publishes exactly once on reconnect. A disabled
/// publish button on a coach who has just planned a month reads as lost work,
/// and "failed to save" for something that will sync is a lie about her data.
///
/// G14 §4.3 states it as a rule about the control rather than about the copy —
/// W08 "replaces its primary button's label, does **not** disable it" — so
/// [PublishButton] has a label that varies and an `enabled` that cannot.
///
/// ## A coach meal publishes by value
///
/// G14 §7.1: "**A coach meal must be EMBEDDED by value, not referenced.** A
/// reference to `coaches/{coachUid}/meals/{id}` would force the client to read
/// another user's document, which the ruleset denies and should keep denying."
///
/// So the id never leaves this file. [requestFor] resolves each coach meal and
/// writes the dish itself into the payload, in §7.1's shape. Two consequences
/// follow, and both are the point: the client needs no cross-user read, and a
/// later edit to the coach's own meal does not silently change a published day
/// — the same property r12 gives a split.
///
/// A meal that cannot be resolved is **refused**, not published with the id
/// left in. A published day pointing at a document she is not allowed to read
/// is a blank dinner with no way to find out what it was.
library;

import 'package:meta/meta.dart';

import '../../../../domain/safety/life_stage_safety_policy.dart';
import '../meal/coach_meal.dart';
import 'plan_draft.dart';

/// What G2's callable is given. G14 §7.1, field for field.
@immutable
class PublishRequest {
  const PublishRequest({
    required this.clientUid,
    required this.draftId,
    required this.effectiveFrom,
    required this.source,
    required this.idempotencyKey,
    this.templateRef,
    this.payload = const <String, Object?>{},
  });

  final String clientUid;
  final String draftId;

  /// `yyyy-MM-dd`, already clamped to today or later here as well as on the
  /// server. G2 is authoritative; sending a past date anyway would be asking
  /// it to refuse something this side could have answered.
  final String effectiveFrom;

  /// `coach` or `split`.
  final String source;

  /// Provenance. Never dereferenced, here or there.
  final String? templateRef;

  /// `publishCoachPlan:{clientUid}:{month}:{draftHash}`. Three retries produce
  /// exactly one version.
  final String idempotencyKey;

  /// The days, with every unfilled meal slot made an explicit free choice.
  final Map<String, Object?> payload;

  @override
  String toString() => 'PublishRequest($draftId, $idempotencyKey)';
}

/// What the callable returns.
@immutable
class PublishReceipt {
  const PublishReceipt({
    required this.version,
    required this.assignmentsWritten,
    required this.mealSlotsWritten,
    this.supersededVersion,
  });

  final String version;
  final int assignmentsWritten;
  final int mealSlotsWritten;
  final String? supersededVersion;
}

/// G2's callable. Implemented server-side; faked in tests.
abstract class PlanPublishGateway {
  Future<PublishReceipt> publishCoachPlan(PublishRequest request);
}

/// Why a publish was refused before it was attempted.
///
/// There is no `referralOutstanding` value, and there never may be.
enum PublishRefusal {
  /// The first six weeks after birth, clearance recorded as withheld.
  clearanceWithheld,

  /// The first six weeks after birth, no clearance recorded at all. Unknown is
  /// not absent.
  clearanceUnrecorded,

  /// Her certificates are still being checked. She may author everything and
  /// publish nothing: putting a prescription in front of a woman on the
  /// strength of unchecked credentials is a different act from writing one.
  coachNotVerified,

  /// A day holds one of the coach's own meals and the dish could not be read,
  /// so there is nothing to embed. Publishing the id instead would write a day
  /// the client is not allowed to open. See the library note.
  coachMealUnreadable,
}

/// What W08's primary button offers. See the library note.
enum PublishButtonLabel {
  /// Online: publish now.
  publishNow,

  /// Offline: *we'll publish the moment you're back online* — G2's precedent,
  /// never a spinner and never a failure.
  publishWhenOnline,
}

/// W08's primary button, which has a label and no disabled state.
@immutable
class PublishButton {
  const PublishButton._(this.label);

  /// The button for [context]. The only thing that varies is the label.
  factory PublishButton.forContext(PublishContext context) => PublishButton._(
    context.online
        ? PublishButtonLabel.publishNow
        : PublishButtonLabel.publishWhenOnline,
  );

  final PublishButtonLabel label;

  /// Always true, and deliberately a getter with no field behind it: there is
  /// no constructor argument through which a screen could disable this button,
  /// so "W08 does not disable it" is a shape rather than a reminder.
  bool get enabled => true;

  bool get queues => label == PublishButtonLabel.publishWhenOnline;

  @override
  String toString() => 'PublishButton(${label.name})';
}

/// Everything the gate needs. Passed in, so nothing here reads a clock or a
/// session.
@immutable
class PublishContext {
  const PublishContext({
    required this.lifeStage,
    required this.today,
    this.clearance,
    this.coachVerified = true,
    this.online = true,
    this.source = 'coach',
    this.templateRef,
  });

  final LifeStage lifeStage;
  final Clearance? clearance;
  final DateTime today;
  final bool coachVerified;
  final bool online;
  final String source;
  final String? templateRef;
}

/// The outcome W08 renders.
@immutable
class PublishOutcome {
  const PublishOutcome.published(PublishReceipt this.receipt)
    : refusal = null,
      queued = null,
      error = null;

  const PublishOutcome.refused(PublishRefusal this.refusal)
    : receipt = null,
      queued = null,
      error = null;

  /// Offline. Not a failure: the intent is held and will publish once.
  const PublishOutcome.queuedOffline(PublishRequest this.queued)
    : receipt = null,
      refusal = null,
      error = null;

  /// The callable answered with an error. The draft keeps its content and the
  /// screen states a reason with a retry — never a half-written version,
  /// because G2 writes the version and its assignments in one transaction.
  const PublishOutcome.failed(Object this.error)
    : receipt = null,
      refusal = null,
      queued = null;

  final PublishReceipt? receipt;
  final PublishRefusal? refusal;
  final PublishRequest? queued;
  final Object? error;

  bool get isPublished => receipt != null;
  bool get isRefused => refusal != null;
  bool get isQueued => queued != null;
  bool get isFailed => error != null;

  /// Whatever happened, the draft is still a draft afterwards.
  PlanDraftStatus get resultingStatus => PlanDraftStatus.draft;
}

/// Holds publish intents while there is no signal.
abstract class PublishIntentQueue {
  Future<void> enqueue(PublishRequest request);
  List<PublishRequest> get pending;
}

/// The in-memory queue. Keyed on the idempotency key, so a coach pressing
/// publish three times offline queues **one** intent.
class InMemoryPublishIntentQueue implements PublishIntentQueue {
  final Map<String, PublishRequest> _pending = <String, PublishRequest>{};

  @override
  Future<void> enqueue(PublishRequest request) async {
    _pending[request.idempotencyKey] = request;
  }

  @override
  List<PublishRequest> get pending =>
      List<PublishRequest>.unmodifiable(_pending.values);

  void clear() => _pending.clear();
}

/// The only way a plan changes.
class CoachPlanPublisher {
  const CoachPlanPublisher({
    required this.gateway,
    required this.queue,
    this.coachMeals,
  });

  final PlanPublishGateway gateway;
  final PublishIntentQueue queue;

  /// Her own meals, for embedding. Null is correct for a workout-only month
  /// and refuses a meal-carrying one: a dish that cannot be read cannot be
  /// embedded, and the id may not travel in its place.
  final CoachMealResolver? coachMeals;

  /// Publishes [draft], or refuses, or queues the intent.
  Future<PublishOutcome> publish({
    required PlanDraft draft,
    required PublishContext context,
  }) async {
    if (!context.coachVerified) {
      return const PublishOutcome.refused(PublishRefusal.coachNotVerified);
    }

    final gate = LifeStageSafetyPolicy.publishGate(
      stage: context.lifeStage,
      clearance: context.clearance,
    );
    if (!gate.allowed) {
      return PublishOutcome.refused(switch (gate.reason!) {
        PublishBlockReason.clearanceWithheld => PublishRefusal.clearanceWithheld,
        PublishBlockReason.clearanceUnrecorded =>
          PublishRefusal.clearanceUnrecorded,
      });
    }

    // Before anything is sent, and identically online and offline: a day whose
    // dish cannot be read has nothing to embed.
    if (unreadableCoachMeals(draft).isNotEmpty) {
      return const PublishOutcome.refused(PublishRefusal.coachMealUnreadable);
    }

    final request = requestFor(draft: draft, context: context);

    if (!context.online) {
      await queue.enqueue(request);
      return PublishOutcome.queuedOffline(request);
    }

    try {
      return PublishOutcome.published(await gateway.publishCoachPlan(request));
    } on Object catch (error) {
      return PublishOutcome.failed(error);
    }
  }

  /// The request, built the same way online and offline — so the intent queued
  /// on a microbus is byte-identical to the one that would have been sent, and
  /// replaying it cannot produce a second version.
  PublishRequest requestFor({
    required PlanDraft draft,
    required PublishContext context,
  }) {
    final explicit = withExplicitFreeChoice(draft);
    final effectiveFrom = clampToToday(
      requested: draft.effectiveFrom,
      today: context.today,
    );
    return PublishRequest(
      clientUid: draft.clientUid,
      draftId: draft.draftId,
      effectiveFrom: effectiveFrom,
      source: context.source,
      templateRef: context.templateRef ?? draft.templateRef,
      idempotencyKey:
          'publishCoachPlan:${draft.clientUid}:${draft.month}:'
          '${explicit.contentHash}',
      payload: embedCoachMeals(explicit.toWire()),
    );
  }

  /// The coach-meal ids in [draft] that cannot be resolved to a dish.
  ///
  /// Named rather than counted, so W08 can say which meal it is instead of
  /// telling a coach that something, somewhere, went wrong.
  List<String> unreadableCoachMeals(PlanDraft draft) {
    final unreadable = <String>[];
    for (final day in draft.days.values) {
      final meal = day.meal;
      if (meal == null) continue;
      for (final assignment in meal.slots.values) {
        if (assignment == null || assignment.source != MealSlotSource.coach) {
          continue;
        }
        final mealId = assignment.coachMealId;
        if (mealId == null || coachMeals?.call(mealId) == null) {
          unreadable.add(mealId ?? '');
        }
      }
    }
    return unreadable;
  }

  /// Replaces every `coachMealId` in [payload] with the dish itself.
  ///
  /// G14 §7.1's shape, and the id is **gone** afterwards rather than carried
  /// alongside: a reference left in the payload is a reference somebody will
  /// eventually dereference.
  Map<String, Object?> embedCoachMeals(Map<String, Object?> payload) {
    final days = payload['days'];
    if (days is! Map<String, Object?>) return payload;

    for (final day in days.values) {
      if (day is! Map<String, Object?>) continue;
      final meal = day['meal'];
      if (meal is! Map<String, Object?>) continue;
      final slots = meal['slots'];
      if (slots is! Map<String, Object?>) continue;

      for (final slotKey in slots.keys.toList()) {
        final slot = slots[slotKey];
        if (slot is! Map<String, Object?>) continue;
        if (slot['source'] != MealSlotSource.coach.wireName) continue;

        final mealId = slot['coachMealId'];
        final dish = mealId is String ? coachMeals?.call(mealId) : null;
        // Unreachable through `publish`, which refuses first. Left as a drop
        // rather than a rethrow so a caller building a preview payload cannot
        // produce one carrying the id.
        if (dish == null) {
          slots[slotKey] = null;
          continue;
        }

        final servings = slot['servings'];
        final note = slot['note'];
        slots[slotKey] = <String, Object?>{
          'source': MealSlotSource.coach.wireName,
          ...dish.toEmbeddedValue(
            servings: servings is int ? servings : 1,
            slotNote: note is String ? note : null,
          ),
        };
      }
    }
    return payload;
  }

  /// Every gap becomes a stated free choice.
  ///
  /// `P0-PLAN-03`: publishing "marks them explicitly as free choice rather than
  /// leaving them undefined. The client's Eat screen renders free choice —
  /// never an empty planned row and never an error." The draft itself is
  /// untouched, so what she sees on W06 tomorrow is still the gap she left.
  static PlanDraft withExplicitFreeChoice(PlanDraft draft) {
    final days = <String, PlanDay>{};
    for (final entry in draft.days.entries) {
      final meal = entry.value.meal ?? DraftMealDay();
      var filled = meal;
      for (final slot in meal.gaps) {
        filled = filled.withSlot(slot, const MealSlotAssignment.freeChoice());
      }
      days[entry.key] = entry.value.withMeal(filled);
    }
    return draft.withDays(days);
  }

  /// `max(requested, today)`. A revision never rewrites finished work.
  static String clampToToday({
    required String? requested,
    required DateTime today,
  }) {
    final todayKey =
        '${today.year.toString().padLeft(4, '0')}-'
        '${today.month.toString().padLeft(2, '0')}-'
        '${today.day.toString().padLeft(2, '0')}';
    if (requested == null) return todayKey;
    return requested.compareTo(todayKey) > 0 ? requested : todayKey;
  }
}
