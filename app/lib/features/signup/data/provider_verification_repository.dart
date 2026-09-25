/// The [VerificationRepository] that `C12`, `C13` and `C14` are wired to.
///
/// It turns one round trip into the state machine those screens read:
/// [VerificationChecking] while it runs, then [VerificationVerified],
/// [VerificationAwaitingReviewer], [VerificationNeedsAnotherLook] or
/// [VerificationRetakeNeeded].
///
/// ## Four rules this file exists to keep
///
/// **Nothing here decides.** There is no branch that grants verification on
/// anything the phone worked out. The only path to [VerificationVerified] runs
/// through a `VerificationProvider` that ran on a server (spine C5).
///
/// **The app branches on the outcome and on nothing else.** The server's
/// `reasons` are coarse and user-safe now, but they still stop here: they are
/// read, logged in a debug build, and dropped. [VerificationState] has no field
/// one could be put in. A gate that names the control you failed is a gate that
/// tells you which one to attack next, and every outcome reads the same to her
/// either way.
///
/// **An approval refreshes the ID token before it is announced.** Custom claims
/// only reach the token on refresh. Skipping it shows a woman "You're in" on
/// `C13` and then an app that still thinks she is unverified, which reads to her
/// as a rejection thirty seconds after being admitted. Since the gate is now the
/// whole app rather than just the community, a stale claim is not a cosmetic
/// bug; it is a locked door.
///
/// **The frames are shredded in a `finally`.** Success, rejection, timeout,
/// crash on a bad response: every path through [submit] wipes
/// `VerificationEvidence` before it returns. Rule 7 is not kept by remembering
/// to clean up on the happy path.
///
/// ## Nothing is stored for a reviewer, because nothing is stored
///
/// An earlier version of this file said the function kept encrypted evidence
/// for a human reviewer to look at. That is not the model and never will be:
/// the bundle is deleted outright whatever the outcome, and review is a short
/// video call with a woman. Nobody is ever sent her photographs. That is why a
/// failed call is not a data-loss problem here, only a repeat of the capture.
library;

import 'dart:async';

import 'package:flutter/foundation.dart';

import '../domain/liveness_challenge.dart';
import '../domain/verification.dart';
import '../domain/verification_evidence.dart';
import '../domain/verification_provider.dart';

/// Forces a fresh ID token so a custom claim written by the function becomes
/// visible. `FirebaseAuth.instance.currentUser?.getIdToken(true)`.
typedef ClaimRefresher = Future<void> Function();

class ProviderVerificationRepository implements VerificationRepository {
  ProviderVerificationRepository({
    required this.provider,
    required this.evidence,
    required this.refreshClaims,
    this.challenge,
    DateTime Function()? now,
  }) : _now = now ?? DateTime.now;

  final VerificationProvider provider;
  final VerificationEvidence evidence;

  /// Required rather than defaulted, so a composition root has to decide.
  /// Defaulting it to a no-op would make "the newly verified woman is locked
  /// out" a bug you get by forgetting a line.
  final ClaimRefresher refreshClaims;

  /// The session `C11` ran against. Set by whoever started it.
  ///
  /// Null means no liveness session was ever minted, which is a submit that
  /// cannot be scored and is treated as a retake rather than as a failure.
  LivenessChallenge? challenge;

  /// Injectable so a test can assert a measured duration instead of whatever
  /// the wall clock did between two statements. `C13` states the number.
  final DateTime Function() _now;

  final _states = StreamController<VerificationState>.broadcast();
  VerificationState _state = const VerificationState.notStarted();

  VerificationState get current => _state;

  @override
  Stream<VerificationState> watch() async* {
    yield _state;
    yield* _states.stream;
  }

  @override
  Future<VerificationState> submit({required VerificationMethod method}) async {
    if (method != VerificationMethod.automatic) {
      // The niqab path and the direct human path. No camera has opened, there
      // is nothing to send, and there is nothing to shred.
      final waiting = VerificationState.awaitingReviewer(submittedAt: _now());
      _emit(waiting);
      return waiting;
    }

    final startedAt = _now();
    final checking = VerificationState.checking(startedAt: startedAt);
    _emit(checking);

    // Not awaited. `submit` returns the state to show *while* the check runs,
    // and C12 is already listening for the outcome. Awaiting here would leave
    // the screen on its previous frame for as long as the function takes.
    unawaited(_run(startedAt));
    return checking;
  }

