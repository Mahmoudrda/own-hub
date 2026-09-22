/// §2.4 — "Suggestions follow the symptoms she logged today, never an inferred
/// cycle phase."
///
/// Plan §5, and this is the sentence the whole file is shaped around:
///
/// > **Enforced by absence of capability**, the pattern G3 used for the streak.
/// > The method takes **one** parameter — today's check-in — and its signature
/// > carries no date, no `CycleDocument`, no phase and no clock. A phase cannot
/// > influence a suggestion because a phase cannot be passed to the only
/// > function that produces one.
///
/// So [resolve] has exactly one parameter. Not "one required parameter and some
/// optional ones" — one. `resolver_signature_test.dart` parses this file and
/// fails the build if a second appears, whatever it is called, because the day
/// someone adds `{DateTime? today}` for a plausible reason is the day rule 4
/// stops being structural and becomes a convention.
///
/// ## Why the collaborators are constructor arguments
///
/// [gate] and [selector] are injected at construction, which does not weaken the
/// guarantee: the claim is about what can influence *one day's* decision, and a
/// collaborator fixed for the lifetime of the resolver cannot carry today's
/// date. A `DateTime` parameter on [resolve] could. The distinction is the point
/// — it is the argument list of the decision function that is load-bearing.
///
/// ## Why `adaptation.workoutSuggestions` is not consulted here
///
/// §3.3 gates `gentlerOffered` on `adaptation.workoutSuggestions`, which is a
/// field on `cycle/current`. Reading it here would mean passing the document to
/// [resolve], which is the one thing this file may not do. So the split is:
/// **the resolver decides what today's symptoms warrant, and the view model
/// decides whether her settings let it be shown.**
///
/// That split has a second property worth stating, because it is the more
/// important one: `adaptation` gates the *gentler card only*. [Suppressed] is
/// never gated by a preference. A woman who turned workout suggestions off has
/// not consented to being shown a workout on a day she logged severe pain, and
/// if suppression were reached through the same switch, turning that switch off
/// would turn suppression off with it.
library;

import 'day_suggestion.dart';
import 'severe_symptom_gate.dart';
import 'symptom_context.dart';
import 'today_check_in.dart';

/// Picks the alternative session offered by [GentlerOption].
///
/// G9 OQ-4's fallback: "`GentlerSessionSelector` picks from the bundled library
/// and the card is labelled **'App suggestion'**". Until G2 publishes
/// `workout.easierOption`, every session this returns is
/// [SessionProvenance.appSuggestion] — it is not able to claim otherwise,
/// because it has no source of coach-approved sessions to read.
class GentlerSessionSelector {
  const GentlerSessionSelector();

  /// The bundled gentle option.
  ///
  /// Takes no arguments, deliberately. A selector parameterised by date would
  /// reintroduce through the back door exactly what [resolve]'s signature keeps
  /// out of the front.
  GentlerSession select() => const GentlerSession(
    minutes: 15,
    floorOnly: true,
    provenance: SessionProvenance.appSuggestion,
  );
}

/// The single implementation of rule 4.
///
/// Published to G4 so R01's "Not feeling it today?" row and Y03's card cannot
/// drift apart (§7.2, OQ-5) — one rule, one implementation, one test, the way
/// rule 9 has one undo.
class SymptomSuggestionResolver {
  const SymptomSuggestionResolver({
    this.gate = const SevereSymptomGate(),
    this.selector = const GentlerSessionSelector(),
    this.careContentVersion = kUnreviewedCareContentVersion,
  });

  final SevereSymptomGate gate;
  final GentlerSessionSelector selector;

  /// The bundled guidance version, from Remote Config in production.
  final String careContentVersion;

  /// Today's suggestion, from today's check-in.
  ///
  /// **One parameter.** See the library comment — that is the rule, not a
  /// stylistic preference.
  DaySuggestion resolve(TodayCheckIn checkIn) {
    // §3.3: a check-in with every field null is `noCheckIn`, not `usual`. Her
    // plan stands and nothing is suggested.
    if (checkIn.isEmpty) return const NoSuggestion();

    final context = SymptomContext.of(checkIn);
    final logged = context.logged;

    // §5: "Evaluated before any suggestion is built; the resolver calls it
    // first and returns immediately." Nothing below this line can offer a
    // workout on a severe day, because nothing below this line runs.
    if (gate.evaluate(checkIn)) {
      return Suppressed(
        reason: logged,
        guidance: SevereGuidance(contentVersion: careContentVersion),
        careRoute: const CareRoute(directory: CareDirectory.bundled),
      );
    }

    // §3.3 `gentlerOffered`: low energy, OR mild/moderate cramps, OR moderate
    // bloating. Appetite and sleep are logged and reported, and neither changes
    // the training suggestion on its own.
    final qualifying = <LoggedSymptom>[
      for (final symptom in logged)
        if (symptom == LoggedSymptom.lowEnergy ||
            symptom == LoggedSymptom.mildCramps ||
            symptom == LoggedSymptom.moderateCramps ||
            symptom == LoggedSymptom.moderateBloating)
          symptom,
    ];

    if (qualifying.isEmpty) return KeepPlan(reason: logged);

    return GentlerOption(reason: qualifying, alternative: selector.select());
  }
}

/// The guidance version shipped while OQ-11 is open.
///
/// Named rather than a bare string so that it is greppable and so that the one
/// place it is set says what it means: **no clinically reviewed Egyptian care
/// content exists yet**, and this version identifies that absence rather than
/// claiming a review that has not happened.
const String kUnreviewedCareContentVersion = 'care-content-unreviewed';
