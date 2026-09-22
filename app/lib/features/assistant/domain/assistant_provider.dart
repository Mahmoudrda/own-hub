/// The seam where a model would go, and the honest statement that none is here.
///
/// **There is no working implementation of this interface, and that is the
/// current state of the product.** G15 was written against Claude (Opus 5 for
/// answers, Haiku 4.5 for the guardrail); the owner has since chosen **Gemini
/// Flash**, and the API key does not exist yet. Rather than guess at a vendor,
/// this file defines the shape the product needs and ships
/// [UnavailableAssistantProvider], which refuses and says why — exactly the
/// posture `UnavailableCaptureService` takes in
/// `lib/features/signup/domain/id_capture.dart`.
///
/// The screens are built against this interface so that adding a model is a
/// dependency change rather than a rewrite, and so that a fake can never be
/// mistaken for a working assistant, because no fake that *works* exists in
/// `lib/` to be mistaken.
///
/// ## The guarantees live here, not in the vendor
///
/// Every promise the product makes survives the change of model, because none
/// of them is a model feature:
///
///  * **It never writes.** No method below returns a handle, a document
///    reference or a write receipt. They return value objects. The owning
///    group's service performs the write after the author taps, so there is no
///    server path from a model token to a published plan.
///  * **It never returns a number.** The return types come from
///    `assistant_wire.dart`, which has no numeric field at all.
///  * **The stop reason is read before the content.** [ProviderOutcome] is
///    sealed: a refusal carries *no* answer, so there is no arrangement of this
///    API in which content is parsed from a response that declined. That is
///    `P0-ASK-06` made structural.
///  * **A truncated response is never rendered.** [ProviderTruncated] has no
///    payload either, so half a pick list cannot reach a screen.
///
/// ## What a real Gemini Flash implementation must satisfy
///
/// It goes in `data/`, not here, and it is **one class**:
///
/// ```dart
/// class GeminiFlashAssistantProvider implements AssistantProvider { … }
/// ```
///
/// Its obligations, none of which this app can enforce from a handset:
///
///  1. **It calls a Cloud Function, never the vendor.** The key is a Secret
///     Manager secret bound to the function. An APK is a zip: anything in it is
///     public, so a key in the bundle is a key that has leaked. There is
///     deliberately no HTTP client and no key parameter anywhere in this
///     feature, and `assistant_product_rules_test.dart` scans `lib/` for both.
///  2. **It maps the response schema onto [AssistantAnswer].** The response
///     must be constrained server-side to `{answerKey, picks[{kind,id,source}],
///     escalate}` with `additionalProperties:false`, so the vendor cannot add a
///     field. Gemini's structured-output mode is the equivalent of the
///     `output_config.format` G15 §2.2 specifies for Claude.
///  3. **It never sees a uid.** [AssistantRequest] carries none.
///  4. **It applies the safety filter server-side, before ranking** — through
///     `ExerciseCandidateFilter` and `AllergyGuard`, never by prompt. The tool
///     results handed to the model are already screened.
///  5. **It surfaces a vendor refusal as [ProviderRefused], and a truncation as
///     [ProviderTruncated]**, rather than as an exception or an empty answer.
///  6. **It throws [AssistantProviderUnavailable] for everything else**, so the
///     caller fails closed rather than rendering a partial answer.
///
/// Nothing above mentions Claude or Gemini by name in code, and that is the
/// point of the seam: the vendor is a detail of one class in `data/`.
library;

import 'package:meta/meta.dart';

import 'assistant_wire.dart';
import 'safety_classifier.dart';

/// Why the assistant cannot answer, in terms a screen can act on.
///
/// [notImplemented] is first because it is today's real answer, and naming it
/// keeps the gap visible in the UI instead of behind a spinner that never
/// resolves.
enum AssistantUnavailableReason {
  /// No model is wired up. Today's state.
  notImplemented,

  /// The kill switch is on, or `Feature.assistant` is off. G15 §2.4's `off`
  /// rung: `X03` stays readable, because it makes no call.
  switchedOff,

  /// Asking needs a connection. There is no queue and no retry-on-reconnect of
  /// a question she may no longer be asking.
  offline,

  /// **The guardrail failed.** Fail closed: this is never a reason to try the
  /// expensive model anyway.
  guardrailUnavailable,

  /// The backend answered, but not with something renderable.
  serverError,

  /// The response was cut off. Never render a truncated pick list.
  truncated,
}

/// The assistant is not available. Thrown by implementations.
class AssistantProviderUnavailable implements Exception {
  const AssistantProviderUnavailable(this.reason);

  final AssistantUnavailableReason reason;

  @override
  String toString() => 'AssistantProviderUnavailable(${reason.name})';
}

/// What came back, with the stop reason read **before** any content.
///
/// Sealed on purpose. A refusal and a truncation carry no payload, so there is
/// no way to reach content that should not be rendered — the guard is the type,
/// not a check somebody remembered to write first.
@immutable
sealed class ProviderOutcome<T> {
  const ProviderOutcome();
}

/// A usable payload. Still unvalidated: ids are checked against the pack by
/// `AssistantResponseValidator` before anything is rendered.
final class ProviderDelivered<T> extends ProviderOutcome<T> {
  const ProviderDelivered(this.value);

  final T value;
}

/// The model itself declined. A second, independent detector alongside the
/// guardrail — G15 §3.2's two detectors.
final class ProviderRefused<T> extends ProviderOutcome<T> {
  const ProviderRefused(this.category);

  final RefusalCategory category;
}

/// The response hit its output ceiling. No content is carried, because a
/// half-finished pick list must never reach a screen.
final class ProviderTruncated<T> extends ProviderOutcome<T> {
  const ProviderTruncated();
}

/// The model behind the assistant.
///
/// Three methods, one per route. None of them writes anything, and none takes a
/// uid — see the file note.
abstract class AssistantProvider {
  /// `X01` — a grounded answer, or a refusal, or a truncation.
  Future<ProviderOutcome<AssistantAnswer>> answer(AssistantRequest request);

  /// `K26` — a plan draft, held on the coach's device. Never written here.
  Future<ProviderOutcome<PlanDraft>> draftPlan(AssistantRequest request);

  /// `K27` — a meal-week draft, held on the coach's device. Never written here.
  Future<ProviderOutcome<MealDraft>> draftMealWeek(AssistantRequest request);
}

/// The only implementation that exists today: one that refuses, and says why.
///
/// It never returns [ProviderDelivered], so no screen built against it can
/// appear to be answering when no model is attached.
class UnavailableAssistantProvider implements AssistantProvider {
  const UnavailableAssistantProvider({
    this.reason = AssistantUnavailableReason.notImplemented,
  });

  final AssistantUnavailableReason reason;

  // Each of these is `async`, so the failure arrives as a **rejected future**
  // rather than as a synchronous throw from a method whose signature promises a
  // future. `UnavailableCaptureService.capture()` takes the same care, and for
  // the same reason: a caller that holds the future and awaits it later would
  // otherwise miss the throw entirely, and a missing model would look like a
  // request that is still in flight — the endless spinner this feature is not
  // allowed to have.

  @override
  Future<ProviderOutcome<AssistantAnswer>> answer(
    AssistantRequest request,
  ) async => throw AssistantProviderUnavailable(reason);

  @override
  Future<ProviderOutcome<PlanDraft>> draftPlan(
    AssistantRequest request,
  ) async => throw AssistantProviderUnavailable(reason);

  @override
  Future<ProviderOutcome<MealDraft>> draftMealWeek(
    AssistantRequest request,
  ) async => throw AssistantProviderUnavailable(reason);
}
