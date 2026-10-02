/// C12 — Checking your card.
///
/// Matches `6-v2/src/screens-signup.mjs` → `C12`. Progress is named step by
/// step so that a slow network reads as slow rather than as a refusal, and the
/// fallback to a woman reviewer is promised *before* it is needed.
///
/// There is no back arrow: the check is running at the provider and stepping
/// backwards out of it would abandon a session she has already paid for in time.
///
/// **Every outcome except "verified" is still not a rejection.** A provider that
/// cannot decide, a provider that times out, and a check that fails all land on
/// a woman reviewer — `DECISIONS.md` D8: she is told we are reviewing her
/// application to keep this community safe and private. This view routes those
/// states and never accuses.
///
/// Three states are told on this screen rather than routed, because each is
/// a stop and none is a review: a daily limit ("try again tomorrow"), an
/// account that has used every automatic check, and a call that failed while
/// asking for a reviewer failed too ("we could not reach Own Hub, nothing was
/// decided"). A refusal goes to `C14`, which says so plainly; a missing
/// agreement goes back to `C09b`.
library;

import 'dart:async';

import 'package:flutter/material.dart';

import '../../../l10n/app_l10n.dart';
import '../../../theme/app_tokens.dart';
import '../../../ui/app_button.dart';
import '../../../ui/app_ring_stat.dart';
import '../../../ui/app_scaffold.dart';
import '../domain/verification.dart';

class CheckingView extends StatefulWidget {
  const CheckingView({
    super.key,
    required this.repository,
    this.fraction = 0.72,
    this.onVerified,
    this.onAwaitingReviewer,
    this.onRetake,
    this.onContinue,
    this.onRejected,
    this.onConsentNeeded,
    this.onAskForReviewer,
    this.onClose,
    this.onSignInAgain,
  });

  /// The server did not accept her sign-in: out to sign in again (N4).
  final VoidCallback? onSignInAgain;

  /// The server refused her account for good: `C14`, which says so.
  final VoidCallback? onRejected;

  /// Her agreement is not on file: back to `C09b`.
  final VoidCallback? onConsentNeeded;

  /// No automatic checks left, and she chose a woman reviewer.
  final VoidCallback? onAskForReviewer;

  /// Leaves the "try again tomorrow" stop.
  final VoidCallback? onClose;

  final VerificationRepository repository;

  /// How far round the ring has gone. 72% is the prototype's value.
  final double fraction;

  /// The check passed — on to `C13`, carrying the result.
  ///
  /// It carries the [VerificationResult] because C13 states how long the check
  /// took. A callback that dropped the result left that screen with nothing to
  /// state but the prototype's 74 seconds, which it then told her as fact.
  final ValueChanged<VerificationResult>? onVerified;

  /// A woman reviewer has it now — on to `C14`. Reached from *both*
  /// [VerificationAwaitingReviewer] and [VerificationNeedsAnotherLook], because
  /// neither is a rejection and both end in the same place.
  final VoidCallback? onAwaitingReviewer;

  /// The photographs need taking again — back to `C10`.
  ///
  /// Falls back to [onAwaitingReviewer] when it is null, which is deliberate
  /// and not laziness: an unwired build must send her to the video call rather
  /// than leave her on a screen whose only other control goes forward to
  /// "You're in". Stranding a woman on a spinner is a worse bug than spending a
  /// review call she did not need.
  final VoidCallback? onRetake;

  /// The prototype's footer button. In the running product the transition is
  /// the listener above, not a tap; this stays because the design has it and
  /// because a woman staring at a stalled check needs something to press.
  final VoidCallback? onContinue;

  @override
  State<CheckingView> createState() => _CheckingViewState();
}

class _CheckingViewState extends State<CheckingView> {
  StreamSubscription<VerificationState>? _subscription;

  /// A stop told on this screen, or null while the check runs.
  VerificationState? _stop;

  @override
  void initState() {
    super.initState();
    _subscription = widget.repository.watch().listen(_onState);
  }

  @override
  void dispose() {
    _subscription?.cancel();
    super.dispose();
  }

  void _onState(VerificationState state) {
    if (!mounted) return;
    switch (state) {
      case VerificationVerified(:final result):
        widget.onVerified?.call(result);
      case VerificationAwaitingReviewer():
      case VerificationNeedsAnotherLook():
        widget.onAwaitingReviewer?.call();
      case VerificationRetakeNeeded():
        // Her move, not a reviewer's. See the note on `onRetake`: with nothing
        // wired up she goes to the video call rather than nowhere at all.
        (widget.onRetake ?? widget.onAwaitingReviewer)?.call();
      case VerificationRejected():
        (widget.onRejected ?? widget.onAwaitingReviewer)?.call();
      case VerificationConsentNeeded():
        widget.onConsentNeeded?.call();
      case VerificationTryTomorrow():
      case VerificationChecksUsedUp():
      case VerificationUnreachable():
      case VerificationAppCannotReach():
      case VerificationSignInAgain():
        setState(() => _stop = state);
      case VerificationReviewOffered():
        // On to C15 with the "could not finish" wording, once. Coming back
        // from it lands on the same offer here, not on another push.
        final first = _stop is! VerificationReviewOffered;
        setState(() => _stop = state);
        if (first) widget.onAskForReviewer?.call();
      case VerificationNotStarted():
      case VerificationChecking():
        if (_stop != null) setState(() => _stop = null);
    }
  }

