/// The order of the gates, which is the whole of the feature's safety.
///
/// Every rule G15 owns is a statement about *sequence*, and this file is where
/// the sequence lives:
///
/// ```
///   flag off ─────────────► unavailable(switchedOff)     no call, no spend
///   offline ──────────────► unavailable(offline)         no call, no queue
///   over the cap ─────────► capped                       no call, no spend
///   guardrail throws ─────► unavailable(guardrail)       ** never falls through **
///   guardrail refuses ────► refused(category)            ** provider never invoked **
///   provider refuses ─────► refused(category)            stop reason read before content
///   provider truncates ───► unavailable(truncated)       never a half pick list
///   delivered ────────────► validated, then answered     unknown ids dropped
/// ```
///
/// ## The two that are easiest to get wrong
///
/// **Fail closed.** A guardrail that throws must not reach the answer model.
/// The `catch` below returns rather than continues, and
/// `assistant_service_test.dart` proves it with a provider that fails the test
/// if it is ever called. `P0-ASK-17`.
///
/// **Never generated, then suppressed.** For a severe symptom the suggestion is
/// not composed and hidden — the provider is never invoked, so no suggestion
/// exists in memory, in a log, or in a response that a later refactor might
/// start rendering. HANDOFF rule 5, and `P0-ASK-05`.
///
/// ## It writes nothing, and cannot
///
/// There is no repository here. Not a private one, not an injected one: this
/// class holds a classifier, a provider, a quota counter, a pack and the flags.
/// `K26` and `K27` hand the validated draft to the screen, the screen hands it
/// to **the owning group's** service after the coach taps, and that service
/// performs the write. G15 D1 — which is what makes "there is no server path
/// from a model token to a published plan" a fact about the code rather than a
/// claim about intentions.
library;

import 'package:meta/meta.dart';

import '../../../domain/flags/feature_flags.dart';
import 'assistant_pack.dart';
import 'assistant_provider.dart';
import 'assistant_quota.dart';
import 'assistant_validator.dart';
import 'assistant_wire.dart';
import 'safety_classifier.dart';

/// What the caller gets back. Sealed, so every screen state is named.
@immutable
sealed class AssistantOutcome {
  const AssistantOutcome();
}

/// A grounded answer, already validated against the pack.
final class AssistantAnswered extends AssistantOutcome {
  const AssistantAnswered(this.answer);

  final AssistantAnswer answer;
}

/// `X02`. Carries the category, so the screen chooses the right copy and the
/// right ordering of the two routes.
final class AssistantRefusal extends AssistantOutcome {
  const AssistantRefusal(this.category);

  final RefusalCategory category;
}

/// She has used today's allowance. The screen offers `Ask Sara instead`, which
/// is enabled and works offline.
final class AssistantCapped extends AssistantOutcome {
  const AssistantCapped(this.route);

  final QuotaRoute route;
}

/// Nothing was produced, and the screen says why without a raw error.
final class AssistantUnavailable extends AssistantOutcome {
  const AssistantUnavailable(this.reason);

  final AssistantUnavailableReason reason;
}

/// A draft is held on the device. **Nothing has been written.**
final class AssistantPlanDrafted extends AssistantOutcome {
  const AssistantPlanDrafted(this.draft);

  final PlanDraft draft;
}

/// A meal-week draft is held on the device. **Nothing has been written.**
final class AssistantMealDrafted extends AssistantOutcome {
  const AssistantMealDrafted(this.draft);

  final MealDraft draft;
}

/// Runs the gates in order. The only entry point the screens use.
class AssistantService {
  AssistantService({
    required this.classifier,
    required this.provider,
    required this.pack,
    AssistantQuota? quota,
    this.flags = FeatureFlags.shipped,
  }) : quota = quota ?? AssistantQuota();

  final SafetyClassifier classifier;
  final AssistantProvider provider;
  final AssistantPack pack;
  final AssistantQuota quota;
  final FeatureFlags flags;

  late final AssistantResponseValidator _validator = AssistantResponseValidator(
    pack,
  );

