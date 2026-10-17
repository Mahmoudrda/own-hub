/// C10 — Your ID card, front and back.
///
/// Matches `6-v2/src/screens-signup.mjs` → `C10`. The card is the gate: the
/// Egyptian national ID number carries sex and date of birth, so the decision
/// comes from a government record rather than from a guess about a face.
/// Auto-capture removes the blurry-photo retry loop that kills completion.
///
/// **Both sides, in two passes of this screen.** The front carries her
/// photograph and the fourteen digit number whose thirteenth digit is even for
/// a woman. The back prints the sex as a word, أنثى or ذكر, and that word is an
/// independent reading of the same fact: two sources that have to agree, rather
/// than one digit nobody can check. `CaptureTarget` decides which pass this is
/// and the copy follows it.
///
/// **She checks every photograph before it is used.** Whether the card
/// photographed itself or she pressed "Take it myself", the photograph is shown
/// with "Use this photo" and "Retake", and nothing moves on until she says so.
/// The back starts with "Now turn the card over" and a Ready button, and its
/// camera opens only after Ready: going straight from the front to a live
/// camera on the back photographed the front a second time, because the card
/// was still the right way up in her hand.
///
/// **No image reaches this widget.** The session writes into
/// `VerificationEvidence` and reports that it finished; there is no member on
/// [CaptureSession] that returns bytes, a path or a URL, which is how rule 7
/// is kept structurally rather than by remembering to delete something. The
/// review draws through [CaptureReview], which hands back a widget, and only
/// while this screen is the one on top: once she moves on, the decoded
/// picture is released.
///
/// **She must have consented before this screen is reachable.** The camera is
/// the first moment her face and her national ID leave the country, and the
/// consent screen that says so, in her language, is `ConsentView`. This widget
/// does not enforce that, because a screen cannot enforce its own
/// unreachability; the router places the consent step ahead of it and
/// `signup_consent_test.dart` asserts the order.
library;

import 'dart:async';

import 'package:flutter/material.dart';

import '../../../l10n/app_l10n.dart';
import '../../../theme/app_tokens.dart';
import '../data/cover_fit_viewfinder.dart' show idCardAspectRatio;
import '../domain/id_capture.dart';
import 'widgets/capture_scaffold.dart';

/// What happened when the captured card was handed on to the next step.
enum CaptureHandOff {
  /// The next screen has been opened.
  moved,

  /// Own Hub could not be reached. Her photographs are still held and she can
  /// try again from here.
  offline,

  /// The same, after enough failed tries that a woman reviewer is offered too.
  offlineOfferReviewer,
}

class IdCaptureView extends StatefulWidget {
  const IdCaptureView({
    super.key,
    required this.captureService,
    this.side = CaptureTarget.idFront,
    this.onCaptured,
    this.onClose,
    this.onOpenSettings,
    this.onAskReviewer,
    this.onHandOff,
    this.onUnavailable,
    this.onAskWoman,
  });

  /// "Having trouble? Ask a woman to check you", while the camera works.
  final VoidCallback? onAskWoman;

  /// Told once each time the camera turns out not to be able to run, with the
  /// reason, so the router can count it. Nothing else about the session.
  final ValueChanged<CaptureUnavailableReason>? onUnavailable;

  /// Used instead of [onCaptured] when the step after this one can fail for
  /// want of a network. `C10b` starts the liveness session here, and a dropped
  /// connection keeps her on this screen with her photographs rather than
  /// sending her to a reviewer queue.
  final Future<CaptureHandOff> Function()? onHandOff;

  /// Opens this app's page in the phone's settings, when she turned the
  /// camera off. The camera is tried again when she comes back.
  final VoidCallback? onOpenSettings;

  /// A woman reviewer instead of a camera that cannot run, with the reason,
  /// so the reviewer path can tell a refusal from a failure.
  final ValueChanged<CaptureUnavailableReason>? onAskReviewer;

  final CaptureService captureService;

  /// Which pass this is. Defaults to the front so the existing route and every
  /// caller that predates the two-sided capture still open the step that
  /// matters most.
  final CaptureTarget side;

  /// Fired once she has checked the photograph and tapped "Use this photo":
  /// on to the back, or to `C11`.
  final VoidCallback? onCaptured;

  /// Closing abandons the capture. Nothing has been sent, so there is no job to
  /// cancel and nothing to clean up on a server.
  final VoidCallback? onClose;

