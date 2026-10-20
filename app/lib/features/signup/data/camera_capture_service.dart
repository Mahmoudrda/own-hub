/// The real camera behind `C10` (front of the card), `C10b` (back) and `C11`
/// (the selfie still).
///
/// ## What this file decides, and what it is forbidden to decide
///
/// It decides whether a frame is worth *sending*: is it lit, is it sharp, is
/// there a reflection across the lamination, is there exactly one face where
/// there should be one. Every rejection here is free, instant and saves a paid
/// OCR call on an image nobody could have read.
///
/// **It decides nothing about who she is.** The match between her and the card,
/// the sex read off the 13th digit and the word printed on the back, the
/// liveness verdict: all of that happens on a server, because a client that
/// scores itself can simply lie. An APK is a zip file; anyone can patch a
/// method that returns `true` and walk into a women-only community. So there is
/// no scoring function in this file, no threshold that decides an outcome, and
/// no value computed here that any server is asked to trust. The phone's entire
/// authority is over the phone: hold it steadier, turn on a light, move closer.
///
/// **ML Kit is used for detection and never for classification of her.** It is
/// asked two questions: how many faces are in this frame, and where is the one
/// face in it. It is never asked what she looks like. Rule 8 forbids inferring
/// sex from a face and the rule is right on the law as well as the ethics
/// (*Tickle v Giggle*, Full Federal Court of Australia, May 2026); sex comes
/// from the national ID number and the word printed beside it.
///
/// ## Rule 7 and the one moment the image touches disk
///
/// `package:camera` has no in-memory shutter. `takePicture()` writes a JPEG to
/// the app's temporary directory on both platforms and hands back a path, and
/// there is no version of this plugin that does otherwise. So the file is read
/// and deleted in the same `finally`, before the bytes reach
/// `VerificationEvidence`, and the path is never stored, never logged and never
/// passed to anything. That window is milliseconds long and it is real, and it
/// is written down here rather than glossed, because the honest statement of
/// rule 7 on this platform is "we delete it immediately", not "it never
/// exists".
///
/// Nothing else writes. No gallery save, no `image_picker`, no photo library
/// permission on either platform: the card is photographed now, live, and a
/// woman who could choose an existing picture could choose someone else's.
library;

import 'dart:async';
import 'dart:io';
import 'dart:math' as math;

import 'package:camera/camera.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart'
    show DeviceOrientation, MissingPluginException;
import 'package:flutter/widgets.dart';
import 'package:google_mlkit_face_detection/google_mlkit_face_detection.dart';

import '../domain/id_capture.dart';
import '../domain/liveness_challenge.dart';
import '../domain/verification_evidence.dart';
import 'frame_budget.dart';
import 'cover_fit_viewfinder.dart';
import 'frame_quality.dart';
import 'held_photo.dart';

/// How often a preview frame is actually measured.
///
/// The stream delivers 30 frames a second and measuring every one of them buys
/// nothing: she cannot react faster than this, and the spare CPU is what keeps
/// the preview from stuttering on the phones this product is for. Eight
/// readings a second is still faster than a hand moves.
const Duration _analysisInterval = Duration(milliseconds: 125);

/// The centred slice of the sensor frame the card measurements read.
///
/// **Deliberately a strict subset of the on-screen guide, and deliberately not
/// a mapping of it.** Turning the guide rectangle into sensor coordinates needs
/// the sensor orientation, the device rotation and whatever crop the preview
/// widget applied to fill the screen, and every one of those varies by handset.
/// Getting it wrong would not fail loudly; it would measure the wall beside the
/// card and tell her to hold still while she already is.
///
/// So the measured box is defined against the frame's own long and short axes:
/// a fifth of the long axis by half the short one, centred. Under the portrait
/// mapping the card guide fills the full short axis and about half of the long
/// one, so this sits inside it whichever way the platform hands us the
/// buffer. What it gives up is noticing a card with one
/// corner outside the guide, which is the gap already recorded at
/// [CardFrameGate.minContrast].
const double _cardRegionLongAxisFraction = 0.20;
const double _cardRegionShortAxisFraction = 0.50;

/// The centred slice used for the selfie's light and blur reading. Framing is
/// the face detector's job there, so this only has to be a piece of her.
const double _faceRegionFraction = 0.5;

