/// The programme O05 offers her, and the catalogue it is chosen from.
///
/// # There is no authored programme content yet
///
/// `6-v2/plans/G2-onboarding-program.md` §9 Q8 states it plainly: three
/// programme *names* appear in the mockup's copy and `R03` shows the shape of a
/// training day, but **no programme content is authored** — no week templates,
/// no day templates, no prescribed sets. The same owner-track dependency as the
/// 124 workout videos.
///
/// So this file models the *shape* of a programme and contains exactly one
/// entry, which carries only what the design already shows on screen. It
/// deliberately does not contain invented exercises, sets, reps or loads.
/// Inventing them would be worse than having none: a plausible-looking week of
/// made-up training is indistinguishable from a real one in review, and it would
/// reach a pregnant woman's phone.
///
/// TODO(owner): author the `programs` catalogue — roughly 12–20 programmes ×
/// weeks × day templates with prescribed sets — and replace
/// [kStartingProgramCatalogue] with it. Until then `publishStartingPlan` has
/// nothing to publish and O05's card is a preview of content that does not exist.
///
/// # Why this is a preview and not the decision
///
/// `plans/**` is server-authored (`SCHEMA-SPINE.md` §5): a client that could
/// write its own plan could write its own prescribed weights, and §2 rule 2
/// would stop being enforceable. The real selection runs in a Cloud Function.
/// What lives here is the **pure preview** G2 §5 describes — enough to draw
/// O05's card, including offline, with a shared fixture test asserting the two
/// agree once both exist.
///
/// # Life stage is recorded here, not filtered here
///
/// `LifeStageSafetyFilter` is server-side and, more importantly, has no authored
/// exclusion list to apply (G2 §9 Q5 — no one has signed off what a pregnancy or
/// postpartum programme may contain). This client-side selector therefore takes
/// no clinical decision at all. It does not quietly hand a pregnant woman a
/// programme it has judged safe, because it is in no position to judge, and it
/// does not invent an exclusion list to look careful.
library;

import 'package:meta/meta.dart';

import 'intake.dart';

/// A starting programme, as much of it as the design puts on screen.
///
/// The copy is **not** here. `programId` is a key the presentation layer maps to
/// dictionary entries, so a programme name never becomes a hardcoded English
/// string in a widget, and the domain layer stays testable without a widget
/// tree.
///
/// Note what is absent: no weight, no target weight, no numeric input that could
/// become a sort key (§2 rule 11), and no per-day counter (§2 rule 3).
@immutable
class StartingProgram {
  const StartingProgram({
    required this.programId,
    required this.weeks,
    required this.daysPerWeek,
    required this.sessionLength,
    required this.quiet,
    required this.equipment,
  });

  /// Matches `programs/{programId}` and the published plan version's
  /// `programId`. The presentation layer maps it to her language.
  final String programId;

  final int weeks;

  /// Sessions per week. A weekly quantity, never a run of days.
  final int daysPerWeek;

  /// Minutes per session.
  final int sessionLength;

  /// Nothing that jumps, nothing a neighbour downstairs would hear. The single
  /// most load-bearing property in this product's promise.
  final bool quiet;

  final Set<Equipment> equipment;

  @override
  bool operator ==(Object other) =>
      other is StartingProgram && other.programId == programId;

  @override
  int get hashCode => programId.hashCode;

  @override
  String toString() => 'StartingProgram($programId)';
}

/// The one programme that exists, and it exists as a name only.
///
/// Its numbers are the ones the design prints on O05's card — "8 weeks · quiet ·
/// no equipment". Nothing more is claimed about it.
const StartingProgram beginnerFoundations = StartingProgram(
  programId: 'beginner_foundations',
  weeks: 8,
  daysPerWeek: 3,
  sessionLength: 15,
  quiet: true,
  equipment: {Equipment.none},
);

