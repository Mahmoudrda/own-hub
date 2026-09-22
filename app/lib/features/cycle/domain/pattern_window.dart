/// Y10's read window — hard-capped, and the cap is the point.
///
/// Plan §2 row 10: "`recentStarts[0..1]` from the listener → **≤6** `get
/// checkins/{date}` … hard cap in `PatternWindow.maxDays = 6`; never a range,
/// never a scan."
///
/// The scalability gate (§9) rests on this: "Y10 is ≤6 document gets from a ≤12
/// element bounded array, hard-capped in `PatternWindow.maxDays`." A range query
/// over check-ins would be unbounded in her history, which is the failure the
/// gate rejects — so this produces a *list of document ids* and there is no
/// method here that could produce a range.
///
/// ## What Y10 may say about the result
///
/// Y10's own copy: "This describes your logs. It does not explain the cause or
/// predict every cycle." So this window carries the dates to read and nothing
/// interpretive — no readiness score, no hormone curve, and missing days stay
/// missing rather than being filled in as low energy.
library;

import 'package:meta/meta.dart';

import 'period_entry.dart';

class PatternWindow {
  const PatternWindow();

  /// The hard cap. Six document gets, never more, whatever the history holds.
  static const int maxDays = 6;

  /// How many period starts are looked at. Y10's copy says "your last two
  /// periods", and `daysPerStart * startsConsidered` is what makes [maxDays] six
  /// rather than a number someone chose.
  static const int startsConsidered = 2;

  /// "the first three days" of each start.
  static const int daysPerStart = 3;

  /// The check-in document ids to read, oldest first.
  ///
  /// Takes `recentStarts` — the bounded array already on the document — so this
  /// costs no extra read to compute. Returns at most [maxDays] ids.
  List<String> daysToRead(List<String> recentStarts) {
    final out = <String>[];

    for (final start in recentStarts.take(startsConsidered)) {
      final parsed = DateTime.tryParse(start);
      // A malformed id is skipped rather than throwing: this runs on the path
      // that renders a chart, and a chart is not worth crashing a screen for.
      if (parsed == null) continue;
      for (var offset = 0; offset < daysPerStart; offset++) {
        out.add(isoDay(parsed.add(Duration(days: offset))));
      }
    }

    // Belt and braces. The arithmetic above cannot exceed the cap, and the cap
    // is still applied, because the assertion this file makes to the
    // scalability gate is about the value returned and not about the arithmetic
    // being right.
    return out.take(maxDays).toList();
  }

  /// How many of the requested days actually had a check-in.
  ///
  /// Y10 states counts in words — "4 of 6 logged days" — and both numbers come
  /// from here so the sentence and the chart cannot disagree. That is the defect
  /// `PHASE1-FIXES.md` #13 records in three places: a number and a sentence
  /// about that number drawn from different sources.
  PatternCounts count({
    required List<String> requested,
    required Set<String> present,
  }) {
    final logged = requested.where(present.contains).length;
    return PatternCounts(logged: logged, requested: requested.length);
  }
}

/// What Y10's sentence is built from.
@immutable
class PatternCounts {
  const PatternCounts({required this.logged, required this.requested});

  /// Days inside the window that have a check-in.
  final int logged;

  /// Days the window asked for — at most [PatternWindow.maxDays].
  final int requested;

  /// True when there is nothing to describe. Y10 says so rather than drawing an
  /// empty chart that reads as "no symptoms".
  bool get isEmpty => logged == 0;
}
