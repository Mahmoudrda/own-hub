/// Identity verification — the reason this product exists.
///
/// A woman is admitted to the community only after the app has established she
/// is a woman. Everything in this file is shaped by four rules that are not
/// negotiable, and each is enforced structurally rather than by a check:
///
///  * **Rule 8 — no face-based gender classification, anywhere.** Sex is read
///    from the 13th digit of the Egyptian national ID number and from nothing
///    else. The selfie establishes that the person holding the card is the
///    person on it; it is never classified. (*Tickle v Giggle*, Full Federal
///    Court of Australia, May 2026.)
///  * **Rule 7 — the images are deleted.** Only the outcome is kept. There is
///    deliberately no field on [VerificationResult] that can hold an image, a
///    URL or a path, so "we forgot to delete it" is not a state this type can
///    represent.
///  * **Spine C5 — the result is server-written.** Nothing here writes it; the
///    app reads a decision and a custom claim. A client that could set its own
///    verified flag would make the women-only gate one line to bypass.
///  * **The niqab path is first-class.** A woman who will not show her face to a
///    camera is not an edge case to be handled later — [VerificationMethod] has
///    a variant for her, and no path through this file demands a selfie.
library;

import 'package:meta/meta.dart';

/// How she was checked.
enum VerificationMethod {
  /// ID document plus a liveness selfie, decided automatically.
  automatic,

  /// A woman reviewer looked at it. Used when the automatic check cannot decide.
  humanReview,

  /// A video call or a partner gym, for a woman who will not be photographed.
  /// No selfie is captured on this path at any point.
  niqabFriendly,
}

/// Where she is in the check.
///
/// A sealed hierarchy rather than an enum plus loose fields, so an impossible
/// combination — decided but with no method, rejected but carrying a review
/// queue position — cannot be constructed.
@immutable
sealed class VerificationState {
  const VerificationState();

  /// She has not started.
  ///
  /// **The gate is the whole app now, not only the community.** An earlier
  /// version of this comment said training, recipes and coach profiles were
  /// already open to her while she waited. The owner has since decided
  /// otherwise: nothing opens until the check completes. Every screen that
  /// promised otherwise has to say the new thing, and `C14` is the one that
  /// said it loudest.
  const factory VerificationState.notStarted() = VerificationNotStarted;

  /// Submitted, waiting on the automatic check.
  ///
  /// [startedAt] is what makes C13's "verified in N seconds" a measurement
  /// rather than a decoration. Nothing recorded a start time before, so that
  /// sentence fell back to the prototype's 74 and told every woman the same
  /// invented number about her own check.
  const factory VerificationState.checking({DateTime? startedAt}) =
      VerificationChecking;

  /// The automatic check could not decide, so a woman will look at it.
  /// **Not a rejection**, and the copy must never imply one.
  const factory VerificationState.awaitingReviewer({DateTime? submittedAt}) =
      VerificationAwaitingReviewer;

  const factory VerificationState.verified(VerificationResult result) =
      VerificationVerified;

  /// Could not be verified. She is told we are reviewing her application to keep
  /// the community safe and private, and routed to the woman-reviewer path —
  /// never accused, never dead-ended (DECISIONS.md D8).
  const factory VerificationState.needsAnotherLook() =
      VerificationNeedsAnotherLook;

  /// The photographs need taking again.
  ///
  /// A separate state from [needsAnotherLook] because it is a separate thing to
  /// do. "A woman will call you" and "take the photograph again" are different
  /// instructions with different costs, and collapsing them would spend a human
  /// video call on a glare patch she could have fixed in ten seconds.
  ///
  /// Also reached when the liveness session expired before she finished. That
  /// is nobody's fault and must not read as one.
  const factory VerificationState.retakeNeeded() = VerificationRetakeNeeded;

  /// A daily limit was reached, hers or the service's. She is told to try
  /// again tomorrow. Never a review: a limit is not a reason to spend a
  /// woman reviewer's call.
  const factory VerificationState.tryTomorrow() = VerificationTryTomorrow;

  /// Every automatic check this account may use has been used. She is told
  /// so, and may ask for a woman reviewer herself; she is not queued for one.
  const factory VerificationState.checksUsedUp() = VerificationChecksUsedUp;

  /// The server has no record of her agreement: back to the consent screen.
  const factory VerificationState.consentNeeded() = VerificationConsentNeeded;

  /// The server refused her account for good. She is told plainly, with how
  /// to delete her data. The same sentence for every reason (no oracle).
  const factory VerificationState.rejected() = VerificationRejected;

  /// The call failed and asking for a reviewer failed too. Nothing was
  /// decided and she is not in any queue; she can try again.
  const factory VerificationState.unreachable() = VerificationUnreachable;

  /// The call failed for a reason nobody classified (no network, a timeout,
  /// a server error). Nothing was decided and she is in no queue. She is
  /// offered a woman reviewer on C15, where she reads what the review means
  /// and asks for it herself (R4). Never queued for her automatically.
  const factory VerificationState.reviewOffered() = VerificationReviewOffered;

