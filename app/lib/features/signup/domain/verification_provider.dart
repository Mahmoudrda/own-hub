/// Whoever actually decides, behind one interface.
///
/// Today that is our own Cloud Functions, `start_verification` and
/// `verify_identity`, because a KYC vendor wants roughly a dollar per check and
/// this product's economics are Egyptian: at fifty thousand sign-ups that is a
/// line item larger than the coaching payouts. Self-hosting is the right call at
/// this size and might stop being the right call at ten times it, which is
/// precisely why the decision has to be one file to swap and not a rewrite.
///
/// ## The phone asks the question and never answers it
///
/// [startSession] gets the challenge. [submit] sends the frames. Between those
/// two calls the app prompts a woman through a sequence it did not choose, and
/// at no point does it form an opinion. There is no method here that scores
/// anything locally and there cannot be one: a client that grades its own
/// homework can simply lie, an APK is a zip file, and a women-only community
/// whose gate is a boolean computed on the attacker's own device has no gate.
///
/// An earlier version of this file sent a client-computed liveness outcome
/// alongside the frames. That was the cheapest possible attack on the whole
/// system and it is gone: [submit] takes a session id, which is a reference,
/// not a verdict.
///
/// ## Rule 8 lives here too
///
/// No gender in this file, no classifier output, no confidence score about a
/// face. The check is: does the card scan as genuine, does the word printed on
/// the back agree with the 13th digit of the number on the front, and is the
/// person holding it the person printed on it. Sex is read from the card, server
/// side, and from nowhere else (*Tickle v Giggle*, Full Federal Court of
/// Australia, May 2026).
library;

import 'package:meta/meta.dart';

import 'liveness_challenge.dart';
import 'verification_evidence.dart';

/// What came back, in the server's own vocabulary.
///
/// Seven values, and the app must branch on these and on nothing else. They are
/// deliberately coarse: several of them mean very different things internally
/// and are indistinguishable from here, which is the point. Which control
/// rejected her is not something this app is told.
enum VerificationOutcome {
  approved,

  /// A woman will check, on a video call. **Not a soft rejection** and it must
  /// never be rendered as one.
  pendingReview,

  /// Refused because the card does not make her eligible.
  rejectedNotEligible,

  /// Refused because the check did not pass.
  rejectedFailed,

  /// This card has been through the check before, on another account.
  rejectedDuplicate,

  /// The photographs need taking again. Recoverable, and nothing to do with
  /// who she is.
  retryCapture,

  /// The whole check needs running again.
  retryRequired,
}

/// Reads the server's spelling of an outcome.
///
/// Anything unrecognised becomes [VerificationOutcome.pendingReview], which is
/// the only safe default. The two failure modes are "a woman who should have
/// been let in waits for a video call" and "a man is let in because the app
/// could not parse the word rejected". Those are not comparable, so the parser
/// leans the one way.
VerificationOutcome verificationOutcomeFrom(Object? wire) => switch (wire) {
  'APPROVED' => VerificationOutcome.approved,
  'PENDING_REVIEW' => VerificationOutcome.pendingReview,
  'REJECTED_NOT_ELIGIBLE' => VerificationOutcome.rejectedNotEligible,
  'REJECTED_FAILED' => VerificationOutcome.rejectedFailed,
  'REJECTED_DUPLICATE' => VerificationOutcome.rejectedDuplicate,
  'RETRY_CAPTURE' => VerificationOutcome.retryCapture,
  'RETRY_REQUIRED' => VerificationOutcome.retryRequired,
  _ => VerificationOutcome.pendingReview,
};

/// The coarse, user-safe reason vocabulary.
///
/// **This is not diagnostic information and it is not allowed to become any.**
/// The server used to be able to say `match_failed` or `sex_conflict`, and
/// stopped, because a gate that names the control you failed is a gate that
/// tells you which one to attack next. What crosses the wire now is the set
/// below and nothing else: five sentences, all of which could be printed on a
/// screen without teaching anybody anything.
///
/// **Nothing may branch on a specific value.** Control flow is
/// [VerificationOutcome]'s job. These exist so that an operations dashboard can
/// count them, and are dropped before the UI layer.
enum VerificationReason {
  /// A code this build has never heard of. First, and the fallback, because the
  /// function deploys on its own schedule.
  unknown,
  retakeFront,
  retakeBack,
  retakeSelfie,
  tryAgainLater,
  contactSupport,
}

