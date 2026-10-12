/// A04 — Safety Centre.
///
/// Matches `6-v2/src/screens-account.mjs` → `A04`.
///
/// # Blocking and reporting are different promises, and the screen says so
///
/// G7 §3.2: "blocking is the protection she gets instantly, reporting is the
/// slower one. A04 must say so in those terms." Blocking is offline-capable and
/// takes effect at once; a report with no signal is **queued and not sent**.
///
/// # Every row here used to be a chevron with nothing behind it
///
/// Five rows rendered, each with the arrow that means "this goes somewhere",
/// and four of them had no `onTap` at all. On a safety screen that is the worst
/// place in the product for a control that looks live and is not: a woman who
/// taps "Talk to a human" and gets nothing concludes there is nobody. So each
/// row now either does the thing or stops claiming it can:
///
///   * **Report someone** answers with where a report starts, because the
///     reason picker belongs to the post or the page she is reporting (`M08`)
///     and this screen has no subject to attach one to.
///   * **Blocked members** opens the list, with unblocking on it. That is the
///     only place in the product a block can be undone.
///   * **Reports you made** and **What happens when I report** keep their
///     copy and lose the arrow: one is a status line, the other an answer, and
///     neither is a destination.
///   * **Talk to a human** opens the support page, and is drawn **only** when
///     that page has an address — the rule `A03` already follows for the
///     policy and the terms, and the one `release_readiness_test` asserts.
///
/// # The queued-report state
///
/// G7 §4 calls a queued report rendered as "a moderator is reading it" "the
/// single most misleading thing this group could ship". The SLA clock starts at
/// a server-stamped `createdAt`, so offline it has not started — and
/// [Report.createdAt] is null in that state, which is what makes the claim
/// unrepresentable rather than merely discouraged.
///
/// The sentence G7 specifies — "Not sent yet. It will send when you have signal,
/// and the hour starts then." — is **absent from the dictionary**. Rather than
/// invent English, the screen uses the authored offline vocabulary that already
/// exists in both languages ("Waiting for signal", "Saved on your phone"), which
/// plainly does not imply the hour has started. The exact sentence is reported
/// as still needed, because its second clause is the part no shipped string
/// carries.
///
/// # The one-hour promise
///
/// "A woman moderator reads it within an hour" is a **staffing commitment, not
/// something code can keep** (G7 Q6, `DECISIONS.md` "Still genuinely open"). The
/// prototype's wording is rendered here as designed; the dictionary also carries
/// the softer, already-translated "A woman moderator reads it, usually within an
/// hour", and choosing between them is an owner copy decision rather than one to
/// take unilaterally in a widget.
library;

import 'package:flutter/material.dart';

import '../../../domain/format/number_label.dart' show countLabel;
import '../../../domain/flags/feature_flags.dart';
import '../../../l10n/app_l10n.dart';
import '../../../routing/app_router.dart';
import '../../../theme/app_tokens.dart';
import '../../../ui/app_button.dart';
import '../../../ui/app_card.dart';
import '../../../ui/app_list_item.dart';
import '../../../ui/app_nav_bar.dart';
import '../../../ui/app_scaffold.dart';
import '../../../ui/app_sheet.dart';
import '../domain/safety.dart';
import 'account_view_models.dart';

class SafetyCentreView extends StatefulWidget {
  const SafetyCentreView({
    super.key,
    required this.blockService,
    required this.reportService,
    this.onBack,
    this.onReportSomeone,
    this.onTalkToAHuman,
    this.nameOf,
    this.onSelectTab,
  });

  final BlockService blockService;
  final ReportService reportService;

  final VoidCallback? onBack;

  /// Reporting a person happens on `M08`, against the post or the page she is
  /// reporting. Null here, and the row says where instead of pretending to be
  /// a second way in.
  final VoidCallback? onReportSomeone;

