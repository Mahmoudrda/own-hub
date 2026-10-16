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
import '../../../ui/app_preparation_steps.dart';
import '../../../ui/app_button.dart';
import '../../../ui/app_scaffold.dart';
import '../../../ui/app_step_progress.dart';
import '../../../ui/hand/mascot/kitten.dart';
import '../domain/verification.dart';

class CheckingView extends StatefulWidget {
  const CheckingView({
    super.key,
    required this.repository,
    this.onVerified,
    this.onAwaitingReviewer,
    this.onRetake,
    this.onTryAgain,
    this.onRejected,
    this.onConsentNeeded,
    this.onAskForReviewer,
    this.onAskForReviewerWhileChecking,
    this.onClose,
    this.onSignInAgain,
    this.reassuringSteps = false,
  });

  /// The server did not accept her sign-in: out to sign in again (N4).
  final VoidCallback? onSignInAgain;

  /// The server refused her account for good: `C14`, which says so.
  final VoidCallback? onRejected;

  /// Her agreement is not on file: back to `C09b`.
  final VoidCallback? onConsentNeeded;

  /// She asks for a woman reviewer: when no automatic check is left, when
  /// the check could not finish, and once the check has run longer than
  /// [slowAfter]. The server refuses the last of these while her check is
  /// still running (`verification_in_progress`), so asking early opens
  /// nothing; this screen stays underneath and still routes the verdict.
  final VoidCallback? onAskForReviewer;

  /// The slow-check button's way to the reviewer, so `C15` can say the check
  /// is still running rather than that it could not start. Falls back to
  /// [onAskForReviewer].
  final VoidCallback? onAskForReviewerWhileChecking;

  /// Leaves the "try again tomorrow" stop.
  final VoidCallback? onClose;

  final VerificationRepository repository;

  /// How long she waits before the screen says the check is slow.
  static const Duration slowAfter = Duration(seconds: 20);

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
  /// than leave her waiting on a screen with no control at all. Stranding a
  /// woman on a wait is a worse bug than spending a review call she did not
  /// need.
  final VoidCallback? onRetake;

  /// "Try again" once the check is slow: her choice, not a verdict, so the
  /// router can tell the two apart. Falls back to [onRetake].
  final VoidCallback? onTryAgain;

  /// Tick the steps that are done in turn (D39), rather than drawing them
  /// done at once. The match is never ticked either way.
  final bool reassuringSteps;

  @override
  State<CheckingView> createState() => _CheckingViewState();
}

class _CheckingViewState extends State<CheckingView> {
  StreamSubscription<VerificationState>? _subscription;

  /// A stop told on this screen, or null while the check runs.
  VerificationState? _stop;

  /// Fires once, [CheckingView.slowAfter] into the wait.
  Timer? _slowTimer;

  /// True once the check has run longer than usual.
  bool _slow = false;

  /// The card has been read and the match is under way. Without the ticking
  /// steps there is no reading to wait for, so it starts there.
  late bool _matching = !widget.reassuringSteps;

  /// The verdict is in and it is a yes.
  bool _verified = false;

  @override
  void initState() {
    super.initState();
    _subscription = widget.repository.watch().listen(_onState);
    _slowTimer = Timer(CheckingView.slowAfter, () {
      if (mounted) setState(() => _slow = true);
    });
  }

  @override
  void dispose() {
    _slowTimer?.cancel();
    _subscription?.cancel();
    super.dispose();
  }

