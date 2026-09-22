/// Estimates, confined to the calendar's presentation folder — and that
/// confinement **is** the enforcement of rule 4.
///
/// Plan §5: "`PhaseEstimator` · `lib/features/cycle/presentation/calendar/` …
/// Physically confined to the calendar's presentation folder.
/// `cycle_phase_import_test.dart` fails the build if anything under `domain/` or
/// any other feature imports it (P1-CYC-01)."
///
/// So the argument is not "no suggestion path happens to call this". It is: the
/// suggestion path **cannot** call this, because importing it from `domain/` is
/// a build failure. A phase is reachable from exactly one place — the dashed
/// cells on Y08 — and from nowhere that decides anything.
///
/// ## What this file deliberately does not compute
///
/// There is **no ovulation day, no fertile window and no "you are here"**, and
/// no method that could return one. Plan §12: "No prediction beyond a stated
/// range. No ovulation day, no fertile window, no 'you are here' ring, no
/// hormone curve." Y08's own note: "no day is ever labelled confirmed
/// ovulation", and Y13 explains the phases in words "precisely because a
/// calendar cannot measure them".
///
/// A fertile-window function is the single most requested feature in this
/// product's category and the single most harmful thing it could ship: it would
/// be read as contraception. Y05's standing note — "for general wellbeing, not
/// diagnosis or contraception" — is only true while this file has no such
/// method.
///
/// ## Nothing pre-fills 28 days
///
/// `P0-CYC-01`: "Usual cycle length stays 'Not sure' — nothing pre-fills 28
/// days." So [estimateNextStart] returns **null** when it has neither a stated
/// cycle length nor two logged starts to measure one from. An invented average
/// becomes a prediction she never gave us the data for, and a null renders no
/// estimate at all rather than a confident wrong one.
library;

import 'package:meta/meta.dart';

import '../../domain/period_entry.dart';

/// An estimate, always a **range** and never a day.
///
/// `P0-CYC-12`: "The estimate is stated as a range with its reason." There is no
/// single-date constructor, so "your period starts on the 12th" is not a
/// sentence this type can produce.
@immutable
class EstimateRange {
  const EstimateRange({required this.from, required this.to});

  final DateTime from;
  final DateTime to;

  /// Whether [date] falls inside the estimated range.
  bool covers(DateTime date) {
    final day = dayOnly(date);
    return !day.isBefore(dayOnly(from)) && !day.isAfter(dayOnly(to));
  }

  /// Every day in the range, for the calendar to mark dashed.
  List<DateTime> get days {
    final out = <DateTime>[];
    var cursor = dayOnly(from);
    final last = dayOnly(to);
    while (!cursor.isAfter(last)) {
      out.add(cursor);
      cursor = cursor.add(const Duration(days: 1));
    }
    return out;
  }

  @override
  bool operator ==(Object other) =>
      other is EstimateRange && other.from == from && other.to == to;

  @override
  int get hashCode => Object.hash(from, to);
}

class PhaseEstimator {
  const PhaseEstimator();

  /// How far either side of the predicted day the range extends.
  ///
  /// One day each way, giving the three-day range the design draws. Named
  /// rather than inlined so that widening it is a deliberate edit to a constant
  /// with a comment, not a silent `+2` in an expression.
  static const int rangeSlackDays = 1;

  /// Two starts is the minimum from which an interval can be *measured*.
  static const int minimumStartsToMeasure = 2;

  /// The typical interval between her logged starts, or null if it cannot be
  /// measured.
  ///
  /// The **median**, not the mean: one unusually long gap — an illness, a
  /// missed log — would drag a mean and produce an estimate that matches none of
  /// her cycles.
  int? measuredCycleLength(List<String> recentStarts) {
    final starts = _parse(recentStarts);
    if (starts.length < minimumStartsToMeasure) return null;

    final gaps = <int>[
      for (var i = 0; i + 1 < starts.length; i++)
        starts[i].difference(starts[i + 1]).inDays,
    ]..sort();

    final valid = gaps.where((g) => g > 0).toList();
    if (valid.isEmpty) return null;
    return valid[valid.length ~/ 2];
  }

  /// When her next period is estimated to start, as a range.
  ///
  /// Returns null when there is nothing to estimate from. See the library note —
  /// this is where "no silent 28 days" lives.
  ///
  /// [statedCycleLength] is her own answer from Y02 and takes precedence over
  /// the measured one, because she knows her body and the measurement is two
  /// data points.
  EstimateRange? estimateNextStart({
    required List<String> recentStarts,
    int? statedCycleLength,
  }) {
    final starts = _parse(recentStarts);
    if (starts.isEmpty) return null;

    final length = statedCycleLength ?? measuredCycleLength(recentStarts);
    // Neither stated nor measurable. No estimate, rather than a default.
    if (length == null) return null;

    final predicted = starts.first.add(Duration(days: length));
    return EstimateRange(
      from: predicted.subtract(const Duration(days: rangeSlackDays)),
      to: predicted.add(const Duration(days: rangeSlackDays)),
    );
  }

  /// Parses `yyyy-MM-dd` ids into dates, newest first, skipping malformed ones.
  List<DateTime> _parse(List<String> recentStarts) {
    final out = <DateTime>[
      for (final raw in recentStarts)
        if (DateTime.tryParse(raw) != null) dayOnly(DateTime.parse(raw)),
    ]..sort((a, b) => b.compareTo(a));
    return out;
  }
}
