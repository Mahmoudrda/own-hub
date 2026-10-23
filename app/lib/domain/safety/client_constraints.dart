/// HANDOFF 13 — the assessment is the only source of a client's constraints.
///
/// G14 §5: `ClientConstraintResolver.resolve(...)` is **the only** constructor
/// of [ClientConstraints], which "has no public setter and no coach-writable
/// field". Both halves are structural here:
///
///  * the constructor is **private to this library**, so no other file — and no
///    widget anywhere — can build a [ClientConstraints] out of whatever it
///    happens to have to hand;
///  * every collection it exposes is unmodifiable, so a screen that gets one
///    cannot add to it either.
///
/// P1-RULE-19 asks a coach to go looking for an input that writes `avoid`,
/// `allergies` or `dietary`. There is no such input, because there is no such
/// method.
///
/// ## Unknown is not empty
///
/// [avoid] is nullable and **null means "could not be read"**, never "she has
/// none". This is the distinction `DietaryConstraints` draws for food, for the
/// reason `AllergyGuard` gives: "An empty set is a **claim** — 'she has no
/// allergies' — and defaulting to it is how a guard silently turns itself off
/// for exactly the women who have not been asked yet."
///
/// ## Why `derivedAvoid` is separate, and always known
///
/// A life stage she declared **in her own profile** is knowledge we have even
/// when the coach's assessment cannot be read. Folding it into the nullable
/// [avoid] would throw it away on a cold start, at the moment the product is
/// least able to protect her. So it sits in its own non-nullable field, and
/// [ExerciseCandidateFilter] applies it on both paths — resolved and not.
///
/// It never makes the result weaker: [blockedTags] is a union.
library;

import 'package:meta/meta.dart';

import 'contraindication_tag.dart';
import 'life_stage_safety_policy.dart';
// `referral_registry.dart` re-exports `screening_item.dart`, so `ScreeningItem`
// arrives with it. Importing both would be flagged as redundant.
import 'referral_registry.dart';
import 'safety_assessment.dart';

/// What she must not be prescribed, and what she must not be offered to eat.
///
/// Read-only by construction. See the library note.
@immutable
class ClientConstraints {
  const ClientConstraints._({
    required this.avoid,
    required this.derivedAvoid,
    required this.allergies,
    required this.dietary,
    required this.referrals,
    required this.lifeStage,
  });

  /// The resolved avoid set — her chips, plus every active referral's tags,
  /// plus what her life stage derives.
  ///
  /// **Null means the constraints could not be resolved**, which is a different
  /// state from an empty set. See [isResolved].
  final Set<ContraindicationTag>? avoid;

  /// What her life stage restricts on its own. Known even when [avoid] is not.
  final Set<ContraindicationTag> derivedAvoid;

  /// Safety, for food. Null = unreadable. Consumed by G5's `AllergyGuard`.
  final Set<String>? allergies;

  /// Preference, for food. Null = unreadable.
  final Set<String>? dietary;

  /// The referrals K22 renders prominently. Never an error state.
  final List<ScreeningItem> referrals;

  /// Both sources of her life stage, or null when neither could be read.
  final EffectiveLifeStage? lifeStage;

  /// False on a cold start, a missing projection or an unreadable assessment.
  /// W04 shows one line when this is false; it never shows an unrestricted list.
  bool get isResolved => avoid != null;

  /// Everything the move filter must remove, with `none` excluded — a token
  /// that means "nothing to avoid" must never suppress the moves carrying it.
  Set<ContraindicationTag> get blockedTags =>
      Set.unmodifiable(<ContraindicationTag>{
        for (final tag in <ContraindicationTag>{...?avoid, ...derivedAvoid})
          if (tag.restricts) tag,
      });

  @override
  String toString() =>
      'ClientConstraints(avoid: ${avoid ?? "unknown"}, '
      'derived: $derivedAvoid, referrals: ${referrals.length})';
}

/// The only constructor of [ClientConstraints].
class ClientConstraintResolver {
  const ClientConstraintResolver._();

  /// Resolves from the assessment, her own declaration, and G11's projection.
  ///
  /// [priorAssessment] is the previous document in the chain. Passing it is how
  /// a re-assessment that simply omits a referral does not drop one —
  /// `ReferralRegistry.carryForward` decides, not the newer document's silence.
  ///
  /// Fails closed when [assessment] is null: the result is *unresolved*, not
  /// an empty constraint set.
  static ClientConstraints resolve({
    required SafetyAssessment? assessment,
    SafetyAssessment? priorAssessment,
    SelfDeclaredLifeStage? selfDeclared,
    Set<String>? allergies,
    Set<String>? dietary,
  }) {
    if (assessment == null) {
      return unresolved(
        selfDeclared: selfDeclared,
        allergies: allergies,
        dietary: dietary,
      );
    }

    final referrals = priorAssessment == null
        ? ReferralRegistry.activeReferrals(assessment)
        : ReferralRegistry.carryForward(
            previous: priorAssessment,
            next: assessment.screening,
          ).where((item) => item.isActiveReferral).toList();

    final stage = LifeStageSafetyPolicy.effective(
      recorded: assessment.lifeStage,
      selfDeclared: selfDeclared,
    );

    return ClientConstraints._(
      avoid: Set.unmodifiable(<ContraindicationTag>{
        for (final tag in <ContraindicationTag>{
          ...assessment.avoid,
          for (final referral in referrals) ...referral.suppresses,
          ...stage.derivedAvoid,
        })
          if (tag.restricts) tag,
      }),
      derivedAvoid: stage.derivedAvoid,
      allergies: allergies == null ? null : Set.unmodifiable(allergies),
      dietary: dietary == null ? null : Set.unmodifiable(dietary),
      referrals: List.unmodifiable(referrals),
      lifeStage: stage,
    );
  }

  /// The fail-closed value: her constraints could not be read.
  ///
  /// A self-declared life stage is still honoured — it narrows the cold-start
  /// list further. It never *resolves* the constraints, because her life stage
  /// says nothing about her knees, and treating it as a complete answer would
  /// be a claim nobody made.
  static ClientConstraints unresolved({
    SelfDeclaredLifeStage? selfDeclared,
    Set<String>? allergies,
    Set<String>? dietary,
  }) => ClientConstraints._(
    avoid: null,
    derivedAvoid: selfDeclared == null
        ? const <ContraindicationTag>{}
        : LifeStageSafetyPolicy.derivedAvoid(selfDeclared.stage),
    allergies: allergies == null ? null : Set.unmodifiable(allergies),
    dietary: dietary == null ? null : Set.unmodifiable(dietary),
    referrals: List.unmodifiable(const <ScreeningItem>[]),
    lifeStage: selfDeclared == null
        ? null
        : LifeStageSafetyPolicy.effective(
            recorded: LifeStage.none,
            selfDeclared: selfDeclared,
          ),
  );
}
