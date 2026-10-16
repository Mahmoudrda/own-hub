/// The one file that knows who decides.
///
/// It calls two Cloud Functions of ours and translates what comes back.
/// Swapping to a KYC vendor is a different implementation of
/// [VerificationProvider] and nothing above this line moves.
///
/// ## The contract, written down because two people build against it
///
/// Reconciled with the backend worker. Region confirmed as
/// [kVerifyIdentityRegion].
///
/// **`start_verification`** takes no arguments beyond the auth token and
/// returns:
///
/// ```json
/// {"sessionId": "<opaque>",
///  "steps": ["face_centre", "turn_left", "face_centre", "blink"],
///  "expiresInSec": 120}
/// ```
///
/// `steps` is the server's ordered challenge. It is not a suggestion and it is
/// not reorderable: frame `n` answers step `n`, and the count must match.
///
/// **`verify_identity`** takes:
///
/// ```json
/// {"front":    "<base64 JPEG of the front of the national ID card>",
///  "back":     "<base64 JPEG of the back>",
///  "frames":   ["<base64 JPEG>", ...],
///  "liveness": {"sessionId": "<opaque>"},
///  "installId": "<random id for this install; hashed by the server>",
///  "operationId": "<uuid v4, one per attempt, reused on the one retry>"}
/// ```
///
/// `niqabPath` is not sent. A woman who asks for a woman reviewer goes through
/// `request_review` instead, which takes no images at all.
///
/// **`liveness` carries a session id and nothing else.** There was an `outcome`
/// field here and it is gone. The client must not compute or transmit a
/// verification result: that is the client being the source of truth, and a
/// patched APK sending `"outcome": "pass"` would walk straight into a
/// women-only community. The server ignores the field entirely now, and this
/// app no longer has one to send.
///
/// Response:
///
/// ```json
/// {"outcome": "APPROVED|PENDING_REVIEW|REJECTED_NOT_ELIGIBLE|REJECTED_FAILED|
///              REJECTED_DUPLICATE|RETRY_CAPTURE|RETRY_REQUIRED",
///  "reasons": ["retake_front", ...],
///  "refreshToken": true}
/// ```
///
/// Authentication is the callable's own: Firebase attaches the signed-in user's
/// token and the function rejects an unauthenticated call. Nothing here passes
/// a uid, because a uid in the payload is a uid an attacker can change, and the
/// token is the only copy of it that is worth anything.
library;

import 'dart:convert';

import 'package:cloud_functions/cloud_functions.dart';

import '../../../app_state/firebase_boot.dart';
import '../domain/liveness_challenge.dart';
import '../domain/verification_evidence.dart';
import '../domain/verification_provider.dart';
import 'callable_failure.dart';

/// Agreed with the backend. The two strings that have to be identical on both
/// sides.
const String kStartVerificationCallable = 'start_verification';
const String kVerifyIdentityCallable = 'verify_identity';

/// Where the functions run. Confirmed.
///
/// `europe-west3` is Frankfurt, the same region as the `own-hub-personal`
/// storage bucket. It is chosen for one reason: the privacy page written for
/// Egyptian women names the places her data goes, and a function left in the
/// default `us-central1` would add the United States to that list in exchange
/// for nothing.
const String kVerifyIdentityRegion = kFunctionsRegion;

/// How long a session is assumed good for when the server does not say.
///
/// Short rather than generous. An over-long guess means she completes a
/// challenge against a session the server has already dropped and is told
/// nothing useful; a short one sends her round again, which is annoying and
/// recoverable.
const int _fallbackExpirySeconds = 90;

class CallableVerificationProvider implements VerificationProvider {
  /// How long `verify_identity` is waited for: the server's own limit, so the
  /// phone never gives up on a check the server is still finishing.
  static const Duration submitTimeout = Duration(seconds: 120);

  CallableVerificationProvider({
    FirebaseFunctions? functions,
    DateTime Function()? now,
  }) : _functions = functions ?? FirebaseBoot.functions,
       _now = now ?? DateTime.now;

  final FirebaseFunctions _functions;

  /// Injectable so a test can assert the computed deadline instead of racing
  /// the wall clock.
  final DateTime Function() _now;

