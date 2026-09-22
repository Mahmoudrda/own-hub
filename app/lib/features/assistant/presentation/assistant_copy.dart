/// The lines `X01` and `X02` resolve at render time — and the ones the
/// dictionary does not carry.
///
/// `assistant_templates.dart` does this for the *answer* sentence, and keeps
/// `kAnswerKeysWithNoDictionaryLine` — empty today — as the place the next
/// withheld key is recorded. This file is the same discipline for the three
/// other things a screen has to say: why it refused, why it is unavailable,
/// and where a pick came from.
///
/// Every resolver returns `String?`, and **null renders nothing**. That is the
/// third of `stated_figure.dart`'s options applied to a missing string rather
/// than a wrong figure: a screen that is honestly incomplete beats one that
/// says something else. `lib/l10n/**` is not this feature's to edit, so a
/// missing line is recorded here — greppable, and asserted by the widget tests
/// — instead of being filled in with hardcoded English that would ship as
/// English in the Arabic build.
///
/// ## Two of the four lines have been minted
///
///  * **The daily-cap sentence exists.** *"You have used today's questions.
///    There will be more tomorrow."* — [assistantCappedLine]. `X01` still shows
///    the disabled composer and *Ask Sara instead*; it now also says why.
///  * **The offline reason exists, per route.** G15 §4 asked for *"Asking needs
///    a connection."* and it is in the dictionary, together with *"Drafting
///    needs a connection."* for `K26`/`K27`. Neither promises a queue, which is
///    why the four near-miss lines — *"You are offline. Everything you log is
///    saved here and sent when you reconnect"*, *"Waiting for signal"*,
///    *"Saved here until you have signal"*, *"We could not reach the server…"*
///    — are still not used here. This feature queues nothing, and none of those
///    sentences can be said about it.
///
/// ## The two that still do not exist
///
///  * **No switched-off reason.** [kUnavailableReasonsWithNoDictionaryLine].
///    The screen falls back to what G15 §2.4 says happens at the `off` rung
///    anyway: the human path, and `X03`. *"Asking needs a connection"* is not
///    borrowed for it — a kill switch is not a signal problem, and telling a
///    woman on full signal to find a connection sends her to fix the wrong
///    thing.
///  * **No refusal sentence for an unsafe request.** X02 copy C
///    ([kRefusalCategoriesWithNoDictionaryLine]). The medical line would be
///    the wrong sentence, not a near-enough one, so it is not substituted.
///  * **No parameterised `{n} moves…` form.** `twoMovesInYourSessionWorkThe`
///    states two, so `assistant_templates.dart` shows it only to the woman
///    looking at two.
///
/// ## Why the source chip does not say "124-move library"
///
/// `n124MoveLibrary` exists, and `X01`'s design uses it. It states a figure with
/// no placeholder form, nothing in `lib/` renders it today, and
/// `test/baked_in_samples_test.dart` counts exactly that — a rendered string
/// carrying the prototype's number. It would also be false of the pack that
/// actually ships (`assistant_sample_pack.dart`: three moves). So the chip says
/// *Library*, which is true of any pack.
library;

import '../../../l10n/app_l10n.dart';
import '../domain/assistant_provider.dart';
import '../domain/assistant_quota.dart';
import '../domain/assistant_wire.dart';
import '../domain/safety_classifier.dart';

/// Refusal categories the dictionary has no sentence for. See the library note.
///
/// When the string is minted, remove the entry — `refusal_view_test.dart` fails
/// if this set stops matching what actually resolves.
const Set<RefusalCategory> kRefusalCategoriesWithNoDictionaryLine =
    <RefusalCategory>{RefusalCategory.unsafeRequest};

/// Unavailable reasons the dictionary has no sentence for.
///
/// `offline` has left this set: both routes now have their own line. The kill
/// switch has not, and borrowing the offline sentence for it would send a woman
/// on full signal to go and find one.
const Set<AssistantUnavailableReason> kUnavailableReasonsWithNoDictionaryLine =
    <AssistantUnavailableReason>{AssistantUnavailableReason.switchedOff};

