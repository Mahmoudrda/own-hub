/// C09b — Before the camera opens.
///
/// The screen between "one check, then you are in" (`C09`) and the first lens
/// opening (`C10`). `C09` is the promise: what is read, what is matched, what is
/// deleted. This is the disclosure: **where her face and her national ID
/// actually go, and how long anything survives.**
///
/// The two are separate screens on purpose. `C09` is written to be read, and it
/// works because it is short. Bolting four sentences about Google Cloud, Amazon
/// Web Services and a keyed hash onto the end of it would either lengthen the
/// screen past the point where anyone reads any of it, or bury the disclosure at
/// the bottom of a screen whose button is at the top of the fold. A separate
/// step costs her one tap and is the difference between telling her and being
/// able to say we told her.
///
/// **Nothing opens a camera until this has been agreed to.** That is the whole
/// job. She taps an affirmative button with the text in front of her, a record
/// of which version she agreed to is written down, and only then does `C10`
/// become reachable.
///
/// **What is recorded is a uid, a version and a timestamp.** Not the text, not a
/// device fingerprint, not an IP address. See `domain/capture_consent.dart` for
/// why the version is the field that makes the record worth anything.
///
/// **Declining is a real option and not a dead end.** "I would rather not" goes
/// to `C15`, the woman-reviewer path, which needs no camera and no processor
/// outside Egypt. A consent screen whose only button is "agree" is not consent.
library;

import 'package:flutter/material.dart';

import '../../../l10n/app_l10n.dart';
import '../../../theme/app_tokens.dart';
import '../../../ui/app_button.dart';
import '../../../ui/app_card.dart';
import '../../../ui/app_scaffold.dart';
import '../domain/capture_consent.dart';
import '../domain/review_request.dart';
import 'widgets/verification_bullet.dart';

class ConsentView extends StatefulWidget {
  const ConsentView({
    super.key,
    required this.uid,
    required this.store,
    this.onAgreed,
    this.onDeclined,
    this.onBack,
    this.now,
  });

  /// Whose consent this is. The record is meaningless without it, so it is
  /// required rather than nullable: a screen that could write a consent record
  /// with no uid would be writing a record about nobody.
  final String uid;

  final CaptureConsentStore store;

  /// On to `C10`, and only ever after [CaptureConsentStore.record] has
  /// returned. If the write fails she does not advance, because a camera
  /// opening on an unrecorded consent is the exact thing this screen exists to
  /// prevent.
  final VoidCallback? onAgreed;

  /// To `C15`. No camera, no processor outside Egypt, a woman reviewer instead.
  final VoidCallback? onDeclined;

  final VoidCallback? onBack;

  /// Injectable so a test can assert the recorded timestamp.
  final DateTime Function()? now;

  @override
  State<ConsentView> createState() => _ConsentViewState();
}

class _ConsentViewState extends State<ConsentView> {
  /// True while the record is being written. It disables the button, because a
  /// double tap on a slow connection would otherwise write the agreement twice
  /// and push `C10` twice.
  bool _recording = false;

  /// True after a write failed. She is told plainly that nothing was saved
  /// and the camera did not open, instead of a button that silently does
  /// nothing, which reads as a broken app and teaches her to give up here.
  bool _failed = false;

  /// True when the failure was this copy of the app being refused.
  bool _appCannotReach = false;

  Future<void> _agree() async {
    if (_recording) return;
    setState(() {
      _recording = true;
      _failed = false;
    });
    final clock = widget.now ?? DateTime.now;
    try {
      await widget.store.record(
        CaptureConsent(
          uid: widget.uid,
          version: kCaptureConsentVersion,
          agreedAt: clock(),
        ),
      );
    } catch (error) {
      // The write failed, so nothing was recorded, so nothing may open. She
      // stays on this screen with the button live again and can try once more.
      // Advancing anyway would mean photographing a woman's ID card with no
      // record that she ever agreed to it.
      if (mounted) {
        setState(() {
          _recording = false;
          _failed = true;
          // App Check refused this copy of the app (R3): a retry cannot fix
          // that, an update can, so she is told which.
          _appCannotReach =
              classifyCallFailure(error) == CallFailureKind.appCannotReach;
        });
      }
      return;
    }
    if (!mounted) return;
    widget.onAgreed?.call();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppL10n.of(context);

    return AppScaffold(
      appBar: AppTopBar(onBack: widget.onBack),
      footer: [
        if (_failed)
          Semantics(
            liveRegion: true,
            child: Text(
              _appCannotReach
                  ? l10n.thisCopyOfTheAppCannotReach_1dlg6
                  : l10n.weCouldNotSaveYourAgreementSo,
              key: const ValueKey('consent-error'),
              style: AppText.bodyM.copyWith(color: AppColors.error),
            ),
          ),
        AppButton(
          l10n.iAgreeStartTheCamera,
          icon: Icons.photo_camera,
          onPressed: _recording ? null : _agree,
        ),
        AppButton(
          l10n.iWouldRatherNot,
          variant: AppButtonVariant.text,
          height: 48,
          fontSize: 15,
          onPressed: widget.onDeclined,
        ),
      ],
      children: [
        Text(l10n.beforeTheCameraOpens, style: AppText.display),
        Text(
          l10n.youWillPhotographTheFrontAndBack,
          style: AppText.bodyM.copyWith(color: AppColors.onSurfaceVariant),
        ),
        AppCard(
          variant: AppCardVariant.sage,
          children: [
            // Named, not implied. "Processed securely" is what a privacy page
            // says when it does not want to say Frankfurt.
            //
            // Google Cloud alone. An earlier draft also named Amazon Web
            // Services, for a liveness service the owner has since ruled out
            // for good. A consent screen naming a processor we do not use is
            // not a harmless leftover: it is consent to something that is not
            // happening, and it would have to be withdrawn and re-taken.
            VerificationBullet(
              icon: Icons.cloud_outlined,
              text: l10n.thePhotographsAreProcessedByGoogleCloud_tqchn,
            ),
            // The keyed hash is the part worth understanding: it is what we
            // keep instead of her ID number, and it cannot be turned back into
            // one. It is also what stops the same card being used twice.
            VerificationBullet(
              icon: Icons.lock_outline,
              text: l10n.ifYourCheckIsApprovedOrRefused,
            ),
            // Nothing is kept, for anybody, ever. There is no retention
            // window and no encrypted bundle sitting somewhere for 72 hours:
            // the photographs are deleted outright whatever the outcome.
            VerificationBullet(
              icon: Icons.delete_outline,
              text: l10n.nothingYouPhotographIsKeptBothSides,
            ),
            // Which is why review is a conversation and not a queue. No woman
            // reviewer is ever sent a photograph of her, because there is no
            // photograph of her to send.
            VerificationBullet(
              icon: Icons.videocam_outlined,
              text: l10n.ifAWomanNeedsToCheckIt,
            ),
            // Said out loud because it is a restriction people expect to be a
            // bug. She cannot upload an old picture, and neither can anybody
            // holding a picture of her.
            VerificationBullet(
              icon: Icons.photo_camera_outlined,
              text: l10n.theCameraIsTheOnlyWayIn,
            ),
          ],
        ),
      ],
    );
  }
}
