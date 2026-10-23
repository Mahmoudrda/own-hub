/// Pregnancy and postpartum, made operative — PHASE3-PLAN §1.4.
///
/// That section is the most serious silence the Phase 3 planning pass found:
///
/// > G14 records `lifeStage`, `birthType` and `clearance{granted}`. **None of
/// > them restricts what may be prescribed.** […] So for a pregnant or
/// > postpartum client the only operative safety mechanism is the coach
/// > manually ticking avoid chips.
///
/// This file closes that. **The owner approved a policy stricter than the
/// spec**, and it has two halves:
///
///  1. A recorded life stage **derives** avoid-tags on its own. A coach who
///     ticks nothing still cannot prescribe a jump to a woman recorded as
///     pregnant, because the derivation does not pass through a coach's hands.
///  2. Publishing is **blocked** while clearance is withheld during `p0_6w`.
///     Everywhere else in the product a recorded `granted:false` is displayed
///     and gates nothing.
///
/// ## Why this enum is not `features/onboarding`'s `LifeStage`
///
/// They are different vocabularies and merging them would weaken this one.
/// O04 asks a coarse question — `none | postpartum | pregnant | pain_injury` —
/// because it is a woman answering about herself at sign-up. G14 §1.4 records
/// `pregnant | p0_6w | p6w_1y | over_1y | none`, where the postpartum window
/// matters because the clearance gate hangs off the first six weeks. Importing
/// the onboarding enum would also invert the layering: `domain/` is depended
/// on by `features/`, never the other way round.
///
/// ## What is deliberately NOT derived
///
/// `p6w_1y` and `over_1y` derive **nothing**, and the five tags below are the
/// owner-approved minimum rather than a clinical position. G2 §9 Q5 records
/// that "what a pregnancy or postpartum programme may actually contain has no
/// authored, clinically-reviewed source yet", and PHASE3-PLAN §1.4 adds that
/// **no clinical review is required anywhere in G14**. Inventing a graded
/// return-to-training ladder here would be fabricating clinical content and
/// putting it between a woman and her coach. The five are the floor; widening
/// them is a clinical decision with a named reviewer, not an implementer's.
///
/// ## The publish gate takes no referral
///
/// HANDOFF 14: `refer` is not a failure state and never blocks a publish. That
/// is enforced by this file not knowing referrals exist — it does not import
/// `referral_registry.dart`, so no later edit can make a referral block a
/// publish without that import appearing in review. Asserted by test.
library;

import 'package:meta/meta.dart';

import 'contraindication_tag.dart';

/// G14 §1.4. **Renamed from the spine's `stage`**, which read like a workflow
/// state; workflow state is `status`.
enum LifeStage {
  pregnant('pregnant'),

  /// The first six weeks after birth. The only stage with a clearance gate.
  postpartum0to6w('p0_6w'),

  postpartum6wTo1y('p6w_1y'),
  over1y('over_1y'),
  none('none');

  const LifeStage(this.wireName);

  /// The string stored in the assessment. Never the Dart name.
  final String wireName;

  /// The stage for [wire], or null when it is outside the vocabulary.
  static LifeStage? fromWire(String wire) {
    final normalised = wire.trim().toLowerCase();
    for (final stage in values) {
      if (stage.wireName == normalised) return stage;
    }
    return null;
  }
}

/// How she gave birth. K21. Never inferred, never required.
enum BirthType {
  vaginal('vaginal'),
  caesarean('caesarean'),
  undisclosed('undisclosed');

  const BirthType(this.wireName);

  final String wireName;

  static BirthType? fromWire(String wire) {
    final normalised = wire.trim().toLowerCase();
    for (final type in values) {
      if (type.wireName == normalised) return type;
    }
    return null;
  }
}

/// K21's toggle. `granted:false` is a **recorded answer, not a missing one** —
/// which is why the absence of a [Clearance] is a different state entirely.
@immutable
class Clearance {
  const Clearance({required this.granted, required this.recordedAt, this.note});

  final bool granted;
  final DateTime recordedAt;
  final String? note;
}

/// What she said about her own body, in her own profile.
///
/// The owner asked for this explicitly: her life stage must not be sayable only
/// through a coach's assessment. It feeds the same policy as the recorded
/// answer, and [LifeStageSafetyPolicy.effective] keeps both readable so a
/// coach's document can never silently overwrite hers.
@immutable
class SelfDeclaredLifeStage {
  const SelfDeclaredLifeStage({required this.stage, required this.declaredAt});

  final LifeStage stage;
  final DateTime declaredAt;
}

/// Why a publish was refused. There is no referral-shaped value here.
enum PublishBlockReason {
  /// `clearance.granted == false` during `p0_6w`.
  clearanceWithheld,

