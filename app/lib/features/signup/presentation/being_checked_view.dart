/// C14 — Being checked.
///
/// Matches `6-v2/src/screens-signup.mjs` → `C14`.
///
/// **This screen is not a rejection and must never read as one.** A check that
/// needs a person, a check that did not pass, and a call that never completed
/// all arrive here. `DECISIONS.md` D8 fixes the substance: we are reviewing your
/// application to make sure this community stays safe and private. Nothing here
/// accuses her and nothing dead-ends.
///
/// The card is **amber, not error**. Amber is the product's "a caution that is
/// not a failure"; red is reserved for genuine problems and medical guidance.
/// Using the error variant here would turn waiting into an accusation with one
/// word of code.
///
/// ## Two owner decisions rewrote this screen
///
/// **Nothing of hers is in a queue being looked at.** The photographs are
/// deleted outright when the check finishes, whatever the outcome, so there is
/// no encrypted bundle and no reviewer studying her ID card. Review is a woman
/// from Own Hub who reviews her case and contacts her by phone within 72
/// hours, the same route `C15` offers. There is no video service. The old
/// headline, "A woman reviewer is looking", described a model that no longer
/// exists and would have been a lie on the one screen where she is most
/// reliant on being told the truth.
///
/// **The gate is the whole app, not only the community.** This screen used to
/// carry three rows promising that workouts, recipes and coach profiles were
/// open while she waited. They are not, so they are gone, and the copy says
/// what is actually true: the app opens when the check is done.
///
/// ## It shows what the server says (S8)
///
/// [status] is `users/{uid}.verification`, read at start-up, and [updates] is
/// the same document live while this screen is open. So the screen survives a
/// restart, shows the booked time once a reviewer books it, and moves on the
/// moment a reviewer approves her. Four variants, all honest:
///
///  * pending: a woman from Own Hub reviews her case and contacts her by phone
///    within 72 hours.
///    No text message is promised, because nothing exists that sends one.
///  * booked: the time, in her locale.
///  * retry: we did not reach her review in time; she can take the check
///    again ([onTryAgain], `C09`).
///  * rejected: told plainly, with where to delete her data ([onDeleteMyData],
///    `A02`).
///
/// While she waits she can open the `C04` preview ([onLookAround]). The rest
/// of the app stays closed: that is the whole-app gate, and it is not this
/// screen's to open.
library;

import 'dart:async';

import 'package:flutter/material.dart';

import '../../../app_state/push_registration.dart' show PushOptIn;
import '../../../l10n/app_l10n.dart';
import '../../../routing/app_router.dart';
import '../../../theme/app_tokens.dart';
import '../../../ui/app_button.dart';
import '../../../ui/app_card.dart';
import '../../../ui/app_scaffold.dart';
import '../../../ui/hand/mascot/kitten.dart';
import '../data/review_scheduling_repository.dart';
import '../domain/review_request.dart';
import '../domain/server_verification.dart';
import '../../train/presentation/notification_explainer.dart'
    show SampleNotification;
import 'widgets/review_slot_picker.dart';

class BeingCheckedView extends StatefulWidget {
  const BeingCheckedView({
    super.key,
    this.status,
    this.updates,
    this.onApproved,
    this.onLookAround,
    this.onTryAgain,
    this.onDeleteMyData,
    this.reviewAsked = true,
    this.requester,
    this.onAskedForCall,
    this.onSignInAgain,
    this.savedWeek,
    this.onBuildWeek,
    this.onNotifyMe,
    this.onOpenSettings,
    this.scheduling,
    this.onKeepExploring,
    this.cheerFor = const Duration(milliseconds: 1600),
  });

  /// Free times and booking for the review call. Null: no picker.
  final ReviewSchedulingRepository? scheduling;

  /// "Keep exploring": back to browsing as a guest while she waits.
  final VoidCallback? onKeepExploring;

  /// How long the kitten cheers before [onApproved] moves her on.
  final Duration cheerFor;

  /// "Tell me when I'm in": asks for notifications and registers this phone
  /// for the one push the server sends when a woman reviewer approves her.
  /// Null in a build with nothing to register with.
  final Future<PushOptIn> Function()? onNotifyMe;

  /// The phone's settings for this app, after she said no to notifications.
  final VoidCallback? onOpenSettings;

  /// "Build your week while we check": the one-screen "Your week", for a
  /// woman who reached this wait without one (she signed in with an account
  /// she already had, or took the niqab path first). Offered only while she
  /// waits and only when [savedWeek] is null. Setup is open before the check,
  /// so nothing behind the gate opens.
  final VoidCallback? onBuildWeek;