  void _onState(VerificationState state) {
    if (!mounted) return;
    switch (state) {
      case VerificationVerified(:final result):
        setState(() => _verified = true);
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
      case VerificationTooSlow():
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
        l10n.thisAccountHasUsedEveryAutomaticCheck_rc3un,
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
      VerificationTooSlow() => (
        l10n.yourConnectionIsTooSlow,
        l10n.weCouldNotFinishTheCheckIn,
        // Her choice, not a verdict, so no decision is recorded (the same
        // button the slow check offers).
        (widget.onTryAgain ?? widget.onRetake) == null
            ? null
            : AppButton(
                l10n.tryAgain,
                onPressed: widget.onTryAgain ?? widget.onRetake,
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
    // No way back out of a running check, by gesture or by button: behind it
    // are the camera screens, and a late verdict must find this screen where
    // it left it. Every stop below has its own way forward.
    return PopScope(canPop: false, child: _body(context));
  }

  Widget _body(BuildContext context) {
    final l10n = AppL10n.of(context);
    final stop = _stop;
    if (stop != null) return _stopped(context, stop);

    return AppScaffold(
      // No lead: there is no stepping back out of a running check. The title
      // is where she is in joining, the same count C09b showed.
      appBar: AppTopBar(title: signupPhaseLabel(l10n, SignupPhase.check)),
      scrollable: false,
      // No Continue. The only way on is the verdict, which the listener above
      // routes. A Continue here used to open "You're in" before anything was
      // decided, so a woman could be told she was verified and then meet the
      // gate one screen later.
      //
      // Once the check is slow she gets two real ways forward, neither of
      // which claims a verdict: a woman reviewer, or taking the photographs
      // again. Asking for the reviewer opens C15 over this screen, so a
      // verdict that still arrives moves her on from here.
      footer: [
        if (_slow &&
            (widget.onAskForReviewerWhileChecking ?? widget.onAskForReviewer) !=
                null)
          AppButton(
            l10n.askForAWomanReviewer,
            key: const ValueKey('checking-ask-reviewer'),
            onPressed:
                widget.onAskForReviewerWhileChecking ?? widget.onAskForReviewer,
          ),
        if (_slow && (widget.onTryAgain ?? widget.onRetake) != null)
          AppButton(
            l10n.tryAgain,
            key: const ValueKey('checking-try-again'),
            variant: AppButtonVariant.outlined,
            onPressed: widget.onTryAgain ?? widget.onRetake,
          ),
      ],
      children: [
        const AppSpacer(),
        Center(
          // A mark that claims no progress. The ring used to stand at a fixed
          // 72% while nothing was measured, which is a number she did not
          // earn. The words underneath carry the detail, and the label is
          // announced for anyone not looking at it.
          child: Semantics(
            label: l10n.checkingYourCard,
            child: Container(
              width: 132,
              height: 132,
              alignment: Alignment.center,
              decoration: const BoxDecoration(
                color: AppColors.primaryContainer,
                shape: BoxShape.circle,
              ),
              // Reading the card, then matching it, then a light cheer when it
              // is done. Only here: every stop below is plain words.
              child: Kitten(
                pose: _verified
                    ? KittenPose.cheer
                    : _matching
                    ? KittenPose.point
                    : KittenPose.think,
                size: 72,
                sessionBudget: true,
              ),
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
        // The first two are true by the time this screen opens: both sides of
        // the card and the selfie were taken on the screens before it. The
        // third is the one the server is working on.
        //
        // D39: the two that are done tick in turn, in sage, over a moment —
        // the work she did is seen being counted — and the match waits in
        // pencil. It never ticks here: only the verdict, routed by the
        // listener above, can say the match is done, and nothing on this
        // screen holds that verdict back.
        if (widget.reassuringSteps)
          AppPreparationSteps(
            key: const ValueKey('checking-steps'),
            labels: [
              l10n.bothSidesOfYourCardTaken,
              l10n.selfieTaken,
              l10n.matchingYourSelfieToYourCard,
            ],
            completed: 2,
            onShown: () {
              if (mounted && !_matching) setState(() => _matching = true);
            },
          )
        else ...const [
          _Step(
            icon: Icons.check_circle,
            done: true,
            labelKey: _StepLabel.cardTaken,
          ),
          _Step(
            icon: Icons.check_circle,
            done: true,
            labelKey: _StepLabel.selfieTaken,
          ),
          _Step(
            icon: Icons.autorenew,
            done: false,
            labelKey: _StepLabel.matching,
          ),
        ],
        const AppSpacer(),
        if (_slow)
          Semantics(
            liveRegion: true,
            child: Text(
              l10n.takingLongerThanUsualYourConnectionMay,
              key: const ValueKey('checking-slow'),
              style: AppText.bodyM.copyWith(color: AppColors.onSurface),
            ),
          ),
        Text(
          l10n.theMatchUsuallyTakesUnderAMinute,
          style: AppText.bodyM.copyWith(color: AppColors.onSurfaceVariant),
        ),
      ],
    );
  }
}

/// Which line a step shows. An enum rather than a string so the three steps
/// cannot be given copy that is not in the dictionary.
enum _StepLabel { cardTaken, selfieTaken, matching }

class _Step extends StatelessWidget {
  const _Step({required this.icon, required this.done, required this.labelKey});

  final IconData icon;
  final bool done;
  final _StepLabel labelKey;

  @override
  Widget build(BuildContext context) {
    final l10n = AppL10n.of(context);
    final label = switch (labelKey) {
      _StepLabel.cardTaken => l10n.bothSidesOfYourCardTaken,
      _StepLabel.selfieTaken => l10n.selfieTaken,
      _StepLabel.matching => l10n.matchingYourSelfieToYourCard,
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
