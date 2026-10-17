/// C11 — Quick selfie.
///
/// Matches `6-v2/src/screens-signup.mjs` → `C11`.
///
/// **The selfie answers exactly one question: is this your card.** It is matched
/// to the photo on the document and then destroyed. It is never classified, and
/// no gender, age or appearance is inferred from it anywhere in this product —
/// rule 8, and a court has already ruled that excluding someone on
/// gender-related appearance is discrimination (*Tickle v Giggle*, Full Federal
/// Court of Australia, May 2026). The copy on this screen says so in her words,
/// and `domain/id_capture.dart` says so in its types: there is no result on that
/// interface that could carry a classification.
///
/// **No woman is ever forced through this screen.** The niqab path leaves from
/// `C09` and reaches a woman reviewer at `C15`→`C14` without a camera opening.
///
/// ## What this screen does and does not prove
///
/// It does **not** decide liveness. The server mints an ordered challenge,
/// `start_verification` hands it over, this screen prompts her through it one
/// step at a time and takes one frame per step, in order, and the server reads
/// the frames. Whether she actually blinked is a question this app never asks:
/// a challenge the client scores is a challenge a patched APK scores `pass`,
/// and a women-only gate decided on the attacker's own handset is not a gate.
/// See `domain/liveness_challenge.dart`.
///
/// ## Her shutter, one step at a time
///
/// Each step's instruction is the headline, big, and "Take photo" takes that
/// step's frame and moves to the next. The button works whenever the camera is
/// live: it is not held back by the face detector, by sharpness or by a clock.
/// An earlier version took the frames itself once ML Kit had seen a good face
/// for over a second, and turning her head kept resetting that clock, so on a
/// real phone the photos were never taken. Framing hints are still shown, as
/// advice beside the step.
///
/// After the last step she sees the photos and chooses "Use these photos" or
/// "Retake". Nothing is sent until she chooses. Retake wipes the frames and
/// starts the steps again. If the server's session runs out first, the frames
/// are wiped and "Start again" asks for a fresh session.
library;

import 'dart:async';

import 'package:flutter/material.dart';

import '../../../l10n/app_l10n.dart';
import '../../../theme/app_tokens.dart';
import '../../../ui/hand/mascot/kitten.dart';
import '../domain/id_capture.dart';
import 'widgets/capture_scaffold.dart';

class SelfieCaptureView extends StatefulWidget {
  const SelfieCaptureView({
    super.key,
    required this.captureService,
    this.onCaptured,
    this.onClose,
    this.onOpenSettings,
    this.onAskReviewer,
    this.onUnavailable,
    this.expiresAt,
    this.onStartAgain,
    this.onAskWoman,
  });

  /// Told once each time the camera turns out not to be able to run, with the
  /// reason, so the router can count it. Nothing else about the session.
  final ValueChanged<CaptureUnavailableReason>? onUnavailable;

  /// Opens this app's page in the phone's settings, when she turned the
  /// camera off. The camera is tried again when she comes back.
  final VoidCallback? onOpenSettings;

  /// A woman reviewer instead of a camera that cannot run, with the reason,
  /// so the reviewer path can tell a refusal from a failure.
  final ValueChanged<CaptureUnavailableReason>? onAskReviewer;

  final CaptureService captureService;

  /// Fired once she has checked the photos and tapped "Use these photos": on
  /// to `C12`.
  final VoidCallback? onCaptured;

  final VoidCallback? onClose;

  /// When the server's liveness session stops being accepted. Read each time
  /// the camera opens, because "Start again" replaces the session.
  final DateTime? Function()? expiresAt;

  /// Asks for a fresh session after this one ran out. True when one is in
  /// hand and the steps can run again; false keeps her on the "Start again"
  /// screen, or the caller has already taken her somewhere else.
  final Future<bool> Function()? onStartAgain;

  /// "Having trouble? Ask a woman to check you", while the camera works.
  final VoidCallback? onAskWoman;

  @override
  State<SelfieCaptureView> createState() => _SelfieCaptureViewState();
}

/// How long before the session's own deadline this screen treats it as gone.
/// The frames still have to reach the server after she taps "Use these
/// photos", and a set that lands a second late is refused for nothing she did.
const Duration _deadlineMargin = Duration(seconds: 15);

