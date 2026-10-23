/// Which illustrations each screen shows, and why they are the ones it shows.
///
/// ## One table, on purpose
///
/// Every placement in the app lives here rather than scattered through 161
/// screen files, so the whole set can be read, audited and changed in one
/// place. `AppScaffold` draws the entry for the screen it is showing; the
/// router tells it which screen that is through [ScreenScope].
///
/// ## How the pictures were chosen
///
///   * **Each one matches what the screen is for.** A food screen shows food, a
///     workout screen shows that kind of work, a coach screen shows coaching.
///   * **The sensitive screens stay calm.** Her cycle, her privacy, the safety
///     centre, her body measurements and every screen where she waits all use
///     [AppArt.meditation], stretching or the yoga mat -- never anything intense.
///   * **No treats on food screens.** There is no cake, cupcake, cookie or
///     chip anywhere in [AppArt], and there deliberately never was one placed
///     here: a picture of a treat beside a calorie total implies a judgement
///     the product itself refuses to make. The treats live only in `FoodMarks`,
///     where they label a specific recipe she chose to open. If a treat is ever
///     added to this set, it does not belong in this table.
///   * **Never the same picture twice on one screen.** Since every name here is
///     one drawing rather than one file, this is now checkable rather than a
///     convention, and `screen_art_test.dart` checks it.
///
/// ## The names changed when the pictures did
///
/// This table used to name 57 WebP files, several of which were the same
/// picture twice — `running`, `run_side`, `jogger` and `dumbbell_run` were four
/// files of a woman running. Those files are gone (see `assets/art/LICENCE.md`)
/// and the set is 32 drawings, so entries that asked for two of the same thing
/// were changed to ask for two different things. `M04` and `M10` are the two
/// that needed a real decision rather than a rename: both were "a runner and a
/// jogger", which was never two pictures.
///
/// `screen_art_test.dart` asserts every built screen is covered, none is given
/// more than two, none is given the same drawing twice, and every name has a
/// drawing behind it.
library;

import 'app_art.dart';

