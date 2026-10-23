/// The one session R11 leads with (§15, Von Restorff and choice overload).
///
/// A list of equal rows asks her to choose before she has a reason to; the
/// second video study's point is that a screen should know which one thing
/// matters and set it apart. The recommendation is not a guess about her:
/// the session she already picked, else the first that fits what she told the
/// app — quiet and without equipment at home, no longer than the minutes she
/// gave — else the first there is.
library;

import '../../onboarding/domain/intake.dart';
import 'train_repository.dart';

LibraryWorkout? recommendedWorkout(
  List<LibraryWorkout> rows,
  Intake intake, {
  String? chosenRowId,
}) {
  if (rows.isEmpty) return null;
  if (chosenRowId != null) {
    for (final row in rows) {
      if (row.id == chosenRowId) return row;
    }
  }
  final atHome = intake.place == TrainingPlace.home;
  for (final row in rows) {
    if (atHome && (!row.quiet || row.needsEquipment)) continue;
    if (row.minutes > intake.minutes) continue;
    return row;
  }
  return rows.first;
}
