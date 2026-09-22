/// The second verification — `K02` and `K06`.
///
/// A coach passes **two** checks. G1's establishes that she is a woman; this one
/// establishes that a human being read her certificates. The second is stricter,
/// and `P0-CVER-01` is the case that says so: *"A coach is verified more strictly
/// than a client."*
///
/// # The one rule this file exists to make structural
///
/// **Coach verification is never automated.** G12 §5 states it as a property of
/// the design rather than a policy — rule 8's row reads *"Certificate review is
/// a human reading a document"* — and D8 fixes who that human is: only women
/// review these checks.
///
/// So the machine below has exactly **one** door into
/// [CoachVerificationState.verified], and it is [ReviewerPass], which carries a
/// [ReviewerDecision] naming the reviewer. An automated issuing-body lookup can
/// produce [LookupFinding], and the most a finding can do — however confident —
/// is move her into [CoachVerificationState.humanReview]. A lookup is *evidence
/// for a reviewer*, never a decision.
///
/// **This is a deliberate, reported divergence from G12 §3.1 row 3**, which
/// draws `docs_checking --LOOKUP_PASS--> verified`. That row would let a
/// credential-database call mint the `coachV` claim with no person in the loop,
/// which is the thing the owner's rule forbids and the thing §5 says is not how
/// certificates are reviewed. Where the plan's table and the plan's rule
/// disagree, the rule wins, and the disagreement is recorded here rather than
/// resolved quietly.
///
/// # What a coach may do while she waits
///
/// Everything except publish. `K06` and `K24` are built on the distinction:
/// [CoachVerificationState.mayAuthor] is true in every state but
/// [CoachVerificationState.suspended], while
/// [CoachVerificationState.mayPublish] is true only when verified. So a coach
/// under review builds her page, saves splits and writes offers, and none of it
/// is visible to anyone until a woman has cleared her certificates. That is what
/// turns waiting from a dead end into work (`P0-CVER-01`, HANDOFF 17).
///
/// # Expiry punishes nobody's client
///
/// `P0-CVER-04`: *"A coach's paperwork never punishes her client."*
/// [CoachVerificationState.expired] keeps [CoachVerificationState.pageIsLive]
/// true and revokes only the ability to take someone new.
///
/// # The rejection reason is a code, never prose
///
/// [CoachVerificationFailReason] is an enum of coarse codes. There is
/// deliberately **no field on this outcome that a raw provider string could live
/// in**, so `P0-CVER-03`'s "never raw provider text" is unrepresentable rather
/// than forbidden — the same technique `verification.dart` uses for rule 7.
library;

import 'package:meta/meta.dart';

/// The eight states of G12 §3.1.
enum CoachVerificationState {
  /// `K01`–`K05` unfinished.
  setupIncomplete,

  /// At least one certificate is uploaded. `K06` is what she sees.
  submitted,

  /// An automated issuing-body lookup is running. It decides nothing.
  docsChecking,

  /// A woman reviewer has claimed it. The only state adjacent to cleared.
  humanReview,

  /// A human cleared her certificates.
  verified,

  /// Not cleared. Not a dead end — the replace-and-resubmit path stays open.
  rejected,

  /// Every certificate has lapsed. Her page stays live; her clients stay hers.
  expired,

  /// A report was upheld, or payout fraud was found.
  suspended;

  /// Whether her public profile is readable by anyone (`coaches.listed`).
  ///
  /// True for [expired] on purpose: revoking a coach mid-plan would punish the
  /// client for the coach's paperwork.
  bool get pageIsLive => this == verified || this == expired;

  /// Whether the `coachV` claim is held. The single gate on accepting anyone.
  bool get holdsCoachClaim => this == verified;

  /// Whether she may accept an enquiry.
  bool get mayAcceptClients => this == verified;

  /// Whether `acceptingClients` may be set true.
  bool get mayAdvertiseAvailability => this == verified;