// **Nothing here takes a photo on its own, card or selfie.**
// An earlier selfie version took each step's frame itself after 1.2 seconds of
// continuously good frames. Turning her head blurs, shifts and tilts the face,
// so the clock kept resetting and on a real iPhone the step never fired. And a
// helper that fires on its own is worse than none during a challenge: it can
// take step n+1's frame before she has turned, and frame n must answer step n.
// So each step's frame is hers to take, with "Take photo", whenever the camera
// is live. ML Kit stays for the framing hints and decides nothing.

/// Opens the lens for a capture step.
class CameraCaptureService implements CaptureService {
  CameraCaptureService({
    required this.evidence,
    this.challenge,
    Future<List<CameraDescription>> Function()? lenses,
  }) : _lenses = lenses ?? availableCameras;

  /// Where a captured frame goes: memory, briefly, and nowhere else.
  final VerificationEvidence evidence;

  /// The server's liveness challenge, if one has been minted.
  ///
  /// Null means `C11` has nothing to prompt her through, and the selfie session
  /// refuses rather than taking a lone photograph the server has no question to
  /// match it against. The card steps do not need it and are unaffected.
  LivenessChallenge? challenge;

  /// Injected so the "this phone has no rear camera" path is testable without
  /// a phone that has no rear camera.
  final Future<List<CameraDescription>> Function() _lenses;

  @override
  Future<CaptureSession> open(CaptureTarget target) async {
    final List<CameraDescription> lenses;
    try {
      lenses = await _lenses();
    } on CameraException catch (error) {
      return _UnavailableSession(_reasonFor(error));
    } on MissingPluginException {
      // A desktop or web build, or a test host. Honest, and not a crash.
      return const _UnavailableSession(CaptureUnavailableReason.notImplemented);
    }

    final session = challenge;
    if (target == CaptureTarget.selfie &&
        (session == null || !session.isRunnable)) {
      // No session, or a sequence containing a step this build cannot prompt.
      // Guessing at an unknown step would produce a frame the server reads as a
      // failed step, which is a woman refused for our being out of date. She
      // goes to the video call instead, which is a path that already exists.
      return const _UnavailableSession(
        CaptureUnavailableReason.providerUnavailable,
      );
    }

    final wanted = target == CaptureTarget.selfie
        ? CameraLensDirection.front
        : CameraLensDirection.back;
    final lens = lenses
        .where((camera) => camera.lensDirection == wanted)
        .firstOrNull;
    if (lens == null) {
      // No fallback to the other lens, on purpose. A front camera pointed at a
      // card produces a mirrored, soft photograph that fails server side, and a
      // rear camera cannot take a selfie she can frame. Saying "this phone
      // cannot do this" is the useful answer; C10 offers her the woman
      // reviewer.
      return const _UnavailableSession(CaptureUnavailableReason.noCamera);
    }

    final controller = CameraController(
      lens,
      captureResolution,
      enableAudio: false,
      // What ML Kit accepts without a conversion pass. NV21 on Android is a
      // single plane whose first `width * height` bytes are luma, so the blur
      // reading and the face detector share one buffer. iOS takes BGRA.
      imageFormatGroup: Platform.isAndroid
          ? ImageFormatGroup.nv21
          : ImageFormatGroup.bgra8888,
    );

    try {
      await controller.initialize();
      // The app is portrait only. Locking the capture orientation stops a
      // woman who tilts the phone from producing a card rotated 90 degrees,
      // which reads as an unreadable document rather than as a rotated one.
      await controller.lockCaptureOrientation(DeviceOrientation.portraitUp);
      // No flash, ever, on a laminated card: the reflection lands exactly on
      // the print. In a dark room the answer is a lamp, which is what
      // CaptureGuidance.moreLight asks for.
      await controller.setFlashMode(FlashMode.off);
    } on CameraException catch (error) {
      await controller.dispose();
      return _UnavailableSession(_reasonFor(error));
    }

    final opened = _LensSession(
      target: target,
      controller: controller,
      lens: lens,
      evidence: evidence,
      steps: target == CaptureTarget.selfie
          ? session!.steps
          : const <LivenessStep>[],
    );
    await opened.start();
    return opened;
  }

