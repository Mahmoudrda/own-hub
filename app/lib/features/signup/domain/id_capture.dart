/// Camera capture for the two document steps, `C10` (the ID card) and `C11`
/// (the selfie).
///
/// The working implementation is `data/camera_capture_service.dart`, built on
/// `package:camera` with `google_mlkit_face_detection` for on-screen guidance.
/// We decide the check ourselves in a Cloud Function rather than renting a KYC
/// vendor's SDK, so this interface is the line between "open the lens and get a
/// usable frame" and "decide whether she is who the card says" — the second half
/// lives behind `VerificationProvider` and runs on a server.
/// [UnavailableCaptureService] stays for the paths where there is genuinely no
/// camera, and for the tests of those paths.
///
/// Three properties of this interface are load-bearing, and each is enforced by
/// what the types cannot express rather than by a check:
///
///  * **Rule 7 — the images are deleted.** No member of [CaptureSession]
///    returns image bytes, a path or a URL. A screen can start a capture and
///    learn that it finished; it can never get the picture. The frames go
///    straight into `VerificationEvidence`, which holds them in memory only,
///    wipes them the moment the call to `verify_identity` returns, and has
///    nowhere to write them down.
///  * **Rule 8 — no face-based gender classification.** There is no result type
///    here at all, and in particular nothing carrying a gender, a face template
///    or a classification score. Sex is read from the 13th digit of the national
///    ID number, inside a Cloud Function, and nowhere else. On-device face
///    detection exists here for one purpose, framing, and [CaptureGuidance] is
///    the entire vocabulary it is allowed to speak in: ten sentences about where
///    to hold a phone.
///  * **The niqab path never touches this file.** `C09`→`C15`→`C14` reaches a
///    woman reviewer without opening a camera, so a woman who will not be
///    photographed never meets a [CaptureService].
library;

import 'dart:async';

import 'package:flutter/widgets.dart' show Widget;
import 'package:meta/meta.dart';

/// Which of the two captures is running.
///
/// Deliberately not a boolean: `isSelfie` reads the same at both call sites and
/// a third target (a passport, G1 open question 5) would have nowhere to go.
enum CaptureTarget {
  /// The front of the Egyptian national ID card: her photograph, her name, and
  /// the 14 digit number whose 13th digit is odd for a man and even for a
  /// woman. This is the step that decides.
  idFront,

  /// The back of the same card.
  ///
  /// Not decoration and not an afterthought. The back prints the holder's sex
  /// as a word, أنثى or ذكر, and that word is an *independent* reading of the
  /// same fact the 13th digit carries. Two sources that have to agree is what
  /// turns "we parsed a number" into a cross-check: a forged or mistyped digit
  /// now has to survive a second field printed somewhere else on the card.
  /// The back also carries the issuing office and the expiry, which is how a
  /// card that expired in 2019 stops being a valid document.
  idBack,

  /// A liveness selfie, matched to the photograph on the card and then
  /// destroyed. **Never classified.**
  selfie,
}

/// The one thing to tell her right now, while the lens is open.
///
/// A closed vocabulary rather than a string, for two reasons. The first is
/// mechanical: every one of these is a line a woman reads, so each has to exist
/// in the dictionary in both languages, and an enum cannot be handed copy that
/// was never translated. The second is the point of the whole file — this is
/// everything the on-device detector is permitted to say. It can ask her to move
/// the phone. It cannot report anything about her.
///
/// **These are capture instructions, not verdicts, and the difference is a hard
/// rule.** Telling her the frame is blurry costs nothing and saves a paid OCR
/// call on a photograph nobody could have read. Telling her *why a check
/// failed* is the opposite: it is a free oracle for anyone iterating on a
/// forgery, and every outcome reads the same to her either way. Nothing in this
/// enum may ever describe the result of a check. See `VerificationReason`,
/// which is the server's vocabulary and never reaches a screen.
enum CaptureGuidance {
  /// The frame is blurry: the card moving, her hand shaking, a lens still
  /// hunting for focus.
  holdSteady,

