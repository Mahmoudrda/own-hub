/// Asking for a woman reviewer, and what a failed call to the server means.
///
/// `request_review` (contracts/identity_contract.json) takes a path and no
/// images, no frames and no phone number. It writes one open review flag for
/// her account, and her verification state becomes `pending`. Until that call
/// has returned she is NOT in any queue, and no screen may say she is.
library;

import 'package:meta/meta.dart';

/// Callable name, identical on both sides of the contract.
const String kRequestReviewCallable = 'request_review';

/// Why she asked for a person. The enum names are the wire values.
enum ReviewPath {
  /// She would rather not show her face to a camera (C09 niqab path).
  niqab,

  /// She declined the camera at the consent step (C09b "I would rather not").
  declined,

  /// The automatic check could not run or could not be reached.
  error,
}

/// What the server answered.
enum ReviewRequestState {
  /// One open flag exists for her now; a woman reviewer will phone her.
  pending,

  /// She was already verified. Nothing was queued.
  approved,
}

/// Turns the wire value into a state, refusing anything unknown.
ReviewRequestState? reviewRequestStateFrom(Object? raw) => switch (raw) {
  'pending' => ReviewRequestState.pending,
  'approved' => ReviewRequestState.approved,
  _ => null,
};

/// Sends `request_review`.
abstract class ReviewRequester {
  /// Throws [VerificationCallFailure] (or anything else) when the call did not
  /// complete. Never returns a state the server did not send.
  Future<ReviewRequestState> request(ReviewPath path);
}

/// The requester a build with no back end holds. It always fails, so the
/// screen above it says honestly that she is not in the queue.
class UnavailableReviewRequester implements ReviewRequester {
  const UnavailableReviewRequester();

  @override
  Future<ReviewRequestState> request(ReviewPath path) async =>
      throw const VerificationCallFailure('unavailable');
}

/// A callable that answered with an error, in the domain's words.
///
/// [code] is the callable error code (`resource-exhausted`,
/// `failed-precondition`, `unavailable`, ...). [reason] is the server's reason
/// code, which the server always puts in the error message.
@immutable
class VerificationCallFailure implements Exception {
  const VerificationCallFailure(this.code, [this.reason]);

  final String code;
  final String? reason;

  @override
  String toString() => 'VerificationCallFailure($code, $reason)';
}

/// A callable's error code and message, read for a woman who is or is not
/// signed in. `unauthenticated` while signed in is App Check refusing this
/// copy of the app (R3), so it reads as `app_check_missing`.
VerificationCallFailure callFailureOf(
  String code,
  String? message, {
  required bool signedIn,
}) {
  if (code == 'unauthenticated' && signedIn) {
    return const VerificationCallFailure(
      'failed-precondition',
      ServerReason.appCheckMissing,
    );
  }
  return VerificationCallFailure(code, message);
}

/// The server reason codes the client acts on (contract `errorReasons`, plus
/// `review_already_open`, which start_verification raises).
abstract final class ServerReason {
  static const String perUidDailyLimit = 'per_uid_daily_limit';
  static const String dailyLimitReached = 'daily_limit_reached';
  static const String costCapReached = 'cost_cap_reached';
  static const String consentMissing = 'consent_missing';
  static const String verificationClosed = 'verification_closed';
  static const String reviewAlreadyOpen = 'review_already_open';
  static const String appCheckMissing = 'app_check_missing';
  static const String imageUndecodable = 'image_undecodable';
  static const String imageTooLarge = 'image_too_large';
  static const String sessionMissing = 'session_missing';
  static const String livenessFailed = 'liveness_failed';
  static const String internalError = 'internal_error';
}

/// What a failed call means for her next screen.
enum CallFailureKind {
  /// A daily limit: hers, or the service's. Try again tomorrow, never review.
  tryTomorrow,

  /// Every automatic check this account may use has been used. Never sent to
  /// review automatically; she may ask for a reviewer herself.
  checksUsedUp,

  /// Her agreement is not on file: back to the consent screen.
  consentMissing,

  /// A review is already open for her: the waiting screen.
  reviewOpen,

  /// Her account has been refused for good.
  closed,

  /// The photographs could not be used (unreadable, too large, a missing or
  /// failed liveness session): take them again. Not a review.
  retake,

  /// App Check refused this copy of the app. Asking for a reviewer would be
  /// refused the same way, so she is told to update the app instead.
  appCannotReach,

  /// Anything else: network, timeout, server error, App Check.
  other,
}

CallFailureKind classifyCallFailure(Object error) {
  if (error is! VerificationCallFailure) return CallFailureKind.other;
  final reason = error.reason;
  switch (error.code) {
    case 'resource-exhausted':
      if (reason == ServerReason.costCapReached) {
        return CallFailureKind.checksUsedUp;
      }
      // per_uid_daily_limit, daily_limit_reached, and any future daily cap.
      return CallFailureKind.tryTomorrow;
    case 'failed-precondition':
      return switch (reason) {
        ServerReason.appCheckMissing => CallFailureKind.appCannotReach,
        ServerReason.consentMissing => CallFailureKind.consentMissing,
        ServerReason.reviewAlreadyOpen => CallFailureKind.reviewOpen,
        ServerReason.verificationClosed => CallFailureKind.closed,
        _ => CallFailureKind.other,
      };
    case 'invalid-argument':
      return switch (reason) {
        ServerReason.imageUndecodable ||
        ServerReason.imageTooLarge ||
        ServerReason.sessionMissing ||
        ServerReason.livenessFailed ||
        ServerReason.internalError => CallFailureKind.retake,
        _ => CallFailureKind.other,
      };
    default:
      return CallFailureKind.other;
  }
}
