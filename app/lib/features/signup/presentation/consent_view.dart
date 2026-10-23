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
/// **What is recorded is a uid, a version, a timestamp, the language and the
/// app version.** Not the text, not a device fingerprint, not an IP address.
/// See `domain/capture_consent.dart` for why the version is the field that
/// makes the record worth anything. The wording is version 2 (privacy policy
/// v3): Frankfurt and the EU Vision endpoint, a face match on our own server,
/// the 180-day result and the keyed ID code, and a woman from Own Hub as the
/// fallback. The privacy policy is one tap away under the list.
///
/// **On the first run it is also the promise.** With [showPromise] the screen
/// opens with `C09`'s title and three plain lines (what is read, what is
/// matched, how long it takes), then the disclosure exactly as before, every
/// bullet visible. One screen instead of two, and the promise is not part of
/// the wording she agrees to. The niqab path leaves from
/// here too ([onNiqabPath]). `C09` stays as the screen the gate sends a
/// returning woman to.
///
/// **Declining is a real option and not a dead end.** "I would rather not" goes
/// to `C15`, the woman-reviewer path, which needs no camera and no processor
/// outside Egypt. A consent screen whose only button is "agree" is not consent.
library;

import 'dart:async';

import 'package:flutter/material.dart';

import '../../../l10n/app_l10n.dart';
import '../../../theme/app_tokens.dart';
import '../../../ui/app_button.dart';
import '../../../ui/app_card.dart';
import '../../../ui/app_scaffold.dart';
import '../domain/capture_consent.dart';
import '../domain/legal_acceptance.dart';
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
    this.onSignInAgain,
    this.showPromise = false,
    this.onNiqabPath,
    this.title,
    this.onOpenPrivacy,
  });

  /// Opens the privacy policy in her language. Null while it has no address.
  final VoidCallback? onOpenPrivacy;

  /// True on the first run through sign-up. The screen shows its own title
  /// and the disclosure either way; `C09`'s promise is not repeated here.
  final bool showPromise;

  /// "I wear niqab, check me another way": `C15`, no selfie on that route.
  final VoidCallback? onNiqabPath;

  /// The bar title: "3 of 3 · Quick check" on the way through sign-up.
  final String? title;

  /// The server did not accept her sign-in: out to sign in again (N4).
  final VoidCallback? onSignInAgain;

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

  /// What the last failure was, read from the server's answer.
  CallFailureKind? _failure;

  /// True once the whole disclosure has been scrolled into view (or it fits
  /// without scrolling). The agree button stays inert until then, so she
  /// cannot agree to a sentence she has not been shown.
  bool _readToEnd = false;

  bool _onScroll(Notification n) {
    final ScrollMetrics? metrics = switch (n) {
      ScrollNotification() when n.depth == 0 => n.metrics,
      ScrollMetricsNotification() when n.depth == 0 => n.metrics,
      _ => null,
    };
    if (metrics == null || metrics.axis != Axis.vertical) return false;
    final atEnd = metrics.extentAfter <= 24;
    if (atEnd && !_readToEnd) {
      // Notifications can fire during layout; defer the rebuild.
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) setState(() => _readToEnd = true);
      });
    }
    return false;
  }

  final GlobalKey _agreeKey = GlobalKey();
  final FocusNode _agreeFocus = FocusNode();

  @override
  void dispose() {
    _agreeFocus.dispose();
    super.dispose();
  }

  /// The ID card route is continued by the agree button, so tapping its card
  /// brings that button into view and focuses it. It never agrees.
  void _showAgreeButton() {
    final target = _agreeKey.currentContext;
    if (target != null) {
      unawaited(Scrollable.ensureVisible(target));
    }
    _agreeFocus.requestFocus();
  }

  Future<void> _agree() async {
    if (_recording) return;
    setState(() {
      _recording = true;
      _failed = false;
    });
    final clock = widget.now ?? DateTime.now;
    final locale = Localizations.localeOf(context).languageCode;
    try {
      await widget.store.record(
        CaptureConsent(
          uid: widget.uid,
          version: kCaptureConsentVersion,
          agreedAt: clock(),
          locale: locale == 'ar' ? 'ar' : 'en',
          appVersion: kAppVersion,
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
          // App Check refused this copy of the app (R3), or the server did
          // not accept her sign-in (N4): a retry cannot fix either, so she is
          // told what can.
          _failure = classifyCallFailure(error);
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

    final canAgree = _readToEnd && !_recording;
    return NotificationListener<Notification>(
      onNotification: _onScroll,
      child: AppScaffold(
        appBar: AppTopBar(title: widget.title ?? '', onBack: widget.onBack),
        footerScrollsWhenLarge: true,
        footer: [
          if (_failed)
            Semantics(
              liveRegion: true,
              child: Text(
                switch (_failure) {
                  CallFailureKind.appCannotReach =>
                    l10n.thisCopyOfTheAppCannotReach_1dlg6,
                  CallFailureKind.signInAgain =>
                    l10n.yourSignInIsNoLongerValid_1cfl5,
                  _ => l10n.weCouldNotSaveYourAgreementSo,
                },
                key: const ValueKey('consent-error'),
                style: AppText.bodyM.copyWith(color: AppColors.error),
              ),
            ),
          if (_failed &&
              _failure == CallFailureKind.signInAgain &&
              widget.onSignInAgain != null)
            AppButton(
              l10n.signInAgain,
              variant: AppButtonVariant.outlined,
              onPressed: widget.onSignInAgain,
            ),
          if (!_readToEnd)
            Text(
              l10n.readToTheEndToAgree,
              key: const ValueKey('consent-read-hint'),
              textAlign: TextAlign.center,
              style: AppText.bodyM.copyWith(color: AppColors.onSurfaceVariant),
            ),
          Focus(
            key: _agreeKey,
            focusNode: _agreeFocus,
            child: AppButton(
              l10n.iAgreeStartTheCamera,
              icon: Icons.photo_camera,
              onPressed: canAgree ? _agree : null,
            ),
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
          // Two routes of equal weight. The camera route is continued by the
          // agree button below, after the disclosure; the other leaves for
          // `C15` at once.
          Text(l10n.howWouldYouLikeToBeChecked, style: AppText.titleM),
          IntrinsicHeight(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              spacing: 12,
              children: [
                Expanded(
                  child: _RouteCard(
                    key: const ValueKey('c09b-route-id'),
                    icon: Icons.badge_outlined,
                    title: l10n.idCardAndASelfie,
                    subtitle: l10n.aboutMinutesMinutes('2'),
                    onTap: _showAgreeButton,
                  ),
                ),
                Expanded(
                  child: _RouteCard(
                    key: const ValueKey('c09b-route-woman'),
                    icon: Icons.support_agent,
                    title: l10n.talkToAWomanReviewer,
                    subtitle: l10n.aShortCall,
                    onTap: widget.onDeclined,
                  ),
                ),
              ],
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            spacing: 14,
            children: [
              // Named, not implied. "Processed securely" is what a privacy page
              // says when it does not want to say Frankfurt. Google Cloud alone:
              // a consent screen naming a processor we do not use is consent to
              // something that is not happening.
              VerificationBullet(
                icon: Icons.cloud_outlined,
                text: l10n.yourPhotosGoToOurServerIn,
              ),
              // The face match runs on our own server with open models. No
              // outside face recognition service is called.
              VerificationBullet(
                icon: Icons.face_retouching_natural,
                text: l10n.yourFaceIsMatchedOnOurOwn,
              ),
              // Nothing is kept, for anybody, ever: the photographs are deleted
              // outright whatever the outcome.
              VerificationBullet(
                icon: Icons.delete_outline,
                text: l10n.noPhotoIsEverStoredBothSides,
              ),
              // What IS kept, and for how long: the result for 180 days, and
              // the keyed code that stops one card opening two accounts.
              VerificationBullet(
                icon: Icons.lock_outline,
                text: l10n.weKeepTheResultAndItsReasons,
              ),
              // Which is why review is a person and not a queue of photographs.
              VerificationBullet(
                icon: Icons.support_agent,
                text: l10n.ifTheCheckCannotDecideYouCan,
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
          if (widget.onOpenPrivacy != null)
            AppButton(
              l10n.readThePrivacyPolicy,
              variant: AppButtonVariant.text,
              height: 44,
              fontSize: 15,
              onPressed: widget.onOpenPrivacy,
            ),
          if (widget.onNiqabPath != null)
            AppButton(
              l10n.iWearNiqabCheckMeAnotherWay,
              variant: AppButtonVariant.text,
              height: 48,
              fontSize: 15,
              onPressed: widget.onNiqabPath,
            ),
        ],
      ),
    );
  }
}

class _RouteCard extends StatelessWidget {
  const _RouteCard({
    super.key,
    required this.icon,
    required this.title,
    required this.subtitle,
    this.onTap,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return AppCard(
      onTap: onTap,
      children: [
        Icon(icon, size: 26, color: AppColors.primaryDim),
        Text(title, style: AppText.titleM),
        Text(
          subtitle,
          style: AppText.bodyM.copyWith(color: AppColors.onSurfaceVariant),
        ),
      ],
    );
  }
}
