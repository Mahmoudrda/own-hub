/// `K17` — Earnings.
///
/// Matches `6-v2/src/screens-coach.mjs` → `K17`.
///
/// # This screen states no figure, and that is the correct rendering
///
/// The prototype draws "21,600 EGP", "Your 80% of 27,000 EGP · 12 clients" and
/// "Payout on 1 October". Every one of those is the mockup's sample about one
/// imagined coach, and there is no provider behind any of them: G12 §9 **Q7**
/// records that payments, escrow, the 80% split and payouts are absent from the
/// spine and owned by no group.
///
/// So [CoachEarningsViewModel.canShowMoney] is false, and this screen renders
/// its empty state. What it says is what stays true whenever a rail arrives —
/// she keeps 80%, and the first payout lands on the 1st of the month after her
/// first client pays.
///
/// **It does not render zero.** A zero is a claim about her month; the absence
/// of a statement is not.
///
/// Everything here is additionally behind `Feature.payments`, which ships off.
///
/// # The one thing still missing when a provider lands
///
/// A parameterised money message. The dictionary carries fixed samples
/// (`21,600 EGP`, `Your 80% of 27,000 EGP · 12 clients`) and **no
/// `"{amount} EGP"` form**, so an arbitrary figure has no honest rendering yet.
/// Reported rather than worked around with `NumberFormat`, which would print
/// Eastern digits under Arabic and break `P0-A11Y-01`.
library;

import 'package:flutter/material.dart';

import '../../../l10n/app_l10n.dart';
import '../../../theme/app_tokens.dart';
import '../../../ui/app_empty_state.dart';
import '../../../ui/app_list_item.dart';
import '../../../ui/app_nav_bar.dart';
import '../../../ui/app_scaffold.dart';
import '../../../ui/app_split_row.dart';
import '../../private_coaching/domain/coach_agreement.dart';
import 'coach_setup_scaffold.dart';
import 'coach_view_models.dart';

class CoachEarningsView extends StatelessWidget {
  const CoachEarningsView({
    super.key,
    required this.model,
    this.onSelectTab,
    this.onOpenPayoutMethod,
  });

  final CoachEarningsViewModel model;
  final ValueChanged<String>? onSelectTab;
  final VoidCallback? onOpenPayoutMethod;

  @override
  Widget build(BuildContext context) {
    final l10n = AppL10n.of(context);

    return Scaffold(
      backgroundColor: AppColors.surface,
      bottomNavigationBar: AppNavBar(
        activeScreenId: 'K17',
        onSelect: (id) {
          final onTab = onSelectTab;
          if (onTab != null) {
            onTab(id);
            return;
          }
          goToScreen(context, id);
        },
      ),
      body: AppScaffold(
        children: [
          AppSplitRow(
            start: Text(
              l10n.earnings,
              style: AppText.titleL.copyWith(
                color: AppColors.onPrimaryContainer,
              ),
            ),
            end: const Icon(
              Icons.receipt_long,
              size: 24,
              color: AppColors.onSurfaceVariant,
            ),
          ),

          // No provider, no statement, no number. What is said instead is true
          // today and stays true afterwards.
          if (!model.canShowMoney)
            AppEmptyState(
              icon: Icons.payments,
              title: l10n.earningsThisMonth,
              body: l10n.clientsPayYouDirectlyOwnHubTakes(
                CoachAgreementFacts.marketplacePercent,
                CoachAgreementFacts.invitePercent,
                '${CoachAgreementFacts.payWithinDays}',
              ),
            ),

          // Where her money would go. `K05` is the screen that sets it — the
          // prototype points this at `K18`, which is her public profile and
          // has nothing to do with a payout method.
          AppListItem(
            leading: const Icon(
              Icons.account_balance_wallet,
              size: 24,
              color: AppColors.primaryDim,
            ),
            title: l10n.payoutMethod,
            subtitle: model.knowsDestination
                ? l10n.vodafoneCashChangeAnyTime
                : l10n.whereYourClientsPayYou,
            trailing: const Icon(
              Icons.chevron_right,
              size: 22,
              color: AppColors.onSurfaceVariant,
            ),
            onTap: () => goToScreen(context, 'K05', onOpenPayoutMethod),
          ),
        ],
      ),
    );
  }
}
