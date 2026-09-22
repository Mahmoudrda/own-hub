/// The illustration set, by name.
///
/// Thirty-six drawings extracted from the owner's artwork: sixteen of food,
/// twenty of women training. They are shipped as WebP at 1x, 2x and 3x, so
/// Flutter resolves the right one for the screen and nothing is ever upscaled.
///
/// ## What these are for, and what they are not
///
/// They are **illustrations, not icons**. The interface is drawn with Material
/// icons -- a 20px chevron, a close cross -- and a picture of a taco cannot do
/// that job. These are for the places the product currently shows nothing at
/// all: an empty list, a finished session, the top of a section.
///
/// **They are deliberately not attached to individual rows.** Putting
/// [bowlSalad] on a food she logged, when the food is not a salad bowl, tells
/// her something untrue about her own data -- the same defect
/// `baked_in_samples_test` exists to catch, in a different medium. Use them
/// where the meaning is general, or not at all.
library;

import 'package:flutter/widgets.dart';

/// Names of the illustrations. Paths are built by [AppArt.image].
abstract final class AppArt {
  // ------------------------------------------------------------------ food
  static const bowlSalad = 'bowl_salad';
  static const bowlGreen = 'bowl_green';
  static const bowlPotato = 'bowl_potato';
  static const plateMixed = 'plate_mixed';
  static const platterGrill = 'platter_grill';
  static const toastEgg = 'toast_egg';
  static const fruitBasket = 'fruit_basket';
  static const wrap = 'wrap';
  static const taco = 'taco';
  static const fries = 'fries';
  static const cakeSlice = 'cake_slice';
  static const cupcake = 'cupcake';
  static const cookies = 'cookies';
  static const pancakes = 'pancakes';
  static const headphones = 'headphones';

  // --------------------------------------------------------------- training
  static const pullUp = 'pull_up';
  static const dance = 'dance';
  static const stretchSeated = 'stretch_seated';
  static const running = 'running';
  static const runSide = 'run_side';
  static const dumbbells = 'dumbbells';
  static const restFloor = 'rest_floor';
  static const boxingGloves = 'boxing_gloves';
  static const glovesOutline = 'gloves_outline';
  static const yogaMat = 'yoga_mat';
  static const lungeWarrior = 'lunge_warrior';
  static const lungeKneeling = 'lunge_kneeling';
  static const sidePlank = 'side_plank';
  static const plank = 'plank';
  static const squatWeights = 'squat_weights';
  static const trainers = 'trainers';
  static const spinBike = 'spin_bike';
  static const barbellPress = 'barbell_press';
  static const overheadRaise = 'overhead_raise';
  static const strongArms = 'strong_arms';


  // ------------------------------------------ from More icons.pdf, food
  static const nuts = 'nuts';
  static const fruitSalad = 'fruit_salad';
  static const saladBlue = 'salad_blue';
  static const saladWood = 'salad_wood';
  static const steak = 'steak';
  static const buddhaBowl = 'buddha_bowl';
  static const breakfast = 'breakfast';
  static const bruschetta = 'bruschetta';
  static const pineapple = 'pineapple';
  static const grapes = 'grapes';
  static const apple = 'apple';
  static const orange = 'orange';
  static const watermelon = 'watermelon';
  static const pasta = 'pasta';

  // -------------------------------------- from More icons.pdf, training
  static const backSquat = 'back_squat';
  static const dumbbellPair = 'dumbbell_pair';
  static const flexBicep = 'flex_bicep';
  static const dumbbellRun = 'dumbbell_run';
  static const jogger = 'jogger';
  static const sideStretch = 'side_stretch';
  static const gymBag = 'gym_bag';

  // --------------------------------------------------------- wellbeing
  /// The only image in the set that is not exercise or food. It carries the
  /// screens that must feel calm: her cycle, her privacy, safety, waiting.
  static const meditation = 'meditation';

  /// Every name, for the test that asserts each one has a file behind it.
  static const all = <String>[
    bowlSalad, bowlGreen, bowlPotato, plateMixed, platterGrill, toastEgg,
    fruitBasket, wrap, taco, fries, cakeSlice, cupcake, cookies, pancakes,
    headphones,
    pullUp, dance, stretchSeated, running, runSide, dumbbells, restFloor,
    boxingGloves, glovesOutline, yogaMat, lungeWarrior, lungeKneeling,
    sidePlank, plank, squatWeights, trainers, spinBike, barbellPress,
    overheadRaise, strongArms,
    nuts, fruitSalad, saladBlue, saladWood, steak, buddhaBowl, breakfast, bruschetta, pineapple, grapes, apple, orange, watermelon, pasta, backSquat, dumbbellPair, flexBicep, dumbbellRun, jogger, sideStretch, gymBag, meditation,
  ];

  static String path(String name) => 'assets/art/$name.webp';

  /// An illustration at [size] logical pixels on its longest side.
  ///
  /// Decorative by default: [ImageSemantics] is excluded from the tree, because
  /// a screen reader announcing "salad bowl" over an empty-state heading adds
  /// noise, not meaning. Pass [semanticLabel] where the picture genuinely
  /// carries information the words do not.
  static Widget image(
    String name, {
    double size = 160,
    String? semanticLabel,
  }) {
    return Image.asset(
      path(name),
      width: size,
      height: size,
      fit: BoxFit.contain,
      excludeFromSemantics: semanticLabel == null,
      semanticLabel: semanticLabel,
      filterQuality: FilterQuality.medium,
    );
  }
}
