/// Y06 — Choose what feels right.
///
/// Matches `screens-cycle.mjs` → `Y06`. Her planned session, the alternative,
/// and rest — "the wording keeps all three choices equal … so the app never
/// praises training through pain."
///
/// ## "coach-approved" is cut, not faked
///
/// The design labels the option "15 min · floor only · **coach-approved**". That
/// claim needs `workout.easierOption` from G2 and a session-level today-only
/// apply from G4, and **neither exists** (OQ-4). The plan's instruction if they
/// are declined is explicit: the card is labelled "App suggestion" and "the
/// words 'coach-approved' must then be cut rather than faked".
///
/// So this screen renders the `appSuggestion` pill and **no subtitle on the
/// option row**. The dictionary's `15 min · floor only · coach-approved` is one
/// string and there is no coach-free variant of it, so the honest render is to
/// omit it rather than to display a claim no coach has made.
///
/// ## Taking the option changes today only
///
/// Never the week, never the plan. This screen has no path to `plans/**`.
library;

import 'package:flutter/material.dart';

import '../../../domain/flags/feature_flags.dart';
import '../../../domain/format/number_label.dart';
import '../../../l10n/app_l10n.dart';
import '../../../routing/app_router.dart';
import '../../../theme/app_tokens.dart';
import '../../../ui/app_button.dart';
import '../../../ui/app_card.dart';
import '../../../ui/app_list_item.dart';
import '../../../ui/app_scaffold.dart';
import '../domain/day_suggestion.dart';
import '../domain/symptom_context.dart';
import 'symptom_labels.dart';

class GentlerOptionView extends StatelessWidget {
  const GentlerOptionView({
    super.key,
    required this.reason,
    this.provenance = SessionProvenance.appSuggestion,
    this.onUseOption,
    this.onKeepWorkout,
    this.onRest,
    this.onWhy,
    this.onClose,
    this.plannedMinutes,
  });

  final List<LoggedSymptom> reason;
  final SessionProvenance provenance;

  final VoidCallback? onUseOption;
  final VoidCallback? onKeepWorkout;
  final VoidCallback? onRest;
  final VoidCallback? onWhy;
  final VoidCallback? onClose;

  /// Length of her planned session; defaults to today's programme session.
  final int? plannedMinutes;

  @override
  Widget build(BuildContext context) {
    final l10n = AppL10n.of(context);
    final logged = loggedSymptomsSentence(l10n, reason);
    final minutes = plannedMinutes ?? AppRouter.todaySessionMinutes();

    return AppScaffold(
      appBar: AppTopBar(
        title: l10n.myCycle,
        onBack: onClose,
        leadingIcon: Icons.close,
      ),
      children: [
        AppCard(
          children: [
            Text(l10n.aGentlerOptionToday, style: AppText.titleM),
            if (logged.isNotEmpty)
              Text(
                logged,
                style: AppText.bodyM.copyWith(
                  color: AppColors.onSurfaceVariant,
                ),
              ),
            AppListItem(
              variant: AppCardVariant.filled,
              leading: const Icon(
                Icons.fitness_center,
                size: 22,
                color: AppColors.onSurfaceVariant,
              ),
              title: l10n.plannedFullBodyStrength,
              subtitle: minutes > 0
                  ? l10n.minutesMinYourProgram(countLabel(minutes))
                  : '',
            ),
            // The option, only when there is a session behind it. "Use this
            // option" opened her planned full-body workout, the very thing it
            // offered to replace; with no gentle session in the library it is
            // not offered at all.
            if (onUseOption != null)
              AppListItem(
                variant: AppCardVariant.selected,
                leading: const Icon(
                  Icons.self_improvement,
                  size: 22,
                  color: AppColors.tertiary,
                ),
                title: l10n.optionGentleMobility,
                // No subtitle. See the library note — the only string available
                // claims a coach approved this, and none has.
                subtitle:
                    provenance == SessionProvenance.appSuggestion ||
                        !AppRouter.featureFlags.isOn(Feature.coachedLife)
                    ? l10n.appSuggestion
                    : l10n.fromYourCoachUnchanged,
              ),
            Row(
              children: [
                if (onUseOption != null) ...[
                  Expanded(
                    child: AppButton(
                      l10n.useThisOption,
                      height: 48,
                      fontSize: 15,
                      onPressed: onUseOption,
                    ),
                  ),
                  const SizedBox(width: 8),
                ],
                Expanded(
                  child: AppButton(
                    l10n.keepMyWorkout,
                    variant: AppButtonVariant.outlined,
                    height: 48,
                    fontSize: 15,
                    onPressed: onKeepWorkout,
                  ),
                ),
              ],
            ),
            Row(
              children: [
                Expanded(
                  child: AppButton(
                    l10n.restToday,
                    variant: AppButtonVariant.text,
                    height: 40,
                    fontSize: 15,
                    onPressed: onRest,
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: AppButton(
                    l10n.whyThisSuggestion,
                    variant: AppButtonVariant.text,
                    height: 40,
                    fontSize: 15,
                    onPressed: onWhy,
                  ),
                ),
              ],
            ),
          ],
        ),
        Text(
          l10n.stopIfMovementMakesYourSymptomsWorse,
          style: AppText.bodyM.copyWith(color: AppColors.onSurfaceVariant),
        ),
      ],
    );
  }
}
