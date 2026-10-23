/// The illustration set, by name.
///
/// Thirty-two illustrations from the owner's own icon set (`Icons.pdf` and
/// `More icons.pdf`), shipped as WebP at 1x, 2x and 3x under `assets/art/`, so
/// Flutter picks the file that matches the screen and nothing is upscaled.
///
/// On 1 October 2026 the owner chose to ship these originals in place of the
/// painted marks that had replaced them. `assets/art/LICENCE.md` records that
/// decision and the licensing question it settles.
///
/// ## What these are for, and what they are not
///
/// They are **illustrations, not icons**. The interface is drawn with Material
/// icons — a 20px chevron, a close cross — and a drawing of a bowl cannot do
/// that job. These are for the places the product would otherwise show nothing
/// at all: an empty list, a finished session, the top of a section.
///
/// **They are deliberately not attached to individual rows.** Putting
/// [bowlSalad] on a food she logged, when the food is not a salad bowl, tells
/// her something untrue about her own data — the same defect
/// `baked_in_samples_test` exists to catch, in a different medium. Use them
/// where the meaning is general, or not at all. The one place a drawing *is*
/// attached to a specific thing is a recipe card, which uses the separate
/// `FoodMarks` vocabulary and is checked against the seed by `rahma_seed_test`.
///
/// ## One name, one drawing
///
/// The old set named subjects: `running`, `run_side`, `jogger` and
/// `dumbbell_run` were four files of a woman running. Here a name IS a drawing,
/// so `screen_art.dart` cannot ask for two pictures and get the same one twice
/// without that being visible in the table — and `screen_art_test.dart` asserts
/// it never does.
library;

import 'package:flutter/widgets.dart';

/// Names of the illustrations. Every one has a WebP file at 1x, 2x and 3x,
/// which `app_art_test.dart` asserts.
abstract final class AppArt {
  // ------------------------------------------------------------- training
  /// A woman mid-stride, one foot planted. Covers everything the old pack
  /// split across `running`, `run_side`, `jogger` and `dumbbell_run`.
  static const running = 'running';

  /// One arm overhead, weight on one leg. The people screens, not the sets.
  static const dance = 'dance';

  /// A flexed arm, not a whole figure. Finishing a session, a personal best.
  static const strongArms = 'strong_arms';

  /// A squat under a bar. Covers the old `back_squat` too: at 92 pt a high-bar
  /// and a low-bar squat are the same drawing.
  static const squatWeights = 'squat_weights';

  /// A kneeling lunge, back shin on the floor.
  static const lungeKneeling = 'lunge_kneeling';

  /// Warrior II: level arms, wide stance. Held, rather than repeated.
  static const lungeWarrior = 'lunge_warrior';

  /// A body on its forearms. Covers the old `side_plank`, which differed only
  /// in a roll the eye cannot see at this size.
  static const plank = 'plank';

  /// Seated, legs out, reaching forward.
  static const stretchSeated = 'stretch_seated';

  /// Standing, one arm arcing over the head.
  static const sideStretch = 'side_stretch';

  /// Lying down, one knee up. Every screen that tells her to stop.
  static const restFloor = 'rest_floor';

  /// Seated cross-legged, head-on, perfectly still. The most-placed mark in
  /// the product: her cycle, her privacy, the safety centre, every wait.
  static const meditation = 'meditation';

  /// A bar above the head. Covers the old `barbell_press`, `overhead_raise`
  /// and `pull_up`: all three are "a bar over her, arms straight to it".
  static const overheadRaise = 'overhead_raise';

  /// A dumbbell. Covers the old `dumbbell_pair`.
  static const dumbbells = 'dumbbells';

  /// A boxing glove. Covers the old `gloves_outline`.
  static const boxingGloves = 'boxing_gloves';

  /// A rolled mat, seen end-on.
  static const yogaMat = 'yoga_mat';

  /// A trainer in profile.
  static const trainers = 'trainers';

  /// A duffel bag.
  static const gymBag = 'gym_bag';

  /// A stationary bike.
  static const spinBike = 'spin_bike';

  /// Over-ear headphones. The audio screens.
  static const headphones = 'headphones';

  // ----------------------------------------------------------------- food
  /// A wide bowl of leaves, seen from the side.
  static const bowlSalad = 'bowl_salad';

  /// A grain bowl, seen from above and divided. Deliberately a different view
  /// from [bowlSalad], because the meal planner sets them side by side.
  static const buddhaBowl = 'buddha_bowl';

  /// A plate with a fork beside it. Covers the old `platter_grill`.
  static const plateMixed = 'plate_mixed';

  /// A cut of meat.
  static const steak = 'steak';

  /// A fried egg.
  static const toastEgg = 'toast_egg';

  /// A stack of pancakes.
  static const breakfast = 'breakfast';

  /// A topped flatbread.
  static const bruschetta = 'bruschetta';

  /// A pot with a lid.
  static const pasta = 'pasta';

  /// A basket heaped with fruit. Covers the old `fruit_salad`.
  static const fruitBasket = 'fruit_basket';

  /// One round fruit with a leaf. Covers the old `orange`.
  static const apple = 'apple';

  /// A bunch of grapes.
  static const grapes = 'grapes';

  /// A melon wedge.
  static const watermelon = 'watermelon';

  /// Three nuts.
  static const nuts = 'nuts';

  /// Every name, for the test that asserts each one has a drawing behind it.
  static const all = <String>[
    running,
    dance,
    strongArms,
    squatWeights,
    lungeKneeling,
    lungeWarrior,
    plank,
    stretchSeated,
    sideStretch,
    restFloor,
    meditation,
    overheadRaise,
    dumbbells,
    boxingGloves,
    yogaMat,
    trainers,
    gymBag,
    spinBike,
    headphones,
    bowlSalad,
    buddhaBowl,
    plateMixed,
    steak,
    toastEgg,
    breakfast,
    bruschetta,
    pasta,
    fruitBasket,
    apple,
    grapes,
    watermelon,
    nuts,
  ];

  /// The bundled file for [name], at 1x. Flutter resolves the 2.0x and 3.0x
  /// variants beside it by itself.
  static String path(String name) => 'assets/art/$name.webp';

  /// An illustration at [size] logical pixels on its longest side.
  ///
  /// Always decorative: a screen reader announcing "salad bowl" over an
  /// empty-state heading adds noise, not meaning, and nothing in this product
  /// puts information in a picture that the words beside it do not carry.
  static Widget image(String name, {double size = 160}) => ExcludeSemantics(
    child: Image.asset(
      path(name),
      width: size,
      height: size,
      fit: BoxFit.contain,
      filterQuality: FilterQuality.medium,
      gaplessPlayback: true,
      errorBuilder: (_, _, _) => SizedBox.square(dimension: size),
    ),
  );
}
