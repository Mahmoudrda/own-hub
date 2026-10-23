/// The plan she picked on O05 or R02, kept as its family so the tier tabs can
/// still move between its levels. Null means the best fit for her answers.
library;

import 'dart:async';

import '../features/onboarding/domain/intake_repository.dart';
import '../features/onboarding/domain/starting_program.dart';
import 'app_changes.dart';
import 'workout_library_state.dart';

abstract final class ChosenProgramme {
  static String? family;

  /// Makes [programme] the one Train and Home follow.
  ///
  /// A session she opened from the library, or a day of the old plan she had
  /// opened, no longer applies to a different plan.
  static void choose(StartingProgram programme) {
    if (family == programme.family) return;
    family = programme.family;
    WorkoutLibraryState.instance
      ..openedSlot = null
      ..chosenRowId = null;
    AppChanges.bump();
  }

  /// Her days a week become the split's: it is what she will train. Her weekday
  /// picks go only when their count no longer matches.
  static void alignDays(IntakeRepository repository, int days) {
    if (repository.read().days == days) return;
    unawaited(repository.merge(days: days, weekdays: const {}));
  }

  /// The programme to follow among [fits], best first: her pick when it still
  /// fits, else the best fit.
  static StartingProgram? among(List<StartingProgram> fits) {
    if (fits.isEmpty) return null;
    final picked = family;
    if (picked != null) {
      for (final programme in fits) {
        if (programme.family == picked) return programme;
      }
    }
    return fits.first;
  }

  static void reset() => family = null;
}
