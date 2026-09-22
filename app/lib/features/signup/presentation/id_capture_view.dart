/// C10 — Your ID card.
///
/// Matches `6-v2/src/screens-signup.mjs` → `C10`. The card is the gate: the
/// Egyptian national ID number carries sex and date of birth, so the decision
/// comes from a government record rather than from a guess about a face.
/// Auto-capture removes the blurry-photo retry loop that kills completion.
///
/// **This screen is real camera capture, and the camera does not exist yet.**
/// It is built against [CaptureService] (`domain/id_capture.dart`), and the only
/// implementation available today is [UnavailableCaptureService]. The shutter is
/// therefore disabled unless a session actually reports it is framing — the
/// screen will not claim to have photographed anything. Wiring the provider's
/// SDK is a dependency change, not a rewrite of this file.
///
/// No image ever reaches our code: the SDK uploads device→provider under a
/// one-time session token, which is how rule 7 is kept structurally rather than
/// by remembering to delete something.
library;

import 'dart:async';

import 'package:flutter/material.dart';

import '../../../l10n/app_l10n.dart';
import '../../../theme/app_tokens.dart';
import '../domain/id_capture.dart';
import 'widgets/capture_scaffold.dart';

class IdCaptureView extends StatefulWidget {
  const IdCaptureView({
    super.key,
    required this.captureService,
    this.onCaptured,
    this.onClose,
  });

  final CaptureService captureService;

  /// Fired once the frame has been handed to the provider — on to `C11`.
  final VoidCallback? onCaptured;

  /// Closing abandons the session. The job stays `submitted` and resuming
  /// reuses the same `jobId`, so there is no duplicate and no second billable
  /// provider check.
  final VoidCallback? onClose;

  @override
  State<IdCaptureView> createState() => _IdCaptureViewState();
}

class _IdCaptureViewState extends State<IdCaptureView> {
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
    final session = await widget.captureService.open(CaptureTarget.idFront);
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
    // Guarded rather than trusted: with no camera behind it there is nothing to
    // capture, and a button that succeeds anyway would be the lie this whole
    // arrangement exists to prevent.
    if (session == null || !_state.isLive) return;
    await session.capture();
    if (!mounted) return;
    widget.onCaptured?.call();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppL10n.of(context);

    return CaptureScaffold(
      title: l10n.yourIdCard,
      onClose: widget.onClose,
      frame: Container(
        width: 300,
        height: 190,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: AppColors.primaryContainer, width: 3),
        ),
        child: CaptureFrameLabel(l10n.frontOfTheCard),
      ),
      headline: l10n.holdItFlatAllFourCornersInside,
      body: l10n.itPhotographsItselfWhenItIsSharp,
      actionLabel: l10n.takeItMyself,
      onAction: _state.isLive ? _capture : null,
    );
  }
}