  /// Her week as she saved it before signing up ("3 days a week, 20 minutes
  /// a session, at home"), or null when she has not built one. Shown while she
  /// waits, so the one thing that is already hers is on the screen that asks
  /// her to wait.
  final String? savedWeek;

  /// The server did not accept her sign-in: out to sign in again (N4).
  final VoidCallback? onSignInAgain;

  /// Whether she has asked for the reviewer's call. False when the automatic
  /// check raised the flag by itself (R4): then this screen says plainly that
  /// a reviewer can only call after she asks, and offers "Ask a woman to contact me".
  final bool reviewAsked;

  /// `request_review`, sent when she taps "Ask a woman to contact me". The server
  /// answers `pending` against the flag already open and records her consent.
  final ReviewRequester? requester;

  /// She asked, and the server confirmed.
  final VoidCallback? onAskedForCall;

  /// What the server last said, or null when it has said nothing yet (shown
  /// as pending).
  final ServerVerification? status;

  /// Live updates while this screen is open.
  final Stream<ServerVerification?>? updates;

  /// A reviewer approved her. Called once when the approval arrives, and
  /// again each time she taps "Open Own Hub".
  final VoidCallback? onApproved;

  /// The `C04` preview, while she waits.
  final VoidCallback? onLookAround;

  /// Retry: take the check again.
  final VoidCallback? onTryAgain;

  /// Rejected: where she deletes her data.
  final VoidCallback? onDeleteMyData;

  @override
  State<BeingCheckedView> createState() => _BeingCheckedViewState();
}

class _BeingCheckedViewState extends State<BeingCheckedView> {
  StreamSubscription<ServerVerification?>? _subscription;
  ServerVerification? _live;
  bool _approvedSent = false;
  late bool _asked = widget.reviewAsked;
  bool _asking = false;
  Timer? _cheerTimer;
  bool _cheering = false;

  /// A time the server just confirmed, shown before the live update arrives.
  DateTime? _bookedNow;
  bool _changingTime = false;

  /// What went wrong with the last "Ask for the call", or null.
  CallFailureKind? _askFailure;

  /// What came of "Tell me when I'm in", or null before she asked.
  PushOptIn? _push;
  bool _askingPush = false;

  Future<void> _notifyMe() async {
    final ask = widget.onNotifyMe;
    if (ask == null || _askingPush) return;
    setState(() => _askingPush = true);
    final answer = await ask();
    if (!mounted) return;
    setState(() {
      _push = answer;
      _askingPush = false;
    });
  }

  Future<void> _askForCall() async {
    final requester = widget.requester;
    if (requester == null || _asking) return;
    setState(() {
      _asking = true;
      _askFailure = null;
    });
    try {
      // `error`: the automatic check could not decide. The server keeps the
      // flag it already opened and records that she asked.
      final answer = await requester.request(ReviewPath.error);
      if (!mounted) return;
      switch (answer) {
        case ReviewRequestState.pending:
          setState(() => _asked = true);
          widget.onAskedForCall?.call();
        case ReviewRequestState.approved:
          setState(
            () => _live = const ServerVerification(
              ServerVerificationState.approved,
            ),
          );
          _maybeApproved();
      }
    } catch (error) {
      if (!mounted) return;
      final kind = classifyCallFailure(error);
      if (kind == CallFailureKind.reviewOpen) {
        setState(() => _asked = true);
        widget.onAskedForCall?.call();
      } else {
        setState(() => _askFailure = kind);
      }
    } finally {
      if (mounted) setState(() => _asking = false);
    }
  }

  @override
  void initState() {
    super.initState();
    _live = widget.status;
    _subscription = widget.updates?.listen((next) {
      if (!mounted || next == null) return;
      setState(() => _live = next);
      _maybeApproved();
    });
    WidgetsBinding.instance.addPostFrameCallback((_) => _maybeApproved());
  }

  @override
  void didUpdateWidget(BeingCheckedView old) {
    super.didUpdateWidget(old);
    if (widget.status != null && widget.status != old.status) {
      _live = widget.status;
    }
  }

  void _maybeApproved() {
    if (!mounted || _approvedSent) return;
    if (_live?.state != ServerVerificationState.approved) return;
    _approvedSent = true;
    setState(() => _cheering = true);
    _cheerTimer = Timer(widget.cheerFor, () {
      if (mounted) widget.onApproved?.call();
    });
  }

  @override
  void dispose() {
    _subscription?.cancel();
    _cheerTimer?.cancel();
    super.dispose();
  }

