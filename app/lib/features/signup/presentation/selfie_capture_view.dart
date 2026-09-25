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
import '../domain/id_capture.dart';
import 'widgets/capture_scaffold.dart';

class SelfieCaptureView extends StatefulWidget {
  const SelfieCaptureView({
    super.key,
    required this.captureService,
    this.onCaptured,
    this.onClose,
  });

  final CaptureService captureService;

  /// Fired once the frame has been taken — on to `C12`.
  final VoidCallback? onCaptured;

  final VoidCallback? onClose;

  @override
  State<SelfieCaptureView> createState() => _SelfieCaptureViewState();
}

class _SelfieCaptureViewState extends State<SelfieCaptureView> {
  CaptureSession? _session;
  StreamSubscription<CaptureState>? _subscription;
  CaptureState _state = const CaptureState.preparing();
  bool _reported = false;

  @override
  void initState() {
    super.initState();
    _open();
  }

  @override
  void dispose() {
    _subscription?.cancel();
    _session?.close();
    super.dispose();
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
      actionLabel: l10n.done_54ca1,
      onAction: ready ? _capture : null,
    );
  }
}
