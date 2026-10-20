/// The programme O05 offers her, and the catalogue it is chosen from.
///
/// # The programmes are drafted, not yet signed off
///
/// `assets/content/starting_programmes.json` holds nine programmes: three plans
/// by goal, each in a home, a home-with-dumbbells and a gym variant (D47). They
/// are written in the shape the owner's console publishes
/// (`AuthoredProgramme`), held to the same `workoutProblems`, and every move is
/// a catalogue or seed exercise carrying that exercise's own tags. The file
/// says `review: drafted ..., pending Rahma's sign-off`, and nothing here
/// pretends otherwise.
///
/// [StartingProgrammes.adopt] reads the file once at start. Until it has, the
/// catalogue is the single placeholder below, which is what a build with no
/// content looked like and what a test that never loads the file still sees.
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

import 'dart:convert';

import 'package:meta/meta.dart';

import '../../train/domain/workout_library.dart';
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
    this.goals = const {},
    this.places = const {},
    this.adapts = false,
    this.rank = 0,
    this.tier = TrainingLevel.beginner,
    String? family,
  }) : family = family ?? programId;

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

  /// Kit she must own. [Equipment.none] and [Equipment.mat] are never required.
  final Set<Equipment> equipment;

  /// The goals it is written for. Empty means any.
  final Set<TrainingGoal> goals;

  /// Where it can be done. Empty means anywhere.
  final Set<TrainingPlace> places;

  /// Its days a week and its minutes follow her answers (a session is trimmed
  /// to her minutes, and she trains the first of its sessions that many days),
  /// so neither is a reason to prefer or refuse it.
  final bool adapts;

  /// How much it asks of where she trains: a programme for the gym outranks one
  /// for dumbbells, which outranks one for the floor, when she can do them all.
  final int rank;

  /// Which of the three versions of its plan this is.
  final TrainingLevel tier;

  /// The id of the plan the three tiers share (the beginner version's id), the
  /// key the presentation layer maps to its copy.
  final String family;

  @override
  bool operator ==(Object other) =>
      other is StartingProgram && other.programId == programId;

  @override
  int get hashCode => programId.hashCode;

  @override
  String toString() => 'StartingProgram($programId)';
}

/// The placeholder a build holds until [StartingProgrammes.adopt] has read the
/// file, and the id O05 still has copy for.
///
/// Its numbers are the ones the design printed on O05's card — "8 weeks · quiet ·
/// no equipment". Nothing more is claimed about it.
const StartingProgram beginnerFoundations = StartingProgram(
  programId: 'beginner_foundations',
  weeks: 8,
  daysPerWeek: 3,
  sessionLength: 15,
  quiet: true,
  equipment: {Equipment.none},
);

/// The id of the plan a programme belongs to: its id without the tier suffix
/// the intermediate and advanced versions carry.
String programmeFamily(String programId) {
  for (final tier in const ['intermediate', 'advanced']) {
    if (programId.endsWith('_$tier')) {
      return programId.substring(0, programId.length - tier.length - 1);
    }
  }
  return programId;
}

/// The programmes in the bundled file, and the content behind each.
///
/// Held in one place so O05 (the card), R02 (the week) and R03 (today's
/// session) read the same programme.
abstract final class StartingProgrammes {
  /// Where the file is bundled.
  static const String assetPath = 'assets/content/starting_programmes.json';

  static List<StartingProgram> _catalogue = const [beginnerFoundations];
  static WorkoutLibrary _library = WorkoutLibrary.empty;
  static final Map<String, ({String en, String ar})> _summaries = {};
  static String _review = '';

  /// What the file says about its own sign-off.
  static String get review => _review;

  static List<StartingProgram> get catalogue => _catalogue;

  /// The programme with [programId], or null when none is loaded under it.
  static AuthoredProgramme? programme(String programId) {
    for (final p in _library.programmes) {
      if (p.programId == programId) return p;
    }
    return null;
  }

  /// A line on what the programme asks of her, in [languageCode].
  static String summary(String programId, String languageCode) {
    final s = _summaries[programId];
    if (s == null) return '';
    return languageCode == 'ar' ? s.ar : s.en;
  }

  /// Reads the file's text. Throws [FormatException] when any programme breaks
  /// a rule; the catalogue is then left as it was, so a bad file never leaves
  /// her half of a programme.
  static void adopt(String source) {
    final decoded = jsonDecode(source);
    if (decoded is! Map) throw const FormatException('not a library');
    final json = decoded.cast<String, Object?>();
    final library = WorkoutLibrary.parse(json);
    final catalogue = <StartingProgram>[];
    final summaries = <String, ({String en, String ar})>{};
    for (final raw in (json['programmes'] as List?) ?? const []) {
      if (raw is! Map) continue;
      final meta = raw.cast<String, Object?>();
      final id = meta['programId'] as String;
      catalogue.add(
        StartingProgram(
          programId: id,
          weeks: (meta['weeks'] as num?)?.toInt() ?? 8,
          daysPerWeek: 3,
          sessionLength: 15,
          quiet: meta['quiet'] != false,
          equipment: _wires(
            meta['equipment'],
            Equipment.values,
            (e) => e.wireName,
          ),
          goals: _wires(meta['goals'], TrainingGoal.values, (e) => e.wireName),
          places: _wires(
            meta['places'],
            TrainingPlace.values,
            (e) => e.wireName,
          ),
          adapts: true,
          rank: (meta['rank'] as num?)?.toInt() ?? 0,
          tier: TrainingLevel.fromWire(meta['tier']) ?? TrainingLevel.beginner,
          family: programmeFamily(id),
        ),
      );
      summaries[id] = (
        en: meta['summaryEn'] as String? ?? '',
        ar: meta['summaryAr'] as String? ?? '',
      );
    }
    if (catalogue.isEmpty) throw const FormatException('no programmes');
    _library = library;
    _catalogue = List.unmodifiable(catalogue);
    _summaries
      ..clear()
      ..addAll(summaries);
    _review = json['review'] as String? ?? '';
  }

