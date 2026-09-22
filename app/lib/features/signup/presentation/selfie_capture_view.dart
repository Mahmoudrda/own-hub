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
/// As with `C10`, this is real capture built against [CaptureService], and no
/// implementation exists yet — the shutter stays disabled rather than pretending.
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

  /// Fired once the frame has been handed to the provider — on to `C12`.
  final VoidCallback? onCaptured;

  final VoidCallback? onClose;

  @override
  State<SelfieCaptureView> createState() => _SelfieCaptureViewState();
}

class _SelfieCaptureViewState extends State<SelfieCaptureView> {
  CaptureSession? _session;
  StreamSubscription<CaptureState>? _subscription;
  CaptureState _state = const CaptureState.preparing();

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
      if (mounted) setState(() => _state = state);
    });
  }

  Future<void> _capture() async {
    final session = _session;
    if (session == null || !_state.isLive) return;
    await session.capture();
    if (!mounted) return;
    widget.onCaptured?.call();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppL10n.of(context);

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
        child: CaptureFrameLabel(l10n.herFaceLive),
      ),
      headline: l10n.lookStraightAheadNoSmileNeeded,
      // "Matched to the photo on your card, then deleted." Rules 7 and 8 in one
      // line, at the moment she is being asked for her face.
      body: l10n.matchedToThePhotoOnYourCard,
      actionLabel: l10n.done_54ca1,
      onAction: _state.isLive ? _capture : null,
    );
  }
}
