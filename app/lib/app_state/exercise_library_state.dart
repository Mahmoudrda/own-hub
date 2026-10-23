/// The exercise library on this phone (D42): what R14 lists and R15 plays.
///
/// Read from the cache at once and from Firestore when due, for a verified
/// account (`ExerciseLibrarySync`). With nothing cached and nothing reachable
/// the library is empty, and R01 and R11 simply do not offer it.
library;

import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:meta/meta.dart';

import '../features/onboarding/domain/intake.dart' show Intake, LifeStage;
import '../features/train/data/exercise_library_sync.dart';
import '../features/train/data/exercise_media_store.dart';
import '../features/train/domain/exercise_library.dart';
import '../features/train/presentation/exercise_clip_player.dart';
import 'app_changes.dart';
import 'firebase_boot.dart';

class ExerciseLibraryState {
  ExerciseLibraryState._();

  static final ExerciseLibraryState instance = ExerciseLibraryState._();

  ExerciseLibrarySync sync = ExerciseLibrarySync(source: _liveSource);

  /// Where clips and posters come from. Nothing until Firebase is up.
  ExerciseMediaStore media = FirebaseExerciseMediaStore();

  /// Makes the player R15 draws a clip with.
  ExerciseClipPlayerFactory players = VideoPlayerClipPlayer.new;

  ExerciseLibrary library = ExerciseLibrary.empty;

  /// The move she opened from R14, for R15.
  String? openExerciseId;

  Future<void>? _loaded;

  static ExerciseLibraryRemoteSource? _liveSource() {
    try {
      if (!FirebaseBoot.isReady) return null;
      return FirestoreExerciseLibrarySource(FirebaseFirestore.instance);
    } catch (_) {
      return null;
    }
  }

  /// The cache, then the server when due. Never throws.
  Future<void> refresh() async {
    try {
      _loaded ??= sync.load().then(_adopt);
      await _loaded;
      final (_, updated) = await sync.refresh();
      if (updated != null) _adopt(updated);
    } catch (_) {
      // The cached library, or none, is already the answer.
    }
  }

  void _adopt(ExerciseLibrary next) {
    if (next.version < library.version) return;
    final newer = next.version > library.version;
    library = next;
    AppChanges.bump();
    // Clips a new version no longer names are deleted, and only then: the
    // cache read at launch must never empty the folder it is about to use.
    if (newer && !next.isEmpty && _loadedOnce) {
      unawaited(media.keepOnly(next.mediaPaths));
    }
    _loadedOnce = true;
  }

  bool _loadedOnce = false;

  /// The moves a woman at [stage] is shown, and whether any were held back.
  ({List<LibraryExercise> shown, bool someHidden}) screenedFor(
    LifeStage? stage,
  ) => screenForLifeStage(library.exercises, stage);

  /// The library's own row for a move id, or null when it does not hold it.
  LibraryExercise? byId(String id) => library.byId(id);

  /// Whether the library holds [exerciseId] with at least one filmed clip. A
  /// move that fails this is not offered anywhere on Train.
  bool hasClip(String exerciseId) =>
      library.byId(exerciseId)?.clips.isNotEmpty ?? false;

  /// Whether every move in [exerciseIds] has a clip, so a workout is shown
  /// only when she can watch all of it.
  bool allMovesFilmed(Iterable<String> exerciseIds) =>
      exerciseIds.every(hasClip);

  /// The clip she may be shown for [exerciseId]: the library's row, screened
  /// for her life stage, or null.
  LibraryExercise? clipFor(String exerciseId, LifeStage? stage) {
    for (final exercise in screenedFor(stage).shown) {
      if (exercise.id == exerciseId) return exercise;
    }
    return null;
  }

  /// What R05 may offer in place of [exerciseId] for a woman with [intake]:
  /// empty when the library does not hold the move.
  List<LibraryExercise> swapCandidates(String exerciseId, Intake intake) {
    final current = library.byId(exerciseId);
    if (current == null) return const <LibraryExercise>[];
    return swapCandidatesFor(
      screenedFor(intake.lifeStage).shown,
      current,
      place: intake.place,
      equipment: intake.equipment,
    );
  }

  /// The move she opened, if she may still be shown it.
  LibraryExercise? openedFor(LifeStage? stage) {
    final id = openExerciseId;
    if (id == null) return null;
    for (final exercise in screenedFor(stage).shown) {
      if (exercise.id == id) return exercise;
    }
    return null;
  }

  @visibleForTesting
  void reset() {
    library = ExerciseLibrary.empty;
    openExerciseId = null;
    _loaded = null;
    _loadedOnce = false;
    sync = ExerciseLibrarySync(source: _liveSource);
    media = FirebaseExerciseMediaStore();
    players = VideoPlayerClipPlayer.new;
  }
}
