/// How much she trained each part of her body, from what she logged (P06).
///
/// Read from her log and nothing else, the way `lastSessionSets` reads it: the
/// moves that reached the server (`flushes`), filed under the day of the
/// session they belong to, and the sets of a session she recalled afterwards.
/// A prescription is never a set she did (spine C8), and a skipped set is not
/// one either.
///
/// **The count.** A set counts in full for each section a primary muscle of
/// the move lies in, and as half a set for each section only a helping muscle
/// lies in, once per section ([ExerciseMuscles.sectionWeights]). A stretch
/// counts nothing.
///
/// **The score.** Neutral and relative to her own most-trained section in the
/// same window: that section is 1, a section she did not train is 0. Nothing
/// about recovery, and nothing compared with anybody else.
///
/// Derived each time it is asked, never stored, so there is nothing to sync,
/// snapshot or wipe.
library;

import 'dart:math' as math;

import 'package:meta/meta.dart';

import '../../../domain/format/number_label.dart';
import '../../train/domain/exercise_library.dart';
import '../../train/domain/train_repository.dart';
import 'muscle_map.dart';

/// One move she logged sets of, on one day.
typedef LoggedMove = ({String dateKey, String exerciseId, int sets});

/// The two windows P06 can show.
enum MuscleWindow {
  week(7),
  month(30);

  const MuscleWindow(this.days);

  /// Today and the days before it.
  final int days;
}

/// One section's weighted sets in a window.
@immutable
class SectionVolume {
  const SectionVolume({
    required this.section,
    required this.sets,
    required this.score,
  });

  final MuscleSection section;

  /// Weighted sets, in halves.
  final double sets;

  /// [sets] over her most-trained section's, 0 to 1.
  final double score;
}

@immutable
class MuscleReport {
  const MuscleReport._(
    this.today,
    this._volume,
    this._regions,
    this._lastTrained,
    this._ever,
  );

  /// A report with nothing in it.
  factory MuscleReport.empty(DateTime today) =>
      MuscleReport._(_dateOf(today), const {}, const {}, const {}, const {});

  /// The day the windows end on, at midnight UTC so day arithmetic is exact.
  final DateTime today;

  final Map<MuscleWindow, Map<MuscleSection, double>> _volume;
  final Map<MuscleWindow, Map<BodyRegion, double>> _regions;
  final Map<MuscleSection, DateTime> _lastTrained;
  final Map<MuscleSection, double> _ever;

  /// True once any section has a set in it, ever.
  bool get hasAnyLog => _lastTrained.isNotEmpty;

  /// Weighted sets for [section] in [window].
  double setsIn(MuscleWindow window, MuscleSection section) =>
      _volume[window]?[section] ?? 0;

  /// Weighted sets for one half of her body in [window].
  double regionSets(MuscleWindow window, BodyRegion region) =>
      _regions[window]?[region] ?? 0;

  /// The most any one section had in [window], or 0.
  double maxIn(MuscleWindow window) =>
      (_volume[window]?.values ?? const <double>[]).fold(0.0, math.max);

  /// [section]'s sets over the most-trained section's, 0 to 1.
  double score(MuscleWindow window, MuscleSection section) {
    final top = maxIn(window);
    return top <= 0 ? 0 : setsIn(window, section) / top;
  }

  /// True when [window] holds at least one set.
  bool hasSetsIn(MuscleWindow window) => maxIn(window) > 0;

  /// Weighted sets for [section] over everything she ever logged.
  double everSets(MuscleSection section) => _ever[section] ?? 0;

  /// The last day [section] had a set, over everything she ever logged.
  DateTime? lastTrained(MuscleSection section) => _lastTrained[section];

  /// Whole days since [section] last had a set: 0 for today.
  int? daysSince(MuscleSection section) {
    final last = _lastTrained[section];
    return last == null ? null : today.difference(last).inDays;
  }

  /// Every section, the most trained first. Ties keep the library's order.
  List<SectionVolume> ranked(MuscleWindow window) {
    final top = maxIn(window);
    final all = [
      for (final s in MuscleSection.values)
        SectionVolume(
          section: s,
          sets: setsIn(window, s),
          score: top <= 0 ? 0 : setsIn(window, s) / top,
        ),
    ];
    final order = {for (final s in MuscleSection.values) s: s.index};
    all.sort((a, b) {
      final bySets = b.sets.compareTo(a.sets);
      return bySets != 0 ? bySets : order[a.section]! - order[b.section]!;
    });
    return all;
  }
}

