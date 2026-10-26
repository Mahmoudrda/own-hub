/// D40 — a light touch on the moments that matter, and nowhere else.
///
/// The first video study's pack-opening example ends on haptics for a reason:
/// a moment she feels is a moment she remembers. Three moments, three
/// strengths, and that is the whole vocabulary, plus one lighter touch for
/// the small things she finishes (D48):
///
/// - **a set logged** — a selection click, the lightest the phone has, so a
///   tap between breaths is confirmed without a buzz in her hand;
/// - **a session finished** — a medium impact as the tick draws on R10, the
///   one haptic of that screen;
/// - **a small thing done** — a meal logged, a grocery line ticked, a period
///   saved: a light impact beside the tick that draws;
/// - **the big moment** — a heavy impact. R10 no longer plays it (D46): the
///   one haptic there is the medium impact above.
///
/// Behind [Feature.haptics]. The platform's own setting still decides whether
/// anything is felt: a phone with haptics off feels nothing, and nothing here
/// overrides that. A platform without haptics throws nothing at her.
library;

import 'package:flutter/services.dart';

import '../domain/flags/feature_flags.dart';
import '../routing/app_router.dart';

enum HapticMoment { setLogged, actionDone, sessionFinished, bigMoment }

abstract final class AppHaptics {
  /// Whether haptics are switched on. Tests replace it.
  static bool Function() enabled = () =>
      AppRouter.featureFlags.isOn(Feature.haptics);

  static Future<void> play(HapticMoment moment) async {
    if (!enabled()) return;
    try {
      switch (moment) {
        case HapticMoment.setLogged:
          await HapticFeedback.selectionClick();
        case HapticMoment.actionDone:
          await HapticFeedback.lightImpact();
        case HapticMoment.sessionFinished:
          await HapticFeedback.mediumImpact();
        case HapticMoment.bigMoment:
          await HapticFeedback.heavyImpact();
      }
    } catch (_) {
      // No haptics on this platform. The moment still happened.
    }
  }
}