abstract final class ScreenArt {
  /// Screen id -> one or two illustrations, drawn at the top of the screen.
  static const Map<String, List<String>> forScreen = {
    'A01': [AppArt.headphones],
    'A03': [AppArt.meditation],
    'A04': [AppArt.meditation],
    'B01': [AppArt.strongArms, AppArt.lungeWarrior],
    'B02': [AppArt.yogaMat],
    'B03': [AppArt.boxingGloves],
    'B04': [AppArt.dance],
    'B05': [AppArt.sideStretch],
    'B06': [AppArt.gymBag],
    'B07': [AppArt.squatWeights],
    'B08': [AppArt.strongArms],
    'B09': [AppArt.running],
    'B10': [AppArt.running],
    'B11': [AppArt.strongArms],
    'B12': [AppArt.yogaMat],
    'B13': [AppArt.dance],
    'C01': [AppArt.dance],
    'C02': [AppArt.meditation],
    'C04': [AppArt.running, AppArt.fruitBasket],
    'C05': [AppArt.trainers],
    'C06': [AppArt.trainers],
    'C07': [AppArt.yogaMat],
    'C08': [AppArt.squatWeights, AppArt.lungeKneeling],
    'C09': [AppArt.meditation],
    // The consent screen. Calm, like every screen where she is reading
    // something about herself rather than doing something.
    'C09b': [AppArt.meditation],
    'C10': [AppArt.stretchSeated],
    // The back of the same card, so the same picture as the front: it is one
    // step in two passes and it should not feel like a new screen.
    'C10b': [AppArt.stretchSeated],
    'C11': [AppArt.strongArms],
    'C12': [AppArt.meditation],
    'C13': [AppArt.dance],
    'C14': [AppArt.meditation],
    'C15': [AppArt.meditation],
    'C16': [AppArt.dance, AppArt.stretchSeated],
    'E01': [AppArt.buddhaBowl],
    'E02': [AppArt.toastEgg],
    'E03': [AppArt.watermelon],
    'E04': [AppArt.plateMixed],
    'E05': [AppArt.pasta, AppArt.buddhaBowl],
    'E06': [AppArt.buddhaBowl],
    'E07': [AppArt.plateMixed, AppArt.bowlSalad],
    'E08': [AppArt.apple, AppArt.grapes],
    // E10 asks her what she cannot eat. Fruit in a basket is the least
    // judgemental thing in the set and the only food picture on any screen that
    // is about a restriction rather than a meal.
    'E10': [AppArt.fruitBasket],
    // E11 is Rahma's letter and nothing else. The art is deliberately quiet and
    // deliberately not a dish: a picture of food beside a letter about why we
    // try to eat well would be the screen changing the subject.
    'E11': [AppArt.fruitBasket],
    // Her plate, photographed and then checked: one small drawing each, so
    // the camera's window keeps the page.
    'E12': [AppArt.bruschetta],
    'E13': [AppArt.bowlSalad],
    'G01': [AppArt.trainers],
    'G02': [AppArt.meditation],
    'G03': [AppArt.yogaMat],
    'G04': [AppArt.squatWeights, AppArt.running],
    'G05': [AppArt.lungeWarrior],
    'G06': [AppArt.squatWeights],
    'G07': [AppArt.restFloor],
    'G08': [AppArt.sideStretch],
    'G10': [AppArt.steak],
    'G11': [AppArt.bowlSalad],
    'G12': [AppArt.running],
    'G13': [AppArt.lungeKneeling],
    'G14': [AppArt.sideStretch],
    'G15': [AppArt.headphones],
    'G16': [AppArt.stretchSeated],
    'G17': [AppArt.fruitBasket, AppArt.breakfast],
    'H01': [AppArt.lungeKneeling],
    'H02': [AppArt.strongArms],
    'H03': [AppArt.gymBag],
    'H04': [AppArt.trainers],
    'H05': [AppArt.squatWeights],
    'H06': [AppArt.sideStretch],
    'K01': [AppArt.lungeKneeling],
    'K02': [AppArt.boxingGloves],
    'K03': [AppArt.squatWeights, AppArt.yogaMat],
    'K04': [AppArt.gymBag],
    'K05': [AppArt.lungeWarrior],
    'K06': [AppArt.meditation],
    // The coach's setup, one thing a screen.
    'K08': [AppArt.strongArms],
    'K10': [AppArt.yogaMat, AppArt.gymBag],
    'K11': [AppArt.squatWeights],
    'K12': [AppArt.sideStretch],
    'K13': [AppArt.meditation],
    'K07': [AppArt.squatWeights],
    'K09': [AppArt.running],
    'K16': [AppArt.sideStretch],
    'K17': [AppArt.strongArms],
    'K18': [AppArt.strongArms],
    'K19': [AppArt.squatWeights],
    'K20': [AppArt.overheadRaise],
    'K21': [AppArt.meditation],
    'K22': [AppArt.stretchSeated],
    'K23': [AppArt.sideStretch, AppArt.lungeKneeling],
    'K25': [AppArt.gymBag, AppArt.trainers],
    'K26': [AppArt.lungeWarrior],
    'K27': [AppArt.bowlSalad],
    'M01': [AppArt.running],
    'M02': [AppArt.dance],
    'M03': [AppArt.strongArms],
    'M04': [AppArt.running, AppArt.dance],
    'M05': [AppArt.plank],
    'M06': [AppArt.squatWeights, AppArt.strongArms],
    'M07': [AppArt.strongArms],
    'M08': [AppArt.meditation],
    'M09': [AppArt.dance],
    'M10': [AppArt.running, AppArt.sideStretch],
    'M11': [AppArt.sideStretch],
    'M12': [AppArt.lungeKneeling],
    'M13': [AppArt.dance],
    'M14': [AppArt.running],
    'M15': [AppArt.yogaMat],
    'M16': [AppArt.running],
    'O01': [AppArt.strongArms],
    'O02': [AppArt.gymBag],
    'O03': [AppArt.trainers],
    'O04': [AppArt.meditation],
    'O05': [AppArt.squatWeights, AppArt.running],
    // What she has at home.
    'O06': [AppArt.dumbbells],
    'P01': [AppArt.running],
    'P02': [AppArt.strongArms],
    'P03': [AppArt.overheadRaise],
    'P04': [AppArt.meditation],
    // Her card: what she did, to celebrate. The weight on it is hers to add.
    'P05': [AppArt.dance],
    // Her muscles: the figure is the page's picture, so one small drawing
    // sits beside the note on how sets are counted.
    'P06': [AppArt.strongArms],
    'R01': [AppArt.dumbbells, AppArt.running],
    'R02': [AppArt.lungeWarrior, AppArt.squatWeights],
    'R03': [AppArt.overheadRaise, AppArt.yogaMat],
    'R04': [AppArt.squatWeights],
    'R05': [AppArt.sideStretch, AppArt.lungeKneeling],
    'R06': [AppArt.plank],
    'R07': [AppArt.dumbbells],
    'R08': [AppArt.overheadRaise],
    'R09': [AppArt.restFloor],
    'R11': [AppArt.yogaMat, AppArt.gymBag],
    'R12': [AppArt.trainers],
    'R13': [AppArt.strongArms],
    'R14': [AppArt.stretchSeated, AppArt.dumbbells],
    'R15': [AppArt.squatWeights],
    'T01': [AppArt.breakfast, AppArt.running],
    'T02': [AppArt.strongArms],
    'T03': [AppArt.running],
    'T04': [AppArt.stretchSeated],
    'T05': [AppArt.restFloor],
    'T07': [AppArt.trainers, AppArt.yogaMat],
    // T08 is T07's completed branch, and it was missing from this table for as
    // long as the route rendered the not-built panel: a screen behind
    // `NotBuiltYet` is skipped by the loop in `screen_art_test.dart`, so the
    // gap only became visible the day the screen was built. One drawing, and
    // the one the product already means by "you did it" (R10's hero) — the file
    // comment on `first_week_view.dart` is explicit that finishing the first
    // week is celebrated QUIETLY, because the confetti belongs to a workout.
    'T08': [AppArt.strongArms],
    'T09': [AppArt.dance],
    'W01': [AppArt.running],
    'W02': [AppArt.lungeKneeling],
    'W03': [AppArt.spinBike, AppArt.yogaMat],
    'W04': [AppArt.dumbbells],
    'W05': [AppArt.trainers],
    'W06': [AppArt.buddhaBowl, AppArt.bowlSalad],
    'W07': [AppArt.breakfast, AppArt.bruschetta],
    'W08': [AppArt.trainers],
    'W09': [AppArt.sideStretch],
    'W10': [AppArt.running],
    'X01': [AppArt.meditation],
    'X03': [AppArt.yogaMat],
    'Y01': [AppArt.meditation],
    'Y02': [AppArt.stretchSeated],
    'Y03': [AppArt.meditation],
    'Y04': [AppArt.sideStretch],
    'Y05': [AppArt.yogaMat],
    'Y06': [AppArt.stretchSeated, AppArt.yogaMat],
    // Y07 "Meals for today" and Y13 "About cycle phases" are cycle screens, and
    // the calm rule at the top of this file governs them: her cycle uses
    // meditation, stretching or the yoga mat. They carried fruit and nuts,
    // which read as a food prescription attached to her period — the one place
    // in the product where a picture of food beside a phase implies a rule
    // about what she should be eating this week. The food marks belong on the
    // Eat screens, where she came looking for them.
    'Y07': [AppArt.meditation, AppArt.sideStretch],
    'Y08': [AppArt.meditation],
    'Y09': [AppArt.stretchSeated],
    'Y10': [AppArt.sideStretch],
    'Y12': [AppArt.meditation],
    'Y13': [AppArt.yogaMat, AppArt.stretchSeated],
    'Z01': [AppArt.gymBag, AppArt.fruitBasket],
    'Z02': [AppArt.dumbbells, AppArt.squatWeights],
    'Z03': [AppArt.lungeWarrior],
    'Z04': [AppArt.fruitBasket, AppArt.apple],
    'Z05': [AppArt.bowlSalad],
    'Z06': [AppArt.pasta],
    'Z07': [AppArt.spinBike],
    'Z08': [AppArt.gymBag],
    'Z09': [AppArt.yogaMat],
    'Z10': [AppArt.dance],
    'Z11': [AppArt.gymBag],
    'Z12': [AppArt.buddhaBowl],
    'Z13': [AppArt.running],
    'Z14': [AppArt.dumbbells],
    'Z15': [AppArt.running],
    'Z16': [AppArt.yogaMat],
    'Z17': [AppArt.dance],
    'Z18': [AppArt.gymBag],
  };

