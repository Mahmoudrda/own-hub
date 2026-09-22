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
///   * **No treats on food screens.** Cake, cupcakes, cookies and fries are in
///     the set but appear nowhere a food is logged or planned: a picture there
///     would imply a judgement the product itself refuses to make.
///   * **Never the same picture twice on one screen.** Where a screen already
///     shows an illustration in its empty state, its header uses a different one.
///
/// `screen_art_test.dart` asserts every built screen is covered, none shows
/// more than two, and every name has a file behind it.
library;

import 'app_art.dart';

abstract final class ScreenArt {
  /// Screen id -> one or two illustrations, drawn at the top of the screen.
  static const Map<String, List<String>> forScreen = {
    'A01': [AppArt.headphones],
    'A02': [AppArt.flexBicep],
    'A03': [AppArt.meditation],
    'A04': [AppArt.meditation],
    'B01': [AppArt.flexBicep, AppArt.lungeWarrior],
    'B02': [AppArt.yogaMat],
    'B03': [AppArt.glovesOutline],
    'B04': [AppArt.dance],
    'B05': [AppArt.sideStretch],
    'B06': [AppArt.gymBag],
    'B07': [AppArt.squatWeights],
    'B08': [AppArt.strongArms],
    'B09': [AppArt.running],
    'B10': [AppArt.jogger],
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
    'C10': [AppArt.stretchSeated],
    'C11': [AppArt.flexBicep],
    'C12': [AppArt.meditation],
    'C13': [AppArt.dance],
    'C14': [AppArt.meditation],
    'C15': [AppArt.meditation],
    'C16': [AppArt.dance, AppArt.stretchSeated],
    'E01': [AppArt.buddhaBowl],
    'E02': [AppArt.toastEgg],
    'E03': [AppArt.watermelon],
    'E04': [AppArt.plateMixed],
    'E05': [AppArt.pasta, AppArt.bowlPotato],
    'E06': [AppArt.buddhaBowl],
    'E07': [AppArt.platterGrill, AppArt.saladWood],
    'E08': [AppArt.orange, AppArt.grapes],
    'G01': [AppArt.trainers],
    'G02': [AppArt.meditation],
    'G03': [AppArt.yogaMat],
    'G04': [AppArt.squatWeights, AppArt.running],
    'G05': [AppArt.lungeWarrior],
    'G06': [AppArt.backSquat],
    'G07': [AppArt.restFloor],
    'G08': [AppArt.sideStretch],
    'G10': [AppArt.steak],
    'G11': [AppArt.saladBlue],
    'G12': [AppArt.running],
    'G13': [AppArt.lungeKneeling],
    'G14': [AppArt.sideStretch],
    'G15': [AppArt.headphones],
    'G16': [AppArt.stretchSeated],
    'G17': [AppArt.fruitSalad, AppArt.breakfast],
    'H01': [AppArt.lungeKneeling],
    'H02': [AppArt.flexBicep],
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
    'K07': [AppArt.squatWeights],
    'K09': [AppArt.jogger],
    'K16': [AppArt.sideStretch],
    'K17': [AppArt.strongArms],
    'K18': [AppArt.flexBicep],
    'K19': [AppArt.squatWeights],
    'K20': [AppArt.overheadRaise],
    'K21': [AppArt.meditation],
    'K22': [AppArt.stretchSeated],
    'K23': [AppArt.sideStretch, AppArt.lungeKneeling],
    'K25': [AppArt.gymBag, AppArt.trainers],
    'K26': [AppArt.lungeWarrior],
    'K27': [AppArt.saladWood],
    'M01': [AppArt.runSide],
    'M02': [AppArt.dance],
    'M03': [AppArt.flexBicep],
    'M04': [AppArt.running, AppArt.jogger],
    'M05': [AppArt.plank],
    'M06': [AppArt.squatWeights, AppArt.strongArms],
    'M07': [AppArt.flexBicep],
    'M08': [AppArt.meditation],
    'M09': [AppArt.dance],
    'M10': [AppArt.jogger, AppArt.running],
    'M11': [AppArt.sideStretch],
    'M12': [AppArt.lungeKneeling],
    'M13': [AppArt.dance],
    'M14': [AppArt.running],
    'M15': [AppArt.yogaMat],
    'M16': [AppArt.dumbbellRun],
    'O01': [AppArt.strongArms, AppArt.running],
    'O02': [AppArt.gymBag, AppArt.dumbbells],
    'O03': [AppArt.trainers, AppArt.yogaMat],
    'O04': [AppArt.meditation],
    'O05': [AppArt.squatWeights, AppArt.running],
    'P01': [AppArt.running],
    'P02': [AppArt.strongArms],
    'P03': [AppArt.overheadRaise],
    'P04': [AppArt.meditation],
    'R01': [AppArt.dumbbells, AppArt.running],
    'R02': [AppArt.lungeWarrior, AppArt.squatWeights],
    'R03': [AppArt.barbellPress, AppArt.yogaMat],
    'R04': [AppArt.backSquat],
    'R05': [AppArt.sideStretch, AppArt.lungeKneeling],
    'R06': [AppArt.sidePlank],
    'R07': [AppArt.dumbbellPair],
    'R08': [AppArt.pullUp],
    'R09': [AppArt.restFloor],
    'R11': [AppArt.yogaMat, AppArt.gymBag],
    'R12': [AppArt.trainers],
    'R13': [AppArt.flexBicep],
    'T01': [AppArt.breakfast, AppArt.running],
    'T02': [AppArt.strongArms],
    'T03': [AppArt.running],
    'T04': [AppArt.stretchSeated],
    'T05': [AppArt.restFloor],
    'T07': [AppArt.trainers, AppArt.yogaMat],
    'W01': [AppArt.jogger],
    'W02': [AppArt.lungeKneeling],
    'W03': [AppArt.spinBike, AppArt.yogaMat],
    'W04': [AppArt.dumbbellPair],
    'W05': [AppArt.trainers],
    'W06': [AppArt.buddhaBowl, AppArt.saladWood],
    'W07': [AppArt.breakfast, AppArt.bruschetta],
    'W08': [AppArt.trainers],
    'W09': [AppArt.sideStretch],
    'W10': [AppArt.jogger],
    'X01': [AppArt.meditation],
    'X03': [AppArt.yogaMat],
    'Y01': [AppArt.meditation],
    'Y02': [AppArt.stretchSeated],
    'Y03': [AppArt.meditation],
    'Y04': [AppArt.sideStretch],
    'Y05': [AppArt.yogaMat],
    'Y06': [AppArt.stretchSeated, AppArt.yogaMat],
    'Y07': [AppArt.fruitSalad, AppArt.nuts],
    'Y08': [AppArt.meditation],
    'Y09': [AppArt.stretchSeated],
    'Y10': [AppArt.sideStretch],
    'Y12': [AppArt.meditation],
    'Y13': [AppArt.yogaMat, AppArt.fruitSalad],
    'Z01': [AppArt.gymBag, AppArt.fruitBasket],
    'Z02': [AppArt.dumbbells, AppArt.squatWeights],
    'Z03': [AppArt.lungeWarrior],
    'Z04': [AppArt.fruitBasket, AppArt.apple],
    'Z05': [AppArt.bowlGreen],
    'Z06': [AppArt.pasta],
    'Z07': [AppArt.spinBike],
    'Z08': [AppArt.gymBag],
    'Z09': [AppArt.yogaMat],
    'Z10': [AppArt.dance],
    'Z11': [AppArt.gymBag],
    'Z12': [AppArt.buddhaBowl],
    'Z13': [AppArt.running],
    'Z14': [AppArt.dumbbells],
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
  static const Set<String> placesOwnArt = {'T01', 'R01', 'E01', 'K07'};

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
