/// The doors into changing a plan: the card at the top of Train, the button on
/// the programme page, and the two links under Home's training card.
///
/// Each is a widget with callbacks, so the router decides where it goes.
library;

import 'package:flutter/material.dart';

import '../../../l10n/app_l10n.dart';
import '../../../theme/app_tokens.dart';
import '../../../ui/app_button.dart';
import '../../../ui/app_card.dart';
import '../../../ui/app_sheet.dart';

/// "Build my own plan": large, with the three things she can do about it.
///
/// With a plan of her own the first button opens it; without one it shows the
/// plan she follows in the editor, to be hers with her first change. Either way
/// it is one tap from this card to the plan editor. Starting from scratch is
/// offered while she has no plan; with one, the editor has its own.
class BuildOwnPlanCard extends StatelessWidget {
  const BuildOwnPlanCard({
    super.key,
    required this.hasMyPlan,
    this.onCustomizePlan,
    this.onStartFromScratch,
    this.onEditSplit,
    this.onBuildWorkout,
    this.onMyWorkouts,
  });

  /// She already has a plan of her own.
  final bool hasMyPlan;

  /// Copies the plan she follows into hers, or opens hers, and shows the
  /// editor.
  final VoidCallback? onCustomizePlan;

  /// Opens the editor on an empty plan.
  final VoidCallback? onStartFromScratch;

  /// Asks which of the three splits to copy.
  final VoidCallback? onEditSplit;

  /// The builder for a single workout.
  final VoidCallback? onBuildWorkout;
  final VoidCallback? onMyWorkouts;

  @override
  Widget build(BuildContext context) {
    final l10n = AppL10n.of(context);
    return AppCard(
      key: const ValueKey('r01-build-plan-card'),
      variant: AppCardVariant.tonal,
      gap: 10,
      padding: const EdgeInsets.fromLTRB(18, 18, 18, 14),
      children: [
        Semantics(
          header: true,
          child: Text(
            l10n.buildMyOwnPlan,
            style: AppText.headline.copyWith(
              color: AppColors.onPrimaryContainer,
            ),
          ),
        ),
        Text(
          l10n.startWithABlankPlanOrChange,
          style: AppText.bodyM.copyWith(color: AppColors.onPrimaryContainer),
        ),
        if (onCustomizePlan != null)
          AppButton(
            hasMyPlan ? l10n.editMyPlan : l10n.customizeThisPlan,
            key: const ValueKey('r01-customize-plan'),
            icon: Icons.tune,
            variant: AppButtonVariant.outlined,
            height: 52,
            fontSize: 16,
            onPressed: onCustomizePlan,
          ),
        if (onStartFromScratch != null && !hasMyPlan)
          AppButton(
            l10n.startFromScratch,
            key: const ValueKey('r01-plan-scratch'),
            icon: Icons.add,
            variant: AppButtonVariant.outlined,
            height: 52,
            fontSize: 16,
            onPressed: onStartFromScratch,
          ),
        if (onEditSplit != null && !hasMyPlan)
          AppButton(
            l10n.editOneOfTheThreeSplits,
            key: const ValueKey('r01-edit-split'),
            variant: AppButtonVariant.outlined,
            height: 52,
            fontSize: 16,
            onPressed: onEditSplit,
          ),
        if (onBuildWorkout != null || onMyWorkouts != null)
          Wrap(
            alignment: WrapAlignment.center,
            children: [
              if (onBuildWorkout != null)
                AppButton(
                  l10n.buildMyOwnWorkout,
                  key: const ValueKey('r01-build-own'),
                  variant: AppButtonVariant.text,
                  height: 48,
                  fontSize: 15,
                  onPressed: onBuildWorkout,
                ),
              if (onMyWorkouts != null)
                AppButton(
                  l10n.myWorkouts,
                  key: const ValueKey('r01-open-my-workouts'),
                  variant: AppButtonVariant.text,
                  height: 48,
                  fontSize: 15,
                  onPressed: onMyWorkouts,
                ),
            ],
          ),
      ],
    );
  }
}

/// Two links under Home's training card: change today's workout, change the
/// plan. Each is the first tap of the way there.
class PlanLinksRow extends StatelessWidget {
  const PlanLinksRow({super.key, this.onEdit, this.onChangePlan});

  final VoidCallback? onEdit;
  final VoidCallback? onChangePlan;

  @override
  Widget build(BuildContext context) {
    final l10n = AppL10n.of(context);
    if (onEdit == null && onChangePlan == null) return const SizedBox.shrink();
    return Wrap(
      key: const ValueKey('home-plan-links'),
      spacing: 8,
      children: [
        if (onEdit != null)
          AppButton(
            l10n.edit,
            key: const ValueKey('home-edit-workout'),
            icon: Icons.edit_outlined,
            variant: AppButtonVariant.text,
            height: 48,
            fontSize: 15,
            onPressed: onEdit,
          ),
        if (onChangePlan != null)
          AppButton(
            l10n.changePlan,
            key: const ValueKey('home-change-plan'),
            icon: Icons.tune,
            variant: AppButtonVariant.text,
            height: 48,
            fontSize: 15,
            onPressed: onChangePlan,
          ),
      ],
    );
  }
}

/// A yes or no over [context]: [title] and [body], a filled [yes] button and an
/// outlined [no] one. True only on [yes]; closing the sheet is a no.
Future<bool> showPlanConfirm(
  BuildContext context, {
  required String title,
  required String body,
  required String yes,
  required String no,
  required Key yesKey,
  required Key noKey,
}) async {
  final answer = await showAppSheet<bool>(
    context: context,
    children: [
      Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(title, style: AppText.titleL),
          const SizedBox(height: 4),
          Text(
            body,
            style: AppText.bodyM.copyWith(color: AppColors.onSurfaceVariant),
          ),
          const SizedBox(height: 16),
          AppButton(
            yes,
            key: yesKey,
            onPressed: () => Navigator.of(context).pop(true),
          ),
          const SizedBox(height: 10),
          AppButton(
            no,
            key: noKey,
            variant: AppButtonVariant.outlined,
            height: 48,
            fontSize: 15,
            onPressed: () => Navigator.of(context).pop(false),
          ),
        ],
      ),
    ],
  );
  return answer == true;
}

/// She has a plan of her own and tapped a split: does the split replace it?
/// True on Replace.
Future<bool> askReplacePlan(BuildContext context) {
  final l10n = AppL10n.of(context);
  return showPlanConfirm(
    context,
    title: l10n.replaceYourPlanWithThisSplit,
    body: l10n.yourPlanIsSwappedForACopy,
    yes: l10n.replace,
    no: l10n.keepMine,
    yesKey: const ValueKey('plan-replace-yes'),
    noKey: const ValueKey('plan-replace-keep'),
  );
}