  /// No clearance recorded at all during `p0_6w`. Unknown is not absent.
  clearanceUnrecorded,
}

/// The gate's answer.
@immutable
class PublishDecision {
  const PublishDecision._(this.allowed, this.reason);

  /// Nothing in this policy stands in the way.
  static const PublishDecision permitted = PublishDecision._(true, null);

  /// Refused, with the reason a screen must state.
  const PublishDecision.blocked(PublishBlockReason this.reason)
    : allowed = false;

  final bool allowed;

  /// Null when [allowed].
  final PublishBlockReason? reason;

  @override
  String toString() =>
      allowed ? 'PublishDecision.permitted' : 'blocked($reason)';
}

/// Both sources of her life stage, and what follows from them.
@immutable
class EffectiveLifeStage {
  const EffectiveLifeStage._({
    required this.recorded,
    required this.selfDeclared,
    required this.stage,
    required this.derivedAvoid,
  });

  /// What the coach's assessment says.
  final LifeStage recorded;

  /// What she said in her own profile, or null if she has not.
  final LifeStage? selfDeclared;

  /// The more protective of the two. What every gate reads.
  final LifeStage stage;

  /// The union of what **both** sources derive — never one alone.
  final Set<ContraindicationTag> derivedAvoid;

  /// True when the two sources differ, so a screen can show the difference
  /// rather than a resolution she never saw.
  bool get sourcesDisagree => selfDeclared != null && selfDeclared != recorded;
}

/// Derives restrictions from a life stage, and gates publishing.
class LifeStageSafetyPolicy {
  const LifeStageSafetyPolicy._();

  /// The owner-approved minimum for pregnancy and the first six weeks.
  ///
  /// "At least" these five. See the library note on what is deliberately not
  /// derived beyond them.
  static const Set<ContraindicationTag> pregnancyAndEarlyPostpartumFloor = {
    ContraindicationTag.pelvicFloorLoad,
    ContraindicationTag.highImpact,
    ContraindicationTag.jumping,
    ContraindicationTag.supineLoad,
    ContraindicationTag.breathHoldValsalva,
  };

  /// The tags [stage] restricts on its own, with no coach input at all.
  static Set<ContraindicationTag> derivedAvoid(LifeStage stage) =>
      switch (stage) {
        LifeStage.pregnant || LifeStage.postpartum0to6w => Set.unmodifiable(
          pregnancyAndEarlyPostpartumFloor,
        ),
        LifeStage.postpartum6wTo1y ||
        LifeStage.over1y ||
        LifeStage.none => const <ContraindicationTag>{},
      };

  /// How much protection a stage implies. Used only to pick between two
  /// disagreeing sources, never rendered.
  ///
  /// `p0_6w` outranks `pregnant` because it additionally gates publishing, so
  /// taking it loses nothing and keeps the gate reachable.
  static int _protection(LifeStage stage) => switch (stage) {
    LifeStage.postpartum0to6w => 4,
    LifeStage.pregnant => 3,
    LifeStage.postpartum6wTo1y => 2,
    LifeStage.over1y => 1,
    LifeStage.none => 0,
  };

  /// The more protective of two stages.
  static LifeStage moreProtective(LifeStage a, LifeStage b) =>
      _protection(a) >= _protection(b) ? a : b;

  /// Reconciles the coach's record with what she said about her own body.
  ///
  /// Where they disagree the **more protective** one governs, and the tag set
  /// is a true union, so the result is never weaker than either source. Both
  /// inputs stay readable on the result.
  static EffectiveLifeStage effective({
    required LifeStage recorded,
    SelfDeclaredLifeStage? selfDeclared,
  }) {
    final declared = selfDeclared?.stage;
    return EffectiveLifeStage._(
      recorded: recorded,
      selfDeclared: declared,
      stage: declared == null ? recorded : moreProtective(recorded, declared),
      derivedAvoid: Set.unmodifiable(<ContraindicationTag>{
        ...derivedAvoid(recorded),
        if (declared != null) ...derivedAvoid(declared),
      }),
    );
  }

  /// Whether a plan may be published.
  ///
  /// Blocks in exactly one situation: the first six weeks after birth without
  /// a granted clearance. A missing clearance blocks for the same reason a
  /// missing allergen list blocks a meal — unknown is not absent.
  static PublishDecision publishGate({
    required LifeStage stage,
    required Clearance? clearance,
  }) {
    if (stage != LifeStage.postpartum0to6w) return PublishDecision.permitted;
    if (clearance == null) {
      return const PublishDecision.blocked(
        PublishBlockReason.clearanceUnrecorded,
      );
    }
    if (!clearance.granted) {
      return const PublishDecision.blocked(
        PublishBlockReason.clearanceWithheld,
      );
    }
    return PublishDecision.permitted;
  }
}