  /// Whether she may write — her page, her splits, her offers, her meals.
  ///
  /// True while she is being checked, which is the whole of `K06`'s promise.
  bool get mayAuthor => this != suspended;

  /// Whether anything she has written may become visible to anyone.
  bool get mayPublish => this == verified;

  /// Whether a decision is still pending on her. Drives `K06`'s amber card and
  /// `K24`'s verification banner.
  bool get isBeingChecked =>
      this == submitted || this == docsChecking || this == humanReview;
}

/// Why a certificate was not cleared. **Coarse codes only** (`P0-CVER-03`, D8).
///
/// Each of these is something the product is willing to say to a woman. None of
/// them accuses her, and none of them is a pass-through of whatever an issuing
/// body's API returned.
enum CoachVerificationFailReason {
  /// We could not find the body that issued it.
  issuingBodyNotRecognised,

  /// The photograph could not be read.
  documentUnreadable,

  /// The name on the certificate is not the name on her account.
  nameDoesNotMatch,

  /// It was genuine and has lapsed.
  credentialLapsed,

  /// Anything the four above do not cover. Deliberately last and deliberately
  /// wordless.
  needsAnotherLook,
}

/// A human decision, and the evidence that a human made it.
///
/// D8: *"Only women review these checks."* [reviewedByWoman] is not a comment —
/// [isAdmissible] is false without it, and an inadmissible decision cannot move
/// the machine, so a reviewer queue that lost that constraint would fail here
/// rather than silently clear coaches.
@immutable
class ReviewerDecision {
  const ReviewerDecision({
    required this.reviewerId,
    required this.reviewedByWoman,
    required this.decidedAt,
  });

  /// Who decided. Non-empty, because "a human decided" with nobody named is the
  /// shape an automated decision takes when it is trying to look like a human
  /// one.
  final String reviewerId;

  /// D8. A decision by anyone else is not a decision this machine accepts.
  final bool reviewedByWoman;

  final DateTime decidedAt;

  /// Whether this decision may move the machine at all.
  bool get isAdmissible => reviewerId.trim().isNotEmpty && reviewedByWoman;
}

/// Everything that can happen to a coach's credential check.
@immutable
sealed class CoachVerificationEvent {
  const CoachVerificationEvent();
}

/// `K01`–`K05` are finished: at least one certificate, a payout method and a
/// capacity.
///
/// The three preconditions are fields rather than a single boolean so that a
/// caller cannot pass `true` without having checked all three.
class SetupCompleted extends CoachVerificationEvent {
  const SetupCompleted({
    required this.hasCertificate,
    required this.hasPayoutMethod,
    required this.hasCapacity,
  });

  final bool hasCertificate;
  final bool hasPayoutMethod;
  final bool hasCapacity;

  bool get isComplete => hasCertificate && hasPayoutMethod && hasCapacity;
}

/// The automated issuing-body lookup started.
class LookupStarted extends CoachVerificationEvent {
  const LookupStarted();
}

/// The automated lookup finished.
///
/// **It reports; it does not decide.** Both values of
/// [allCertificatesRecognised] lead to [CoachVerificationState.humanReview] —
/// the flag changes what the reviewer is looking at, never whether there is
/// one. There is deliberately no event a machine can raise that reaches
/// [CoachVerificationState.verified].
class LookupFinding extends CoachVerificationEvent {
  const LookupFinding({required this.allCertificatesRecognised});

  final bool allCertificatesRecognised;
}

/// A woman reviewer cleared her.
class ReviewerPass extends CoachVerificationEvent {
  const ReviewerPass(this.decision);
  final ReviewerDecision decision;
}

/// A woman reviewer did not clear her. Carries a coarse code and nothing else.
class ReviewerFail extends CoachVerificationEvent {
  const ReviewerFail(this.decision, this.reason);
  final ReviewerDecision decision;
  final CoachVerificationFailReason reason;
}

