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
/// It takes one still of her face, with the front camera, once ML Kit says
/// there is exactly one face in the frame and it is centred. That is a *framing*
/// check and nothing more: it makes the still worth matching against the
/// photograph on the card.
///
/// It does **not** decide liveness. The server mints an ordered challenge,
/// `start_verification` hands it over, this screen prompts her through it one
/// step at a time and takes one frame per step, in order, and the server reads
/// the frames. Whether she actually blinked is a question this app never asks:
/// a challenge the client scores is a challenge a patched APK scores `pass`,
/// and a women-only gate decided on the attacker's own handset is not a gate.
/// See `domain/liveness_challenge.dart`.
///
/// So the shutter is not hers during a challenge. The frames are taken on the
/// server's sequence and the Done button stays inert, because a button she
/// could press between prompts would take a frame answering the wrong step.
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
  });

  /// Opens this app's page in the phone's settings, when she turned the
  /// camera off. The camera is tried again when she comes back.
  final VoidCallback? onOpenSettings;

  /// A woman reviewer instead of a camera that cannot run, with the reason,
  /// so the reviewer path can tell a refusal from a failure.
  final ValueChanged<CaptureUnavailableReason>? onAskReviewer;

  final CaptureService captureService;

  /// Fired once the frame has been taken — on to `C12`.
  final VoidCallback? onCaptured;

  final VoidCallback? onClose;

  @override
  State<SelfieCaptureView> createState() => _SelfieCaptureViewState();
}

class _SelfieCaptureViewState extends State<SelfieCaptureView>
    with WidgetsBindingObserver {
  CaptureSession? _session;
  StreamSubscription<CaptureState>? _subscription;
  CaptureState _state = const CaptureState.preparing();
  bool _reported = false;

  /// True between "Open settings" and her return to the app.
  bool _awaitingSettings = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _open();
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
    _subscription = session.watch().listen((state) {
      if (!mounted) return;
      setState(() => _state = state);
      if (state is CaptureCaptured) _report();
    });
  }

  void _report() {
    if (_reported) return;
    _reported = true;
    widget.onCaptured?.call();
  }

  Future<void> _capture() async {
    final session = _session;
    if (session == null || !_state.isLive) return;
    await session.capture();
    if (!mounted) return;
    _report();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppL10n.of(context);
    final live = _state;
    final session = _session;
    // Promoted through an explicit cast rather than a type test in the tree:
    // `Viewfinder` is not a subtype of `CaptureSession`, so the analyser will
    // not narrow a nullable session to it on its own.
    final lens = _state.isLive && session is Viewfinder
        ? session as Viewfinder
        : null;
    final current = _state;
    final unavailable = current is CaptureUnavailable ? current.reason : null;

    // The shutter waits for the framing to be good, unlike the card, where she
    // may always override because she can see the card and we can only see a
    // number. Here the thing being judged is the frame itself, and a still with
    // two faces in it or none costs her a check she did nothing to earn. During
    // a server-chosen challenge this is false throughout, by design.
    final ready = live is CaptureFraming && live.sharp;

    // "Step 2 of 4". The challenge is the only part of sign-up where she is
    // asked to perform a sequence she did not choose and cannot predict, and
    // the counter is the difference between following instructions and being
    // messed about. The total comes from the server, so it cannot be baked into
    // the sentence the way this dictionary's other Step strings are.
    final step = live is CaptureFraming ? live.stepNumber : null;
    final stepCount = live is CaptureFraming ? live.stepCount : null;

    return CaptureScaffold(
      title: l10n.quickSelfie,
      onClose: widget.onClose,
      frame: Container(
        width: 230,
        height: 300,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(AppRadius.full),
          border: Border.all(color: AppColors.primaryContainer, width: 3),
        ),
        child: lens != null
            ? ClipRRect(
                borderRadius: BorderRadius.circular(AppRadius.full),
                child: lens.buildViewfinder(),
              )
            : CaptureFrameLabel(l10n.herFaceLive),
      ),
      headline: step != null && stepCount != null
          ? l10n.stepStepOfTotal('$step', '$stepCount')
          : l10n.lookStraightAheadNoSmileNeeded,
      // "Matched to the photo on your card, then deleted." Rules 7 and 8 in one
      // line, at the moment she is being asked for her face.
      body: l10n.matchedToThePhotoOnYourCard,
      guidance: live is CaptureFraming && live.guidance != null
          ? captureGuidanceText(l10n, live.guidance!, isSelfie: true)
          : null,
      // The kitten shows the step with its own face. Only the challenge
      // steps: a framing correction is hers to read, not to copy.
      guide: switch (live is CaptureFraming ? live.guidance : null) {
        CaptureGuidance.turnLeft => const Kitten(
          pose: KittenPose.lookLeft,
          size: 44,
        ),
        CaptureGuidance.turnRight => const Kitten(
          pose: KittenPose.lookRight,
          size: 44,
        ),
        CaptureGuidance.blink => const Kitten(pose: KittenPose.blink, size: 44),
        CaptureGuidance.lookStraight => const Kitten(
          pose: KittenPose.rest,
          size: 44,
        ),
        _ => null,
      },
      actionLabel: l10n.done_54ca1,
      onAction: ready ? _capture : null,
      unavailable: unavailable,
      isSelfie: true,
      onOpenSettings: _openSettings,
      onRetry: () => unawaited(_reopen()),
      onAskReviewer: unavailable == null || widget.onAskReviewer == null
          ? null
          : () => widget.onAskReviewer!(unavailable),
    );
  }
}