  /// Opens the published support page. The launching belongs to the router,
  /// which is the only place that knows how to reach outside the app.
  final VoidCallback? onTalkToAHuman;

  /// Her name, for a woman she has blocked.
  ///
  /// Supplied by the router from the community store. Returns an empty string
  /// when this build has never seen a name for that uid, and the row then
  /// carries the unblock action alone rather than a uid dressed up as a person.
  final String Function(String uid)? nameOf;

  final ValueChanged<String>? onSelectTab;

  @override
  State<SafetyCentreView> createState() => _SafetyCentreViewState();
}

class _SafetyCentreViewState extends State<SafetyCentreView> {
  static const Icon _chevron = Icon(
    Icons.chevron_right,
    size: 22,
    color: AppColors.onSurfaceVariant,
  );

  Future<void> _openBlocked() async {
    await showAppSheet<void>(
      context: context,
      children: [
        _BlockedMembersSheet(
          service: widget.blockService,
          nameOf: widget.nameOf,
        ),
      ],
    );
    // The sheet unblocks through the same service this screen counts from, so
    // the row underneath has to be re-read rather than left at its old count.
    if (mounted) setState(() {});
  }

  Future<void> _openWhatHappens() => showAppSheet<void>(
    context: context,
    children: const [_WhatHappensSheet()],
  );

  /// Whether there is a community to be kept safe in.
  bool get _community => AppRouter.featureFlags.isOn(Feature.community);