  /// Maps a plugin error onto something a screen can act on.
  ///
  /// The permission codes differ per platform and per plugin version, so this
  /// matches on the substring rather than on an exact code: a new spelling of
  /// "denied" must not turn a recoverable permission prompt into a dead end
  /// that tells her the camera is broken.
  static CaptureUnavailableReason _reasonFor(CameraException error) {
    final code = error.code.toLowerCase();
    if (code.contains('denied') ||
        code.contains('permission') ||
        code.contains('restricted')) {
      return CaptureUnavailableReason.permissionDenied;
    }
    if (code.contains('notfound') || code.contains('nocamera')) {
      return CaptureUnavailableReason.noCamera;
    }
    return CaptureUnavailableReason.providerUnavailable;
  }
}

/// One run of one lens.
class _LensSession implements CaptureSession, Viewfinder, CaptureReview {
  _LensSession({
    required this.target,
    required this.controller,
    required this.lens,
    required this.evidence,
    required this.steps,
  });

  final CaptureTarget target;
  final CameraController controller;
  final CameraDescription lens;
  final VerificationEvidence evidence;

  /// The server's ordered challenge. Empty for the card steps.
  ///
  /// Frame `n` answers step `n`, so this list is walked strictly in order and
  /// never reordered, skipped or retried out of sequence. A challenge that
  /// produced three frames for four steps is not a shorter challenge, it is an
  /// unreadable one.
  final List<LivenessStep> steps;

  /// Which step she is on, counting from zero.
  int _step = 0;

  /// How many photographs this session took and still holds.
  int _taken = 0;

  /// Every frame this session needed has been taken. Nothing more is taken
  /// after this, by either shutter, until the session is closed.
  bool _done = false;

  /// The back of the card only: whether the last measured frame had a face in
  /// it. The back of an Egyptian card has none, so a face means she is still
  /// showing the front. Advice for the review screen, and nothing else.
  bool _faceInView = false;

  /// [_faceInView] at the moment the back was photographed.
  bool _takenLooksLikeFront = false;

  late final FaceDetector _faces = FaceDetector(
    options: FaceDetectorOptions(
      // **Off, everywhere.** The classifier's only outputs are smiling and
      // eyes-open probabilities, and this app has no use for either: the
      // server judges the liveness steps, and a client opinion about whether
      // she blinked is exactly what the contract refuses to send. Leaving it on
      // would burn CPU on a phone that has none to spare, to compute a number
      // nothing is allowed to read. ML Kit has no gender output at all and
      // would not be permitted one if it had (rule 8).
      enableClassification: false,
      // The printed photograph on an ID card is small inside the frame; her own
      // face fills a third of it. One threshold for both would either miss the
      // card's face or lock onto a bystander's.
      minFaceSize: target == CaptureTarget.selfie ? 0.15 : 0.05,
      performanceMode: FaceDetectorMode.fast,
    ),
  );

  final _states = StreamController<CaptureState>.broadcast();
  CaptureState _state = const CaptureState.preparing();

  DateTime _lastAnalysis = DateTime.fromMillisecondsSinceEpoch(0);
  bool _analysing = false;
  bool _taking = false;
  bool _closed = false;

  Future<void> start() async {
    // A run of the steps always starts from no frames. See
    // [VerificationEvidence.dropFrames].
    if (target == CaptureTarget.selfie) evidence.dropFrames();
    _emit(_framing(sharp: false));
    await controller.startImageStream(_onFrame);
  }

  @override
  CaptureState get current => _state;

  @override
  Stream<CaptureState> watch() async* {
    yield _state;
    yield* _states.stream;
  }

  @override
  Widget buildViewfinder() {
    // The selfie stays a portrait preview. The card fills its landscape frame,
    // cropped, so the strip she sees is the middle of a photograph that is
    // taken whole.
    if (target == CaptureTarget.selfie) return CameraPreview(controller);
    final ratio = controller.value.aspectRatio;
    final upright = ratio > 1 ? Size(1, ratio) : Size(ratio, 1);
    return CoverFitViewfinder(
      previewSize: Size(upright.width * 1000, upright.height * 1000),
      preview: CameraPreview(controller),
    );
  }

  /// Her shutter. Obeyed on any live frame, on the card and on every selfie
  /// step alike: not gated on sharpness, on a face count or on a clock. She can
  /// see herself and the card; we can only see a number, and the detector can
  /// miss a face that is plainly there. The server judges the frame either way.
  @override
  Future<void> capture() async {
    if (_closed || _taking || _done) return;
    await _take();
  }

  // ------------------------------------------------------------------ review