  @override
  Future<LivenessChallenge> startSession() async {
    final callable = _functions.httpsCallable(
      kStartVerificationCallable,
      options: HttpsCallableOptions(timeout: const Duration(seconds: 30)),
    );
    final HttpsCallableResult<Object?> response;
    try {
      response = await callable.call<Object?>();
    } on FirebaseFunctionsException catch (error) {
      throw callFailureFrom(error);
    }
    final data = response.data;
    if (data is! Map) {
      throw StateError('start_verification returned ${data.runtimeType}');
    }

    final sessionId = data['sessionId'];
    if (sessionId is! String || sessionId.isEmpty) {
      // Without a session id there is nothing to submit against, and inventing
      // one client side is exactly the thing this contract exists to prevent.
      throw StateError('start_verification returned no sessionId');
    }

    final rawSteps = data['steps'];
    final steps = <LivenessStep>[
      if (rawSteps is List)
        for (final step in rawSteps) livenessStepFrom(step),
    ];

    // `expiresInSec` arrives as an int over the channel, but a JSON number can
    // decode as a double, and a cast that assumed one would throw in the middle
    // of a sign-up.
    final rawExpiry = data['expiresInSec'];
    final seconds = rawExpiry is num
        ? rawExpiry.round()
        : _fallbackExpirySeconds;

    return LivenessChallenge(
      sessionId: sessionId,
      steps: steps,
      // Computed from the moment the response landed rather than from a server
      // clock we cannot read. It is a few hundred milliseconds pessimistic,
      // which is the right direction to be wrong in.
      expiresAt: _now().add(Duration(seconds: seconds)),
    );
  }

  @override
  Future<VerificationDecision> submit(
    VerificationEvidence evidence,
    String sessionId, {
    String? operationId,
    String? installId,
  }) async {
    final front = evidence.front;
    final back = evidence.back;
    if (front == null || back == null) {
      // Both sides or nothing. A server asked to cross-check the word printed
      // on the back against the 13th digit on the front, with only the front in
      // hand, can do nothing but guess, and this check exists precisely so that
      // nobody guesses.
      throw StateError('verify_identity needs both sides of the card');
    }

    final callable = _functions.httpsCallable(
      kVerifyIdentityCallable,
      // The same 120 seconds the function is given (`TIMEOUT_SEC`). OCR plus a
      // face match on a cold function is slow, and a client that gives up
      // before the server does turns a completed check into a duplicate one.
      options: HttpsCallableOptions(timeout: submitTimeout),
    );

    final HttpsCallableResult<Object?> response;
    try {
      response = await callable.call<Object?>(
        verifyPayload(
          front: base64Encode(front),
          back: base64Encode(back),
          frames: <String>[
            for (final frame in evidence.frames) base64Encode(frame),
          ],
          sessionId: sessionId,
          operationId: operationId,
          installId: installId,
        ),
      );
    } on FirebaseFunctionsException catch (error) {
      throw callFailureFrom(error);
    }

    return _decisionFrom(response.data);
  }

  /// The `verify_identity` body. Its keys are pinned to the contract's
  /// `requestKeys` by test/contracts/identity_contract_test.dart.
  static Map<String, Object?> verifyPayload({
    required String front,
    required String back,
    required List<String> frames,
    required String sessionId,
    String? operationId,
    String? installId,
  }) => <String, Object?>{
    'front': front,
    'back': back,
    'frames': frames,
    // A reference, not a verdict. There is no outcome field here and there
    // must never be one again.
    'liveness': <String, Object?>{'sessionId': sessionId},
    'installId': ?installId,
    'operationId': ?operationId,
  };

  /// Turns whatever came back into a decision, without trusting its shape.
  ///
  /// `data` is `Object?` and really is: a callable can return a map, a string,
  /// or null if the function returned nothing, and a cast that assumed a map
  /// would throw in the one place where throwing costs a woman her sign-up.
  static VerificationDecision _decisionFrom(Object? data) {
    if (data is! Map) {
      return const VerificationDecision(
        outcome: VerificationOutcome.pendingReview,
        reasons: <VerificationReason>{VerificationReason.tryAgainLater},
      );
    }

    final raw = data['reasons'];
    return VerificationDecision(
      outcome: verificationOutcomeFrom(data['outcome']),
      reasons: <VerificationReason>{
        if (raw is List)
          for (final code in raw) verificationReasonFrom(code),
      },
      refreshToken: data['refreshToken'] == true,
    );
  }
}
