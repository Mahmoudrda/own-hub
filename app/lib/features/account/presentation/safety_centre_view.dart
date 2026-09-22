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

import '../../../l10n/app_l10n.dart';
import '../../../theme/app_tokens.dart';
import '../../../ui/app_card.dart';
import '../../../ui/app_list_item.dart';
import '../../../ui/app_nav_bar.dart';
import '../../../ui/app_scaffold.dart';
import '../domain/safety.dart';
import 'account_view_models.dart';

class SafetyCentreView extends StatelessWidget {
  const SafetyCentreView({
    super.key,
    required this.blockService,
    required this.reportService,
    this.onBack,
    this.onReportSomeone,
    this.onSelectTab,
  });

  final BlockService blockService;
  final ReportService reportService;

  final VoidCallback? onBack;

  /// Reporting a person happens on M08 (Phase 3). A04 is the door.
  final VoidCallback? onReportSomeone;

  final ValueChanged<String>? onSelectTab;

  @override
  Widget build(BuildContext context) {
    final l10n = AppL10n.of(context);
    final view = SafetyCentreModel.from(
      blocks: blockService.blocks(),
      reports: reportService.reports(),
    );

    return AppScaffold(
      appBar: AppTopBar(title: l10n.safetyCentre, onBack: onBack),
      footer: [AppNavBar(activeScreenId: 'T01', onSelect: onSelectTab)],
      children: [
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

        AppListItem(
          leading: const Icon(
            Icons.flag_outlined,
            size: 24,
            color: AppColors.primaryDim,
          ),
          title: l10n.reportSomeone,
          subtitle: l10n.aWomanModeratorReadsItWithinAn,
          trailing: const Icon(
            Icons.chevron_right,
            size: 22,
            color: AppColors.onSurfaceVariant,
          ),
          onTap: onReportSomeone,
        ),

        // "2 blocked" and "1 · resolved in 40 minutes" are the prototype's
        // samples and the dictionary has no parameterised form for either, so
        // the counts are computed (and tested) but not stated. Rendering the
        // fixed strings would tell every woman she has blocked two people.
        AppListItem(
          leading: const Icon(
            Icons.block,
            size: 24,
            color: AppColors.primaryDim,
          ),
          title: l10n.blockedMembers,
          trailing: const Icon(
            Icons.chevron_right,
            size: 22,
            color: AppColors.onSurfaceVariant,
          ),
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
          trailing: const Icon(
            Icons.chevron_right,
            size: 22,
            color: AppColors.onSurfaceVariant,
          ),
        ),

        AppListItem(
          leading: const Icon(
            Icons.help_outline,
            size: 24,
            color: AppColors.primaryDim,
          ),
          title: l10n.whatHappensWhenIReport,
          subtitle: l10n.theThreeStepsPlainly,
          trailing: const Icon(
            Icons.chevron_right,
            size: 22,
            color: AppColors.onSurfaceVariant,
          ),
        ),

        AppListItem(
          leading: const Icon(
            Icons.support_agent,
            size: 24,
            color: AppColors.primaryDim,
          ),
          title: l10n.talkToAHuman,
          subtitle: l10n.aWomanOnTheTeam9amTo,
          trailing: const Icon(
            Icons.chevron_right,
            size: 22,
            color: AppColors.onSurfaceVariant,
          ),
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
