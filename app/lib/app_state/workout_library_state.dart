/// The owner's workouts on this phone: what R11 lists beside the bundled
/// session, and the one she chose for R03.
///
/// Read from the cache at once and from Firestore once a day for a verified
/// account (`WorkoutSync`). With nothing cached and nothing reachable the
/// library is empty and Train is exactly what it was: the bundled session,
/// which day one always uses.
library;

import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:meta/meta.dart';

import '../features/onboarding/domain/intake.dart' show LifeStage;
import '../features/train/data/workout_sync.dart';
import '../features/train/domain/workout_library.dart';
import 'app_changes.dart';
import 'firebase_boot.dart';

class WorkoutLibraryState {
  WorkoutLibraryState._();

  static final WorkoutLibraryState instance = WorkoutLibraryState._();

  WorkoutSync sync = WorkoutSync(source: _liveSource);

  WorkoutLibrary library = WorkoutLibrary.empty;

  /// The R11 row she tapped, or null for the bundled session.
  String? chosenRowId;

  /// The day of her week she opened on R02, or null for today's. Counted from
  /// the first day, never a weekday.
  int? openedSlot;

  Future<void>? _loaded;

  static WorkoutRemoteSource? _liveSource() {
    try {
      if (!FirebaseBoot.isReady) return null;
      return FirestoreWorkoutSource(FirebaseFirestore.instance);
    } catch (_) {
      return null;
    }
  }

  /// The cache, then the server when a day has passed. Never throws.
  Future<void> refresh() async {
    try {
      _loaded ??= sync.load().then(_adopt);
      await _loaded;
      final (_, updated) = await sync.refresh();
      if (updated != null) _adopt(updated);
    } catch (_) {
      // The cache, or the bundled session, is already the answer.
    }
  }

  void _adopt(WorkoutLibrary next) {
    if (next.version < library.version) return;
    library = next;
    AppChanges.bump();
  }

  /// The sessions a woman at [stage] is offered.
  List<({AuthoredProgramme programme, AuthoredSession session})> sessionsFor(
    LifeStage? stage,
  ) => library.sessionsFor(stage);

  /// The chosen session, if she may still be offered it.
  ({AuthoredProgramme programme, AuthoredSession session})? chosenFor(
    LifeStage? stage,
  ) {
    final id = chosenRowId;
    if (id == null) return null;
    for (final entry in sessionsFor(stage)) {
      if (libraryRowId(entry.programme.programId, entry.session.sessionId) ==
          id) {
        return entry;
      }
    }
    return null;
  }

  @visibleForTesting
  void reset() {
    library = WorkoutLibrary.empty;
    chosenRowId = null;
    openedSlot = null;
    _loaded = null;
    sync = WorkoutSync(source: _liveSource);
  }
}