  String _when(BuildContext context, DateTime at) {
    final local = at.toLocal();
    final m = MaterialLocalizations.of(context);
    return '${m.formatFullDate(local)}, '
        '${m.formatTimeOfDay(TimeOfDay.fromDateTime(local))}';
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppL10n.of(context);
    final quiet = AppText.bodyM.copyWith(color: AppColors.onSurfaceVariant);
    final state = _live?.state ?? ServerVerificationState.pending;
    final booked = _live?.reviewScheduledFor ?? _bookedNow;

    final (String title, String body) = switch (state) {
      ServerVerificationState.rejected => (
        l10n.weCouldNotVerifyYourAccount,
        l10n.youCanDeleteYourAccountAndEverything,
      ),
      ServerVerificationState.retry => (
        l10n.yourReviewTimeRanOut,
        l10n.weDidNotReachYourReviewIn,
      ),
      // Approved is never "waiting" (R1). The server let her in; the button
      // takes her to the product, however many times the first attempt to
      // refresh her token failed.
      ServerVerificationState.approved => (
        l10n.yourCheckIsDone,
        l10n.youAreVerifiedOpenOwnHubTo,
      ),
      _ => (
        l10n.aWomanFromOwnHubWillReview,
        booked != null
            ? l10n.aWomanFromOwnHubWillContact(_when(context, booked))
            // PENDING COUNSEL: with "Your phone number is used only to
            // arrange your check" below, this is the review consent wording
            // (review-v3, the same substance as C15), shown before she asks.
            // No video: a woman from Own Hub reviews and contacts her within
            // config.REVIEW_SLA_HOURS (72).
            : !_asked && widget.requester != null
            ? l10n.aWomanFromOwnHubCanContact
            : l10n.aWomanFromOwnHubReviewsYour,
      ),
    };
    final offerCall =
        state == ServerVerificationState.pending &&
        booked == null &&
        !_asked &&
        widget.requester != null;
    final waiting = state == ServerVerificationState.pending;
    final approved = state == ServerVerificationState.approved;
    final scheduling = widget.scheduling;
    final canSchedule = waiting && _asked;

    return Scaffold(
      backgroundColor: AppColors.surface,
      // No tab bar: the app opens after the check, and a bar here would
      // offer doors that are closed and cover the last button.
      body: AppScaffold(
        // No lead: there is nowhere to step back to, and nothing to undo.
        appBar: AppTopBar(title: l10n.beingChecked),
        children: [
          AppCard(
            variant: AppCardVariant.amber,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (_cheering)
                    const Kitten(pose: KittenPose.cheer, size: 56)
                  else if (waiting)
                    // Sits and waits, settling once. Only while the check is
                    // still to come: never beside a refusal or a retry.
                    const Kitten(
                      pose: KittenPose.wait,
                      size: 56,
                      tint: KittenTint.sage,
                      sessionBudget: true,
                    )
                  else
                    Icon(
                      approved ? Icons.check_circle : Icons.info_outline,
                      size: 26,
                      color: AppColors.amber,
                    ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(title, style: AppText.titleM),
                        const SizedBox(height: 3),
                        Text(body, style: quiet),
                      ],
                    ),
                  ),
                ],
              ),
            ],
          ),
          if (widget.savedWeek case final week?
              when state != ServerVerificationState.rejected)
            AppCard(
              key: const ValueKey('c14-saved-week'),
              variant: AppCardVariant.sage,
              borderRadius: AppRadius.md,
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
              children: [
                Text(
                  l10n.yourWeekIsSaved,
                  style: AppText.titleM.copyWith(
                    color: AppColors.onTertiaryContainer,
                  ),
                ),
                Text(
                  week,
                  style: AppText.bodyM.copyWith(
                    color: AppColors.onTertiaryContainer,
                  ),
                ),
              ],
            ),
          // Rule 7, at the moment she is most likely to wonder where her
          // photographs went. Nothing was filed, nothing is waiting, nobody is
          // looking at a picture of her.
          Text(l10n.nothingYouPhotographedIsStoredItWas, style: quiet),
          // The closed door, named as the point rather than as a punishment.
          // Only while a decision is still to come.
          if (waiting) Text(l10n.theAppOpensAsSoonAsYour, style: quiet),
          if (offerCall) ...[
            Text(l10n.yourPhoneNumberIsUsedOnlyTo_thda4, style: quiet),
            if (_askFailure != null)
              Semantics(
                liveRegion: true,
                child: Text(switch (_askFailure) {
                  CallFailureKind.tryTomorrow =>
                    l10n.youHaveAskedForAReviewerToo,
                  CallFailureKind.appCannotReach =>
                    l10n.thisCopyOfTheAppCannotReach_agbhf,
                  CallFailureKind.signInAgain =>
                    l10n.yourSignInIsNoLongerValid_1y16r,
                  _ => l10n.weCouldNotReachOwnHubSo_3usbb,
                }, style: AppText.bodyM.copyWith(color: AppColors.error)),
              ),
            if (_askFailure == CallFailureKind.signInAgain &&
                widget.onSignInAgain != null)
              AppButton(
                l10n.signInAgain,
                variant: AppButtonVariant.outlined,
                onPressed: widget.onSignInAgain,
              ),
            AppButton(
              l10n.askAWomanToContactMe,
              key: const ValueKey('c14-ask-for-the-call'),
              onPressed: _asking ? null : _askForCall,
            ),
          ],
          if (scheduling != null &&
              canSchedule &&
              booked != null &&
              !_changingTime)
            AppButton(
              l10n.changeTheTime,
              key: const ValueKey('c14-change-time'),
              variant: AppButtonVariant.outlined,
              onPressed: () => setState(() => _changingTime = true),
            ),
          if (scheduling != null &&
              canSchedule &&
              (booked == null || _changingTime))
            ReviewSlotPicker(
              key: const ValueKey('c14-slot-picker'),
              repository: scheduling,
              onBooked: (at) => setState(() {
                _bookedNow = at;
                _changingTime = false;
              }),
            ),
          if (approved && widget.onApproved != null)
            AppButton(
              l10n.openOwnHub,
              key: const ValueKey('c14-open-own-hub'),
              onPressed: widget.onApproved,
            ),
          if (state == ServerVerificationState.retry &&
              widget.onTryAgain != null)
            AppButton(l10n.takeTheCheckAgain, onPressed: widget.onTryAgain),
          if (state == ServerVerificationState.rejected &&
              widget.onDeleteMyData != null)
            AppButton(
              l10n.openProfileAndSettings,
              onPressed: widget.onDeleteMyData,
            ),
          // She may close the app for days. One push, when the check is done,
          // and only if she asks for it here.
          if (waiting && widget.onNotifyMe != null) ...[
            if (_push == null) ...[
              Center(child: SampleNotification(body: l10n.yourCheckIsDone)),
              Text(l10n.turnOnNotificationsSoWeCanTell, style: quiet),
              AppButton(
                l10n.tellMeWhenImIn,
                key: const ValueKey('c14-notify-me'),
                variant: AppButtonVariant.outlined,
                onPressed: _askingPush ? null : _notifyMe,
              ),
            ] else
              Semantics(
                liveRegion: true,
                child: Text(
                  switch (_push!) {
                    PushOptIn.on => l10n.weWillTellYouOnThisPhone,
                    PushOptIn.denied => l10n.notificationsAreOffForOwnHubOn,
                    PushOptIn.unavailable =>
                      l10n.notificationsCannotReachThisPhoneOpenOwn,
                  },
                  key: const ValueKey('c14-notify-answer'),
                  style: quiet,
                ),
              ),
            if (_push == PushOptIn.denied && widget.onOpenSettings != null)
              AppButton(
                l10n.openSettings,
                variant: AppButtonVariant.text,
                onPressed: widget.onOpenSettings,
              ),
          ],
          if (waiting && widget.savedWeek == null && widget.onBuildWeek != null)
            AppButton(
              l10n.buildYourWeekWhileWeCheck,
              key: const ValueKey('c14-build-week'),
              variant: AppButtonVariant.outlined,
              onPressed: widget.onBuildWeek,
            ),
          if (waiting &&
              widget.onLookAround != null &&
              AppRouter.screenIsOn('C04'))
            AppButton(
              l10n.lookAroundWhileYouWait,
              variant: AppButtonVariant.outlined,
              onPressed: widget.onLookAround,
            ),
          if (waiting && widget.onKeepExploring != null)
            AppButton(
              l10n.keepExploring,
              key: const ValueKey('c14-keep-exploring'),
              variant: AppButtonVariant.outlined,
              onPressed: widget.onKeepExploring,
            ),
          // Never a dead end: whatever she is waiting on, she can leave this
          // account on this phone and sign in with another number.
          if (widget.onSignInAgain != null)
            AppButton(
              l10n.useADifferentNumber,
              key: const ValueKey('c14-use-another-number'),
              variant: AppButtonVariant.text,
              onPressed: widget.onSignInAgain,
            ),
        ],
      ),
    );
  }
}
