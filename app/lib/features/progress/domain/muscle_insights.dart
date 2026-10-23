/// What P06 says about her map, worked out before any word is chosen.
///
/// Each insight is a fact with its numbers, so the screen can say it in
/// either language and never lets a colour carry it alone. None of them ranks
/// her against anybody or calls a muscle weak: the most trained is hers, a
/// section she has rested is named with the days and a move or two she could
/// add, and an uneven week is described, not judged.
library;

import 'package:meta/meta.dart';

import '../../onboarding/domain/intake.dart'
    show Equipment, LifeStage, TrainingPlace;
import '../../train/domain/exercise_library.dart';
import 'muscle_map.dart';
import 'muscle_report.dart';

/// Days without a set before a section she has trained is named as resting.
const int kRestingDays = 10;

/// Her top areas in the window, most first. One to three, never empty.
@immutable
class MostTrained {
  const MostTrained(this.top);
  final List<SectionVolume> top;
}

/// A section she has trained before and not for [days] days, with moves she
/// could add for it.
@immutable
class RestingSection {
  const RestingSection({
    required this.section,
    required this.days,
    this.moves = const <LibraryExercise>[],
  });

  final MuscleSection section;
  final int days;

  /// Two or three library moves for it, screened for her life stage and her
  /// kit. Empty when the phone holds no library yet.
  final List<LibraryExercise> moves;
}

enum BalanceAxis { upperLower, frontBack }

/// How the two halves on one axis compare, with both totals.
@immutable
class Balance {
  const Balance({
    required this.axis,
    required this.first,
    required this.second,
    required this.more,
    required this.times,
  });

  final BalanceAxis axis;

  /// Upper body, or the front.
  final double first;

  /// Lower body, or the back.
  final double second;

  /// The half that had more, or null when they are about the same.
  final BodyRegion? more;

  /// 0 when every set went to [more], 1 for a little more, otherwise about
  /// how many times as much, rounded. Meaningless when [more] is null.
  final int times;

  bool get even => more == null;
}

/// Her two or three most trained sections in [window], or null when the
/// window has no sets.
MostTrained? mostTrained(MuscleReport report, MuscleWindow window) {
  final top = [
    for (final v in report.ranked(window))
      if (v.sets > 0) v,
  ].take(3).toList(growable: false);
  return top.isEmpty ? null : MostTrained(top);
}

/// The section she has rested longest, among those she has trained before and
/// not for at least [kRestingDays] days. Read over everything she ever
/// logged, not the window: "trained before" means ever. Between two rested
/// equally long, the one she trained more is named: a push-up's chest, not
/// the abs that steadied it.
RestingSection? restingSection(
  MuscleReport report, {
  List<LibraryExercise> library = const <LibraryExercise>[],
  LifeStage? lifeStage,
  TrainingPlace place = TrainingPlace.home,
  Set<Equipment> equipment = const {Equipment.none},
}) {
  MuscleSection? longest;
  var days = -1;
  for (final section in MuscleSection.values) {
    final since = report.daysSince(section);
    if (since == null || since < kRestingDays) continue;
    if (since > days ||
        (since == days &&
            report.everSets(section) > report.everSets(longest!))) {
      days = since;
      longest = section;
    }
  }
  if (longest == null) return null;
  final shown = screenForLifeStage(library, lifeStage).shown;
  return RestingSection(
    section: longest,
    days: days,
    moves: movesForSection(shown, longest, place: place, equipment: equipment),
  );
}

/// The more uneven of upper against lower and front against back in
/// [window], or null when neither axis holds a whole set.
///
/// The trunk is in neither upper nor lower body, and the sides of the
/// shoulders and hips are in neither front nor back ([regionsOf]).
Balance? balance(MuscleReport report, MuscleWindow window) {
  Balance? of(BalanceAxis axis, BodyRegion a, BodyRegion b) {
    final first = report.regionSets(window, a);
    final second = report.regionSets(window, b);
    if (first + second < 1) return null;
    final big = first >= second ? first : second;
    final small = first >= second ? second : first;
    final bigger = first >= second ? a : b;
    if (small <= 0) {
      return Balance(
        axis: axis,
        first: first,
        second: second,
        more: bigger,
        times: 0,
      );
    }
    final ratio = big / small;
    if (ratio < 1.25) {
      return Balance(
        axis: axis,
        first: first,
        second: second,
        more: null,
        times: 1,
      );
    }
    return Balance(
      axis: axis,
      first: first,
      second: second,
      more: bigger,
      times: ratio < 1.75 ? 1 : ratio.round(),
    );
  }

  double unevenness(Balance b) {
    if (b.even) return 1;
    final small = b.first < b.second ? b.first : b.second;
    final big = b.first < b.second ? b.second : b.first;
    return small <= 0 ? double.infinity : big / small;
  }

  final upperLower = of(
    BalanceAxis.upperLower,
    BodyRegion.upper,
    BodyRegion.lower,
  );
  final frontBack = of(
    BalanceAxis.frontBack,
    BodyRegion.front,
    BodyRegion.back,
  );
  if (upperLower == null) return frontBack;
  if (frontBack == null) return upperLower;
  // The more uneven axis says the more useful thing; a tie goes to upper
  // and lower body, the one she is likelier to recognise.
  return unevenness(frontBack) > unevenness(upperLower)
      ? frontBack
      : upperLower;
}
