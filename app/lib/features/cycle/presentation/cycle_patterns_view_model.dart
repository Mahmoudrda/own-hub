/// Y10 — "Your patterns". Her logs described, never a score.
///
/// Y10's own copy: "This describes your logs. It does not explain the cause or
/// predict every cycle." And plan §12: "No daily streak, no adherence score, no
/// 'readiness'."
///
/// So this view model produces bars and two counts and nothing else. There is no
/// field here for a score, a trend, a percentage or a cause, and
/// `no_streak_test` asserts the feature stores no counter.
///
/// ## Missing days are shown as missing
///
/// The design note: "missing days are shown as missing rather than as low
/// energy." [PatternBar.energy] is nullable, and a null bar renders as absent —
/// not as zero, and not as low. Treating an unlogged day as a low-energy day
/// would manufacture a pattern out of her not opening the app.
///
/// ## Both numbers come from one source
///
/// "You logged low energy on 4 of 6 logged days" and the chart beside it are
/// built from the same [PatternCounts], because a number and a sentence about
/// that number drawn from different sources is the defect `PHASE1-FIXES.md` #13
/// records three times over.
library;

import 'package:meta/meta.dart';

import '../domain/pattern_window.dart';
import '../domain/today_check_in.dart';

/// One bar of Y10's chart.
@immutable
class PatternBar {
  const PatternBar({required this.dayId, required this.energy});

  /// The check-in document id this bar came from.
  final String dayId;

  /// Her logged energy, or **null when she did not log that day**.
  final Energy? energy;

  bool get isMissing => energy == null;
}

/// Everything Y10 renders.
@immutable
class CyclePatternsSnapshot {
  const CyclePatternsSnapshot({
    required this.bars,
    required this.counts,
    required this.lowEnergyDays,
    required this.cyclesCovered,
    required this.easierWhenLowEnergy,
  });

  /// At most [PatternWindow.maxDays] bars, oldest first.
  final List<PatternBar> bars;

  /// Days asked for, and days that had a check-in.
  final PatternCounts counts;

  /// How many of the logged days were low energy — the subject of Y10's
  /// sentence.
  final int lowEnergyDays;

  /// How many period starts the window covered.
  final int cyclesCovered;

  /// The one adaptation switch Y10 hosts.
  final bool easierWhenLowEnergy;

  /// True when there is nothing to describe.
  ///
  /// Y10 says so plainly rather than drawing an empty chart, which would read as
  /// "no symptoms" — the same error `notShared` exists to prevent on the coach's
  /// side.
  bool get isEmpty => counts.isEmpty;
}

class CyclePatternsViewModel {
  const CyclePatternsViewModel({this.window = const PatternWindow()});

  final PatternWindow window;

  /// Builds Y10 from the bounded window.
  ///
  /// [checkIns] is keyed by `yyyy-MM-dd` and holds only the days the window
  /// asked for — at most six. Passing a map rather than a repository keeps the
  /// cap visible at the call site: a caller cannot hand this more than the
  /// window requested without it being obvious in the diff.
  CyclePatternsSnapshot build({
    required List<String> recentStarts,
    required Map<String, TodayCheckIn> checkIns,
    bool easierWhenLowEnergy = false,
  }) {
    final requested = window.daysToRead(recentStarts);

    final bars = <PatternBar>[
      for (final dayId in requested)
        PatternBar(dayId: dayId, energy: checkIns[dayId]?.energy),
    ];

    final counts = window.count(
      requested: requested,
      present: checkIns.entries
          .where((e) => e.value.isNotEmpty)
          .map((e) => e.key)
          .toSet(),
    );

    return CyclePatternsSnapshot(
      bars: bars,
      counts: counts,
      lowEnergyDays: bars.where((b) => b.energy == Energy.low).length,
      cyclesCovered: recentStarts.take(PatternWindow.startsConsidered).length,
      easierWhenLowEnergy: easierWhenLowEnergy,
    );
  }
}