/// What `X01` says when today's allowance is spent.
///
/// *"You have used today's questions. There will be more tomorrow."* — the
/// whole of it: what happened, and when it stops being true. It names no
/// number, so the cap can be tightened from Remote Config (`AssistantQuotaCaps`
/// — 5 → 3 at the 70% spend rung) without the sentence becoming a lie.
///
/// The composer is disabled and *Ask Sara instead* is enabled beside it, which
/// is the part that matters: the human path works when the machine path does
/// not.
String assistantCappedLine(AppL10n l10n) =>
    l10n.youHaveUsedTodaysQuestionsThereWill;

/// Why it will not answer, or null when the dictionary has no line.
///
/// The medical sentence covers the three medical categories. It is **not**
/// borrowed for an unsafe request: *"It is a medical question"* would be untrue
/// of *"give me something intense despite my injury"*, and a sentence that is
/// untrue is worse than no sentence.
String? assistantRefusalLine(AppL10n l10n, RefusalCategory category) =>
    switch (category) {
      RefusalCategory.medicalDiagnostic ||
      RefusalCategory.severeSymptom ||
      RefusalCategory.emergency => l10n.iAmNotAbleToAnswerThat,
      RefusalCategory.unsafeRequest => null,
    };

/// The guidance that sits under *"This needs a doctor, not an app"*, or null.
///
/// HANDOFF rule 5's medical-guidance state, and the same line `Y11` shows. The
/// design's body — *"Bleeding between periods with sharp pain…"* — is the
/// mockup's own symptom and would be rendered to a woman who asked something
/// else, so the general line is used and the specific one is not.
String? assistantCareGuidance(AppL10n l10n, RefusalCategory category) =>
    switch (category) {
      RefusalCategory.severeSymptom || RefusalCategory.emergency =>
        l10n.severeOrUnusualPainDeservesMedicalAdvice,
      RefusalCategory.medicalDiagnostic ||
      RefusalCategory.unsafeRequest => null,
    };

/// Whether `X02` offers the route to care at all.
///
/// An unsafe request is not a medical question, and sending her to a clinic for
/// one would be as wrong as answering it.
bool refusalRoutesToCare(RefusalCategory category) =>
    category != RefusalCategory.unsafeRequest;

/// Why nothing came back, or null when the dictionary has no line.
///
/// [route] is which call could not be made — a woman asking on `X01`, or a
/// coach drafting on `K26`/`K27`. The two have their own sentences because they
/// are two different things to be told you cannot do, and neither promises that
/// it will happen later: there is no queue on either route, and the four
/// nearest dictionary lines all say there is.
String? assistantUnavailableLine(
  AppL10n l10n,
  AssistantUnavailableReason reason, {
  QuotaRoute route = QuotaRoute.question,
}) => switch (reason) {
  AssistantUnavailableReason.offline => switch (route) {
    QuotaRoute.question => l10n.askingNeedsAConnection,
    QuotaRoute.draft => l10n.draftingNeedsAConnection,
  },
  // Still nothing honest to say. A kill switch is not a signal problem.
  AssistantUnavailableReason.switchedOff => null,
  AssistantUnavailableReason.notImplemented ||
  AssistantUnavailableReason.guardrailUnavailable ||
  AssistantUnavailableReason.serverError ||
  AssistantUnavailableReason.truncated =>
    l10n.somethingWentWrongAtOurEndNothing,
};

/// The source chip. "An assistant that cannot show its source is
/// indistinguishable from one that guessed."
String pickSourceLabel(AppL10n l10n, PickSource source) => switch (source) {
  PickSource.herPlan => l10n.fromYourPlan,
  PickSource.moveLibrary || PickSource.foodLibrary => l10n.libraryLabel,
};

/// The slot heading on `K27`.
String mealSlotLabel(AppL10n l10n, MealSlot slot) => switch (slot) {
  MealSlot.breakfast => l10n.breakfast,
  MealSlot.lunch => l10n.lunch,
  MealSlot.dinner => l10n.dinner,
  MealSlot.snack => l10n.snack,
};
