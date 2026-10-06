/// The moment the app treats as "now" on her own screens.
///
/// On a phone this is the wall clock and nothing else. It exists so a harness
/// can stand the member-facing screens (Home, Eat, Train, Progress, My cycle)
/// on one fixed morning: the store screenshots must not show a breakfast filed
/// under Lunch because of the hour the render happened to run.
///
/// Consent records, ids and audit timestamps keep reading `DateTime.now()`
/// directly. They are facts about when something happened and are never
/// pinned.
library;

import 'package:meta/meta.dart';

abstract final class AppClock {
  static DateTime Function() _now = DateTime.now;

  /// Now, as her screens read it.
  static DateTime now() => _now();

  /// Replaces the clock for a test. `null` puts the wall clock back.
  @visibleForTesting
  static set debugNow(DateTime Function()? clock) =>
      _now = clock ?? DateTime.now;
}
