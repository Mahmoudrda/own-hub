/// Where her application stands: sent, changes asked for, not approved, or
/// approved.
library;

import 'dart:async';

import 'package:flutter/material.dart';

import '../../../../app_state/coach_application_draft.dart';
import '../../../../app_state/open_link.dart';
import '../../../../config/team_contact.dart';
import '../../../../domain/format/date_label.dart';
import '../../../../l10n/app_l10n.dart';
import '../../../../theme/app_tokens.dart';
import '../../../../ui/app_button.dart';
import '../../../../ui/app_card.dart';
import '../../../../ui/app_scaffold.dart';
import '../../data/coaching_repository.dart';
import '../../domain/coach_application.dart';
import '../../domain/coaching_contract.dart';
import 'apply_labels.dart';
import 'apply_rules.dart';

/// The status page for [application], null for none yet.
class ApplicationStatusView extends StatelessWidget {
  const ApplicationStatusView({
    super.key,
    required this.application,
    this.onEditSection,
    this.onSendAgain,
    this.onOpenCoachSpace,
    this.onStart,
    this.onBack,
    this.now,
  });

  final CoachApplication? application;

  /// Opens the step for the section the reviewer flagged (1 to 8).
  final ValueChanged<int>? onEditSection;

  /// Goes to the review page to send again.
  final VoidCallback? onSendAgain;
  final VoidCallback? onOpenCoachSpace;

  /// With no application yet.
  final VoidCallback? onStart;
  final VoidCallback? onBack;
  final DateTime? now;

  @override
  Widget build(BuildContext context) {
    final l10n = AppL10n.of(context);
    final app = application;
    final status = app?.status;
    return AppScaffold(
      appBar: AppTopBar(onBack: onBack),
      footer: [
        if (app == null || status == null)
          AppButton(l10n.startMyApplication, onPressed: onStart)
        else if (status == ApplicationStatus.needsChanges)
          AppButton(l10n.sendAgain, onPressed: onSendAgain)
        else if (status == ApplicationStatus.approved)
          AppButton(l10n.openMyCoachSpace, onPressed: onOpenCoachSpace)
        else if (status == ApplicationStatus.submitted)
          _back(context, l10n)
        else if (status == ApplicationStatus.rejected) ...[
          _back(context, l10n),
          AppButton(
            l10n.contactOwnHub,
            variant: AppButtonVariant.outlined,
            onPressed: () => unawaited(
              openExternalLink(context, 'mailto:${TeamContact.supportEmail}'),
            ),
          ),
        ],
      ],
      children: switch ((app, status)) {
        (null, _) || (_, null) => _plain(
          l10n.noApplicationYet,
          l10n.reviewTakesUpToDaysWorkingDays('$kReviewWorkingDays'),
        ),
        (final a?, ApplicationStatus.submitted) => [
          ..._plain(
            l10n.weHaveYourApplication,
            l10n.ownHubsReviewerIsReadingItThis('$kReviewWorkingDays'),
          ),
          AppCard(
            children: [
              Text(
                l10n.whatHappensNext,
                style: AppText.titleM.copyWith(color: AppColors.onSurface),
              ),
              for (final line in [
                l10n.aWomanReviewerReadsEachPart,
                l10n.sheMayAskYouToChangeSomething,
                l10n.whenYouAreApprovedYourCoachSpace,
              ])
                Text(
                  line,
                  style: AppText.bodyM.copyWith(color: AppColors.onSurface),
                ),
            ],
          ),
          if (a.note.isEmpty) const SizedBox.shrink(),
        ],
        (final a?, ApplicationStatus.needsChanges) => [
          ..._plain(
            l10n.aFewChangesPlease,
            l10n.theReviewerAskedYouToUpdateThese,
          ),
          if (a.note.isNotEmpty) _note(l10n, a.note),
          for (final section in a.sectionsNeedingChanges)
            if (applyStepOfSection(section, a, now: now) case final step?)
              AppCard(
                children: [
                  Text(
                    applyStepTitle(l10n, step),
                    style: AppText.titleM.copyWith(color: AppColors.onSurface),
                  ),
                  Text(
                    reasonLabel(l10n, a.reasons[section] ?? 'other'),
                    style: AppText.bodyM.copyWith(color: AppColors.onSurface),
                  ),
                  AppButton(
                    l10n.edit,
                    variant: AppButtonVariant.outlined,
                    height: 48,
                    fontSize: 15,
                    onPressed: onEditSection == null
                        ? null
                        : () => onEditSection!(step),
                  ),
                ],
              ),
        ],
        (final a?, ApplicationStatus.rejected) => [
          ..._plain(
            l10n.notApprovedThisTime,
            l10n.theReviewerCouldNotApproveThisApplication,
          ),
          if (a.note.isNotEmpty) _note(l10n, a.note),
          for (final section in a.sectionsNeedingChanges)
            if (applyStepOfSection(section, a, now: now) case final step?)
              AppCard(
                children: [
                  Text(
                    applyStepTitle(l10n, step),
                    style: AppText.titleM.copyWith(color: AppColors.onSurface),
                  ),
                  Text(
                    reasonLabel(l10n, a.reasons[section] ?? 'other'),
                    style: AppText.bodyM.copyWith(color: AppColors.onSurface),
                  ),
                ],
              ),
          Text(
            _again(l10n, a),
            style: AppText.body.copyWith(color: AppColors.onSurface),
          ),
        ],
        (_, ApplicationStatus.approved) => _plain(
          l10n.youAreApproved,
          l10n.welcomeToOwnHubsCoachesYourCoach,
        ),
      },
    );
  }