/// She replaced a rejected certificate and resubmitted.
class CertificateReplaced extends CoachVerificationEvent {
  const CertificateReplaced();
}

/// Every certificate passed its expiry date.
class AllCertificatesExpired extends CoachVerificationEvent {
  const AllCertificatesExpired();
}

/// She renewed, and it goes back through a human.
class CertificateRenewed extends CoachVerificationEvent {
  const CertificateRenewed();
}

/// A report against her was upheld, or payout fraud was found.
class SafetyActionTaken extends CoachVerificationEvent {
  const SafetyActionTaken();
}

/// What a transition changed.
///
/// Note the absence: there is no `message`, `detail`, `providerResponse` or any
/// other free-text field. `P0-CVER-03` requires that a rejection is a coarse
/// code and never raw provider text, and the cheapest way to keep that promise
/// is to have nowhere to put it.
@immutable
class CoachVerificationOutcome {
  const CoachVerificationOutcome({
    required this.state,
    required this.changed,
    this.mintsCoachClaim = false,
    this.revokesCoachClaim = false,
    this.failReason,
    this.clearsCertificatesStep = false,
    this.replacementAttempts = 0,
  });

  final CoachVerificationState state;

  /// False when the event was not applicable and nothing moved. A no-op is
  /// reported rather than thrown: a replayed callable must be inert, not fatal.
  final bool changed;

  /// Whether `coachV` is minted by this transition. Only ever true alongside a
  /// [ReviewerPass].
  final bool mintsCoachClaim;

  final bool revokesCoachClaim;

  /// Set only when [state] is [CoachVerificationState.rejected].
  final CoachVerificationFailReason? failReason;

  /// `firstWeek.certsCleared` — `K25`'s third card.
  final bool clearsCertificatesStep;

  /// How many times she has replaced a rejected certificate. Three is the
  /// ceiling (G12 §3.1).
  final int replacementAttempts;

  /// Whether her page is readable after this transition.
  bool get pageIsLive => state.pageIsLive;
}

/// The **only** code path that decides a coach's credential state.
///
/// A pure function, so the whole of G12 §3.1 is testable without a network, an
/// emulator or a reviewer. In production the same transitions run inside a Cloud
/// Function and nothing else writes `verification`, `verifiedCerts`, `listed` or
/// the `coachV` claim — the posture G1 took for `users/{uid}.verification`, for
/// the same reason (spine C5).
class CoachVerificationStateMachine {
  const CoachVerificationStateMachine();

  /// Three rejected certificates and she is suspended rather than looped.
  static const int replacementCeiling = 3;

