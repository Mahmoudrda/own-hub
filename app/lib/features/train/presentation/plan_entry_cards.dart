/// The doors into changing a plan: the two links under Home's training card,
/// and the yes-or-no asked before a split replaces her plan. The rest of the
/// ways to change a plan are in the "…" of the programme page (R02).
library;

import 'package:flutter/material.dart';

import '../../../l10n/app_l10n.dart';
import '../../../theme/app_tokens.dart';
import '../../../ui/app_button.dart';
import '../../../ui/app_sheet.dart';

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