  @override
  int get takenCount {
    if (target == CaptureTarget.selfie) {
      return math.min(_taken, evidence.frames.length);
    }
    final side = target == CaptureTarget.idFront
        ? evidence.front
        : evidence.back;
    return _taken > 0 && side != null ? 1 : 0;
  }

  @override
  Widget buildTaken(int index) {
    final Uint8List? jpeg;
    if (target == CaptureTarget.selfie) {
      final frames = evidence.frames;
      jpeg = index >= 0 && index < takenCount ? frames[index] : null;
    } else {
      jpeg = index == 0 && takenCount == 1
          ? (target == CaptureTarget.idFront ? evidence.front : evidence.back)
          : null;
    }
    if (jpeg == null) return const SizedBox.expand();
    // The selfie frames are drawn as small thumbnails, the card across the
    // width of the screen.
    return HeldPhoto(
      jpeg: jpeg,
      decodeWidth: target == CaptureTarget.selfie ? 240 : 720,
    );
  }

  @override
  int get neededCount => steps.isEmpty ? 1 : steps.length;

  @override
  bool get looksLikeFront => _takenLooksLikeFront;

  @override
  void discardTaken() {
    switch (target) {
      case CaptureTarget.idFront:
      case CaptureTarget.idBack:
        evidence.dropCardSide(target);
      case CaptureTarget.selfie:
        evidence.dropFrames();
    }
    _taken = 0;
    _takenLooksLikeFront = false;
  }

  @override
  Future<void> close() async {
    if (_closed) return;
    _closed = true;
    try {
      if (controller.value.isStreamingImages) {
        await controller.stopImageStream();
      }
    } catch (_) {
      // Disposing is the point; a stream that has already stopped is fine.
    }
    // Closing is called on the way out of a screen and when the app goes to
    // the background, often unawaited. It must release what it can and never
    // throw into a zone nobody is listening to.
    try {
      await controller.dispose();
    } catch (error) {
      if (kDebugMode) debugPrint('camera dispose failed: $error');
    }
    try {
      await _faces.close();
    } catch (error) {
      if (kDebugMode) debugPrint('detector close failed: $error');
    }
    await _states.close();
  }

  /// A framing state with the challenge step attached.
  CaptureFraming _framing({required bool sharp, CaptureGuidance? guidance}) {
    if (steps.isEmpty) {
      return CaptureFraming(sharp: sharp, guidance: guidance);
    }
    final index = _step.clamp(0, steps.length - 1);
    return CaptureFraming(
      sharp: sharp,
      // The step and the framing hint travel separately, so the step stays on
      // screen while a hint shows beside it.
      guidance: guidance,
      prompt: _promptFor(steps[index]),
      stepNumber: index + 1,
      stepCount: steps.length,
    );
  }

  static CaptureGuidance? _promptFor(LivenessStep step) => switch (step) {
    LivenessStep.faceCentre => CaptureGuidance.lookStraight,
    LivenessStep.blink => CaptureGuidance.blink,
    LivenessStep.turnLeft => CaptureGuidance.turnLeft,
    LivenessStep.turnRight => CaptureGuidance.turnRight,
    // Unreachable: a challenge containing one of these is refused before the
    // camera opens. Null rather than a guess, because a guessed prompt is a
    // frame the server scores against a step she was never asked to perform.
    LivenessStep.unsupported => null,
  };

  // ---------------------------------------------------------------- analysis

  Future<void> _onFrame(CameraImage frame) async {
    if (_closed || _taking || _analysing) return;
    final now = DateTime.now();
    if (now.difference(_lastAnalysis) < _analysisInterval) return;
    _lastAnalysis = now;
    _analysing = true;
    try {
      final advice = await _read(frame);
      // Her shutter may have fired while the detector was busy. Its result is
      // about a frame that is no longer the one that matters.
      if (_closed || _taking || _done) return;

      // Hints only: every frame, on the card and on the selfie, is taken when
      // she presses the shutter, never by this loop.
      _emit(_framing(sharp: advice == null, guidance: advice));
    } catch (error) {
      // Measuring a frame must never stop her. The shutter does not depend on
      // anything this loop produces.
      if (kDebugMode) debugPrint('frame analysis failed: $error');
    } finally {
      _analysing = false;
    }
  }

