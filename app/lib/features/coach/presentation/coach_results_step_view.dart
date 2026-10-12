/// `K11` — Your clients' results.
///
/// Matches `6-v2/src/screens-coach.mjs` → `K11`. What a coach most wants on her
/// page, and the one thing she cannot put there herself.
///
/// A result is another woman's body. The product's rule is that a coach may
/// show a client's result only with that client's agreement, given in the
/// client's own app (`consent.dart`: the coach can create a request and
/// nothing else). So this step does not ask her to upload anything. It shows
/// her the card the app draws for every result, a before and an after side by
/// side ([BeforeAfterCard]), says who adds the photos and who decides, and
/// tells her where she will ask once she has clients here. Nothing on it is an
/// example result: the two photos are placeholders and there are no figures.
library;

import 'package:flutter/material.dart';

import '../../../l10n/app_l10n.dart';
import '../../../theme/app_tokens.dart';
import '../../../ui/app_sage_note.dart';
import '../../coachbrand/presentation/before_after_card.dart';
import 'coach_setup_scaffold.dart';
import 'coach_view_models.dart';

class CoachResultsStepView extends StatelessWidget {
  const CoachResultsStepView({
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
      step: CoachSetupStep.results,
      title: l10n.yourClientsResults,
      subtitle: l10n.eachResultIsABeforeAndAn,
      onBack: onBack,
      onSaveAndClose: onSaveAndClose,
      onPrimary: () => goToScreen(context, 'K12', onContinue),
      children: [
        CoachFieldLabel(l10n.howItWillLook),
        const BeforeAfterCard(),
        Text(
          l10n.facesStayHiddenUnlessSheChoosesTo,
          style: AppText.bodyM.copyWith(color: AppColors.onSurfaceVariant),
        ),
        AppSageNote(l10n.whenYourCheckIsDoneAskAny),
      ],
    );
  }
}
