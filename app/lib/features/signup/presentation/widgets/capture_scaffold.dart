/// The dark chrome shared by `C10` (the ID card) and `C11` (the selfie).
///
/// Both screens are a viewfinder: `inverseSurface` behind a white close bar, a
/// cut-out the subject is framed in, two lines of guidance, and one white
/// button. The two differ only in the shape of the cut-out and the words, so the
/// shape lives here once.
///
/// The cut-out holds the live camera when there is one to hold, and the
/// prototype's own annotation — "front of the card", "her face, live" — when
/// there is not. It never imitates a live image, and the shutter is disabled
/// unless a real [CaptureSession] reports it is framing. See
/// `domain/id_capture.dart`.
///
/// [guidance] is the one line the on-device checks are allowed to say, and it
/// sits under the body copy rather than over the viewfinder because a sentence
/// printed across a card is a sentence she cannot read and a card she cannot
/// see. Null most of the time, and that is the design: a viewfinder that always
/// has an instruction on it teaches her to stop reading the instruction.
///
/// When the camera cannot run ([unavailable]), the cut-out and the disabled
/// shutter give way to a message and two ways forward. Camera access she turned
/// off gets "Open settings"; anything else gets "Try again". Both get "Check me
/// another way", a woman reviewer with no camera. A woman who tapped "Don't
/// allow" used to meet an empty frame and a dead button, with nothing said.
library;

import '../../../../ui/screen_art_strip.dart';

import 'package:flutter/material.dart';

import '../../../../l10n/app_l10n.dart';
import '../../../../theme/app_tokens.dart';
import '../../../../ui/app_white_button.dart';
import '../../domain/id_capture.dart';

/// White at 60% — the prototype's annotation colour on the dark screens.
const Color _annotation = Color(0x99FFFFFF);

/// White at 75% — the prototype's body colour on the dark screens.
const Color _onDarkVariant = Color(0xBFFFFFFF);

const Color _onDark = Color(0xFFFFFFFF);

class CaptureScaffold extends StatelessWidget {
  const CaptureScaffold({
    super.key,
    required this.title,
    required this.frame,
    required this.headline,
    required this.body,
    required this.actionLabel,
    this.guidance,
    this.onAction,
    this.onClose,
    this.unavailable,
    this.isSelfie = false,
    this.onOpenSettings,
    this.onRetry,
    this.onAskReviewer,
  });

  /// Why the camera cannot run, or null while it can.
  final CaptureUnavailableReason? unavailable;

  /// Which sentence explains a camera that is off: the card's or the selfie's.
  final bool isSelfie;

  /// Opens this app's page in the phone's settings. Offered only for
  /// [CaptureUnavailableReason.permissionDenied].
  final VoidCallback? onOpenSettings;

  /// Opens the camera again. Offered for every other reason.
  final VoidCallback? onRetry;

  /// A woman reviewer instead of the camera.
  final VoidCallback? onAskReviewer;

  /// Shown in the bar, in white.
  final String title;

  /// The cut-out: a card rectangle on `C10`, an oval on `C11`.
  final Widget frame;

  /// The instruction, 17 and semibold.
  final String headline;

  /// The reassurance underneath, 15/22.
  final String body;

  final String actionLabel;

  /// The live instruction, already translated, or null when there is nothing
  /// worth saying.
  final String? guidance;

  /// Null disables the shutter — which is the honest state whenever there is no
  /// camera behind it.
  final VoidCallback? onAction;

  final VoidCallback? onClose;