  @override
  State<IdCaptureView> createState() => _IdCaptureViewState();
}

class _IdCaptureViewState extends State<IdCaptureView>
    with WidgetsBindingObserver {
  CaptureSession? _session;
  StreamSubscription<CaptureState>? _subscription;
  CaptureState _state = const CaptureState.preparing();

  /// "Use this photo" has moved her on. Guards a double tap from pushing the
  /// next screen twice, and is lifted when she comes back to this one.
  bool _reported = false;

  /// True between "Open settings" and her return to the app.
  bool _awaitingSettings = false;

  /// The last hand-off could not reach Own Hub.
  CaptureHandOff? _handOffFailed;

  /// A hand-off is in flight.
  bool _handingOff = false;

  /// The back only: she has turned the card over and tapped Ready. The
  /// camera for the back does not open before this.
  late bool _turnedOver = widget.side != CaptureTarget.idBack;

  /// A photograph is held and on screen for her to check.
  bool _reviewing = false;

  /// Her shutter is in flight.
  bool _capturing = false;

  /// Whether this screen is the one on top. The review photograph is drawn
  /// only while it is.
  bool _onTop = true;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    if (_turnedOver) _open();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final onTop = ModalRoute.isCurrentOf(context) ?? true;
    // Back on this screen after moving on: the choice is hers again.
    if (onTop && !_onTop) _reported = false;
    _onTop = onTop;
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
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

  /// "Ready" on the back: the card is turned over, so the camera may open.
  void _ready() {
    if (_turnedOver) return;
    setState(() => _turnedOver = true);
    unawaited(_open());
  }

  Future<void> _open() async {
    final session = await widget.captureService.open(widget.side);
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
  }

  /// A failure inside the session, a face detector that threw most likely,
  /// changes nothing on this screen: the last state stands and her shutter
  /// keeps working. The server judges the frames either way.
  void _ignoreSessionError(Object error) {}

  /// [IdCaptureView.onUnavailable], once per session that cannot run.
  void _noteUnavailable(CaptureState state) {
    if (state is CaptureUnavailable) widget.onUnavailable?.call(state.reason);
  }

  /// The session as a source of the photograph she checks, when it is one.
  CaptureReview? get _review {
    final session = _session;
    return session is CaptureReview ? session as CaptureReview : null;
  }

  /// Both the auto-capture and her shutter arrive here, so "it photographed
  /// itself" and "she pressed the button" show one review between them.
  void _enterReview() {
    if (_reviewing || !mounted) return;
    setState(() => _reviewing = true);
  }

  Future<void> _capture() async {
    final session = _session;
    // Guarded rather than trusted: with no camera behind it there is nothing to
    // capture, and a button that succeeds anyway would be the lie this whole
    // arrangement exists to prevent.
    if (session == null || !_state.isLive || _capturing || _reviewing) return;
    setState(() => _capturing = true);
    try {
      await session.capture();
    } finally {
      if (mounted) setState(() => _capturing = false);
    }
    if (!mounted) return;
    // A shutter that failed on the camera leaves nothing to check. A session
    // that cannot show its photograph is reviewed all the same: she still
    // decides before anything moves on.
    final review = _review;
    if (review == null || review.takenCount > 0) _enterReview();
  }

  /// "Use this photo". The single place the next screen is asked for.
  void _usePhoto() {
    if (_reported || _handingOff) return;
    final review = _review;
    if (review != null && review.takenCount == 0) return;
    _reported = true;
    // The lens is let go before the next screen opens its own. The
    // photograph stays held for the check; only the camera is released.
    unawaited(_releaseCamera());
    if (widget.onHandOff != null) {
      unawaited(_handOff());
      return;
    }
    widget.onCaptured?.call();
  }

  Future<void> _releaseCamera() async {
    unawaited(_subscription?.cancel());
    _subscription = null;
    await _session?.close();
  }

  /// "Retake": the photograph is wiped now, and the camera opens again.
  Future<void> _retake() async {
    if (_handingOff) return;
    _review?.discardTaken();
    setState(() {
      _reviewing = false;
      _reported = false;
      _handOffFailed = null;
    });
    await _reopen();
  }

  Future<void> _handOff() async {
    final handOff = widget.onHandOff;
    if (handOff == null || _handingOff) return;
    setState(() {
      _handingOff = true;
      _handOffFailed = null;
    });
    final result = await handOff();
    if (!mounted) return;
    setState(() {
      _handingOff = false;
      _handOffFailed = result == CaptureHandOff.moved ? null : result;
    });
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppL10n.of(context);
    final isBack = widget.side == CaptureTarget.idBack;
    final title = isBack ? l10n.theBackOfYourCard : l10n.yourIdCard;
    final placeholder = isBack ? l10n.backOfTheCard : l10n.frontOfTheCard;

    Widget cardFrame(Widget child) => Container(
      width: 300,
      height: 300 / idCardAspectRatio,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: AppColors.primaryContainer, width: 3),
      ),
      child: child,
    );

    // The back, before Ready. No camera is open yet, so nothing can fire.
    if (!_turnedOver) {
      return CaptureScaffold(
        title: title,
        onClose: widget.onClose,
        frame: cardFrame(
          Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.flip, size: 40, color: Color(0x99FFFFFF)),
              const SizedBox(height: 8),
              CaptureFrameLabel(placeholder),
            ],
          ),
        ),
        headline: l10n.nowTurnTheCardOver,
        body: l10n.theBackHasNoPhotoOnIt,
        actionLabel: l10n.ready,
        onAction: _ready,
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
    final current = _state;
    final failed = _handOffFailed;
    final unavailable = failed != null
        ? CaptureUnavailableReason.offline
        : current is CaptureUnavailable
        ? current.reason
        : null;
    final offerReviewer =
        failed == null || failed == CaptureHandOff.offlineOfferReviewer;
    // After a failed hand-off the photographs are kept, so "Try again" asks
    // again rather than opening the camera.
    final VoidCallback? retry = failed != null
        ? (_handingOff ? null : () => unawaited(_handOff()))
        : () => unawaited(_reopen());
    final VoidCallback? askReviewer =
        unavailable == null || widget.onAskReviewer == null || !offerReviewer
        ? null
        : () => widget.onAskReviewer!(unavailable);

    if (_reviewing) {
      final review = _review;
      final held = review?.takenCount ?? 1;
      final photo = _onTop && review != null && held > 0
          ? review.buildTaken(0)
          : null;
      return CaptureScaffold(
        title: title,
        onClose: widget.onClose,
        frame: cardFrame(
          photo != null
              ? ClipRRect(
                  key: const ValueKey('capture-review-photo'),
                  borderRadius: BorderRadius.circular(15),
                  child: photo,
                )
              : CaptureFrameLabel(placeholder),
        ),
        headline: l10n.checkYourPhoto,
        body: l10n.canYouReadEveryWordIfNot,
        // Advice only. She can still use it; the server reads it either way.
        guidance: isBack && (review?.looksLikeFront ?? false)
            ? l10n.thisLooksLikeTheFrontOfThe
            : null,
        actionLabel: l10n.useThisPhoto,
        onAction: _handingOff || held == 0 ? null : _usePhoto,
        secondaryActionLabel: l10n.retake,
        onSecondaryAction: _handingOff ? null : () => unawaited(_retake()),
        unavailable: unavailable,
        onOpenSettings: _openSettings,
        onRetry: retry,
        onAskReviewer: askReviewer,
        onAskWoman: widget.onAskWoman,
      );
    }

    return CaptureScaffold(
      title: title,
      onClose: widget.onClose,
      // The live image inside the guide, or the design's own annotation when
      // there is no camera. Clipped one pixel inside the border so the
      // preview does not paint over the rectangle she is aiming with.
      frame: cardFrame(
        lens != null
            ? ClipRRect(
                borderRadius: BorderRadius.circular(15),
                child: lens.buildViewfinder(),
              )
            : CaptureFrameLabel(placeholder),
      ),
      headline: isBack
          ? l10n.turnTheCardOver
          : l10n.holdItFlatAllFourCornersInside,
      body: isBack
          ? l10n.weReadBothSidesNothingIsUploaded
          : l10n.itPhotographsItselfWhenItIsSharp,
      guidance: live is CaptureFraming && live.guidance != null
          ? captureGuidanceText(l10n, live.guidance!, isSelfie: false)
          : null,
      actionLabel: l10n.takeItMyself,
      // Always hers on a live camera, whatever the detector thinks.
      onAction: _state.isLive && !_capturing ? _capture : null,
      unavailable: unavailable,
      onOpenSettings: _openSettings,
      onRetry: retry,
      onAskReviewer: askReviewer,
      onAskWoman: widget.onAskWoman,
    );
  }
}
