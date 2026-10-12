/// `K10` — How you coach.
///
/// Matches `6-v2/src/screens-coach.mjs` → `K10`. The two small choices that
/// used to share `K03` with her specialties: the languages she coaches in and
/// where her clients train. Both are chips from fixed vocabularies, so the
/// filters a client uses read exactly what the coach picked.
library;

import 'package:flutter/material.dart';

import '../../../l10n/app_l10n.dart';
import '../../../ui/app_chip_row.dart';
import '../domain/coach_profile.dart';
import 'coach_setup_scaffold.dart';
import 'coach_specialties_view.dart' show languageLabel, placeLabel;
import 'coach_view_models.dart';

class CoachHowYouCoachView extends StatefulWidget {
  const CoachHowYouCoachView({
    super.key,
    required this.model,
    this.onContinue,
    this.onBack,
    this.onSaveAndClose,
  });

  final CoachSetupViewModel model;
  final VoidCallback? onContinue;
  final VoidCallback? onBack;
  final VoidCallback? onSaveAndClose;

  @override
  State<CoachHowYouCoachView> createState() => _CoachHowYouCoachViewState();
}

class _CoachHowYouCoachViewState extends State<CoachHowYouCoachView> {
  @override
  Widget build(BuildContext context) {
    final l10n = AppL10n.of(context);
    final model = widget.model;

    return CoachSetupScaffold(
      step: CoachSetupStep.howYouCoach,
      title: l10n.howYouCoach,
      subtitle: l10n.clientsLookForACoachByLanguage,
      onBack: widget.onBack,
      onSaveAndClose: widget.onSaveAndClose,
      onPrimary: () => goToScreen(context, 'K04', widget.onContinue),
      children: [
        CoachFieldLabel(l10n.languages),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            for (final language in CoachLanguage.values)
              AppChip(
                languageLabel(l10n, language),
                selected: model.languages.contains(language),
                onTap: () => setState(() => model.toggleLanguage(language)),
              ),
          ],
        ),
        CoachFieldLabel(l10n.whereYourClientsTrain),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            for (final place in ClientPlace.values)
              AppChip(
                placeLabel(l10n, place),
                selected: model.clientPlaces.contains(place),
                onTap: () => setState(() => model.togglePlace(place)),
              ),
          ],
        ),
      ],
    );
  }
}
