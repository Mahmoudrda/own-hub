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
/// no encrypted bundle and no reviewer studying her ID card. Review is a short
/// video call with a woman, the same two minutes `C15` already offers. The old
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
///  * pending: a woman reviewer will phone her to arrange a short video call.
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

import '../../../l10n/app_l10n.dart';
import '../../../theme/app_tokens.dart';
import '../../../ui/app_button.dart';
import '../../../ui/app_card.dart';
import '../../../ui/app_nav_bar.dart';
import '../../../ui/app_scaffold.dart';
import '../domain/server_verification.dart';

class BeingCheckedView extends StatefulWidget {
  const BeingCheckedView({
    super.key,
    this.status,
    this.updates,
    this.onApproved,
    this.onLookAround,
    this.onTryAgain,
    this.onDeleteMyData,
    this.onSelectTab,
  });

  /// What the server last said, or null when it has said nothing yet (shown
  /// as pending).
  final ServerVerification? status;

  /// Live updates while this screen is open.
  final Stream<ServerVerification?>? updates;

  /// A reviewer approved her. Called once.
  final VoidCallback? onApproved;

  /// The `C04` preview, while she waits.
  final VoidCallback? onLookAround;

  /// Retry: take the check again.
  final VoidCallback? onTryAgain;

  /// Rejected: where she deletes her data.
  final VoidCallback? onDeleteMyData;

  /// The bottom bar. It is drawn because the design draws it and because a
  /// screen with no bar reads as a modal she is trapped in, and every tab it
  /// offers lands back here while the check is running, which is the gate
  /// saying the same thing twice rather than a dead control.
  final ValueChanged<String>? onSelectTab;

  @override
  State<BeingCheckedView> createState() => _BeingCheckedViewState();
}

class _BeingCheckedViewState extends State<BeingCheckedView> {
  StreamSubscription<ServerVerification?>? _subscription;
  ServerVerification? _live;
  bool _approvedSent = false;

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
    widget.onApproved?.call();
  }

  @override
  void dispose() {
    _subscription?.cancel();
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
    final booked = _live?.reviewScheduledFor;

    final (String title, String body) = switch (state) {
      ServerVerificationState.rejected => (
        l10n.weCouldNotVerifyYourAccount,
        l10n.youCanDeleteYourAccountAndEverything,
      ),
      ServerVerificationState.retry => (
        l10n.yourReviewTimeRanOut,
        l10n.weDidNotReachYourReviewIn,
      ),
      _ => (
        l10n.aShortVideoCallWithAWoman,
        booked != null
            ? l10n.yourVideoCallIsBookedForTime(_when(context, booked))
            : l10n.aWomanReviewerFromOwnHubWill,
      ),
    };
    final waiting =
        state == ServerVerificationState.pending ||
        state == ServerVerificationState.approved;

    return Scaffold(
      backgroundColor: AppColors.surface,
      bottomNavigationBar: AppNavBar(
        activeScreenId: 'T01',
        onSelect: widget.onSelectTab,
      ),
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
                  Icon(
                    waiting ? Icons.hourglass_top : Icons.info_outline,
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
          // Rule 7, at the moment she is most likely to wonder where her
          // photographs went. Nothing was filed, nothing is waiting, nobody is
          // looking at a picture of her.
          Text(l10n.nothingYouPhotographedIsStoredItWas, style: quiet),
          // The closed door, named as the point rather than as a punishment.
          // Only while a decision is still to come.
          if (waiting) Text(l10n.theAppOpensAsSoonAsYour, style: quiet),
          if (state == ServerVerificationState.retry &&
              widget.onTryAgain != null)
            AppButton(l10n.takeTheCheckAgain, onPressed: widget.onTryAgain),
          if (state == ServerVerificationState.rejected &&
              widget.onDeleteMyData != null)
            AppButton(
              l10n.openProfileAndSettings,
              onPressed: widget.onDeleteMyData,
            ),
          if (waiting && widget.onLookAround != null)
            AppButton(
              l10n.lookAroundWhileYouWait,
              variant: AppButtonVariant.outlined,
              onPressed: widget.onLookAround,
            ),
        ],
      ),
    );
  }
}
