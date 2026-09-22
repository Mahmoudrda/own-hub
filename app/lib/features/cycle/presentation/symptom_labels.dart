/// Turning a [LoggedSymptom] into words she can read.
///
/// ## Why these are joined, not templated
///
/// `PHASE1-FIXES.md` #5: parameterising "{move} saved" produced Arabic that
/// cannot agree in gender with a varying subject, and the fix was to restructure
/// into a form needing no agreement. The same constraint applies here, from the
/// other direction: there is no dictionary sentence that says "you logged low
/// energy and moderate cramps", and composing one from fragments would produce
/// ungrammatical Arabic.
///
/// So a reason is rendered as **label-and-value pairs joined by a separator** —
/// "Energy: Low · Cramps: Mild". A colon and a middle dot are punctuation rather
/// than grammar, so they are correct in both languages, and each half is a word
/// the dictionary already owns as a chip label on Y04.
///
/// ## All nine symptoms can be named now
///
/// `Sleep`, `Bloating` and `Bleeding`, and the values `Poor`, `Good`,
/// `Spotting` and `Heavy`, used to return **zero matches** against
/// `app_en.arb`, so [loggedSymptomLabel] returned an empty string for three of
/// the nine reasons and [loggedSymptomsSentence] dropped them.
///
/// That was the reportable half of a worse gap: `bleeding == heavy` is half of
/// §2.5's severe gate, and the interface could neither let her log it nor name
/// it back to her. Both halves are closed — Y04 has a bleeding row, and the
/// three arms below say what she logged.
library;

import '../../../l10n/app_l10n.dart';
import '../domain/symptom_context.dart';

/// One logged symptom, in words. Empty when the dictionary has no word for it.
String loggedSymptomLabel(AppL10n l10n, LoggedSymptom symptom) {
  return switch (symptom) {
    LoggedSymptom.lowEnergy => '${l10n.energy}: ${l10n.low}',
    LoggedSymptom.mildCramps => '${l10n.cramps}: ${l10n.mild}',
    LoggedSymptom.moderateCramps => '${l10n.cramps}: ${l10n.moderate}',
    LoggedSymptom.severeCramps => '${l10n.cramps}: ${l10n.severe}',
    LoggedSymptom.moreHunger => '${l10n.appetite}: ${l10n.moreHungry}',
    LoggedSymptom.lessHunger => '${l10n.appetite}: ${l10n.lessHungry}',
    // The three that used to render as nothing. Same label-and-value shape as
    // the six above, so no new grammar is invented in either language.
    LoggedSymptom.moderateBloating => '${l10n.bloating}: ${l10n.moderate}',
    LoggedSymptom.heavyBleeding => '${l10n.bleeding}: ${l10n.heavy}',
    LoggedSymptom.poorSleep => '${l10n.sleep}: ${l10n.poor}',
  };
}

/// The reason line Y03's card and Y05's "What you logged" render.
///
/// Falls back to the dictionary's own sentence when the reason is exactly the
/// pair that sentence describes, so the shipped copy is used where it is
/// actually true — and a computed list is used everywhere else, rather than
/// telling every woman the mockup's "low energy, mild cramps".
String loggedSymptomsSentence(AppL10n l10n, List<LoggedSymptom> reason) {
  const mockupPair = {LoggedSymptom.lowEnergy, LoggedSymptom.mildCramps};
  if (reason.length == 2 && reason.toSet().containsAll(mockupPair)) {
    return l10n.lowEnergyMildCrampsTodayOnly;
  }

  final parts = <String>[
    for (final symptom in reason)
      if (loggedSymptomLabel(l10n, symptom).isNotEmpty)
        loggedSymptomLabel(l10n, symptom),
  ];

  return parts.join(' · ');
}