  @override
  Widget build(BuildContext context) {
    final l10n = AppL10n.of(context);
    final view = SafetyCentreModel.from(
      blocks: widget.blockService.blocks(),
      reports: widget.reportService.reports(),
    );

    return AppScaffold(
      appBar: AppTopBar(title: l10n.safetyCentre, onBack: widget.onBack),
      // Its own id: A04 is not a tab, and claiming Home was the active one left
      // the Home tab drawn and unresponsive. See `profile_view.dart`.
      footer: [AppNavBar(activeScreenId: 'A04', onSelect: widget.onSelectTab)],
      children: [
        // Everything down to "Talk to a human" is about other women: a
        // verified membership, reporting one, blocking one, what happens to a
        // report. The first release ships with no community at all, so none
        // of it is true and none of it is drawn. What stays is the help route
        // and the emergency line, which are hers whether or not anyone else
        // is here.
        if (_community) ...[
          AppCard(
            variant: AppCardVariant.sage,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Icon(
                    Icons.verified_user,
                    size: 26,
                    color: AppColors.tertiary,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(l10n.everyMemberIsVerified, style: AppText.titleM),
                        const SizedBox(height: 3),
                        Text(
                          l10n.idCheckedWomenOnlyReviewedByWomen,
                          style: AppText.bodyM.copyWith(
                            color: AppColors.onSurfaceVariant,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ],
          ),

          // A report needs a subject, and this screen has none: the reason picker
          // lives on `M08`, against the post or the page being reported. The row
          // answers with where a report starts instead of opening a picker with
          // nobody in it, and carries no arrow, because it is not a destination.
          AppListItem(
            leading: const Icon(
              Icons.flag_outlined,
              size: 24,
              color: AppColors.primaryDim,
            ),
            title: l10n.reportSomeone,
            subtitle: l10n.aWomanModeratorReadsItWithinAn,
            onTap: widget.onReportSomeone,
          ),

          // The count is computed, never the prototype's fixed "2 blocked", and
          // it is stated only once there is something to state.
          AppListItem(
            leading: const Icon(
              Icons.block,
              size: 24,
              color: AppColors.primaryDim,
            ),
            title: l10n.blockedMembers,
            subtitle: view.blockedCount == 0
                ? ''
                : l10n.blockedCount(countLabel(view.blockedCount)),
            trailing: _chevron,
            onTap: _openBlocked,
          ),

          AppListItem(
            leading: const Icon(
              Icons.history,
              size: 24,
              color: AppColors.primaryDim,
            ),
            title: l10n.reportsYouMade,
            // The one subtitle here that IS honest, and only while it is true.
            subtitle: view.hasUnsentReport ? l10n.waitingForSignal : '',
            // No arrow: there is no screen of her own reports among the 161, so
            // this is a status line about the reports she filed from `M08`.
          ),

          AppListItem(
            leading: const Icon(
              Icons.help_outline,
              size: 24,
              color: AppColors.primaryDim,
            ),
            title: l10n.whatHappensWhenIReport,
            subtitle: l10n.theThreeStepsPlainly,
            trailing: _chevron,
            onTap: _openWhatHappens,
          ),
        ],

        // Drawn only when the support page has an address. An empty link would
        // make this the one row on the safety screen that goes nowhere, which
        // is both Apple 2.1 and the worst possible place to break that rule.
        if (widget.onTalkToAHuman != null)
          AppListItem(
            leading: const Icon(
              Icons.support_agent,
              size: 24,
              color: AppColors.primaryDim,
            ),
            title: l10n.talkToAHuman,
            subtitle: l10n.emailUsReadSundayToThursday9,
            trailing: const Icon(
              Icons.open_in_new,
              size: 20,
              color: AppColors.onSurfaceVariant,
            ),
            onTap: widget.onTalkToAHuman,
          ),

        // The emergency line names the Egyptian number and is honest that the
        // app cannot call it for her.
        Text(
          l10n.ifYouAreInDangerRightNow,
          style: AppText.bodyM.copyWith(color: AppColors.onSurfaceVariant),
        ),
      ],
    );
  }
}

/// The women she has blocked, and the only way to undo one.
///
/// Her own block list, which is hers to see. The graph's `hiddenAuthors` is a
/// different thing and is never rendered anywhere: it holds blocks in both
/// directions, so a screen that showed it would tell a woman who had blocked
/// her.
class _BlockedMembersSheet extends StatefulWidget {
  const _BlockedMembersSheet({required this.service, this.nameOf});

  final BlockService service;
  final String Function(String uid)? nameOf;

  @override
  State<_BlockedMembersSheet> createState() => _BlockedMembersSheetState();
}

class _BlockedMembersSheetState extends State<_BlockedMembersSheet> {
  Future<void> _unblock(String uid) async {
    await widget.service.unblock(uid);
    if (mounted) setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppL10n.of(context);
    final blocks = widget.service.blocks();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(l10n.blockedMembers, style: AppText.titleL),
        const SizedBox(height: 14),
        if (blocks.isEmpty)
          Text(
            l10n.youHaveNotBlockedAnyone,
            style: AppText.bodyM.copyWith(color: AppColors.onSurfaceVariant),
          )
        else
          for (final block in blocks)
            AppListItem(
              title: widget.nameOf?.call(block.blockedUid) ?? '',
              trailing: AppButton(
                l10n.unblock,
                variant: AppButtonVariant.outlined,
                height: 40,
                fontSize: 15,
                onPressed: () => _unblock(block.blockedUid),
              ),
            ),
        const SizedBox(height: 8),
      ],
    );
  }
}

/// The three steps the row promises, written out.
///
/// Nothing here says a moderator has already read anything: it describes the
/// path a report takes, which is what the question asks.
class _WhatHappensSheet extends StatelessWidget {
  const _WhatHappensSheet();

  @override
  Widget build(BuildContext context) {
    final l10n = AppL10n.of(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(l10n.whatHappensWhenIReport, style: AppText.titleL),
        const SizedBox(height: 14),
        for (final step in [
          l10n.youPickAReasonAndSendIt,
          l10n.aWomanOnTheTeamReadsIt,
          l10n.sheTellsYouWhatSheDidAbout,
        ]) ...[Text(step, style: AppText.bodyM), const SizedBox(height: 8)],
      ],
    );
  }
}