  /// `X01` — ask a question.
  ///
  /// [online] is passed rather than sensed, so the decision is testable and so
  /// this layer holds no platform dependency. When false nothing is queued:
  /// G15 §4 is explicit that a question she may no longer be asking is not
  /// retried on reconnect.
  Future<AssistantOutcome> ask(
    AssistantRequest request, {
    required DateTime now,
    bool online = true,
  }) async {
    final gate = _openGates(QuotaRoute.question, now: now, online: online);
    if (gate != null) return gate;

    // ---- The guardrail, FIRST, and failing closed. ------------------------
    final SafetyVerdict verdict;
    try {
      verdict = await classifier.classify(request.question);
    } on Object {
      // Any failure at all — a throw, a timeout converted to a throw, a vendor
      // error. It must never continue to the expensive model.
      return const AssistantUnavailable(
        AssistantUnavailableReason.guardrailUnavailable,
      );
    }

    if (verdict is Refused) {
      // The provider is NOT called. No suggestion is composed, so none has to
      // be suppressed.
      return AssistantRefusal(verdict.category);
    }

    // ---- Only now does anything expensive happen. -------------------------
    final ProviderOutcome<AssistantAnswer> outcome;
    try {
      outcome = await provider.answer(request);
    } on AssistantProviderUnavailable catch (e) {
      return AssistantUnavailable(e.reason);
    } on Object {
      return const AssistantUnavailable(AssistantUnavailableReason.serverError);
    }

    return switch (outcome) {
      ProviderRefused<AssistantAnswer>(:final category) => AssistantRefusal(
        category,
      ),
      ProviderTruncated<AssistantAnswer>() => const AssistantUnavailable(
        AssistantUnavailableReason.truncated,
      ),
      ProviderDelivered<AssistantAnswer>(:final value) => AssistantAnswered(
        _validator.validate(value),
      ),
    };
  }

  /// `K26` — draft a plan. Returns a payload; writes nothing.
  Future<AssistantOutcome> draftPlan(
    AssistantRequest request, {
    required DateTime now,
    bool online = true,
  }) async {
    return _draft<PlanDraft>(
      request,
      now: now,
      online: online,
      call: provider.draftPlan,
      validate: _validator.validatePlan,
      wrap: AssistantPlanDrafted.new,
    );
  }

  /// `K27` — draft a meal week. Returns a payload; writes nothing.
  Future<AssistantOutcome> draftMealWeek(
    AssistantRequest request, {
    required DateTime now,
    bool online = true,
  }) async {
    return _draft<MealDraft>(
      request,
      now: now,
      online: online,
      call: provider.draftMealWeek,
      validate: _validator.validateMeal,
      wrap: AssistantMealDrafted.new,
    );
  }

  /// The gates every route shares, in G15 §6.2's order.
  ///
  /// Returns the outcome that stops the call, or null to proceed.
  AssistantOutcome? _openGates(
    QuotaRoute route, {
    required DateTime now,
    required bool online,
  }) {
    if (!flags.isOn(Feature.assistant)) {
      return const AssistantUnavailable(AssistantUnavailableReason.switchedOff);
    }
    if (!online) {
      return const AssistantUnavailable(AssistantUnavailableReason.offline);
    }
    // Before any provider call, and before the guardrail — which costs money
    // too.
    if (!quota.tryConsume(route, now)) return AssistantCapped(route);
    return null;
  }

  /// Both draft routes, which differ only in their payload type.
  Future<AssistantOutcome> _draft<T>(
    AssistantRequest request, {
    required DateTime now,
    required bool online,
    required Future<ProviderOutcome<T>> Function(AssistantRequest) call,
    required T Function(T) validate,
    required AssistantOutcome Function(T) wrap,
  }) async {
    final gate = _openGates(QuotaRoute.draft, now: now, online: online);
    if (gate != null) return gate;

    final SafetyVerdict verdict;
    try {
      verdict = await classifier.classify(request.question);
    } on Object {
      return const AssistantUnavailable(
        AssistantUnavailableReason.guardrailUnavailable,
      );
    }
    if (verdict is Refused) return AssistantRefusal(verdict.category);

    final ProviderOutcome<T> outcome;
    try {
      outcome = await call(request);
    } on AssistantProviderUnavailable catch (e) {
      return AssistantUnavailable(e.reason);
    } on Object {
      return const AssistantUnavailable(AssistantUnavailableReason.serverError);
    }

    return switch (outcome) {
      ProviderRefused<T>(:final category) => AssistantRefusal(category),
      ProviderTruncated<T>() => const AssistantUnavailable(
        AssistantUnavailableReason.truncated,
      ),
      ProviderDelivered<T>(:final value) => wrap(validate(value)),
    };
  }
}
