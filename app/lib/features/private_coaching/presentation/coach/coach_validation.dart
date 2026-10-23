/// What the coach's forms check before they ask the server.
///
/// The server stays the judge. These mirror its rules (`profiles.update`,
/// `packages._validate`) so a form can say what is wrong first. Package rules
/// sit on top of `PackageDraft.problems`, which is looser than the server for
/// a short title, a short or empty description and an empty includes list.
library;

import '../../domain/coach_profile.dart';
import '../../domain/coaching_contract.dart';
import '../../domain/pricing.dart';

const int kHeadlineMin = 10;
const int kTitleMin = 3;
const int kDescriptionMin = 20;
const int kIncludeMin = 2;

bool _within(String text, int min, int max) {
  final n = text.trim().length;
  return n >= min && n <= max;
}

/// The portfolio fields that fail, by name: `headline`, `approach`.
List<String> portfolioProblems({
  required String headline,
  required String approach,
}) => <String>[
  if (!_within(headline, kHeadlineMin, CoachingLimits.headlineMax)) 'headline',
  if (!_within(
    approach,
    CoachingLimits.approachTextMin,
    CoachingLimits.approachTextMax,
  ))
    'approach',
];

/// The package fields that fail, by request key.
List<String> packageProblems(PackageDraft draft) {
  final out = <String>{...draft.problems()};
  if (!_within(draft.title, kTitleMin, CoachingLimits.packageTitleMax)) {
    out.add('title');
  }
  if (!_within(
    draft.description,
    kDescriptionMin,
    CoachingLimits.packageDescriptionMax,
  )) {
    out.add('description');
  }
  if (draft.includes.isEmpty ||
      draft.includes.any(
        (line) => !_within(line, kIncludeMin, CoachingLimits.includeTextMax),
      )) {
    out.add('includes');
  }
  return out.toList();
}

/// The coach price whose final price is [final], or null when no whole price
/// gives it. The server never sends her own price back, only the final one;
/// [finalPrice] only goes up, so there is at most one answer.
int? coachPriceFromFinal(int final_) {
  if (final_ <= 0) return null;
  final guess = final_ * 100 ~/ (100 + CoachingLimits.marginPercent);
  for (var c = guess - 2; c <= guess + 2; c++) {
    if (c > 0 && finalPrice(c) == final_) return c;
  }
  return null;
}
