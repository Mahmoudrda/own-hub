/// The liveness challenge, chosen by a server and performed on a phone.
///
/// ## Why the server picks the steps
///
/// A challenge the client chooses is not a challenge. If this app drew the
/// sequence itself, an attacker would read the sequence out of our own APK,
/// pre-record a woman performing every step in every order, and play back
/// whichever one the app asked for. The randomisation is only worth something
/// if the person answering it could not have known the question, so
/// `start_verification` mints the session and the order, and the phone finds
/// out at the same moment she does.
///
/// ## Why the phone reports no verdict at all
///
/// [LivenessChallenge] carries a [sessionId], a list of [steps] and a deadline.
/// There is no outcome field, no score, no boolean, and that absence is the
/// design. An earlier version of this file sent the server what the client
/// thought of the challenge, which is the cheapest attack on the whole system:
/// a patched APK sends "pass" and walks into a women-only community. The server
/// reads the frames and decides; the phone's only job is to prompt her, take
/// one frame per step, and put them in the right order.
///
/// So there is nothing here that evaluates whether she blinked. ML Kit runs
/// during the challenge purely for framing, the same guidance it gives on the
/// card: is there a face, is there exactly one, is it centred, is the frame lit
/// and sharp. Whether the *step* was performed is a question this app does not
/// ask and could not be trusted to answer.
///
/// ## Frame count must equal step count
///
/// The server matches frame `n` against step `n`. A challenge that produced
/// three frames for four steps is not a shorter challenge, it is an unreadable
/// one, so [VerificationEvidence.isComplete] is checked against the challenge
/// rather than against a constant.
library;

import 'package:meta/meta.dart';

/// One thing the server asks her to do.
///
/// The wire vocabulary is the server's, and this enum is the closed set this
/// build knows how to prompt. [unsupported] is what an unrecognised step
/// becomes, and it is not a step we can run: see [LivenessChallenge.isRunnable].
enum LivenessStep {
  /// `face_centre`. Look straight at the lens.
  faceCentre,

  /// `turn_left`. Turn her head slightly to her own left.
  turnLeft,

  /// `turn_right`. Turn her head slightly to her own right.
  turnRight,

  /// `blink`.
  blink,

  /// A step this build has never heard of.
  ///
  /// The function deploys on its own schedule and may add steps. Prompting an
  /// unknown step with a guess would produce a frame the server then reads as a
  /// failed step, which is a woman refused for our being out of date. So an
  /// unknown step makes the whole challenge unrunnable and she is offered the
  /// video call instead, which is a path that already exists and already works.
  unsupported,
}

/// Reads the server's spelling. Unknown becomes [LivenessStep.unsupported]
/// rather than throwing: a new step code must not crash a sign-up.
LivenessStep livenessStepFrom(Object? wire) => switch (wire) {
  'face_centre' => LivenessStep.faceCentre,
  'turn_left' => LivenessStep.turnLeft,
  'turn_right' => LivenessStep.turnRight,
  'blink' => LivenessStep.blink,
  _ => LivenessStep.unsupported,
};

/// One liveness session, as `start_verification` handed it over.
@immutable
class LivenessChallenge {
  const LivenessChallenge({
    required this.sessionId,
    required this.steps,
    required this.expiresAt,
  });

  /// Opaque, minted by the server. The only thing about the challenge that
  /// travels back with the frames.
  final String sessionId;

  /// The ordered challenge. Frame `n` answers step `n`.
  final List<LivenessStep> steps;

  /// When the session stops being accepted.
  ///
  /// Computed from `expiresInSec` at the moment the response arrived. A woman
  /// who puts the phone down halfway through comes back to an expired session,
  /// and submitting against it would fail server side with nothing on screen to
  /// explain it, so expiry is checked before the frames are sent.
  final DateTime expiresAt;

  /// Whether this build can prompt every step in the sequence.
  bool get isRunnable =>
      steps.isNotEmpty && !steps.contains(LivenessStep.unsupported);

  bool hasExpiredAt(DateTime now) => !now.isBefore(expiresAt);
}

/// Starts a liveness session.
///
/// One method, because there is only one thing the phone is allowed to ask
/// for: the question. It never asks for the answer.
abstract class LivenessSessionSource {
  /// Whether this build can start a session at all.
  bool get isAvailable;

  /// Mints a session. Throws on transport failure, so "the server refused" and
  /// "the call never arrived" stay distinguishable at the call site.
  Future<LivenessChallenge> start();
}

/// The source for a build with no back end behind it.
///
/// It never returns a challenge, so nothing downstream can mistake it for a
/// working check. `C11` sees an unavailable session and offers the video call.
class UnavailableLivenessSessionSource implements LivenessSessionSource {
  const UnavailableLivenessSessionSource();

  @override
  bool get isAvailable => false;

  @override
  Future<LivenessChallenge> start() =>
      throw StateError('no liveness session source is wired up');
}

/// A source a test can drive.
///
/// **It still cannot let anyone in.** It hands out a challenge, which is a
/// question, and questions are not verdicts: the decision is the server's in
/// every build, so there is no configuration of this class that approves
/// anybody.
@visibleForTesting
class ScriptedLivenessSessionSource implements LivenessSessionSource {
  ScriptedLivenessSessionSource({
    required this.challenge,
    this.isAvailable = true,
  });

  final LivenessChallenge challenge;
  int starts = 0;

  @override
  final bool isAvailable;

  @override
  Future<LivenessChallenge> start() async {
    starts++;
    return challenge;
  }
}
