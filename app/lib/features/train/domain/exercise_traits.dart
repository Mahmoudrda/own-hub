/// What each move is measured on, and what it is called.
///
/// The app bundles no exercise library: the synced one is empty until the
/// phone has fetched it. `assets/content/exercise_traits.json` (built by
/// `tool/build_exercise_traits.py` from the catalogue and the starting
/// programmes) holds a metric, the kit and the English name of every
/// move the programmes prescribe, so a personal best can be detected and named
/// with no library at all.
///
/// A move the bundle knows keeps the bundle's metric even when the synced
/// library also holds it: only the bundle knows a plank is prescribed in
/// seconds, and a best must not change what it is measured on when the library
/// arrives. A move only the library knows is read from its row.
library;

import 'dart:async';
import 'dart:convert';

import 'package:flutter/services.dart' show AssetBundle, rootBundle;
import 'package:meta/meta.dart';

import '../../../app_state/exercise_library_state.dart';
import '../../../domain/rewards/personal_best_detector.dart';
import '../presentation/exercise_labels.dart' show englishMoveNames;
import 'exercise_library.dart';
import 'load_advice.dart' show LoadKit, loadKitFor;

@immutable
class ExerciseTraits {
  const ExerciseTraits({
    required this.exerciseId,
    required this.metric,
    required this.equipment,
    required this.nameEn,
  });

  final String exerciseId;
  final BestMetric metric;

  /// The kit the move is done with.
  final List<LibraryEquipment> equipment;

  /// The move's name. Names are English in every locale.
  final String nameEn;

  /// Where the bundled file lives.
  static const String assetPath = 'assets/content/exercise_traits.json';

  static Map<String, ExerciseTraits> _bundled = const {};
  static Future<void>? _loading;

  // The synced library as a map by id, rebuilt only when a different library
  // object arrives, and the detector map made from it and the bundle.
  static ExerciseLibrary? _indexedLibrary;
  static Map<String, LibraryExercise> _rows = const {};
  static Map<String, ExerciseMeta>? _metrics;

  /// Reads the bundled table once. Safe to call again; a failed read is not
  /// tried again until [resetForTest].
  static Future<void> load({AssetBundle? bundle}) => _loading ??= () async {
    try {
      adopt(await (bundle ?? rootBundle).loadString(assetPath));
    } catch (_) {
      // Detection stays closed.
    }
  }();

  /// Reads the table's text. Throws [FormatException] for a file that is not
  /// one, leaving what was loaded as it was.
  static void adopt(String source) {
    final decoded = jsonDecode(source);
    final moves = decoded is Map ? decoded['moves'] : null;
    if (moves is! Map) throw const FormatException('not a traits file');
    final out = <String, ExerciseTraits>{};
    moves.forEach((id, row) {
      if (id is! String || row is! Map) {
        throw const FormatException('bad traits row');
      }
      final metric = switch (row['metric']) {
        'load' => BestMetric.load,
        'reps' => BestMetric.reps,
        'hold' => BestMetric.hold,
        _ => throw FormatException('bad metric for $id'),
      };
      out[id] = ExerciseTraits(
        exerciseId: id,
        metric: metric,
        equipment: [
          for (final e in (row['equipment'] as List))
            ?LibraryEquipment.fromWire(e),
        ],
        nameEn: row['nameEn'] as String,
      );
    });
    _bundled = out;
    _metrics = null;
  }

  @visibleForTesting
  static void resetForTest() {
    _bundled = const {};
    _loading = null;
    _indexedLibrary = null;
    _rows = const {};
    _metrics = null;
  }

  static Map<String, LibraryExercise> _rowsOf(ExerciseLibrary library) {
    if (!identical(library, _indexedLibrary)) {
      _rows = {for (final e in library.exercises) e.id: e};
      _indexedLibrary = library;
      _metrics = null;
    }
    return _rows;
  }

  /// The traits of [id]: the bundled table, else the synced library's row.
  /// Null for a move neither knows.
  static ExerciseTraits? of(String id, {ExerciseLibrary? library}) {
    _ensureLoading();
    final bundled = _bundled[id];
    final row = _rowsOf(library ?? ExerciseLibraryState.instance.library)[id];
    if (row == null) return bundled;
    return ExerciseTraits(
      exerciseId: id,
      metric: bundled?.metric ?? _metricOf(row),
      equipment: row.equipment,
      nameEn: row.nameEn,
    );
  }

  /// What to call [id] on screen, in English in every locale: its traits, else
  /// the name the first screens give the six legacy moves, else the id spoken
  /// as words.
  static String nameOf(String id, {ExerciseLibrary? library}) {
    final traits = of(id, library: library);
    if (traits != null) return traits.nameEn;
    final legacy = switch (id) {
      'glute_bridge' => englishMoveNames.gluteBridge,
      'goblet_squat' => englishMoveNames.gobletSquat,
      'step_back_lunge' => englishMoveNames.stepBackLunge,
      'hip_thrust_hold' => englishMoveNames.hipThrustHold,
      'plank_hold' => englishMoveNames.plankHold,
      'dead_bug' => englishMoveNames.deadBug,
      _ => null,
    };
    if (legacy != null) return legacy;
    final words = id.replaceAll('_', ' ').trim();
    return words.isEmpty ? id : words[0].toUpperCase() + words.substring(1);
  }

  /// The kit [id] is done with, as library values, for the load ladders and
  /// the plate helper. Null for a move neither source knows.
  static List<LibraryEquipment>? equipmentOf(String id) => of(id)?.equipment;

  /// A detector map for every bundled move, and every library move the bundle
  /// does not hold.
  static Map<String, ExerciseMeta> traitsMetrics({ExerciseLibrary? library}) {
    _ensureLoading();
    final source = library ?? ExerciseLibraryState.instance.library;
    _rowsOf(source);
    return _metrics ??= Map.unmodifiable(<String, ExerciseMeta>{
      for (final t in _bundled.values)
        t.exerciseId: ExerciseMeta(exerciseId: t.exerciseId, metric: t.metric),
      for (final row in source.exercises)
        if (!_bundled.containsKey(row.id))
          row.id: ExerciseMeta(exerciseId: row.id, metric: _metricOf(row)),
    });
  }

  static void _ensureLoading() {
    // Fire and forget: the first call before the asset is read sees an empty
    // table, which fails closed. The app awaits [load] at launch.
    if (_bundled.isEmpty) unawaited(load());
  }

  static BestMetric _metricOf(LibraryExercise row) {
    if (row.kind == ExerciseKind.stretch) return BestMetric.hold;
    return loadKitFor(row.equipment) == LoadKit.unknown
        ? BestMetric.reps
        : BestMetric.load;
  }
}