  static String _again(AppL10n l10n, CoachApplication app) {
    final decided = app.decidedAt;
    if (decided == null) {
      return l10n.youCanApplyAgainDaysDaysAfter(
        '${CoachingLimits.reapplyAfterDays}',
      );
    }
    final d = decided.toLocal().add(
      const Duration(days: CoachingLimits.reapplyAfterDays),
    );
    return l10n.youCanApplyAgainOnDate(dayMonthYearLabel(l10n, d));
  }

  Widget _back(BuildContext context, AppL10n l10n) => AppButton(
    l10n.backToProfile,
    onPressed: onBack ?? () => Navigator.of(context).maybePop(),
  );

  static Widget _note(AppL10n l10n, String note) => AppCard(
    children: [
      Text(
        l10n.reviewersNote,
        style: AppText.titleS.copyWith(color: AppColors.onSurfaceVariant),
      ),
      Text(note, style: AppText.body.copyWith(color: AppColors.onSurface)),
    ],
  );

  static List<Widget> _plain(String title, String body) => [
    Semantics(
      header: true,
      child: Text(
        title,
        style: AppText.headline.copyWith(color: AppColors.onPrimaryContainer),
      ),
    ),
    Text(body, style: AppText.body.copyWith(color: AppColors.onSurfaceVariant)),
  ];
}

/// The status page fed live from her application. Opening a section for
/// editing starts her draft from what the server holds.
class ApplicationStatusScreen extends StatelessWidget {
  const ApplicationStatusScreen({
    super.key,
    required this.repository,
    required this.draft,
    this.onEditStep,
    this.onSendAgain,
    this.onOpenCoachSpace,
    this.onStart,
    this.onBack,
  });

  final CoachingRepository repository;
  final CoachApplicationDraft draft;

  /// Opened from a flagged section; the step comes back from the view.
  final ValueChanged<int>? onEditStep;
  final VoidCallback? onSendAgain;
  final VoidCallback? onOpenCoachSpace;
  final VoidCallback? onStart;
  final VoidCallback? onBack;

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<CoachApplication?>(
      stream: repository.watchMyApplication(),
      builder: (context, snapshot) {
        final waiting =
            snapshot.connectionState == ConnectionState.waiting &&
            !snapshot.hasData;
        if (waiting) {
          return AppScaffold(
            appBar: AppTopBar(onBack: onBack),
            children: const [Center(child: CircularProgressIndicator())],
          );
        }
        final app = snapshot.data;
        void seed() {
          if (app != null && !draft.touched) draft.seedFrom(app);
        }

        return ApplicationStatusView(
          application: app,
          onBack: onBack,
          onStart: onStart,
          onOpenCoachSpace: onOpenCoachSpace,
          onEditSection: (step) {
            seed();
            onEditStep?.call(step);
          },
          onSendAgain: () {
            seed();
            onSendAgain?.call();
          },
        );
      },
    );
  }
}
