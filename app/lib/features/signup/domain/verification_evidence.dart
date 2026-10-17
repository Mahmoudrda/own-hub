/// The only place in this app where a picture of her exists, and the shortest
/// life we can give it.
///
/// Rule 7 says the ID photograph and the selfie are destroyed once the check
/// completes. Everywhere else that rule is kept by having nowhere to put them:
/// `VerificationResult` has no field for an image, `CaptureSession` returns
/// none, and `product_rules_test.dart` fails the build over an identifier
/// shaped like storage. But the bytes have to exist for the few seconds between
/// the shutter and the HTTPS call, so one object holds them, and this is it.
///
/// What that costs is paid back in what it makes checkable. There is exactly
/// one thing to audit rather than a trail of local variables, and the
/// guarantees are testable properties of a plain Dart class:
///
///  * **Memory only.** Nothing here writes a file, takes a path or knows what a
///    directory is. The camera plugin's own temporary file is read and deleted
///    by `CameraCaptureService` before the bytes ever arrive here.
///  * **Wiped, not dropped.** [shred] overwrites every byte with zero before
///    releasing the buffer. Dropping the reference would leave the frames in
///    the heap for as long as the collector felt like it, and a 200 KB
///    photograph of a national ID card sitting in a live process is exactly
///    what a memory dump on a rooted phone is looking for. Zeroing is the only
///    part of that we control, so we do that part.
///  * **Used once.** [shred] runs in the `finally` of the submit, so it runs on
///    the failure path too. A check that times out must not leave her card in
///    memory until she closes the app.
///
/// **This is not a cache and must never become one.** If a call fails, the
/// frames are gone and she photographs the card again. That is worse for her by
/// about twenty seconds and better for her by an amount nobody can put a number
/// on.
library;

import 'dart:typed_data';

import 'package:meta/meta.dart';

import 'id_capture.dart';

/// Frames held between the shutter and `verify_identity`.
///
/// One instance per sign-up, shared by the capture service that fills it and
/// the repository that empties it. Not immutable, deliberately: it is a
/// hand-off, and two screens fill it at two different moments.
class VerificationEvidence {
  final Map<CaptureTarget, Uint8List> _cardSides = <CaptureTarget, Uint8List>{};
  final List<Uint8List> _frames = <Uint8List>[];

  /// One side of the national ID card, JPEG, from `C10` or `C10b`.
  ///
  /// Replacing a side shreds the frame it replaces, so "take it again" does not
  /// quietly leave the first attempt in the heap beside the second. Asserts on
  /// [CaptureTarget.selfie] rather than accepting it, because a selfie filed as
  /// a card side would be submitted as a document and read as one.
  ///
  /// A new front starts a new run, so any liveness frames still held from an
  /// earlier one are zeroed and let go here: the selfie always comes after
  /// both sides, and frames from before this front answer a session that is
  /// no longer the one she is on.
  void holdCardSide(CaptureTarget side, Uint8List jpeg) {
    assert(
      side == CaptureTarget.idFront || side == CaptureTarget.idBack,
      'holdCardSide takes a side of the card, not $side',
    );
    final previous = _cardSides[side];
    if (previous != null) _wipe(previous);
    if (side == CaptureTarget.idFront) dropFrames();
    _cardSides[side] = jpeg;
  }

  /// Wipes one side of the card, when she chose to take it again.
  ///
  /// Straight away rather than when the next photograph replaces it, so a
  /// retake she then abandons does not leave the first attempt in the heap.
  void dropCardSide(CaptureTarget side) {
    final previous = _cardSides.remove(side);
    if (previous != null) _wipe(previous);
  }

  /// One frame of the liveness check, JPEG, from `C11`.
  void addFrame(Uint8List jpeg) => _frames.add(jpeg);

  /// Wipes every liveness frame and leaves the card alone.
  ///
  /// Run each time a selfie session opens. Frame `n` answers step `n`, so a
  /// run of the steps always starts from none: a retake, a fresh challenge or
  /// a camera reopened after Settings would otherwise append four new frames
  /// to the old ones, and the server refuses a frame count that does not
  /// match its steps.
  void dropFrames() {
    // Zeroed first, then let go: clearing the list alone would leave every
    // frame in the heap until the collector got round to it.
    for (final frame in _frames) {
      _wipe(frame);
    }
    _frames.clear();
  }

  /// The front of the card, or null before `C10` has run.
  Uint8List? get front => _cardSides[CaptureTarget.idFront];

  /// The back of the card, or null before `C10b` has run.
  ///
  /// The back is what makes the sex on the card a cross-check rather than a
  /// single parsed digit: it prints the word, the front prints the number, and
  /// the server requires them to agree.
  Uint8List? get back => _cardSides[CaptureTarget.idBack];

  /// The liveness frames in the order they were taken.
  List<Uint8List> get frames => List<Uint8List>.unmodifiable(_frames);

  /// Enough to submit: both sides of the card, and at least one live frame.
  ///
  /// Both sides are required. One side is not a cheaper version of the check,
  /// it is a different check, and a server asked to cross-reference a word
  /// against a digit with only the digit in hand can only pretend.
  bool get isComplete => front != null && back != null && _frames.isNotEmpty;

  /// Total bytes held, for the size assertions and for a debug build's log.
  int get byteCount =>
      _cardSides.values.fold<int>(0, (sum, side) => sum + side.length) +
      _frames.fold<int>(0, (sum, frame) => sum + frame.length);

  /// Zero every byte and let go.
  ///
  /// Called from the `finally` of the submit, so it happens on the timeout and
  /// the crash as well as the success.
  void shred() {
    for (final side in _cardSides.values) {
      _wipe(side);
    }
    _cardSides.clear();
    for (final frame in _frames) {
      _wipe(frame);
    }
    _frames.clear();
  }

  /// Overwrites the buffer in place.
  ///
  /// `fillRange` on a `Uint8List` writes through to the same backing store, so
  /// this really does scribble over the photograph rather than hand back a
  /// cleared copy. What it cannot reach is anything the platform kept: the
  /// camera plugin's own buffers, the JPEG the OS encoder held, whatever the
  /// TLS stack copied on the way out. Those are outside Dart and outside this
  /// promise, and pretending otherwise would be the dishonest version.
  static void _wipe(Uint8List buffer) => buffer.fillRange(0, buffer.length, 0);

  /// True when nothing is held. The assertion rule 7 is really about.
  @visibleForTesting
  bool get isEmpty => _cardSides.isEmpty && _frames.isEmpty;
}