  /// What to tell her about this frame, or null when it is good enough.
  Future<CaptureGuidance?> _read(CameraImage frame) async {
    final luma = _lumaReader(frame);
    if (luma == null) {
      // An unexpected pixel format. Measuring nothing and reporting nothing is
      // right: the manual shutter still works, and inventing guidance from a
      // buffer we cannot read would be worse than silence.
      return null;
    }

    final region = _regionFor(frame);
    final quality = measureFrame(
      luma: luma,
      width: frame.width,
      height: frame.height,
      left: region.$1,
      top: region.$2,
      right: region.$3,
      bottom: region.$4,
    );

    final advice = target == CaptureTarget.selfie
        ? FaceFrameGate.advise(quality)
        : CardFrameGate.advise(quality);
    if (advice != null) {
      // Nothing was measured, so nothing is known about a face either.
      _faceInView = false;
      return _adviceToGuidance(advice);
    }

    // Only once the pixels are good, because face detection is the expensive
    // half and there is nothing to find in a dark or blurred frame anyway.
    return _faceGuidance(frame);
  }

  /// The face half: how many, and for the selfie, where.
  ///
  /// On the front of the card this is a side check. The Egyptian card prints
  /// her photograph on the front and nothing on the back, so "no face here"
  /// almost always means she is holding the card the wrong way round, and
  /// catching that now saves a round trip that would come back asking for the
  /// same thing.
  Future<CaptureGuidance?> _faceGuidance(CameraImage frame) async {
    final List<Face> found;
    try {
      final input = _inputFrom(frame);
      if (input == null) {
        _faceInView = false;
        return null;
      }
      found = await _faces.processImage(input);
    } catch (error) {
      // A detector that throws must not stop her. The server does the real
      // work; this was only ever going to save it a call.
      if (kDebugMode) debugPrint('face detection failed: $error');
      _faceInView = false;
      return null;
    }

    if (target == CaptureTarget.idBack) {
      // Never guidance and never a gate on the back: only remembered, so the
      // review can ask whether this is really the back. The front prints her
      // photograph and the back prints none.
      _faceInView = found.isNotEmpty;
      return null;
    }

    if (target == CaptureTarget.idFront) {
      if (found.isEmpty) return CaptureGuidance.showTheFront;
      // Her own face beside the card, or a second person in shot. Either way
      // the OCR gets a harder problem than it needs.
      if (found.length > 1) return CaptureGuidance.onlyOneFace;
      return null;
    }

    if (found.isEmpty) return CaptureGuidance.centreYourFace;
    // Someone standing behind her. It fails the match, and it is the shape a
    // coerced sign-up has.
    if (found.length > 1) return CaptureGuidance.onlyOneFace;

    final face = found.single;
    final upright = _uprightSize(frame);
    final box = face.boundingBox;

    final fill = box.height / upright.height;
    if (fill < 0.25) return CaptureGuidance.moveCloser;
    if (fill > 0.80) return CaptureGuidance.moveBack;

    final offCentre = math.max(
      (box.center.dx - upright.width / 2).abs() / (upright.width / 2),
      (box.center.dy - upright.height / 2).abs() / (upright.height / 2),
    );
    if (offCentre > 0.35) return CaptureGuidance.centreYourFace;

    // **No eye check during a challenge, and this is not an oversight.** An
    // earlier version nagged "hold still" when both eyes were shut, to avoid a
    // blinking still. With a server-chosen sequence that is actively harmful:
    // `blink` is one of the steps, so the correction would fire at exactly the
    // moment she is doing what she was asked, and tell her she was wrong to.
    // It is also the client forming an opinion about the challenge, which is
    // the thing this whole design refuses to do.
    return null;
  }

  static CaptureGuidance _adviceToGuidance(CaptureAdvice advice) =>
      switch (advice) {
        CaptureAdvice.tooDark => CaptureGuidance.moreLight,
        CaptureAdvice.glare => CaptureGuidance.lessGlare,
        CaptureAdvice.tooFar => CaptureGuidance.moveCloser,
        CaptureAdvice.blurred => CaptureGuidance.holdSteady,
      };

