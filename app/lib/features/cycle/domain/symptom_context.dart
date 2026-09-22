/// What G9 publishes to G3, G4 and G5 — logged symptoms, and nothing else.
///
/// Plan §5: "The value object published to G4, G5 and G3 has fields for logged
/// symptoms **only**: no `cycleDay`, no `phase`, no `startDate`. A consumer
/// cannot render 'because you are on day 2' because it is never given a day 2."
///
/// This is the downstream half of rule 4. `SymptomSuggestionResolver` keeps a
/// phase out of the *decision*; [SymptomContext] keeps it out of every consumer
/// that acts on the decision, so the rule cannot be reintroduced one screen
/// further along by someone who never read this plan.
library;

import 'package:meta/meta.dart';

import 'today_check_in.dart';

/// One thing she logged that a suggestion may name as its reason.
///
/// Deliberately an enum of *logged facts*, not free text and not a severity
/// score: Y03's card and Y05's "What you logged" render these, and a reason that
/// could hold arbitrary text is a reason that could one day hold "day 2 of your
/// cycle".
enum LoggedSymptom {
  lowEnergy,
  mildCramps,
  moderateCramps,
  severeCramps,
  moderateBloating,
  heavyBleeding,
  moreHunger,
  lessHunger,
  poorSleep,
}

/// Today's logged symptoms, for a consumer outside this feature.
@immutable
class SymptomContext {
  const SymptomContext({
    this.energy,
    this.cramps,
    this.appetite,
    this.sleep,
    this.bloating,
    this.bleeding,
  });

  /// Nothing logged today.
  static const SymptomContext none = SymptomContext();

  /// Projects a check-in. Note that nothing else is accepted: there is no
  /// `from(checkIn, date)` overload, and adding one would be a visible change.
  factory SymptomContext.of(TodayCheckIn checkIn) => SymptomContext(
    energy: checkIn.energy,
    cramps: checkIn.cramps,
    appetite: checkIn.appetite,
    sleep: checkIn.sleep,
    bloating: checkIn.bloating,
    bleeding: checkIn.bleeding,
  );

  final Energy? energy;
  final Cramps? cramps;
  final Appetite? appetite;
  final Sleep? sleep;
  final Bloating? bloating;
  final Bleeding? bleeding;

  bool get isEmpty =>
      energy == null &&
      cramps == null &&
      appetite == null &&
      sleep == null &&
      bloating == null &&
      bleeding == null;

  /// The logged facts, in the order Y05 reads them out.
  ///
  /// Used as `DaySuggestion.reason`, which is why it is derived here rather than
  /// assembled by each caller: "a suggestion with no logged reason is
  /// unconstructible, so 'a date alone changed it' cannot be expressed" (§5).
  List<LoggedSymptom> get logged {
    final out = <LoggedSymptom>[];
    if (energy == Energy.low) out.add(LoggedSymptom.lowEnergy);
    switch (cramps) {
      case Cramps.mild:
        out.add(LoggedSymptom.mildCramps);
      case Cramps.moderate:
        out.add(LoggedSymptom.moderateCramps);
      case Cramps.severe:
        out.add(LoggedSymptom.severeCramps);
      case Cramps.none:
      case null:
        break;
    }
    if (bloating == Bloating.moderate) out.add(LoggedSymptom.moderateBloating);
    if (bleeding == Bleeding.heavy) out.add(LoggedSymptom.heavyBleeding);
    if (appetite == Appetite.high) out.add(LoggedSymptom.moreHunger);
    if (appetite == Appetite.low) out.add(LoggedSymptom.lessHunger);
    if (sleep == Sleep.poor) out.add(LoggedSymptom.poorSleep);
    return out;
  }

  @override
  bool operator ==(Object other) =>
      other is SymptomContext &&
      other.energy == energy &&
      other.cramps == cramps &&
      other.appetite == appetite &&
      other.sleep == sleep &&
      other.bloating == bloating &&
      other.bleeding == bleeding;

  @override
  int get hashCode =>
      Object.hash(energy, cramps, appetite, sleep, bloating, bleeding);
}
