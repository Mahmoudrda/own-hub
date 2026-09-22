/// `K03` — What you coach.
///
/// Matches `6-v2/src/screens-coach.mjs` → `K03`.
///
/// Three specialties, no more. The cap is [CoachProfile.maxSpecialties] and it
/// is enforced in [CoachSetupViewModel.toggleSpecialty] rather than here — a
/// widget that counted chips would be a second copy of the rule, and the
/// security rules enforce a third (`specialties.size() <= 3`).
///
/// Every chip is an **id**, not a typed word. The client-side filters read the
/// same vocabulary she picked from, which is the only reason a cap of three
/// means anything: a coach who could type her own specialties would rank for
/// none of them.
library;

import 'package:flutter/material.dart';

import '../../../l10n/app_l10n.dart';
import '../../../ui/app_chip_row.dart';
import '../domain/coach_profile.dart';
import 'coach_setup_scaffold.dart';
import 'coach_view_models.dart';

/// The dictionary name for each specialty. A switch, so a specialty added
/// without a minted string is a compile error.
String specialtyLabel(AppL10n l10n, Specialty specialty) => switch (specialty) {
  Specialty.postpartum => l10n.postpartum,
  Specialty.beginners => l10n.beginners,
  Specialty.strength => l10n.strength,
  Specialty.weightLoss => l10n.weightLoss,
  Specialty.pregnancy => l10n.pregnancy,
};

String languageLabel(AppL10n l10n, CoachLanguage language) =>
    switch (language) {
      CoachLanguage.arabic => l10n.arabic,
      CoachLanguage.english => l10n.english,
    };

String placeLabel(AppL10n l10n, ClientPlace place) => switch (place) {
  ClientPlace.atHome => l10n.atHome,
  ClientPlace.ladiesOnlyGym => l10n.ladiesOnlyGym,
};

class CoachSpecialtiesView extends StatefulWidget {
  const CoachSpecialtiesView({
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
  State<CoachSpecialtiesView> createState() => _CoachSpecialtiesViewState();
}

class _CoachSpecialtiesViewState extends State<CoachSpecialtiesView> {
  @override
  Widget build(BuildContext context) {
    final l10n = AppL10n.of(context);
    final model = widget.model;

    return CoachSetupScaffold(
      step: CoachSetupStep.specialties,
      title: l10n.whatDoYouCoach,
      subtitle: l10n.pickUpToThreeClientsFilterBy,
      onBack: () => goToScreen(context, 'K02', widget.onBack),
      onSaveAndClose: widget.onSaveAndClose,
      onPrimary: model.canAdvanceFrom(CoachSetupStep.specialties)
          ? () => goToScreen(context, 'K04', widget.onContinue)
          : null,
      children: [
        // Wrapped rather than scrolled: an option she coaches must never sit
        // off-screen where she will not find it.
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            for (final specialty in Specialty.values)
              AppChip(
                specialtyLabel(l10n, specialty),
                selected: model.specialties.contains(specialty),
                onTap: () => setState(() => model.toggleSpecialty(specialty)),
              ),
          ],
        ),
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