VerificationReason verificationReasonFrom(Object? wire) => switch (wire) {
  'retake_front' => VerificationReason.retakeFront,
  'retake_back' => VerificationReason.retakeBack,
  'retake_selfie' => VerificationReason.retakeSelfie,
  'try_again_later' => VerificationReason.tryAgainLater,
  'contact_support' => VerificationReason.contactSupport,
  _ => VerificationReason.unknown,
};

/// The verdict.
@immutable
class VerificationDecision {
  const VerificationDecision({
    required this.outcome,
    this.reasons = const <VerificationReason>{},
    this.refreshToken = false,
  });

  final VerificationOutcome outcome;

  /// Zero or more, coarse, and never branched on.
  final Set<VerificationReason> reasons;

  /// The server wrote a custom claim and the ID token has to be refreshed
  /// before it is visible.
  ///
  /// Custom claims only reach the token on refresh, so a freshly verified woman
  /// who is not refreshed sees an app that still thinks she is unverified. That
  /// reads to her as a rejection thirty seconds after being told she is in,
  /// which is the worst possible moment for the product to look broken.
  final bool refreshToken;
}

/// Starts sessions and submits frames.
abstract class VerificationProvider {
  /// Mints the liveness session and its challenge.
  ///
  /// Called before `C11` opens, because the sequence she is prompted through
  /// has to come from somewhere she cannot reach.
  Future<LivenessChallenge> startSession();

  /// One authenticated round trip with the captured frames.
  ///
  /// [sessionId] is a reference to the challenge, not a claim about how it
  /// went. Nothing in this signature can carry a verdict, which is the point.
  ///
  /// [evidence] is read, never retained: the caller shreds it in a `finally`
  /// the moment this returns, so an implementation that squirrelled the frames
  /// away would be holding zeros within a millisecond of the response.
  ///
  /// Throws on transport failure rather than returning an eighth outcome, so
  /// that "the server refused her" and "the call never arrived" cannot be
  /// confused at the call site.
  Future<VerificationDecision> submit(
    VerificationEvidence evidence,
    String sessionId,
  );
}

/// The implementation that refuses, and says why.
///
/// It exists for one build shape and one only: the app came up with no back end
/// behind it. `FirebaseBoot` is deliberately built so that a failed
/// `initializeApp` never stops the app opening, which means the router can be
/// asked for `C10` on a handset where `FirebaseFunctions` cannot even be
/// constructed. Constructing [VerificationProvider]'s real implementation there
/// throws `[core/no-app]` in the middle of a sign-up; this one throws something
/// the layer above already knows how to answer.
///
/// **It is not a stand-in decision maker.** Both members throw, and neither can
/// ever produce an outcome: `IdentityCheck.startLiveness` catches the first and
/// returns false, so `C11` is never opened for frames nothing can score, and
/// `ProviderVerificationRepository` catches the second and sends her to a woman
/// reviewer. A provider that answered `approved` offline would be the whole
/// women-only gate decided on the handset, which is precisely what the
/// interface above is written to make impossible.
///
/// It is deliberately a different thing from `FakeVerificationRepository`,
/// which stands one layer higher and is a test fixture. This is what the
/// shipping app holds when Frankfurt is not reachable.
class UnavailableVerificationProvider implements VerificationProvider {
  const UnavailableVerificationProvider();

  @override
  Future<LivenessChallenge> startSession() async =>
      throw StateError('no verification back end in this build');

  @override
  Future<VerificationDecision> submit(
    VerificationEvidence evidence,
    String sessionId,
  ) async => throw StateError('no verification back end in this build');
}
