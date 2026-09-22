/// The dark chrome shared by `C10` (the ID card) and `C11` (the selfie).
///
/// Both screens are a viewfinder: `inverseSurface` behind a white close bar, a
/// cut-out the subject is framed in, two lines of guidance, and one white
/// button. The two differ only in the shape of the cut-out and the words, so the
/// shape lives here once.
///
/// **The cut-out is a placeholder, not a camera.** Until the provider's SDK is a
/// dependency there is no live preview to draw, so the frame shows the
/// prototype's own annotation — "front of the card", "her face, live" — which is
/// what the design draws too. It never imitates a live image, and the shutter is
/// disabled unless a real [CaptureSession] reports it is framing. See
/// `domain/id_capture.dart`.
library;

import '../../../../ui/screen_art_strip.dart';

import 'package:flutter/material.dart';

import '../../../../theme/app_tokens.dart';
import '../../../../ui/app_white_button.dart';

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
    this.onAction,
    this.onClose,
  });

  /// Shown in the bar, in white.
  final String title;

  /// The cut-out: a card rectangle on `C10`, an oval on `C11`.
  final Widget frame;

  /// The instruction, 17 and semibold.
  final String headline;

  /// The reassurance underneath, 15/22.
  final String body;

  final String actionLabel;

  /// Null disables the shutter — which is the honest state whenever there is no
  /// camera behind it.
  final VoidCallback? onAction;

  final VoidCallback? onClose;

  @override
  Widget build(BuildContext context) {
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
                    frame,
                    const SizedBox(height: 18),
                    Text(
                      headline,
                      textAlign: TextAlign.center,
                      style: AppText.titleM.copyWith(color: _onDark),
                    ),
                    const SizedBox(height: 18),
                    ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 300),
                      child: Text(
                        body,
                        textAlign: TextAlign.center,
                        style: AppText.bodyM.copyWith(
                          height: 22 / 15,
                          color: _onDarkVariant,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 14),
              child: AppWhiteButton(
                actionLabel,
                height: 52,
                fontSize: 15,
                onPressed: onAction,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

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