class _SelfieCaptureViewState extends State<SelfieCaptureView>
    with WidgetsBindingObserver {
  CaptureSession? _session;
  StreamSubscription<CaptureState>? _subscription;
  CaptureState _state = const CaptureState.preparing();

  /// "Use these photos" has moved her on. Lifted when she comes back.
  bool _reported = false;

  /// True between "Open settings" and her return to the app.
  bool _awaitingSettings = false;

  /// Every step's frame is taken and on screen for her to check.
  bool _reviewing = false;

  /// Her shutter is in flight. A second tap now would answer the next step.
  bool _capturing = false;

  /// The session ran out before she used the photos.
  bool _expired = false;

  /// "Start again" is asking for a fresh session.
  bool _startingAgain = false;

  /// Whether this screen is the one on top. Thumbnails are drawn only while
  /// it is.
  bool _onTop = true;

  Timer? _deadline;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _open();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final onTop = ModalRoute.isCurrentOf(context) ?? true;
    if (onTop && !_onTop && _reported) {
      // Back on this screen after moving on: the choice is hers again, and
      // the session clock with it.
      _reported = false;
      _armDeadline();
    }
    _onTop = onTop;
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _deadline?.cancel();
    _subscription?.cancel();
    _session?.close();
    super.dispose();
  }

  /// Back from the settings page: the camera is asked for again, so a woman
  /// who turned access on finds it working rather than still refused.
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed && _awaitingSettings) {
      _awaitingSettings = false;
      unawaited(_reopen());
    }
  }

  /// Closes whatever session is open and opens a fresh one.
  Future<void> _reopen() async {
    // The old subscription is dropped, not awaited: its state no longer
    // matters, and the camera itself is released below before a new one opens.
    unawaited(_subscription?.cancel());
    _subscription = null;
    final old = _session;
    _session = null;
    if (mounted) setState(() => _state = const CaptureState.preparing());
    await old?.close();
    if (mounted) await _open();
  }

  void _openSettings() {
    _awaitingSettings = true;
    widget.onOpenSettings?.call();
  }

  Future<void> _open() async {
    final session = await widget.captureService.open(CaptureTarget.selfie);
    if (!mounted) {
      await session.close();
      return;
    }
    setState(() {
      _session = session;
      _state = session.current;
    });
    _noteUnavailable(session.current);
    _subscription = session.watch().listen((state) {
      if (!mounted) return;
      final was = _state;
      setState(() => _state = state);
      if (was is! CaptureUnavailable) _noteUnavailable(state);
      if (state is CaptureCaptured) _enterReview();
    }, onError: _ignoreSessionError);
    _armDeadline();
  }

  /// A failure inside the session, a face detector that threw most likely,
  /// changes nothing on this screen: the last state stands and her shutter
  /// keeps working. The server judges the frames either way.
  void _ignoreSessionError(Object error) {}

  /// [SelfieCaptureView.onUnavailable], once per session that cannot run.
  void _noteUnavailable(CaptureState state) {
    if (state is CaptureUnavailable) widget.onUnavailable?.call(state.reason);
  }

  /// The moment this session is treated as gone, or null when there is none.
  DateTime? _cutOff() =>
      widget.expiresAt?.call()?.subtract(_deadlineMargin);

  void _armDeadline() {
    _deadline?.cancel();
    _deadline = null;
    final cutOff = _cutOff();
    if (cutOff == null || _expired) return;
    final left = cutOff.difference(DateTime.now());
    if (left <= Duration.zero) {
      _expire();
      return;
    }
    _deadline = Timer(left, _expire);
  }

  bool get _pastDeadline {
    final cutOff = _cutOff();
    return cutOff != null && !DateTime.now().isBefore(cutOff);
  }

  /// The session ran out. The frames are wiped and the camera let go: frames
  /// answering a session the server no longer accepts are worth nothing.
  void _expire() {
    _deadline?.cancel();
    _deadline = null;
    if (!mounted || _reported || _expired) return;
    _review?.discardTaken();
    unawaited(_releaseCamera());
    setState(() {
      _expired = true;
      _reviewing = false;
    });
  }

  Future<void> _startAgain() async {
    if (_startingAgain) return;
    setState(() => _startingAgain = true);
    final starter = widget.onStartAgain;
    final started = starter == null ? true : await starter();
    if (!mounted) return;
    setState(() => _startingAgain = false);
    if (!started) return;
    setState(() {
      _expired = false;
      _reviewing = false;
      _reported = false;
    });
    await _reopen();
  }

  /// The session as a source of the photos she checks, when it is one.
  CaptureReview? get _review {
    final session = _session;
    return session is CaptureReview ? session as CaptureReview : null;
  }

  void _enterReview() {
    if (_reviewing || _expired || !mounted) return;
    setState(() => _reviewing = true);
  }

  /// "Take photo": this step's frame, then the next step's prompt.
  Future<void> _capture() async {
    final session = _session;
    if (session == null || !_state.isLive || _capturing || _reviewing) return;
    setState(() => _capturing = true);
    try {
      await session.capture();
    } finally {
      if (mounted) setState(() => _capturing = false);
    }
    if (!mounted) return;
    if (session.current is CaptureCaptured) _enterReview();
  }

  /// "Use these photos". The single place `C12` is asked for.
  void _usePhotos() {
    if (_reported) return;
    final review = _review;
    if (review != null && review.takenCount == 0) return;
    if (_pastDeadline) {
      _expire();
      return;
    }
    _reported = true;
    _deadline?.cancel();
    _deadline = null;
    unawaited(_releaseCamera());
    widget.onCaptured?.call();
  }

  Future<void> _releaseCamera() async {
    unawaited(_subscription?.cancel());
    _subscription = null;
    await _session?.close();
  }

  /// "Retake": the frames are wiped and the steps start again from the first.
  Future<void> _retake() async {
    _review?.discardTaken();
    setState(() {
      _reviewing = false;
      _reported = false;
    });
    await _reopen();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppL10n.of(context);

    Widget oval(Widget child) => Container(
      width: 230,
      height: 300,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(AppRadius.full),
        border: Border.all(color: AppColors.primaryContainer, width: 3),
      ),
      child: child,
    );

    if (_expired) {
      return CaptureScaffold(
        title: l10n.quickSelfie,
        onClose: widget.onClose,
        frame: oval(
          const Icon(Icons.timer_outlined, size: 56, color: Color(0x99FFFFFF)),
        ),
        headline: l10n.timeIsUpForThisStep,
        body: l10n.forYourSafetyItStaysOpenA,
        actionLabel: l10n.startAgain,
        onAction: _startingAgain ? null : () => unawaited(_startAgain()),
        isSelfie: true,
        onAskWoman: widget.onAskWoman,
      );
    }

    if (_reviewing) {
      final review = _review;
      final held = review?.takenCount ?? 0;
      return CaptureScaffold(
        title: l10n.quickSelfie,
        onClose: widget.onClose,
        frame: _onTop && review != null && held > 0
            ? _Thumbnails(review: review, count: held, label: l10n.yourPhoto)
            : oval(CaptureFrameLabel(l10n.herFaceLive)),
        headline: l10n.checkYourPhotos,
        body: l10n.isYourFaceClearInEachOne,
        actionLabel: l10n.useThesePhotos,
        onAction: review != null && held == 0 ? null : _usePhotos,
        secondaryActionLabel: l10n.retake,
        onSecondaryAction: () => unawaited(_retake()),
        isSelfie: true,
        onAskWoman: widget.onAskWoman,
      );
    }

    final live = _state;
    final session = _session;
    // Promoted through an explicit cast rather than a type test in the tree:
    // `Viewfinder` is not a subtype of `CaptureSession`, so the analyser will
    // not narrow a nullable session to it on its own.
    final lens = _state.isLive && session is Viewfinder
        ? session as Viewfinder
        : null;
    final unavailable = live is CaptureUnavailable ? live.reason : null;
    final framing = live is CaptureFraming ? live : null;

    // "Step 2 of 4". The challenge is the only part of sign-up where she is
    // asked to perform a sequence she did not choose and cannot predict, and
    // the counter is the difference between following instructions and being
    // messed about. The total comes from the server, so it cannot be baked into
    // the sentence the way this dictionary's other Step strings are.
    final step = framing?.stepNumber;
    final stepCount = framing?.stepCount;
    final counter = step != null && stepCount != null
        ? l10n.stepStepOfTotal('$step', '$stepCount')
        : null;
    final prompt = framing?.prompt;
    final hint = framing?.guidance;

    return CaptureScaffold(
      title: l10n.quickSelfie,
      onClose: widget.onClose,
      frame: oval(
        lens != null
            ? ClipRRect(
                borderRadius: BorderRadius.circular(AppRadius.full),
                child: lens.buildViewfinder(),
              )
            : CaptureFrameLabel(l10n.herFaceLive),
      ),
      // The step she is being asked for, big, with the counter above it.
      headline: prompt != null
          ? _promptText(l10n, prompt)
          : counter ?? l10n.lookStraightAheadNoSmileNeeded,
      stepLabel: prompt != null ? counter : null,
      largeHeadline: prompt != null,
      // The kitten acts the step out with its own face, above the words.
      headlineGuide: prompt != null ? _kittenFor(prompt) : null,
      // "Matched to the photo on your card, then deleted." Rules 7 and 8 in one
      // line, at the moment she is being asked for her face.
      body: l10n.matchedToThePhotoOnYourCard,
      // A framing hint, as advice. It never holds the shutter back.
      guidance: hint != null
          ? captureGuidanceText(l10n, hint, isSelfie: true)
          : null,
      // A session that sends the step as its only line still gets the kitten
      // beside it. A framing correction is hers to read, not to copy.
      guide: prompt == null ? _kittenFor(hint) : null,
      actionLabel: l10n.takePhoto,
      // Hers whenever the camera is live: no detector, sharpness or clock in
      // the way.
      onAction: live.isLive && !_capturing ? _capture : null,
      unavailable: unavailable,
      isSelfie: true,
      onOpenSettings: _openSettings,
      onRetry: () => unawaited(_reopen()),
      onAskReviewer: unavailable == null || widget.onAskReviewer == null
          ? null
          : () => widget.onAskReviewer!(unavailable),
      onAskWoman: widget.onAskWoman,
    );
  }
}