  Future<void> _run(DateTime startedAt) async {
    try {
      final session = challenge;
      if (session == null || session.hasExpiredAt(_now())) {
        // A session that expired while she was framing, or a submit with no
        // session behind it. Neither is a failure of hers and neither can be
        // scored, so she takes the photographs again rather than being judged
        // on frames the server will refuse to look at.
        _emit(const VerificationState.retakeNeeded());
        return;
      }

      final decision = await _submitWithOneRetry(session.sessionId);
      if (kDebugMode && decision.reasons.isNotEmpty) {
        // Debug only, and it never leaves the device. This is the one place the
        // reason codes are visible at all, and it exists so that a developer
        // holding the phone can see them while a woman holding the same phone
        // in release cannot.
        debugPrint(
          'verification reasons: '
          '${decision.reasons.map((reason) => reason.name).join(', ')}',
        );
      }

      switch (decision.outcome) {
        case VerificationOutcome.approved:
          if (decision.refreshToken) await _refreshWithRetries();
          _emit(
            VerificationState.verified(
              VerificationResult(
                method: VerificationMethod.automatic,
                decidedAt: _now(),
                startedAt: startedAt,
                // The images are destroyed by the function as a matter of
                // course, for every outcome, so this is the moment the check
                // returned rather than a separate confirmation we waited for.
                imagesDeletedAt: _now(),
              ),
            ),
          );
        case VerificationOutcome.pendingReview:
          _emit(VerificationState.awaitingReviewer(submittedAt: _now()));
        case VerificationOutcome.rejectedNotEligible:
        case VerificationOutcome.rejectedFailed:
        case VerificationOutcome.rejectedDuplicate:
          // All three land in the same place, and she is told the same coarse
          // sentence. Separating them on screen would be the oracle the reason
          // vocabulary was narrowed to remove.
          _emit(const VerificationState.needsAnotherLook());
        case VerificationOutcome.retryCapture:
        case VerificationOutcome.retryRequired:
          _emit(const VerificationState.retakeNeeded());
      }
    } catch (error, stack) {
      if (kDebugMode) debugPrint('verification call failed: $error\n$stack');
      // The call never completed, so nobody decided anything. She is not
      // refused for her network: a woman reviewer picks it up on a video call,
      // and there is no half-written case anywhere because nothing is stored.
      _emit(VerificationState.awaitingReviewer(submittedAt: _now()));
    } finally {
      // Rule 7. Every path, including the ones above that threw.
      evidence.shred();
      // The session is single use. Keeping it would let a second submit run
      // against a challenge whose frames have already been spent.
      challenge = null;
    }
  }

  /// One attempt, plus one retry when the call provably never landed.
  ///
  /// The retry is narrow on purpose. We still hold the frames at this point, so
  /// retrying is free in her time and cheap in ours, and a dropped packet on
  /// Egyptian mobile data should not cost a woman a video call she has to
  /// schedule. But a blind retry risks a second billable OCR pass on a request
  /// the server already processed, so only `unavailable` is retried: that is
  /// the code for "the connection could not be established", and it is the one
  /// case where we know nothing was charged. A timeout is *not* retried,
  /// because a timeout may well have been a success we did not hear about.
  Future<VerificationDecision> _submitWithOneRetry(String sessionId) async {
    try {
      return await provider.submit(evidence, sessionId);
    } catch (error) {
      if (!_worthRetrying(error)) rethrow;
      if (kDebugMode) debugPrint('verify_identity unavailable, retrying once');
      return provider.submit(evidence, sessionId);
    }
  }

  static bool _worthRetrying(Object error) {
    // Matched on the code rather than the type so this file does not have to
    // import the Firebase exception hierarchy to make a decision about
    // retrying. `unavailable` is gRPC's "could not connect".
    return error.toString().toLowerCase().contains('unavailable');
  }

  /// Refreshes the ID token, with two retries and a short backoff.
  ///
  /// Worth retrying where the call itself is not: this happens *after* the
  /// server has already decided, so there is nothing to double-charge and
  /// nothing to duplicate. What is at stake is whether she can open the app she
  /// was just admitted to.
  ///
  /// If all three attempts fail she is still told she is in, because she is:
  /// the claim is written and Firebase refreshes the token on its own within
  /// the hour. The residual risk is a woman who is verified and locked out
  /// until then, which is bad and is still better than telling a verified woman
  /// she is not verified.
  Future<void> _refreshWithRetries() async {
    for (var attempt = 0; attempt < 3; attempt++) {
      try {
        await refreshClaims();
        return;
      } catch (error) {
        if (kDebugMode) debugPrint('claim refresh failed: $error');
        if (attempt < 2) {
          await Future<void>.delayed(const Duration(milliseconds: 400));
        }
      }
    }
  }

  void _emit(VerificationState next) {
    _state = next;
    if (!_states.isClosed) _states.add(next);
  }

  Future<void> dispose() => _states.close();
}