  /// App Check refused this copy of the app: it cannot reach Own Hub at all.
  /// She is told to install the latest version. Never a review, because the
  /// review call would be refused the same way.
  const factory VerificationState.appCannotReach() = VerificationAppCannotReach;

  /// The server did not accept her sign-in (N4). Nothing was decided; she
  /// signs in again with her phone number. Never a review.
  const factory VerificationState.signInAgain() = VerificationSignInAgain;

  /// The connection was too slow for the check to finish in time. Nothing was
  /// decided on this phone and she is in no queue; her photographs are already
  /// deleted, so she takes them again. The retry carries the same operation id,
  /// so a check the server did finish is not run and billed a second time.
  /// Never a review: the connection is not a reason to spend a woman's call.
  const factory VerificationState.tooSlow() = VerificationTooSlow;

  /// Whether the community is open to her.
  bool get isVerified => this is VerificationVerified;

  /// Whether she is waiting on someone. Drives the "we are reviewing" copy.
  ///
  /// [VerificationRetakeNeeded] is deliberately not pending: she is not waiting
  /// on anybody, the next move is hers, and copy that told her to sit tight
  /// would leave her sitting tight forever.
  bool get isPending =>
      this is VerificationChecking ||
      this is VerificationAwaitingReviewer ||
      this is VerificationNeedsAnotherLook;
}

class VerificationNotStarted extends VerificationState {
  const VerificationNotStarted();
}

class VerificationChecking extends VerificationState {
  const VerificationChecking({this.startedAt});

  /// When the check began. Nullable because a check restored from a cold start
  /// genuinely does not know, and guessing would reintroduce the fiction this
  /// field exists to remove.
  final DateTime? startedAt;
}

class VerificationAwaitingReviewer extends VerificationState {
  const VerificationAwaitingReviewer({this.submittedAt});
  final DateTime? submittedAt;
}

class VerificationVerified extends VerificationState {
  const VerificationVerified(this.result);
  final VerificationResult result;
}

class VerificationNeedsAnotherLook extends VerificationState {
  const VerificationNeedsAnotherLook();
}

class VerificationRetakeNeeded extends VerificationState {
  const VerificationRetakeNeeded();
}

class VerificationTryTomorrow extends VerificationState {
  const VerificationTryTomorrow();
}

class VerificationChecksUsedUp extends VerificationState {
  const VerificationChecksUsedUp();
}

class VerificationConsentNeeded extends VerificationState {
  const VerificationConsentNeeded();
}

class VerificationRejected extends VerificationState {
  const VerificationRejected();
}

class VerificationUnreachable extends VerificationState {
  const VerificationUnreachable();
}

class VerificationReviewOffered extends VerificationState {
  const VerificationReviewOffered();
}

class VerificationAppCannotReach extends VerificationState {
  const VerificationAppCannotReach();
}

class VerificationTooSlow extends VerificationState {
  const VerificationTooSlow();
}

class VerificationSignInAgain extends VerificationState {
  const VerificationSignInAgain();
}

/// What is kept after a successful check.
///
/// Note what is absent and must stay absent: no image, no document number, no
/// date of birth, no name. Rule 7 says the pictures are deleted once the check
/// completes, and the cheapest way to keep that promise is to have nowhere to
/// put them.
@immutable
class VerificationResult {
  const VerificationResult({
    required this.method,
    required this.decidedAt,
    required this.imagesDeletedAt,
    this.startedAt,
  });

  final VerificationMethod method;
  final DateTime decidedAt;

  /// When the check began, carried through from [VerificationChecking].
  ///
  /// Nullable, and [took] is nullable with it, because C13 must be able to tell
  /// the difference between "this took 12 seconds" and "we did not time it".
  /// The screen says nothing about duration in the second case rather than
  /// reaching for a plausible-looking number.
  final DateTime? startedAt;

  /// How long the check actually took, or null when it was never timed.
  Duration? get took {
    final began = startedAt;
    return began == null ? null : decidedAt.difference(began);
  }

  /// When the images were destroyed.
  ///
  /// Nullable on purpose: null means "not yet confirmed", which is a state the
  /// reconciler must page on rather than a state to render as fine. A boolean
  /// would have made "we never checked" indistinguishable from "it is done".
  ///
  /// Under the current model the function deletes the bundle outright for every
  /// outcome, approved or refused, so there is no retention window and nothing
  /// is ever put in front of a human reviewer. Review is a video call. Null
  /// therefore now means the check never returned at all, which is still a
  /// thing to page on.
  final DateTime? imagesDeletedAt;

  bool get imagesConfirmedDeleted => imagesDeletedAt != null;
}

/// Reads verification state. **There is no write method, by design** — the
/// decision is made by a Cloud Function and delivered as an auth claim.
abstract class VerificationRepository {
  /// Her current state.
  Stream<VerificationState> watch();

  /// Starts a check. Returns the state to show while it runs; the outcome
  /// arrives through [watch].
  Future<VerificationState> submit({required VerificationMethod method});
}