/// The step's instruction, as the big headline.
String _promptText(AppL10n l10n, CaptureGuidance prompt) => switch (prompt) {
  CaptureGuidance.lookStraight => l10n.lookStraightAtTheCamera,
  CaptureGuidance.turnLeft => l10n.turnYourHeadALittleToYour,
  CaptureGuidance.turnRight => l10n.turnYourHeadALittleToYour_g5o1x,
  CaptureGuidance.blink => l10n.blinkSlowly,
  _ => captureGuidanceText(l10n, prompt, isSelfie: true),
};

Widget? _kittenFor(CaptureGuidance? step) => switch (step) {
  CaptureGuidance.turnLeft => const Kitten(pose: KittenPose.lookLeft, size: 44),
  CaptureGuidance.turnRight => const Kitten(
    pose: KittenPose.lookRight,
    size: 44,
  ),
  CaptureGuidance.blink => const Kitten(pose: KittenPose.blink, size: 44),
  CaptureGuidance.lookStraight => const Kitten(pose: KittenPose.rest, size: 44),
  _ => null,
};

/// The photos she just took, one per step, in the order they were taken.
class _Thumbnails extends StatelessWidget {
  const _Thumbnails({
    required this.review,
    required this.count,
    required this.label,
  });

  final CaptureReview review;
  final int count;
  final String label;

  @override
  Widget build(BuildContext context) {
    return ConstrainedBox(
      key: const ValueKey('capture-review-photos'),
      constraints: const BoxConstraints(maxWidth: 320),
      child: Wrap(
        alignment: WrapAlignment.center,
        spacing: 8,
        runSpacing: 8,
        children: [
          for (var index = 0; index < count; index++)
            Semantics(
              image: true,
              label: label,
              child: Container(
                width: 70,
                height: 94,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(
                    color: AppColors.primaryContainer,
                    width: 2,
                  ),
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(12),
                  child: review.buildTaken(index),
                ),
              ),
            ),
        ],
      ),
    );
  }
}
