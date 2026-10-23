/// H01: three answers become up to five coaches, then everyone A to Z.
///
/// A coach is never ranked by how many clients she has coached, by ratings or
/// by how long she has been on Own Hub. Only the three answers count, and a
/// tie goes to the name A to Z.
library;

import 'coach_profile.dart';
import 'coaching_contract.dart';

/// What she says on H01.
class MatchAnswers {
  const MatchAnswers({
    required this.goal,
    required this.place,
    required this.budgetBand,
  });

  /// One of `CoachingEnums.goals`.
  final String goal;

  /// One of `CoachingEnums.places`.
  final String place;

  /// One of `CoachingEnums.budgetBands`.
  final String budgetBand;
}

class CoachMatchResult {
  const CoachMatchResult(this.coach, this.score);

  final CoachProfile coach;
  final int score;
}

abstract final class CoachMatch {
  /// Per goal, the specialties that serve it. Index 0 is the best fit.
  ///
  /// - stronger: strength first, then muscle, then endurance
  /// - buildMuscle: muscle gain first, then strength
  /// - loseSteadily: fat loss first, then healthy eating, then endurance
  /// - feelBetter: mobility first, then healthy eating, then beginners
  /// - backIntoIt: beginners first, then postnatal return, then mobility
  static const Map<String, List<String>> goalSpecialties =
      <String, List<String>>{
        'stronger': <String>['strength', 'muscleGain', 'endurance'],
        'buildMuscle': <String>['muscleGain', 'strength'],
        'loseSteadily': <String>['fatLoss', 'healthyEating', 'endurance'],
        'feelBetter': <String>['mobility', 'healthyEating', 'beginners'],
        'backIntoIt': <String>['beginners', 'postnatalReturn', 'mobility'],
      };

  /// Points for the first specialty, then one less for each after it.
  static const int goalPoints = 4;

  /// Points for a place she can be trained at.
  static const int placePoints = 3;

  /// Points when the cheapest active package fits her budget.
  static const int budgetPoints = 2;

  /// The most a month (28 days) may cost, per band, in final pounds. Null
  /// means no limit.
  static const Map<String, int?> bandCeilingEgp = <String, int?>{
    'under1500': 1499,
    'from1500to3000': 3000,
    'over3000': null,
  };

  /// Places a coach trains at that serve [place]. Online coaching reaches a
  /// woman wherever she trains.
  static bool _servesPlace(CoachProfile coach, String place) {
    final where = coach.trainsWhere;
    if (where.contains('online')) return true;
    return switch (place) {
      'home' => where.contains('home'),
      'gym' => where.contains('gym'),
      _ => where.contains('home') || where.contains('gym'),
    };
  }

  static int scoreOf(MatchAnswers answers, CoachProfile coach) {
    var score = 0;
    final wanted = goalSpecialties[answers.goal] ?? const <String>[];
    for (var i = 0; i < wanted.length; i++) {
      if (coach.specialties.contains(wanted[i])) {
        score += goalPoints - i;
        break;
      }
    }
    if (_servesPlace(coach, answers.place)) {
      score += placePoints;
      if (answers.place == 'home' &&
          coach.specialties.contains('homeTraining')) {
        score += 1;
      }
      if (answers.place == 'gym' && coach.specialties.contains('gymTraining')) {
        score += 1;
      }
    }
    final cheapest = coach.fromMonthlyEgp;
    final ceiling = bandCeilingEgp[answers.budgetBand];
    if (cheapest != null && (ceiling == null || cheapest <= ceiling)) {
      score += budgetPoints;
    }
    return score;
  }

  static int _byName(CoachMatchResult a, CoachMatchResult b) =>
      _compareNames(a.coach, b.coach);

  static int _compareNames(CoachProfile a, CoachProfile b) {
    final byName = a.displayName.toLowerCase().compareTo(
      b.displayName.toLowerCase(),
    );
    return byName != 0 ? byName : a.uid.compareTo(b.uid);
  }

  /// Published coaches (the server publishes a page while she has an active
  /// package) who are taking clients.
  static List<CoachProfile> _open(List<CoachProfile> coaches) => <CoachProfile>[
    for (final c in coaches)
      if (c.published && c.acceptingClients) c,
  ];

  /// Up to [CoachingLimits.matchResultsMax] best fits, best first, ties by
  /// name A to Z. A coach who fits on none of the three is left out.
  static List<CoachMatchResult> rank(
    MatchAnswers answers,
    List<CoachProfile> coaches,
  ) {
    final scored =
        <CoachMatchResult>[
          for (final coach in _open(coaches))
            CoachMatchResult(coach, scoreOf(answers, coach)),
        ].where((r) => r.score > 0).toList()..sort((a, b) {
          final byScore = b.score.compareTo(a.score);
          return byScore != 0 ? byScore : _byName(a, b);
        });
    return scored.take(CoachingLimits.matchResultsMax).toList();
  }

  /// Everyone she can ask, A to Z. Never ordered by clients or ratings.
  static List<CoachProfile> allCoachesAtoZ(List<CoachProfile> coaches) {
    final list = <CoachProfile>[
      for (final c in coaches)
        if (c.published) c,
    ];
    list.sort(_compareNames);
    return list;
  }
}