  /// Screens that already draw a large centred illustration of their own. They
  /// count as illustrated, and get no second one on top of the first.
  static const Map<String, String> drawsOwnHero = {
    'C03': AppArt.stretchSeated,
    'G09': AppArt.strongArms,
    'R10': AppArt.strongArms,
  };

  /// Screens composed like a cover, which set their illustrations inside the
  /// page — beside the figure or the section they illustrate — instead of in a
  /// strip across the top. They still draw exactly what [forScreen] gives them,
  /// through [inlineFor].
  ///
  /// The setup questions `O01` to `O04` and `O06` set one small drawing beside
  /// their title, so the answers fit the screen without scrolling. `P06`'s
  /// figure is its picture, so its drawing sits at the foot of the page.
  static const Set<String> placesOwnArt = {
    'T01',
    'R01',
    'E01',
    'K07',
    'O01',
    'O02',
    'O03',
    'O04',
    'O06',
    'P06',
  };

  /// The illustrations to draw at the top of [screenId], or none.
  static List<String> headerFor(String? screenId) {
    if (screenId == null ||
        drawsOwnHero.containsKey(screenId) ||
        placesOwnArt.contains(screenId)) {
      return const [];
    }
    return forScreen[screenId] ?? const [];
  }

  /// The illustrations a cover screen places for itself, or none.
  static List<String> inlineFor(String? screenId) =>
      screenId != null && placesOwnArt.contains(screenId)
      ? forScreen[screenId] ?? const []
      : const [];
}
