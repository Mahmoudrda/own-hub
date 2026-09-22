/// `W02` — one client, and the constraints a plan is written against.
///
/// ## Everything on this screen about her body is read-only
///
/// r13: the assessment is the **only** source of a client's constraints. There
/// is no input on this screen that writes `avoid`, `allergies` or `dietary`,
/// and there is no parameter on [ClientOverviewView] through which one could be
/// passed in — [ConstraintPanel] is the whole of the rendering and it has no
/// controller. Changing what is shown here means recording a new assessment,
/// which is what `K21`/`K23` are for.
///
/// ## What is missing, and why it is absent rather than invented
///
/// The prototype's goal / trains / where / adherence rows come from G11's
/// `relationships/{relId}/shared/constraints` and `rollups/{isoWeek}`
/// projections. Neither is modelled in this feature's domain — G11 owns them —
/// so there is nothing here to render them from. They are left out rather than
/// filled with a mockup's answer about somebody else's week.
library;

import 'package:flutter/material.dart';

import '../../../domain/format/day_key.dart';
import '../../../domain/safety/client_constraints.dart';
import '../../../l10n/app_l10n.dart';
import '../../../theme/app_tokens.dart';
import '../../../ui/app_button.dart';
import '../../../ui/app_list_item.dart';
import '../../../ui/app_pill.dart';
import '../../../ui/app_scaffold.dart';
import '../domain/assessment/assessment_record.dart';
import '../domain/clients/coach_client.dart';
import 'coachplan_widgets.dart';

class ClientOverviewView extends StatelessWidget {
  const ClientOverviewView({
    super.key,
    required this.client,
    required this.constraints,
    this.assessment,
    this.now,
    this.onBack,
    this.onOpenChat,
    this.onOpenAssessment,
    this.onOpenPlan,
    this.onOpenMeals,
    this.onOpenReview,
    this.onTab,
  });

  final CoachClient client;

  /// Resolved by `ClientConstraintResolver`, which is the only constructor
  /// there is. Nothing on this screen can add to it.
  final ClientConstraints constraints;

  /// Her latest, read by the pointer on the relationship. Null when she has
  /// none — which is a state W08 names before publishing, not an error here.
  final AssessmentRecord? assessment;

  final DateTime? now;

  final VoidCallback? onBack;
  final VoidCallback? onOpenChat;
  final VoidCallback? onOpenAssessment;
  final VoidCallback? onOpenPlan;
  final VoidCallback? onOpenMeals;
  final VoidCallback? onOpenReview;
  final ValueChanged<String>? onTab;

  @override
  Widget build(BuildContext context) {
    final l10n = AppL10n.of(context);
    final moment = now ?? DateTime.now();
    final record = assessment;
    final due = client.queue.matches(QueueFilter.assessmentDue, moment);

    return Scaffold(
      backgroundColor: AppColors.surface,
      bottomNavigationBar: CoachPlanNavBar(activeScreenId: 'W01', onTab: onTab),
      appBar: AppTopBar(
        title: client.displayName,
        onBack: onBack,
        actions: [
          IconButton(
            tooltip: l10n.message,
            color: AppColors.onSurfaceVariant,
            icon: const Icon(Icons.chat_bubble_outline),
            onPressed: onOpenChat,
          ),
        ],
      ),
      body: AppScaffold(
        children: [
          AppListItem(
            variant: AppCardVariant.tonal,
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            leading: const Icon(
              Icons.checklist,
              size: 22,
              color: AppColors.primaryDim,
            ),
            title: l10n.assessment,
            // The day it was taken, as the id it is. No re-assessment
            // countdown: "re-assess in 2 weeks" is the mockup's fortnight.
            subtitle: record == null ? '' : dayKey(record.takenAt),
            trailing: due
                ? AppPill(
                    l10n.assessmentDue,
                    background: AppColors.amberContainer,
                    foreground: AppColors.amber,
                  )
                : const Icon(
                    Icons.chevron_right,
                    size: 22,
                    color: AppColors.onSurfaceVariant,
                  ),
            onTap: onOpenAssessment,
          ),
          // r13, as a shape: read-only, and there is no field anywhere below.
          ConstraintPanel(constraints: constraints),
          Row(
            children: [
              Expanded(
                child: AppButton(
                  l10n.plan,
                  height: 46,
                  fontSize: 14,
                  onPressed: onOpenPlan,
                ),
              ),
              const SizedBox(width: 6),
              Expanded(
                child: AppButton(
                  l10n.meals,
                  variant: AppButtonVariant.tonal,
                  height: 46,
                  fontSize: 14,
                  onPressed: onOpenMeals,
                ),
              ),
              const SizedBox(width: 6),
              Expanded(
                child: AppButton(
                  l10n.review,
                  variant: AppButtonVariant.outlined,
                  height: 46,
                  fontSize: 14,
                  onPressed: onOpenReview,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