/// The bundled catalogue.
///
/// Never queried from Firestore: it is content, it is small, and selection is a
/// pure in-memory filter (G2 §2.6). One entry today; see the TODO at the top of
/// this file.
const List<StartingProgram> kStartingProgramCatalogue = [beginnerFoundations];

/// Picks the programme O05 shows her.
///
/// A pure function of her answers over a bundled list — no Firestore query, no
/// index, no network, and the same result offline. With a real catalogue this
/// becomes a genuine filter on place, equipment, days and minutes; with one
/// entry it returns that entry, and saying so is more honest than writing a
/// filter that has nothing to filter.
///
/// Returns null when the catalogue is empty, which the caller must handle — an
/// empty catalogue is a content failure, not a woman with no options.
StartingProgram? selectStartingProgram(
  Intake intake, {
  List<StartingProgram> catalogue = kStartingProgramCatalogue,
}) {
  if (catalogue.isEmpty) return null;

  // This took `intake` and ignored it — `return catalogue.first` — so a woman
  // who chose five days at a gym was shown the same three-days-at-home
  // programme as everyone else. O05 exists to reflect her answers back to her,
  // so ignoring them there is the one place it is least forgivable.
  //
  // Scored rather than filtered: the catalogue is thin (one authored programme
  // today), and a filter that matches nothing would leave her with a blank
  // screen. Scoring always returns the closest thing we have.
  StartingProgram? best;
  var bestScore = -1000;
  for (final programme in catalogue) {
    var score = 0;

    // Equipment is a hard constraint, not a preference. Offering a dumbbell
    // programme to a woman who owns nothing is offering her nothing, so a
    // programme needing kit she does not have is pushed below everything else
    // rather than excluded outright — see the note on scoring above.
    if (programme.equipment.difference(intake.equipment).isNotEmpty) {
      score -= 100;
    }

    // Her stated shape of week. Closeness, not equality: three days when she
    // asked for four is a better offer than nothing.
    score -= (programme.daysPerWeek - intake.days).abs() * 2;
    score -= (programme.sessionLength - intake.minutes).abs() ~/ 5;

    // At home means quiet matters; a gym programme need not be.
    if (intake.place == TrainingPlace.home && programme.quiet) score += 3;

    if (score > bestScore) {
      bestScore = score;
      best = programme;
    }
  }
  return best;
}

/// Whether her life stage actually changes the training she is handed.
///
/// **Measured, not declared.** It runs [selectStartingProgram] once per
/// [LifeStage] over the same answers and reports whether any of them lands
/// somewhere different. So it is false today for the two reasons the top of
/// this file gives — nothing here reads `intake.lifeStage`, and the catalogue
/// holds one programme — and it turns true by itself on the day either of those
/// stops being so. Nobody has to remember to flip it.
///
/// O04 is its one caller, and this is why it exists. That screen offered
/// *"Pelvic floor first, once your doctor says you are ready"* and *"Gentler
/// movements, nothing on the belly"* to every woman who ticked those rows, and
/// then handed all four life stages `beginner_foundations`. An earlier pass
/// removed two false clinical claims from those rows and replaced them with
/// false claims about us, on the only screen in the product that asks about a
/// pregnancy. The promises are kept in the dictionary and shown only when this
/// is true — the arrangement `care_links.dart` uses for Y11's button, which
/// appears only when there is a page behind it.
bool lifeStageShapesTraining({
  List<StartingProgram> catalogue = kStartingProgramCatalogue,
}) {
  const answers = Intake(place: TrainingPlace.home, days: 3, minutes: 15);
  final baseline = selectStartingProgram(answers, catalogue: catalogue);
  for (final stage in LifeStage.values) {
    if (stage == LifeStage.none) continue;
    final chosen = selectStartingProgram(
      answers.copyWith(lifeStage: stage),
      catalogue: catalogue,
    );
    if (chosen?.programId != baseline?.programId) return true;
  }
  return false;
}
