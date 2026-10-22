/// "Update my saved workout?": asked once after she changes a workout or a plan
/// day she keeps. Update writes the change to the saved version; Just this time
/// leaves the saved version alone and the change is for today.
library;

import 'package:flutter/material.dart';

import '../../../l10n/app_l10n.dart';
import '../../../theme/app_tokens.dart';
import '../../../ui/app_button.dart';
import '../../../ui/app_sheet.dart';

/// What an edit would update: a workout she saved, or a day of her plan.
enum SavedKind { workout, plan }

/// Asks the question and answers true for Update. Closing the sheet is Just
/// this time.
Future<bool> askUpdateSaved(BuildContext context, SavedKind kind) async {
  final l10n = AppL10n.of(context);
  final yes = await showAppSheet<bool>(
    context: context,
    children: [
      Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            kind == SavedKind.plan
                ? l10n.updateMyPlan
                : l10n.updateMySavedWorkout,
            style: AppText.titleL,
          ),
          const SizedBox(height: 4),
          Text(
            kind == SavedKind.plan
                ? l10n.thisDayInYourPlanWillChange
                : l10n.yourChangesWillReplaceTheSavedVersion,
            style: AppText.bodyM.copyWith(color: AppColors.onSurfaceVariant),
          ),
          const SizedBox(height: 16),
          AppButton(
            l10n.update,
            key: const ValueKey('r03-update-yes'),
            onPressed: () => Navigator.of(context).pop(true),
          ),
          const SizedBox(height: 10),
          AppButton(
            l10n.justThisTime,
            key: const ValueKey('r03-update-no'),
            variant: AppButtonVariant.outlined,
            height: 48,
            fontSize: 15,
            onPressed: () => Navigator.of(context).pop(false),
          ),
        ],
      ),
    ],
  );
  return yes == true;
}