  /// Back to the placeholder. For tests.
  @visibleForTesting
  static void reset() {
    _catalogue = const [beginnerFoundations];
    _library = WorkoutLibrary.empty;
    _summaries.clear();
    _review = '';
  }
}

Set<T> _wires<T>(Object? wires, List<T> values, String Function(T) wireOf) => {
  for (final w in (wires as List?) ?? const [])
    ...values.where((v) => wireOf(v) == w),
};

/// The bundled catalogue: the programmes in the file once it is read.
///
/// Never queried from Firestore: it is content, it is small, and selection is a
/// pure in-memory filter (G2 §2.6).
List<StartingProgram> get kStartingProgramCatalogue =>
    StartingProgrammes.catalogue;

/// What she owns, as far as selection is concerned.
///
/// Nothing is always owned, and a mat is not kit worth refusing a floor
/// programme over. At a ladies' gym, or both, the gym's own kit is hers too.
/// This is read at selection only: it is never written back into her answers.
Set<Equipment> _kitFor(Intake intake) => {
  Equipment.none,
  Equipment.mat,
  ...intake.equipment,
  if (intake.place != TrainingPlace.home) ...{
    Equipment.dumbbells,
    Equipment.bands,
    Equipment.bench,
    Equipment.barbell,
    Equipment.cable,
    Equipment.smithMachine,
    Equipment.machine,
  },
};

/// Picks the programme O05 shows her.
///
/// A pure function of her answers over a bundled list: no Firestore query, no
/// index, no network, and the same result offline.
///
/// **The kit is a hard rule.** A programme that needs something she does not
/// have is never offered, so no programme at all (null) is what she gets when
/// nothing fits; an empty catalogue and an unsatisfiable one are both a content
/// failure to the caller, never a woman handed training she cannot do.
///
/// Her [tier] comes first (her own level unless the caller names another), so
/// a catalogue with only one tier still answers. Among what fits, her goal
/// comes next, then how much the programme asks of
/// where she trains (the gym's over the dumbbells' over the floor's), then how
/// close its week is to hers (programmes that adapt to her days and minutes
/// have nothing to be close to).
StartingProgram? selectStartingProgram(
  Intake intake, {
  List<StartingProgram>? catalogue,
  TrainingLevel? tier,
}) {
  final wanted = tier ?? intake.level;
  final programmes = catalogue ?? kStartingProgramCatalogue;
  final have = _kitFor(intake);

  StartingProgram? best;
  List<int>? bestKey;
  for (final programme in programmes) {
    if (!programme.equipment.every(have.contains)) continue;
    if (programme.places.isNotEmpty &&
        !programme.places.contains(intake.place)) {
      continue;
    }
    // Compared left to right; a bigger number wins at the first difference.
    final key = [
      programme.tier == wanted ? 1 : 0,
      programme.goals.isEmpty || programme.goals.contains(intake.goal) ? 1 : 0,
      programme.rank,
      programme.adapts
          ? 0
          : -((programme.daysPerWeek - intake.days).abs() * 2 +
                (programme.sessionLength - intake.minutes).abs() ~/ 5),
      // At home quiet matters; a gym programme need not be.
      intake.place == TrainingPlace.home && programme.quiet ? 1 : 0,
    ];
    if (bestKey == null || _later(key, bestKey)) {
      best = programme;
      bestKey = key;
    }
  }
  return best;
}

bool _later(List<int> a, List<int> b) {
  for (var i = 0; i < a.length; i++) {
    if (a[i] != b[i]) return a[i] > b[i];
  }
  return false;
}

/// Whether her life stage actually changes the training she is handed.
///
/// **Measured, not declared.** It runs [selectStartingProgram] once per
/// [LifeStage] over the same answers and reports whether any of them lands
/// somewhere different. So it is false today: nothing here reads
/// `intake.lifeStage`, because the gentler sessions for pregnancy and after a
/// birth sit inside each programme and are chosen from its list
/// (`programmeSessionsFor`), not between programmes. It turns true by itself on
/// the day a stage selects a different programme. Nobody has to remember to
/// flip it.
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
bool lifeStageShapesTraining({List<StartingProgram>? catalogue}) {
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
