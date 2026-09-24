/// How one set reads, in her language — asked for, agreed to, or saved.
///
/// A set is one of three shapes, and each reads differently:
///
///  * **loaded** — "12 kg × 10". A weight and a count.
///  * **bodyweight** — "12 reps". There is no load, so none is stated; "0 kg"
///    is a number she never lifted.
///  * **timed** — "30 seconds". A hold has no repetitions to count.
///
/// R07's button, R09's undo bar and R08's sheet all say the same set, so the
/// three sentences are chosen in one place rather than in three widgets that
/// could drift apart. Every figure goes through [weightLabel] or [countLabel],
/// which keep Western digits in Arabic (P0-A11Y-01).
library;

import '../../../domain/format/number_label.dart';
import '../../../l10n/app_l10n.dart';
import '../domain/weight_label.dart';

bool _loaded(num? weightKg, int? reps) =>
    weightKg != null && weightKg > 0 && reps != null;

bool _timed(int? reps, int? holdSeconds) => reps == null && holdSeconds != null;

/// "Move 2 of 5" for the bar at the top of the session screens, or empty.
///
/// Empty for anything that is not a real position in a real list: no numbers
/// at all, a session with no moves, or a number past the end. R07, R08 and R09
/// all carried the fixed `move2Of5`, which said "Move 2 of 5" over the first
/// move of a four-move session; the first replacement then read "Move 1 of 0"
/// on a screen opened with no session behind it. Saying nothing is the honest
/// reading of not knowing, and it is decided once here rather than in three
/// app bars.
String moveTitle(AppL10n l10n, int? number, int? total) {
  if (number == null || total == null) return '';
  if (total <= 0 || number <= 0 || number > total) return '';
  return l10n.moveMoveOfTotal(countLabel(number), countLabel(total));
}

/// "12 kg × 10", "12 reps" or "30 seconds". Empty when nothing is stated.
String setFigure(AppL10n l10n, {num? weightKg, int? reps, int? holdSeconds}) {
  if (_loaded(weightKg, reps)) {
    return l10n.weightKgReps(weightLabel(weightKg!), countLabel(reps!));
  }
  if (_timed(reps, holdSeconds)) {
    return l10n.secondsSeconds(countLabel(holdSeconds!));
  }
  if (reps != null) return l10n.repsReps(countLabel(reps));
  return '';
}

/// The button that logs the set: "Done · 12 kg × 10", "Done — 12 reps",
/// "Done — 30 seconds".
String setDoneLabel(
  AppL10n l10n, {
  num? weightKg,
  int? reps,
  int? holdSeconds,
}) {
  if (_loaded(weightKg, reps)) {
    return l10n.doneWeightKgReps(weightLabel(weightKg!), reps!);
  }
  if (_timed(reps, holdSeconds)) {
    return l10n.doneSecondsSeconds(countLabel(holdSeconds!));
  }
  if (reps != null) return l10n.doneRepsReps(countLabel(reps));
  return l10n.done_54ca1;
}

/// The undo bar's sentence once it is logged: "Set 2 saved · 12 kg × 10".
String setSavedLabel(
  AppL10n l10n, {
  required int setNumber,
  num? weightKg,
  int? reps,
  int? holdSeconds,
}) {
  if (_loaded(weightKg, reps)) {
    return l10n.setSetnumberSavedWeightKgReps(
      setNumber,
      weightLabel(weightKg!),
      reps!,
    );
  }
  if (_timed(reps, holdSeconds)) {
    return l10n.setSetnumberSavedSecondsSeconds(
      countLabel(setNumber),
      countLabel(holdSeconds!),
    );
  }
  if (reps != null) {
    return l10n.setSetnumberSavedRepsReps(
      countLabel(setNumber),
      countLabel(reps),
    );
  }
  // A set that prescribes neither a count nor a hold has no figure to repeat.
  return l10n.done_54ca1;
}