  /// Applies [event] to [current].
  ///
  /// [replacementAttempts] is carried in rather than stored, because this is a
  /// pure function and the counter lives on the document the caller is already
  /// holding.
  CoachVerificationOutcome transition(
    CoachVerificationState current,
    CoachVerificationEvent event, {
    int replacementAttempts = 0,
  }) {
    CoachVerificationOutcome stay() => CoachVerificationOutcome(
      state: current,
      changed: false,
      replacementAttempts: replacementAttempts,
    );

    switch (event) {
      case SetupCompleted():
        if (current != CoachVerificationState.setupIncomplete) return stay();
        if (!event.isComplete) return stay();
        return CoachVerificationOutcome(
          state: CoachVerificationState.submitted,
          changed: true,
          replacementAttempts: replacementAttempts,
        );

      case LookupStarted():
        if (current != CoachVerificationState.submitted) return stay();
        return CoachVerificationOutcome(
          state: CoachVerificationState.docsChecking,
          changed: true,
          replacementAttempts: replacementAttempts,
        );

      // The rule, as code. A finding — even a clean one — buys her a reviewer,
      // never a badge. Both branches land in the same state on purpose: if this
      // ever grows a branch to `verified`, the whole posture of the coach side
      // has changed and the diff should be impossible to miss.
      case LookupFinding():
        if (current != CoachVerificationState.docsChecking) return stay();
        return CoachVerificationOutcome(
          state: CoachVerificationState.humanReview,
          changed: true,
          replacementAttempts: replacementAttempts,
        );

      case ReviewerPass():
        if (!event.decision.isAdmissible) return stay();
        // A reviewer may clear her from review, from a checking state she was
        // pulled out of, or after a renewal. She is never cleared out of
        // suspension by this event — that is a different decision entirely.
        const from = {
          CoachVerificationState.submitted,
          CoachVerificationState.docsChecking,
          CoachVerificationState.humanReview,
          CoachVerificationState.expired,
        };
        if (!from.contains(current)) return stay();
        return CoachVerificationOutcome(
          state: CoachVerificationState.verified,
          changed: true,
          mintsCoachClaim: true,
          clearsCertificatesStep: true,
          replacementAttempts: replacementAttempts,
        );

      case ReviewerFail():
        if (!event.decision.isAdmissible) return stay();
        const from = {
          CoachVerificationState.submitted,
          CoachVerificationState.docsChecking,
          CoachVerificationState.humanReview,
          CoachVerificationState.verified,
        };
        if (!from.contains(current)) return stay();
        return CoachVerificationOutcome(
          state: CoachVerificationState.rejected,
          changed: true,
          revokesCoachClaim: current.holdsCoachClaim,
          failReason: event.reason,
          replacementAttempts: replacementAttempts,
        );

      case CertificateReplaced():
        if (current != CoachVerificationState.rejected) return stay();
        final attempts = replacementAttempts + 1;
        if (attempts > replacementCeiling) {
          return CoachVerificationOutcome(
            state: CoachVerificationState.suspended,
            changed: true,
            replacementAttempts: attempts,
          );
        }
        return CoachVerificationOutcome(
          state: CoachVerificationState.submitted,
          changed: true,
          replacementAttempts: attempts,
        );

      case AllCertificatesExpired():
        if (current != CoachVerificationState.verified) return stay();
        return CoachVerificationOutcome(
          state: CoachVerificationState.expired,
          changed: true,
          // The claim goes; the page and her clients stay.
          revokesCoachClaim: true,
          replacementAttempts: replacementAttempts,
        );

      case CertificateRenewed():
        if (current != CoachVerificationState.expired) return stay();
        // Back through a human, like everything else. A renewal is not a
        // shortcut around review.
        return CoachVerificationOutcome(
          state: CoachVerificationState.submitted,
          changed: true,
          replacementAttempts: replacementAttempts,
        );

      case SafetyActionTaken():
        if (current == CoachVerificationState.suspended) return stay();
        return CoachVerificationOutcome(
          state: CoachVerificationState.suspended,
          changed: true,
          revokesCoachClaim: current.holdsCoachClaim,
          replacementAttempts: replacementAttempts,
        );
    }
  }
}

/// What a coach in a given state is allowed to do, as one object a screen can
/// read.
///
/// Exists so that "may author, may not publish" is asked once and answered once.
/// Three screens need it — `K06`, `K18` and `K24` — and three copies of the same
/// boolean expression is how two of them end up disagreeing.
@immutable
class CoachPublishingRights {
  const CoachPublishingRights._({
    required this.mayAuthor,
    required this.mayPublish,
    required this.mayAcceptClients,
    required this.pageIsLive,
  });

  factory CoachPublishingRights.forState(CoachVerificationState state) =>
      CoachPublishingRights._(
        mayAuthor: state.mayAuthor,
        mayPublish: state.mayPublish,
        mayAcceptClients: state.mayAcceptClients,
        pageIsLive: state.pageIsLive,
      );

  /// She may write everything.
  final bool mayAuthor;

  /// Nothing she wrote is visible to anyone.
  final bool mayPublish;

  final bool mayAcceptClients;
  final bool pageIsLive;

  /// The state `K06` exists for: she can build, and none of it shows yet.
  bool get isAuthoringWhileUnpublished => mayAuthor && !mayPublish;
}