  /// The subject is too small in the frame to be read.
  moveCloser,

  /// The subject is cropped or filling the frame.
  moveBack,

  /// Not enough light for the sharpness measurement to mean anything.
  moreLight,

  /// A bright specular patch across the card. Egyptian ID cards are laminated
  /// and a ceiling light lands straight on them, which is the single most
  /// common reason a card will not read.
  lessGlare,

  /// No face, or a face too far off centre for the oval.
  centreYourFace,

  /// More than one face in the frame.
  ///
  /// On the selfie it means someone is standing behind her, which is both a
  /// coercion signal and a reason the match will fail. On the front of the card
  /// it usually means her own face is in shot beside the card.
  onlyOneFace,

  /// The front of the card was asked for and no printed face is in the frame,
  /// which almost always means she is holding the back towards the lens.
  showTheFront,

  // The liveness prompts. These are the server's challenge steps, rendered as
  // sentences. **The app prompts them and never judges them**: whether she
  // actually blinked is decided from the frames, on a server, because a client
  // that scores its own challenge can be patched to score it however it likes.
  // See `domain/liveness_challenge.dart`.
  /// `face_centre`.
  lookStraight,

  /// `blink`.
  blink,

  /// `turn_left`. Her own left.
  turnLeft,

  /// `turn_right`. Her own right.
  turnRight,
}

/// Why capture cannot run, in terms a screen can act on.
enum CaptureUnavailableReason {
  /// No camera implementation is wired to this screen. Still reachable:
  /// [UnavailableCaptureService] is what the router holds until the real
  /// service is wired in, and it is the honest answer on a platform where
  /// `package:camera` has no implementation, such as a desktop build.
  notImplemented,

  /// The device has no usable camera.
  noCamera,

  /// She declined the camera permission. Recoverable: she can grant it.
  permissionDenied,

  /// The camera opened and then failed: a `CameraException` on initialise, a
  /// lens another app had already taken, a device that reported a camera it
  /// cannot actually start. **Never a rejection** — the screen offers the
  /// woman-reviewer path instead.
  providerUnavailable,

  /// Known to be offline before the camera opens, because a drop mid-capture
  /// abandons the session (G1 §4).
  ///
  /// Nothing reports this today. `pubspec.yaml` carries no connectivity plugin,
  /// and guessing is worse than not knowing: a phone can be on Wi-Fi with no
  /// route out, and telling a woman in that state that she is offline sends her
  /// to fix something that is not broken. The camera opens, the call is
  /// attempted, and a failed call becomes a woman reviewer rather than an
  /// accusation.
  offline,
}

/// Where a capture has got to.
///
/// A sealed hierarchy rather than an enum plus loose fields, so "captured but
/// unavailable" cannot be constructed.
@immutable
sealed class CaptureState {
  const CaptureState();

  /// The camera is not running and will not start. Carries the reason so the
  /// screen can offer the right way out.
  const factory CaptureState.unavailable(CaptureUnavailableReason reason) =
      CaptureUnavailable;

  /// Opening the camera. On a first run this is also the permission sheet.
  const factory CaptureState.preparing() = CapturePreparing;

  /// Live. [sharp] drives the design's promise that the card "photographs
  /// itself when it is sharp" — auto-capture, which is what removes the
  /// blurry-photo retry loop that kills completion.
  const factory CaptureState.framing({
    required bool sharp,
    CaptureGuidance? guidance,
    int? stepNumber,
    int? stepCount,
  }) = CaptureFraming;

  /// Every frame this step needed has been taken and handed over. Nothing is
  /// returned here: see the note on rule 7 at the top of this file.
  const factory CaptureState.captured() = CaptureCaptured;

  /// Whether the preview surface can show a live image.
  bool get isLive => this is CaptureFraming;
}

class CaptureUnavailable extends CaptureState {
  const CaptureUnavailable(this.reason);

  final CaptureUnavailableReason reason;
}

class CapturePreparing extends CaptureState {
  const CapturePreparing();
}