/// Her log, read into a report ending on [today].
///
/// [musclesOf] answers an exercise id with its muscles, or null for a move
/// nothing describes, which then counts nowhere. A day key that is not a date,
/// or a day after [today], is left out.
MuscleReport buildMuscleReport({
  required Iterable<LoggedMove> log,
  required ExerciseMuscles? Function(String exerciseId) musclesOf,
  required DateTime today,
}) {
  final end = _dateOf(today);
  final volume = <MuscleWindow, Map<MuscleSection, double>>{
    for (final w in MuscleWindow.values) w: <MuscleSection, double>{},
  };
  final regions = <MuscleWindow, Map<BodyRegion, double>>{
    for (final w in MuscleWindow.values) w: <BodyRegion, double>{},
  };
  final lastTrained = <MuscleSection, DateTime>{};
  final ever = <MuscleSection, double>{};

  for (final entry in log) {
    if (entry.sets <= 0) continue;
    final parsed = DateTime.tryParse(entry.dateKey);
    if (parsed == null) continue;
    final day = _dateOf(parsed);
    final ago = end.difference(day).inDays;
    if (ago < 0) continue;
    final muscles = musclesOf(entry.exerciseId);
    if (muscles == null || muscles.stretch) continue;

    final weights = muscles.sectionWeights;
    for (final MapEntry(key: section, value: weight) in weights.entries) {
      if (weight <= 0) continue;
      final had = lastTrained[section];
      if (had == null || day.isAfter(had)) lastTrained[section] = day;
      ever[section] = (ever[section] ?? 0) + weight * entry.sets;
      for (final w in MuscleWindow.values) {
        if (ago >= w.days) continue;
        volume[w]![section] = (volume[w]![section] ?? 0) + weight * entry.sets;
      }
    }
    final halves = muscles.regionWeights;
    for (final MapEntry(key: region, value: weight) in halves.entries) {
      for (final w in MuscleWindow.values) {
        if (ago >= w.days) continue;
        regions[w]![region] = (regions[w]![region] ?? 0) + weight * entry.sets;
      }
    }
  }

  return MuscleReport._(end, volume, regions, lastTrained, ever);
}

/// The moves she logged, read from what the phone holds of her training.
///
/// Empty for a repository that is not the in-memory one: the interface has no
/// history read, and inventing one here would put a query on every
/// implementation (the same answer `set_history.dart` gives).
List<LoggedMove> loggedMovesFrom(TrainRepository repository) {
  if (repository is! InMemoryTrainRepository) return const <LoggedMove>[];
  final out = <LoggedMove>[];
  for (final flush in repository.flushes) {
    final session = repository.sessionById(flush.sessionId);
    if (session == null) continue;
    final sets = flush.sets.where((s) => s.isLogged).length;
    if (sets == 0) continue;
    out.add((
      dateKey: session.dateKey,
      exerciseId: flush.exerciseId,
      sets: sets,
    ));
  }
  // A session she recalled carries its own sets; a live one carries only its
  // prescription, which is never counted.
  for (final session in repository.sessions) {
    if (session.source != SessionSource.recalled) continue;
    final byMove = <String, int>{};
    for (final set in session.sets) {
      if (!set.isLogged) continue;
      final id = set.prescribed.exerciseId;
      byMove[id] = (byMove[id] ?? 0) + 1;
    }
    for (final MapEntry(key: id, value: sets) in byMove.entries) {
      out.add((dateKey: session.dateKey, exerciseId: id, sets: sets));
    }
  }
  return out;
}

/// Weighted sets as she reads them: "9", or "7.5" for a half. Western digits
/// in both languages.
String setsLabel(double sets) {
  final halves = (sets * 2).round();
  final whole = halves ~/ 2;
  return halves.isEven ? countLabel(whole) : '${countLabel(whole)}.5';
}

DateTime _dateOf(DateTime moment) =>
    DateTime.utc(moment.year, moment.month, moment.day);
