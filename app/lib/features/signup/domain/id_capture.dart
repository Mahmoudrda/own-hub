/// Camera capture for the two document steps, `C10` (the ID card) and `C11`
/// (the selfie).
///
/// **There is no working implementation of this interface, and that is the
/// honest state of the product.** `C10` and `C11` are real camera capture
/// hosted by a licensed provider's SDK (G1 §10.1): the SDK auto-captures, reads
/// the document and performs the liveness match, and the bytes travel
/// device→provider under a one-time session token. Neither the provider SDK nor
/// a camera plugin is in `pubspec.yaml` yet, so the only implementation here is
/// [UnavailableCaptureService], which says so rather than pretending.
///
/// The screens are built against this interface so that adding the SDK is a
/// dependency change rather than a rewrite — and so that a fake can never be
/// mistaken for a working camera, because no fake that *works* exists to be
/// mistaken.
///
/// Three properties of this interface are load-bearing, and each is enforced by
/// what the types cannot express rather than by a check:
///
///  * **Rule 7 — the images are deleted.** No member of [CaptureSession]
///    returns image bytes, a path or a URL. Our code never holds the picture, so
///    "we forgot to delete it" is not a state this layer can reach. The images
///    exist only inside the provider's SDK and are purged by the Cloud Function
///    that stamps `imagesDeletedAt`.
///  * **Rule 8 — no face-based gender classification.** There is no result type
///    here at all, and in particular nothing carrying a gender, a face template
///    or a classification score. Sex is read from the 13th digit of the national
///    ID number, inside a Cloud Function, and nowhere else. The selfie proves
///    the card is hers; it is never classified.
///  * **The niqab path never touches this file.** `C09`→`C15`→`C14` reaches a
///    woman reviewer without opening a camera, so a woman who will not be
///    photographed never meets a [CaptureService].
library;

import 'dart:async';

import 'package:meta/meta.dart';

/// Which of the two captures is running.
///
/// Deliberately not a boolean: `isSelfie` reads the same at both call sites and
/// a third target (a passport, G1 open question 5) would have nowhere to go.
enum CaptureTarget {
  /// The front of the Egyptian national ID card. The card carries the number
  /// that decides sex and age; this is the step that matters.
  idFront,

  /// A liveness selfie, matched to the photo on the card and then destroyed.
  /// **Never classified.**
  selfie,
}

/// Why capture cannot run, in terms a screen can act on.
///
/// [notImplemented] is first because it is today's real answer, and naming it
/// keeps the gap visible in the UI instead of hiding behind a spinner that never
/// resolves.
enum CaptureUnavailableReason {
  /// No provider SDK and no camera plugin are wired up yet.
  notImplemented,

  /// The device has no usable camera.
  noCamera,

  /// She declined the camera permission. Recoverable: she can grant it.
  permissionDenied,

  /// The provider could not mint a session (G1 §10.2). **Never a rejection** —
  /// the screen offers the woman-reviewer path instead.
  providerUnavailable,

  /// Connectivity is checked *before* the camera opens, because a drop
  /// mid-capture abandons the session (G1 §4).
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

  /// Opening the camera and minting the provider session.
  const factory CaptureState.preparing() = CapturePreparing;

  /// Live. [sharp] drives the design's promise that the card "photographs
  /// itself when it is sharp" — auto-capture, which is what removes the
  /// blurry-photo retry loop that kills completion.
  const factory CaptureState.framing({required bool sharp}) = CaptureFraming;

  /// The frame was taken and handed to the provider. Nothing is returned here:
  /// see the note on rule 7 at the top of this file.
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
  const CaptureFraming({required this.sharp});

  /// True when the provider's auto-capture would fire.
  final bool sharp;
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

/// The only implementation that exists today: one that refuses, and says why.
///
/// It is **not** a stand-in camera. It never reports [CaptureFraming], so no
/// screen built against it can appear to be capturing when it is not, and no
/// test can pass by pretending. When the provider SDK lands, the replacement
/// goes in `data/` and this class stays for tests of the unavailable path.
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