class CaptureFraming extends CaptureState {
  const CaptureFraming({
    required this.sharp,
    this.guidance,
    this.stepNumber,
    this.stepCount,
  });

  /// True when a capture taken right now would be accepted.
  ///
  /// It means two different things by design, because the screens want the same
  /// thing from it: on `C10` it is "this frame is sharp enough to read", which
  /// is what fires auto-capture; on `C11` it is "the liveness steps are all
  /// done", which is what lights up `Done`. Both answer the question the button
  /// is asking, which is whether pressing it now would be worth anything.
  final bool sharp;

  /// The one line to show her, or null when there is nothing useful to say.
  ///
  /// Null is common and correct. A viewfinder that always has an instruction on
  /// it teaches her to stop reading the instruction.
  final CaptureGuidance? guidance;

  /// Which step of the liveness challenge she is on, counting from one, and how
  /// many there are. Both null outside `C11`.
  ///
  /// Shown because the challenge is the only part of sign-up where a woman is
  /// asked to perform a sequence she did not choose and cannot predict. "Step 2
  /// of 4" is the difference between following instructions and being messed
  /// about. The count comes from the server's challenge, so it is not a
  /// constant and cannot be baked into the copy.
  final int? stepNumber;
  final int? stepCount;
}

class CaptureCaptured extends CaptureState {
  const CaptureCaptured();
}

/// One run of the camera, owned by the screen that opened it.
abstract class CaptureSession {
  Stream<CaptureState> watch();

  CaptureState get current;

  /// The manual shutter behind "Take it myself" (`C10`) and "Done" (`C11`).
  ///
  /// Returns nothing, on purpose. See rule 7 at the top of this file.
  Future<void> capture();

  /// Releases the camera. A session that is abandoned leaves the verification
  /// job at `submitted`, and resuming reuses the same `jobId` so there is no
  /// duplicate and no second billable provider check (G1 §4).
  Future<void> close();
}

/// Opens capture sessions.
abstract class CaptureService {
  Future<CaptureSession> open(CaptureTarget target);
}

/// A session that has a live image to draw.
///
/// Separate from [CaptureSession] rather than a member of it, for two reasons.
/// One is compatibility: [CaptureSession] is `implement`ed by a handful of
/// stand-ins, and adding a member would break every one of them to serve the
/// single session that has a camera. The other is that a viewfinder is a
/// [Widget] and the rest of this file is deliberately not — a screen asks
/// `session is Viewfinder` and gets a texture it can composite, or it draws the
/// design's placeholder.
///
/// **This does not put a picture within reach.** What comes back is a platform
/// texture the framework composites; nothing in Dart can read a pixel out of
/// it, save it or send it. Rule 7 survives a live preview for the same reason
/// it survives her seeing her own reflection.
abstract class Viewfinder {
  Widget buildViewfinder();
}

/// The implementation that refuses, and says why.
///
/// It is **not** a stand-in camera. It never reports [CaptureFraming], so no
/// screen built against it can appear to be capturing when it is not, and no
/// test can pass by pretending. The real one is `CameraCaptureService` in
/// `data/`; this stays as the answer on a build with no camera plugin behind it,
/// and as the fixture for the unavailable paths.
class UnavailableCaptureService implements CaptureService {
  const UnavailableCaptureService({
    this.reason = CaptureUnavailableReason.notImplemented,
  });

  final CaptureUnavailableReason reason;

  @override
  Future<CaptureSession> open(CaptureTarget target) async =>
      _UnavailableSession(reason);
}

class _UnavailableSession implements CaptureSession {
  _UnavailableSession(this._reason);

  final CaptureUnavailableReason _reason;

  @override
  CaptureState get current => CaptureState.unavailable(_reason);

  @override
  Stream<CaptureState> watch() => Stream<CaptureState>.value(current);

  @override
  Future<void> capture() async {
    // Nothing to capture. Silently succeeding here is what would turn a missing
    // camera into a screen that claims to have taken a picture.
    throw StateError('No capture implementation: ${_reason.name}');
  }

  @override
  Future<void> close() async {}
}
