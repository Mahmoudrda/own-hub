/// C15 — Checked by a woman, no photo kept.
///
/// Matches `6-v2/src/screens-signup.mjs` → `C15`.
///
/// **The niqab path is first class.** It is designed, not improvised: a live
/// check with a woman reviewer, or an in-person check at a ladies-only gym, with
/// the ID card doing exactly the same work it does on the automatic path. A
/// woman reaches this screen straight from `C09` and leaves it for `C14` — and
/// **no route through `C09`→`C15`→`C14` opens a camera or asks for a selfie**.
/// Nothing in this file imports the capture layer, which is what makes that
/// structural rather than a promise.
///
/// The button calls `request_review` with the path she came by (niqab,
/// declined camera, or after an error). She moves on to `C14` only once the
/// server has answered: if the call fails she is told plainly that she is not
/// in the queue yet, and the button stays live as a retry. Nothing here ever
/// claims a place in a queue the server did not confirm.
///
/// There is one option, the video check. The partner-gym card is gone: no
/// partner gyms exist, and a screen offering them would be a promise nobody
/// keeps. A woman reviewer phones her to arrange the call; no text message is
/// sent, because nothing exists that could send one.
library;

import 'package:flutter/material.dart';

import '../../../l10n/app_l10n.dart';
import '../../../theme/app_tokens.dart';
import '../../../ui/app_button.dart';
import '../../../ui/app_card.dart';
import '../../../ui/app_scaffold.dart';
import '../domain/review_request.dart';

/// Which no-selfie check she chose. Only the video check is offered; the
/// value travels to the router, which records it.
enum ReviewerPath { video, gym }

class WomanReviewerView extends StatefulWidget {
  const WomanReviewerView({
    super.key,
    required this.requester,
    this.path = ReviewPath.niqab,
    this.onBooked,
    this.onAlreadyVerified,
    this.onRejected,
    this.onBack,
    this.onSignInAgain,
  });

  /// The server did not accept her sign-in: out to sign in again (N4).
  final VoidCallback? onSignInAgain;

  /// `request_review`.
  final ReviewRequester requester;

  /// Why she is here. Sent to the server, which records it on the flag.
  final ReviewPath path;

  /// Fired only after the server confirmed she is queued: on to `C14`.
  final ValueChanged<ReviewerPath>? onBooked;

  /// The server says she is already verified.
  final VoidCallback? onAlreadyVerified;

  /// The server says her account was refused for good.
  final VoidCallback? onRejected;

  final VoidCallback? onBack;

  @override
  State<WomanReviewerView> createState() => _WomanReviewerViewState();
}

/// What went wrong with the last tap, if anything.
enum _Failure { none, unreachable, tooManyToday, appCannotReach, signInAgain }

class _WomanReviewerViewState extends State<WomanReviewerView> {
  bool _booking = false;
  _Failure _failure = _Failure.none;

  Future<void> _book() async {
    if (_booking) return;
    setState(() {
      _booking = true;
      _failure = _Failure.none;
    });
    try {
      final answer = await widget.requester.request(widget.path);
      if (!mounted) return;
      switch (answer) {
        case ReviewRequestState.pending:
          widget.onBooked?.call(ReviewerPath.video);
        case ReviewRequestState.approved:
          widget.onAlreadyVerified?.call();
      }
    } catch (error) {
      if (!mounted) return;
      switch (classifyCallFailure(error)) {
        case CallFailureKind.closed:
          widget.onRejected?.call();
        case CallFailureKind.reviewOpen:
          widget.onBooked?.call(ReviewerPath.video);
        case CallFailureKind.tryTomorrow:
          setState(() => _failure = _Failure.tooManyToday);
        case CallFailureKind.appCannotReach:
          setState(() => _failure = _Failure.appCannotReach);
        case CallFailureKind.signInAgain:
          setState(() => _failure = _Failure.signInAgain);
        default:
          // Never onBooked: she is not in the queue, and she is told so.
          setState(() => _failure = _Failure.unreachable);
      }
    } finally {
      if (mounted) setState(() => _booking = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppL10n.of(context);

    return AppScaffold(
      appBar: AppTopBar(onBack: widget.onBack),
      footer: [
        AppButton(l10n.askForAVideoCheck, onPressed: _booking ? null : _book),
      ],
      children: [
        Text(l10n.checkedByAWomanNoPhotoKept, style: AppText.headline),
        if (widget.path == ReviewPath.error)
          Text(
            l10n.theAutomaticCheckCouldNotStartJust,
            style: AppText.bodyM.copyWith(color: AppColors.onSurfaceVariant),
          ),
        Text(
          l10n.ifYouDoNotShowYourFace,
          style: AppText.bodyM.copyWith(color: AppColors.onSurfaceVariant),
        ),
        // Shown before `request_review`, which records her agreement to the
        // review route on the server (users/{uid}/consents/review-v1, written
        // before the flag): who calls, how, and what her number is used for.
        // This sentence and the one above are that consent's wording. PENDING COUNSEL: this wording is part of the consent
        // mechanism the PDPC must approve, and needs a lawyer's sign-off.
        Text(
          l10n.yourPhoneNumberIsUsedOnlyTo,
          style: AppText.bodyM.copyWith(color: AppColors.onSurfaceVariant),
        ),
        _PathCard(
          icon: Icons.videocam,
          title: l10n.aShortVideoCheck,
          body: l10n.twoMinutesWithAWomanReviewerNothing,
          selected: true,
          onTap: () {},
        ),
        // `sageNote()`: only women review these checks.
        AppCard(
          variant: AppCardVariant.sage,
          borderRadius: AppRadius.md,
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          children: [
            Text(
              l10n.onlyWomenReviewTheseChecksNoMan,
              style: AppText.body.copyWith(
                color: AppColors.onTertiaryContainer,
              ),
            ),
          ],
        ),
        if (_failure != _Failure.none)
          Semantics(
            liveRegion: true,
            child: Text(switch (_failure) {
              _Failure.tooManyToday => l10n.youHaveAskedForAReviewerToo,
              _Failure.appCannotReach => l10n.thisCopyOfTheAppCannotReach_agbhf,
              _Failure.signInAgain => l10n.yourSignInIsNoLongerValid_1y16r,
              _ => l10n.weCouldNotReachOwnHubSo_3usbb,
            }, style: AppText.bodyM.copyWith(color: AppColors.error)),
          ),
        if (_failure == _Failure.signInAgain && widget.onSignInAgain != null)
          AppButton(
            l10n.signInAgain,
            variant: AppButtonVariant.outlined,
            onPressed: widget.onSignInAgain,
          ),
      ],
    );
  }
}

class _PathCard extends StatelessWidget {
  const _PathCard({
    required this.icon,
    required this.title,
    required this.body,
    required this.selected,
    required this.onTap,
  });

  final IconData icon;
  final String title;
  final String body;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return AppCard(
      variant: selected ? AppCardVariant.selected : AppCardVariant.outlined,
      onTap: onTap,
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon, size: 26, color: AppColors.primaryDim),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: AppText.titleM),
                  const SizedBox(height: 3),
                  Text(
                    body,
                    style: AppText.bodyM.copyWith(
                      color: AppColors.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ),
            if (selected) ...[
              const SizedBox(width: 12),
              const Icon(
                Icons.check_circle,
                size: 24,
                color: AppColors.primary,
              ),
            ],
          ],
        ),
      ],
    );
  }
}