  @override
  Widget build(BuildContext context) {
    final l10n = AppL10n.of(context);
    final reason = unavailable;
    final refused = reason == CaptureUnavailableReason.permissionDenied;
    final String? stopTitle = reason == null
        ? null
        : refused
        ? l10n.cameraAccessIsOff
        : null;
    final String? stopBody = reason == null
        ? null
        : refused
        ? (isSelfie
              ? l10n.ownHubNeedsTheCameraForA
              : l10n.ownHubNeedsTheCameraToRead)
        : reason == CaptureUnavailableReason.offline
        ? l10n.noConnectionYourPhotosAreStillHere
        : l10n.theCameraCouldNotStartThisIs;
    final Widget shownFrame = reason == null
        ? frame
        : Container(
            width: 132,
            height: 132,
            alignment: Alignment.center,
            decoration: const BoxDecoration(
              color: Color(0x33FFFFFF),
              shape: BoxShape.circle,
            ),
            child: Icon(
              reason == CaptureUnavailableReason.offline
                  ? Icons.wifi_off
                  : Icons.no_photography_outlined,
              size: 56,
              color: _onDark,
            ),
          );
    final List<Widget> actions = reason == null
        ? [
            AppWhiteButton(
              actionLabel,
              height: 52,
              fontSize: 15,
              onPressed: onAction,
            ),
          ]
        : [
            AppWhiteButton(
              refused ? l10n.openSettings : l10n.tryAgain,
              height: 52,
              fontSize: 15,
              onPressed: refused ? onOpenSettings : onRetry,
            ),
            if (onAskReviewer != null)
              TextButton(
                onPressed: onAskReviewer,
                style: TextButton.styleFrom(
                  foregroundColor: _onDark,
                  minimumSize: const Size.fromHeight(48),
                ),
                child: Text(
                  l10n.checkMeAnotherWay,
                  style: AppText.titleM.copyWith(color: _onDark, fontSize: 15),
                ),
              ),
          ];

    return Scaffold(
      backgroundColor: AppColors.inverseSurface,
      appBar: AppBar(
        toolbarHeight: 64,
        backgroundColor: Colors.transparent,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        titleSpacing: 4,
        // Close, not back: leaving here abandons the capture rather than
        // stepping one screen back through it.
        leading: onClose == null
            ? const SizedBox(width: 8)
            : IconButton(
                onPressed: onClose,
                iconSize: 24,
                color: _onDark,
                icon: const Icon(Icons.close),
              ),
        title: Text(title, style: AppText.titleM.copyWith(color: _onDark)),
      ),
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(16),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    // The screen's own illustration (C10 or C11). Draws nothing
                    // outside the router.
                    const ScreenArtStrip(size: 84),
                    const SizedBox(height: 12),
                    shownFrame,
                    const SizedBox(height: 18),
                    if (reason != null)
                      Semantics(
                        liveRegion: true,
                        child: Text(
                          stopTitle ?? stopBody!,
                          key: const ValueKey('capture-unavailable'),
                          textAlign: TextAlign.center,
                          style: AppText.titleM.copyWith(color: _onDark),
                        ),
                      )
                    else
                      Text(
                        headline,
                        textAlign: TextAlign.center,
                        style: AppText.titleM.copyWith(color: _onDark),
                      ),
                    // A refused camera has a title and a body; any other stop
                    // says it in one sentence, above.
                    if (reason == null || stopTitle != null) ...[
                      const SizedBox(height: 18),
                      ConstrainedBox(
                        constraints: const BoxConstraints(maxWidth: 300),
                        child: Text(
                          reason == null ? body : stopBody!,
                          textAlign: TextAlign.center,
                          style: AppText.bodyM.copyWith(
                            height: 22 / 15,
                            color: _onDarkVariant,
                          ),
                        ),
                      ),
                    ],
                    if (reason == null && guidance != null) ...[
                      const SizedBox(height: 16),
                      // Announced as well as drawn. The guidance is the only
                      // part of this screen that changes while she is holding
                      // the phone, and a woman using TalkBack gets no value
                      // from a viewfinder she cannot see unless the correction
                      // is spoken. `liveRegion` is what makes the screen reader
                      // read it again each time it changes.
                      Semantics(
                        liveRegion: true,
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 14,
                            vertical: 8,
                          ),
                          decoration: BoxDecoration(
                            color: const Color(0x33FFFFFF),
                            borderRadius: BorderRadius.circular(AppRadius.full),
                          ),
                          child: Text(
                            guidance!,
                            textAlign: TextAlign.center,
                            style: AppText.bodyM.copyWith(color: _onDark),
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 14),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: actions,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// The dictionary entry for one piece of on-device guidance.
///
/// Exhaustive over [CaptureGuidance] with no default arm, so adding a guidance
/// value without minting copy for it in both languages is a compile error
/// rather than an English sentence appearing in an Arabic build.
/// [isSelfie] exists for one line: "hold the card still" is nonsense when she
/// is the subject, and a single shared sentence would have had to be vague
/// enough to be useless in both places.
String captureGuidanceText(
  AppL10n l10n,
  CaptureGuidance guidance, {
  required bool isSelfie,
}) => switch (guidance) {
  CaptureGuidance.holdSteady =>
    isSelfie ? l10n.holdStill : l10n.holdTheCardStill,
  CaptureGuidance.moveCloser => l10n.moveALittleCloser,
  CaptureGuidance.moveBack => l10n.moveBackALittle,
  CaptureGuidance.moreLight => l10n.thereIsNotEnoughLight,
  CaptureGuidance.lessGlare => l10n.tiltTheCardToCutTheGlare,
  CaptureGuidance.centreYourFace => l10n.bringYourFaceIntoTheCircle,
  CaptureGuidance.onlyOneFace => l10n.onlyOneFaceInTheFrame,
  CaptureGuidance.showTheFront => l10n.showTheFrontOfTheCard,
  CaptureGuidance.lookStraight => l10n.lookStraightAhead,
  CaptureGuidance.blink => l10n.blinkSlowly,
  CaptureGuidance.turnLeft => l10n.turnYourHeadSlightlyToTheLeft,
  CaptureGuidance.turnRight => l10n.turnYourHeadSlightlyToTheRight,
};

/// The label drawn inside a cut-out where the camera image will go.
///
/// The prototype sets it in a monospace face to mark it as an annotation rather
/// than copy. This product ships only Rubik, so it is set small and dimmed
/// instead — the same signal with the type we actually have.
class CaptureFrameLabel extends StatelessWidget {
  const CaptureFrameLabel(this.text, {super.key});

  final String text;

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      textAlign: TextAlign.center,
      style: AppText.label.copyWith(
        fontSize: 12,
        fontWeight: FontWeight.w400,
        color: _annotation,
      ),
    );
  }
}
