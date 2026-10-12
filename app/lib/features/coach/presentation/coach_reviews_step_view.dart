/// `K12` — What your clients say.
///
/// Matches `6-v2/src/screens-coach.mjs` → `K12`. Only a woman a coach trains
/// here can write about her, so a review on a coach's page cannot be invented,
/// pasted in or bought. This step shows the shape one takes (a "Coached here"
/// label over her words, first name only) with nothing written in it, and
/// says where the coach will ask once she has clients.
library;

import 'package:flutter/material.dart';

import '../../../l10n/app_l10n.dart';
import '../../../theme/app_tokens.dart';
import '../../../ui/app_pill.dart';
import '../../../ui/app_sage_note.dart';
import '../../../ui/hand/hand.dart';
import 'coach_setup_scaffold.dart';
import 'coach_view_models.dart';

class CoachReviewsStepView extends StatelessWidget {
  const CoachReviewsStepView({
    super.key,
    this.onContinue,
    this.onBack,
    this.onSaveAndClose,
  });

  final VoidCallback? onContinue;
  final VoidCallback? onBack;
  final VoidCallback? onSaveAndClose;

  @override
  Widget build(BuildContext context) {
    final l10n = AppL10n.of(context);
    return CoachSetupScaffold(
      step: CoachSetupStep.reviews,
      title: l10n.whatYourClientsSay,
      subtitle: l10n.onlyWomenYouCoachHereCanWrite,
      onBack: onBack,
      onSaveAndClose: onSaveAndClose,
      onPrimary: () => goToScreen(context, 'K02', onContinue),
      children: [
        CoachFieldLabel(l10n.howItWillLook),
        // A review with no words in it: the lines are where hers will go.
        HandSurface(
          seed: handSeed(['review-shape']),
          fill: AppColors.surfaceLowest,
          frame: AppColors.outline,
          padding: const EdgeInsets.all(14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              AppPill(l10n.coachedHere, icon: Icons.verified),
              const SizedBox(height: 12),
              const HandRule(seed: 81, height: 10),
              const HandRule(seed: 82, height: 10),
              const FractionallySizedBox(
                widthFactor: 0.6,
                child: HandRule(seed: 83, height: 10),
              ),
            ],
          ),
        ),
        Text(
          l10n.herWordsShowWithHerFirstName,
          style: AppText.bodyM.copyWith(color: AppColors.onSurfaceVariant),
        ),
        AppSageNote(l10n.whenYourCheckIsDoneAskAny),
      ],
    );
  }
}
