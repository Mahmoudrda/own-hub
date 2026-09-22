/// `X03` — what it can and cannot do, and the four boundaries it names.
///
/// The screen the rest of the feature is measured against. Two lists, and **the
/// cannot list is the longer and more specific one**, which is the opposite of
/// how a feature like this is usually sold.
///
/// ## Why this screen is modelled at all, rather than written straight into a widget
///
/// Because each line in the *cannot* list is a claim about the code, and a claim
/// nobody checks is marketing. [AssistantLimit] gives each one a name, so
/// `assistant_screens_test.dart` can assert that the promise on screen and the
/// guarantee in the source are the same four things:
///
/// | Line | What makes it true |
/// |---|---|
/// | [AssistantLimit.diagnose] | `SafetyClassifier` runs **first** and a refusal short-circuits the provider, so a suggestion for a medical question is never generated (not generated and hidden). `AssistantService.ask`, `P0-ASK-04`/`05`. |
/// | [AssistantLimit.changeYourPlan] | The feature holds no repository and has no publish tool. `AssistantService` returns a payload; the owning group's service writes after a tap. G15 D1, `P1-RULE-10B`. |
/// | [AssistantLimit.seeYourCycle] | Cycle is not in the payload allowlist **at all**. `AssistantSubject.boundToCaller` takes no cycle parameter, so there is no field and therefore no switch to consult. C12. |
/// | [AssistantLimit.inventAQuantity] | No field on the wire can carry a number; every figure is read from the pack row by id. G15 D2. |
///
/// ## One line promises less than the code delivers, and that is recorded here
///
/// `seeYourCycleInformationUnlessYouShare` reads *"See your cycle information
/// unless you share it"* — which implies that turning sharing on would let the
/// assistant read it. **It would not.** Cycle data has no field on the wire, so
/// the sharing switch is never consulted by this feature and the answer is the
/// same with it on. The dictionary is `lib/l10n/**` and not this feature's to
/// edit, so the stronger sentence is not written here; the discrepancy is
/// named, and [AssistantLimit.seeYourCycle] carries it as
/// [AssistantLimit.copyUnderstatesTheGuarantee].
///
/// ## It makes no call, and that is the point
///
/// G15 §4: X03 "fully works" offline — static content, zero calls — and it is
/// the screen that **stays readable when `kill_switches.assistant` is on**. The
/// honest description of the feature survives the feature being off, so
/// [AssistantBoundaries] takes no service, no provider and no network state.
library;

import 'package:meta/meta.dart';

import '../../../l10n/app_l10n.dart';

/// The four things it can do. Ordered as `X03` lists them.
enum AssistantAbility {
  /// Find a move for her equipment and her knee.
  findAMove,

  /// Swap today's exercise for an alternative Sara already approved.
  swapForAnApprovedAlternative,

  /// Tell her the portion of a dish she already logs.
  portionOfADishSheLogs,

  /// Explain a rule: why a week counted, what a rest week covers.
  explainARule,
}

/// The four things it cannot do. Each is a property of the code; see the file
/// note for what makes each one true.
enum AssistantLimit {
  /// Diagnose anything, or answer a medical question.
  diagnose,

  /// Change her plan. Only Sara publishing does that.
  changeYourPlan,

  /// See her cycle information. The copy says "unless you share it"; the code
  /// says never. See the file note.
  seeYourCycle,

  /// Invent a meal or a quantity: every gram comes from the food library.
  inventAQuantity;

  /// True where the dictionary line promises **less** than the code guarantees.
  ///
  /// Only [seeYourCycle]. Recorded so the gap is visible to a reader of this
  /// file rather than discovered by someone who later wires up a sharing
  /// switch this feature does not consult.
  bool get copyUnderstatesTheGuarantee => this == seeYourCycle;
}

/// Everything `X03` needs to draw itself. Strings only — it computes nothing.
@immutable
class AssistantBoundaries {
  const AssistantBoundaries({
    required this.title,
    required this.canHeading,
    required this.cannotHeading,
    required this.can,
    required this.cannot,
    required this.whatLeavesYourPhoneHeading,
    required this.whatLeavesYourPhoneBody,
    required this.askCta,
  });

  final String title;
  final String canHeading;
  final String cannotHeading;

  /// In `X03`'s order, one line per [AssistantAbility].
  final Map<AssistantAbility, String> can;

  /// In `X03`'s order, one line per [AssistantLimit].
  final Map<AssistantLimit, String> cannot;

  final String whatLeavesYourPhoneHeading;
  final String whatLeavesYourPhoneBody;

  /// The one action on the screen, which leads back to `X01`.
  final String askCta;

  /// **False.** Static content, zero calls — G15 §4.
  bool get needsNetwork => false;

  /// **True.** `X03` is what stays readable at the `off` rung of G15 §2.4's
  /// degrade ladder, when `X01`'s entry point has been replaced by *Ask Sara*.
  /// The screen that explains the boundaries is the one that never needs the
  /// feature to be on.
  bool get readableWhenSwitchedOff => true;

  /// The stated rule: the cannot list is longer and more specific.
  bool get cannotListIsNotShorter => cannot.length >= can.length;
}

/// Builds `X03` from the dictionary. Every string is an `AppL10n` getter; not
/// one is composed here.
AssistantBoundaries assistantBoundaries(AppL10n l10n) => AssistantBoundaries(
  title: l10n.whatItCanAndCannotDo,
  canHeading: l10n.itCan,
  cannotHeading: l10n.itCannot,
  can: <AssistantAbility, String>{
    AssistantAbility.findAMove: l10n.findAMoveForYourEquipmentAnd,
    AssistantAbility.swapForAnApprovedAlternative:
        l10n.swapTodaysExerciseForAnApprovedAlternative,
    AssistantAbility.portionOfADishSheLogs: l10n.tellYouThePortionOfADish,
    AssistantAbility.explainARule: l10n.explainARuleWhyAWeekCounted,
  },
  cannot: <AssistantLimit, String>{
    AssistantLimit.diagnose: l10n.diagnoseAnythingOrAnswerAMedicalQuestion,
    AssistantLimit.changeYourPlan: l10n.changeYourPlanOnlySaraPublishingDoes,
    AssistantLimit.seeYourCycle: l10n.seeYourCycleInformationUnlessYouShare,
    AssistantLimit.inventAQuantity: l10n.inventAMealOrAQuantityEvery,
  },
  whatLeavesYourPhoneHeading: l10n.whatLeavesYourPhone,
  whatLeavesYourPhoneBody: l10n.yourQuestionYourEquipmentAndWhatYou,
  askCta: l10n.askSomething,
);
