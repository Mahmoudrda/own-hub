/// When a logged meal gets a sound, and when it stays quiet.
///
/// The sound is a soft wooden tap that says "that is saved". It must never
/// become a reward for eating too little, so it is silent in two cases:
///
/// - her calorie targets are withheld (an eating-history answer to her coach
///   means the app shows her no figures to aim at, and no sound should cheer
///   what she logs);
/// - the log is under [minKcal]: a black coffee or a glass of water is not a
///   meal, and a near-empty log should not be answered like one.
///
/// Voice logs on E03 are quiet too: no sound plays on a screen where she has
/// just been speaking.
library;

import 'dart:async';

import 'eat_state.dart';
import 'sound.dart';

abstract final class MealCue {
  /// A log of fewer calories than this is not answered with a sound.
  static const int minKcal = 100;

  /// Her calorie targets, read only when a sound would actually play.
  /// Tests replace it.
  static bool Function() targetsWithheld = () =>
      EatAppState.instance.targets().withheld;

  static bool allowed(int kcal) =>
      kcal >= minKcal && !targetsWithheld();

  /// A meal was added.
  static void logged(int kcal, {bool byVoice = false}) {
    if (byVoice || !AppSound.active || !allowed(kcal)) return;
    unawaited(AppSound.play(SoundCue.foodLogged));
  }

  /// A meal was taken back inside its five seconds.
  static void takenBack(int kcal) {
    if (!AppSound.active || !allowed(kcal)) return;
    unawaited(AppSound.play(SoundCue.undo));
  }
}
