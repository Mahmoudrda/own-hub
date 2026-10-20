/// Which tier of her programme Train and Home are showing right now.
///
/// Null means "her own level" ([Intake.level]). Tapping another tier on R01,
/// R02 or Home sets it, so the week she sees and the session she starts are the
/// same tier. It lives for the session only: it is a view, not an answer, and
/// changing her level on O03 clears it.
library;

import 'package:flutter/foundation.dart';

import '../../onboarding/domain/intake.dart';

abstract final class ViewedTier {
  static final ValueNotifier<TrainingLevel?> notifier = ValueNotifier(null);

  /// The tier to show a woman with [intake].
  static TrainingLevel of(Intake intake) => notifier.value ?? intake.level;

  static void show(TrainingLevel tier) => notifier.value = tier;

  /// Back to her own level.
  static void clear() => notifier.value = null;
}