  /// The centred box the pixel measurements read. Left, top, right, bottom.
  (int, int, int, int) _regionFor(CameraImage frame) {
    final longAxisIsWidth = frame.width >= frame.height;
    final double longFraction;
    final double shortFraction;
    if (target == CaptureTarget.selfie) {
      longFraction = _faceRegionFraction;
      shortFraction = _faceRegionFraction;
    } else {
      longFraction = _cardRegionLongAxisFraction;
      shortFraction = _cardRegionShortAxisFraction;
    }

    final widthFraction = longAxisIsWidth ? longFraction : shortFraction;
    final heightFraction = longAxisIsWidth ? shortFraction : longFraction;

    final halfWidth = frame.width * widthFraction / 2;
    final halfHeight = frame.height * heightFraction / 2;
    final cx = frame.width / 2;
    final cy = frame.height / 2;
    return (
      (cx - halfWidth).round(),
      (cy - halfHeight).round(),
      (cx + halfWidth).round(),
      (cy + halfHeight).round(),
    );
  }

  /// A brightness reader for whichever buffer this platform handed us.
  ///
  /// Returns null for a format we did not ask for, which does happen: a device
  /// that cannot produce NV21 falls back to YUV_420_888, whose luma plane is
  /// still plane zero, so that case is handled rather than refused.
  LumaAt? _lumaReader(CameraImage frame) {
    if (frame.planes.isEmpty) return null;
    final plane = frame.planes.first;
    final bytes = plane.bytes;
    final stride = plane.bytesPerRow;

    switch (frame.format.group) {
      case ImageFormatGroup.nv21:
      case ImageFormatGroup.yuv420:
        return (x, y) {
          final index = y * stride + x;
          return index >= 0 && index < bytes.length ? bytes[index] : 0;
        };
      case ImageFormatGroup.bgra8888:
        return (x, y) {
          final index = y * stride + x * 4;
          if (index < 0 || index + 2 >= bytes.length) return 0;
          // Rec. 601 luma, in integers, from BGRA order. The fixed-point
          // weights are 0.114, 0.587 and 0.299 scaled by 256, so this is one
          // multiply-add per channel and no floating point in the hot loop.
          final blue = bytes[index];
          final green = bytes[index + 1];
          final red = bytes[index + 2];
          return (blue * 29 + green * 150 + red * 77) >> 8;
        };
      case ImageFormatGroup.jpeg:
      case ImageFormatGroup.unknown:
        return null;
    }
  }

  /// The frame as ML Kit wants it.
  InputImage? _inputFrom(CameraImage frame) {
    final rotation = _rotation();
    if (rotation == null) return null;
    if (frame.planes.isEmpty) return null;

    final format = switch (frame.format.group) {
      ImageFormatGroup.nv21 => InputImageFormat.nv21,
      ImageFormatGroup.bgra8888 => InputImageFormat.bgra8888,
      ImageFormatGroup.yuv420 => InputImageFormat.yuv_420_888,
      _ => null,
    };
    if (format == null) return null;

    // Single-plane formats only. A multi-plane YUV buffer would have to be
    // repacked into NV21 first, and doing that per frame in Dart costs more
    // than the guidance is worth; the manual shutter still works.
    if (frame.planes.length > 1 && format != InputImageFormat.bgra8888) {
      return null;
    }

    return InputImage.fromBytes(
      bytes: frame.planes.first.bytes,
      metadata: InputImageMetadata(
        size: Size(frame.width.toDouble(), frame.height.toDouble()),
        rotation: rotation,
        format: format,
        bytesPerRow: frame.planes.first.bytesPerRow,
      ),
    );
  }

  /// How far the sensor buffer is rotated from upright.
  ///
  /// The standard recipe from the plugin's own example. The front camera adds
  /// the device rotation and the rear camera subtracts it, which is the one
  /// asymmetry that makes this worth writing out rather than guessing: getting
  /// the sign wrong gives a detector that finds no faces at all on one lens and
  /// works perfectly on the other.
  InputImageRotation? _rotation() {
    final sensor = lens.sensorOrientation;
    if (Platform.isIOS) {
      return InputImageRotationValue.fromRawValue(sensor);
    }
    final device = switch (controller.value.deviceOrientation) {
      DeviceOrientation.portraitUp => 0,
      DeviceOrientation.landscapeLeft => 90,
      DeviceOrientation.portraitDown => 180,
      DeviceOrientation.landscapeRight => 270,
    };
    final compensated = lens.lensDirection == CameraLensDirection.front
        ? (sensor + device) % 360
        : (sensor - device + 360) % 360;
    return InputImageRotationValue.fromRawValue(compensated);
  }

