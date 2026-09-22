/// G08 — swap an exercise. **Approved first, ask second.**
///
/// Matches `6-v2/src/screens-coached.mjs` → `G08`. Its design note: *"Substitutions
/// the coach approved in advance turn a blocked session into a completed one.
/// Asking is offered after them, and skipping stays available without asking
/// anyone."*
///
/// The order of this sheet is the whole design:
///
///  1. the alternatives her coach approved **in advance**, which travel with
///     the assignment and therefore work with no signal;
///  2. asking her for something else, which costs a reply and a wait;
///  3. skipping, which costs nothing and needs nobody.
///
/// A sheet that opened with "Ask your coach" would turn a knee that hurts today
/// into a session abandoned today. The approved list exists so she can finish.
library;

import 'package:flutter/material.dart';

import '../../../l10n/app_l10n.dart';
import '../../../theme/app_tokens.dart';
import '../../../ui/app_button.dart';
import '../../../ui/app_list_item.dart';
import '../../../ui/app_scaffold.dart';
import '../../../ui/app_sheet.dart';

/// One coach-approved option, as the sheet renders it.
@immutable
class SwapOption {
  const SwapOption({
    required this.exerciseId,
    required this.name,
    required this.reason,
    this.selected = false,
  });

  final String exerciseId;

  /// "Box squat to a chair".
  final String name;

  /// "Coach-approved · same muscles, less depth".
  final String reason;

  final bool selected;
}

class SwapExerciseView extends StatelessWidget {
  const SwapExerciseView({
    super.key,
    this.onClose,
    this.onChoose,
    this.onAskCoach,
    this.onSkip,
    this.moveName,
    this.options,
  });

  final VoidCallback? onClose;

  /// Applies the swap for **today only**. The published plan is untouched.
  final ValueChanged<SwapOption>? onChoose;

  final VoidCallback? onAskCoach;
  final VoidCallback? onSkip;

  final String? moveName;

  /// Null renders the two options the mockup shows. An **empty list** is a
  /// different thing and renders no options at all — a coach who approved
  /// nothing must not appear to have approved something.
  final List<SwapOption>? options;

  @override
  Widget build(BuildContext context) {
    final l10n = AppL10n.of(context);
    final shown =
        options ??
        [
          SwapOption(
            exerciseId: 'box_squat',
            name: l10n.boxSquatToAChair,
            reason: l10n.coachApprovedSameMusclesLessDepth,
            selected: true,
          ),
          SwapOption(
            exerciseId: 'glute_bridge',
            name: l10n.gluteBridge,
            reason: l10n.coachApprovedNothingStanding,
          ),
        ];

    return Stack(
      children: [
        AppScaffold(
          appBar: AppTopBar(
            title: l10n.move2Of5,
            onBack: onClose,
            leadingIcon: Icons.close,
          ),
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        moveName ?? l10n.gobletSquat,
                        style: AppText.headline,
                      ),
                      const SizedBox(height: 2),
                      Text(
                        l10n.fromCoachSara,
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
        Align(
          alignment: Alignment.bottomCenter,
          child: AppSheet(
            gap: 10,
            children: [
              Text(l10n.swapThisExercise, style: AppText.titleL),
              Text(
                // Why she is not waiting: the coach already said yes.
                l10n.saraApprovedTheseInAdvanceSoYou,
                style: AppText.bodyM.copyWith(
                  color: AppColors.onSurfaceVariant,
                ),
              ),
              for (final option in shown)
                AppListItem(
                  title: option.name,
                  subtitle: option.reason,
                  variant: option.selected
                      ? AppCardVariant.selected
                      : AppCardVariant.outlined,
                  onTap: onChoose == null ? null : () => onChoose!(option),
                  trailing: option.selected
                      ? const Icon(
                          Icons.check_circle,
                          size: 24,
                          color: AppColors.primary,
                        )
                      : null,
                ),
              AppButton(
                l10n.askSaraForSomethingElse,
                variant: AppButtonVariant.outlined,
                height: 48,
                fontSize: 15,
                onPressed: onAskCoach,
              ),
              // Last, and always available.
              AppButton(
                l10n.skipThisExercise,
                variant: AppButtonVariant.text,
                height: 44,
                fontSize: 15,
                onPressed: onSkip,
              ),
            ],
          ),
        ),
      ],
    );
  }
}