  Widget _stopped(BuildContext context, VerificationState stop) {
    final l10n = AppL10n.of(context);
    final (String title, String body, Widget? action) = switch (stop) {
      VerificationTryTomorrow() => (
        l10n.tryAgainTomorrow,
        l10n.todaysLimitForIdentityChecksHasBeen,
        widget.onClose == null
            ? null
            : AppButton(l10n.close, onPressed: widget.onClose),
      ),
      VerificationChecksUsedUp() => (
        l10n.noAutomaticChecksLeft,
        l10n.thisAccountHasUsedEveryAutomaticCheck,
        widget.onAskForReviewer == null
            ? null
            : AppButton(
                l10n.askForAWomanReviewer,
                onPressed: widget.onAskForReviewer,
              ),
      ),
      VerificationReviewOffered() => (
        l10n.theCheckDidNotFinish,
        l10n.theAutomaticCheckCouldNotStartJust_1od6p,
        widget.onAskForReviewer == null
            ? null
            : AppButton(
                l10n.askForAWomanReviewer,
                onPressed: widget.onAskForReviewer,
              ),
      ),
      VerificationAppCannotReach() => (
        l10n.thisCopyOfTheAppCannotReach,
        l10n.pleaseInstallTheLatestVersionFromThe,
        widget.onClose == null
            ? null
            : AppButton(l10n.close, onPressed: widget.onClose),
      ),
      VerificationSignInAgain() => (
        l10n.pleaseSignInAgain,
        l10n.yourSignInIsNoLongerValid,
        widget.onSignInAgain == null
            ? null
            : AppButton(l10n.signInAgain, onPressed: widget.onSignInAgain),
      ),
      _ => (
        l10n.weCouldNotReachOwnHub,
        l10n.nothingWasDecidedAndYouAreNot,
        widget.onRetake == null
            ? null
            : AppButton(l10n.tryAgain, onPressed: widget.onRetake),
      ),
    };
    // The offer's other way forward. This screen has no back control, so
    // "try again" is a button here, not a direction to go back.
    final tryAgain =
        stop is VerificationReviewOffered && widget.onRetake != null
        ? AppButton(
            l10n.tryAgain,
            variant: AppButtonVariant.outlined,
            onPressed: widget.onRetake,
          )
        : null;
    return AppScaffold(
      appBar: const AppTopBar(),
      footer: [?action, ?tryAgain],
      children: [
        Semantics(
          liveRegion: true,
          child: Text(title, style: AppText.headline),
        ),
        Text(
          body,
          style: AppText.bodyM.copyWith(color: AppColors.onSurfaceVariant),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppL10n.of(context);
    final stop = _stop;
    if (stop != null) return _stopped(context, stop);

    return AppScaffold(
      // No lead: there is no stepping back out of a running check.
      appBar: const AppTopBar(),
      scrollable: false,
      footer: [AppButton(l10n.continueLabel, onPressed: widget.onContinue)],
      children: [
        const AppSpacer(),
        Center(
          // A ring with nothing in it: on this screen the progress *is* the
          // message and the words underneath carry the detail, so `big` and
          // `small` are empty exactly as the prototype has them. The label is
          // announced instead, because a wordless ring is invisible to anyone
          // not looking at it.
          child: Semantics(
            label: l10n.checkingYourCard,
            child: AppRingStat(
              fraction: widget.fraction,
              big: '',
              small: '',
              size: 132,
              thickness: 12,
              color: AppColors.primary,
            ),
          ),
        ),
        Text(
          l10n.checkingYourCard,
          textAlign: TextAlign.center,
          // 24 is the prototype's value and is NOT a token — `headline` is 26
          // and `titleL` is 20. Recorded rather than silently rounded.
          style: AppText.headline.copyWith(
            fontSize: 24,
            color: AppColors.onPrimaryContainer,
          ),
        ),
        const _Step(
          icon: Icons.check_circle,
          done: true,
          labelKey: _StepLabel.cardRead,
        ),
        const _Step(
          icon: Icons.check_circle,
          done: true,
          labelKey: _StepLabel.selfieMatched,
        ),
        const _Step(
          icon: Icons.autorenew,
          done: false,
          labelKey: _StepLabel.finalCheck,
        ),
        const AppSpacer(),
        Text(
          l10n.usuallySecondsIfItNeedsAPerson,
          style: AppText.bodyM.copyWith(color: AppColors.onSurfaceVariant),
        ),
      ],
    );
  }
}

/// Which line a step shows. An enum rather than a string so the three steps
/// cannot be given copy that is not in the dictionary.
enum _StepLabel { cardRead, selfieMatched, finalCheck }

class _Step extends StatelessWidget {
  const _Step({required this.icon, required this.done, required this.labelKey});

  final IconData icon;
  final bool done;
  final _StepLabel labelKey;

  @override
  Widget build(BuildContext context) {
    final l10n = AppL10n.of(context);
    final label = switch (labelKey) {
      _StepLabel.cardRead => l10n.cardRead,
      _StepLabel.selfieMatched => l10n.selfieMatchedToTheCard,
      _StepLabel.finalCheck => l10n.finalCheck,
    };

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(
          icon,
          size: 22,
          color: done ? AppColors.tertiary : AppColors.onSurfaceVariant,
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Text(
            label,
            style: AppText.bodyM.copyWith(
              color: done ? AppColors.onSurface : AppColors.onSurfaceVariant,
            ),
          ),
        ),
      ],
    );
  }
}