  /// The frame's size after [_rotation] is applied, which is the space the
  /// bounding boxes come back in.
  Size _uprightSize(CameraImage frame) {
    final rotation = _rotation();
    final quarterTurned =
        rotation == InputImageRotation.rotation90deg ||
        rotation == InputImageRotation.rotation270deg;
    return quarterTurned
        ? Size(frame.height.toDouble(), frame.width.toDouble())
        : Size(frame.width.toDouble(), frame.height.toDouble());
  }

  // ----------------------------------------------------------------- shutter

  /// Take the picture, read it, delete it.
  Future<void> _take() async {
    if (_taking || _closed) return;
    _taking = true;
    try {
      // The stream is stopped around the shutter rather than left running.
      // Android's CameraX rejects a still capture while an analysis use case is
      // delivering frames on some devices, and the failure is a
      // `CameraException` at the exact moment she is trying to photograph her
      // ID card. Half a second of paused preview is the cheaper problem.
      if (controller.value.isStreamingImages) {
        await controller.stopImageStream();
      }

      final shot = await controller.takePicture();
      final bytes = await _readAndDelete(shot);
      if (_closed) return;
      if (bytes == null) {
        // The photograph could not be read. Nothing was taken for this step,
        // so the preview and its hints come back and she presses again.
        _emit(_framing(sharp: false));
        await _resumeStream();
        return;
      }

      if (kDebugMode && !frameIsWithinBudget(bytes)) {
        debugPrint(
          'capture out of budget: ${bytes.length} bytes, '
          'long edge ${jpegLongEdge(bytes)}',
        );
      }

      switch (target) {
        case CaptureTarget.idFront:
        case CaptureTarget.idBack:
          evidence.holdCardSide(target, bytes);
          _taken = 1;
          _takenLooksLikeFront = target == CaptureTarget.idBack && _faceInView;
        case CaptureTarget.selfie:
          evidence.addFrame(bytes);
          _taken++;
      }

      if (steps.isNotEmpty && _step + 1 < steps.length) {
        // On to the next prompt. The stream is restarted because `_take`
        // stopped it, for the framing hints.
        _step++;
        _emit(_framing(sharp: false));
        await _resumeStream();
        return;
      }

      // Every frame is in. The stream stays stopped: nothing more is taken
      // here, and the review she sees next needs no camera.
      _done = true;
      _emit(const CaptureState.captured());
    } catch (error) {
      // Never out of here. A camera that failed, or one released under the
      // shutter because the app went to the background, is a frame not taken,
      // not a crash on the screen she is holding.
      if (kDebugMode) debugPrint('capture failed: $error');
      if (_closed) return;
      _emit(_framing(sharp: false));
      await _resumeStream();
    } finally {
      _taking = false;
    }
  }

  /// Starts the preview stream again after the shutter stopped it, so the
  /// framing hints keep coming. Quietly does nothing on a closed or failed
  /// camera: the next press, or the screen reopening it, is the recovery.
  Future<void> _resumeStream() async {
    if (_closed) return;
    try {
      if (!controller.value.isStreamingImages) {
        await controller.startImageStream(_onFrame);
      }
    } catch (error) {
      if (kDebugMode) debugPrint('could not restart the preview: $error');
    }
  }

  /// Reads the plugin's temporary file and removes it.
  ///
  /// The delete is in a `finally` so it happens when the read throws, which is
  /// the case that would otherwise leave a photograph of a national ID card in
  /// the cache directory until the OS felt like clearing it. Nothing returns
  /// the path, so there is no second reference to forget about.
  Future<Uint8List?> _readAndDelete(XFile shot) async {
    final file = File(shot.path);
    try {
      return await file.readAsBytes();
    } catch (error) {
      if (kDebugMode) debugPrint('could not read the capture: $error');
      return null;
    } finally {
      try {
        if (file.existsSync()) await file.delete();
      } catch (error) {
        if (kDebugMode) debugPrint('could not delete the capture: $error');
      }
    }
  }

  void _emit(CaptureState next) {
    _state = next;
    if (!_states.isClosed) _states.add(next);
  }
}

/// The refusing session, local to this file so the reason travels with it.
class _UnavailableSession implements CaptureSession {
  const _UnavailableSession(this._reason);

  final CaptureUnavailableReason _reason;

  @override
  CaptureState get current => CaptureState.unavailable(_reason);

  @override
  Stream<CaptureState> watch() => Stream<CaptureState>.value(current);

  @override
  Future<void> capture() async {
    throw StateError('No camera: ${_reason.name}');
  }

  @override
  Future<void> close() async {}
}
