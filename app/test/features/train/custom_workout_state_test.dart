// Her own workouts: the bounds every edit keeps, the snapshot they ride in,
// the cloud documents they become and the weekly goal they count toward.

import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:own_hub/app_state/app_snapshot.dart';
import 'package:own_hub/app_state/cloud_documents.dart';
import 'package:own_hub/app_state/custom_workout_state.dart';
import 'package:own_hub/domain/clock/app_clock.dart';
import 'package:own_hub/domain/training/prescribed_set.dart';
import 'package:own_hub/features/train/domain/custom_workout.dart';
import 'package:own_hub/features/train/domain/programme_week.dart';
import 'package:own_hub/features/train/domain/train_repository.dart';
import 'package:own_hub/features/train/presentation/authored_workout.dart';
import 'package:own_hub/l10n/app_l10n_en.dart';

CustomWorkout _workout(String id, {String name = 'Legs'}) => CustomWorkout(
  id: id,
  name: name,
  moves: const [
    CustomMove(exerciseId: 'goblet_squat', sets: 4, reps: 8, weightKg: 12.5),
    CustomMove(exerciseId: 'forearm_plank', sets: 2, holdSeconds: 40),
  ],
);

void main() {
  final state = CustomWorkoutState.instance;
  setUp(state.reset);
  tearDown(state.reset);

  group('bounds', () {
    test('sets, reps, seconds and weight stay inside their limits', () {
      final move = const CustomMove(
        exerciseId: 'a',
        reps: 10,
      ).copyWith(sets: 99, reps: 0, weightKg: 900);
      expect(move.sets, kMaxSets);
      expect(move.reps, kMinReps);
      expect(move.weightKg, kMaxWeightKg);
      final held = move.copyWith(timed: true, holdSeconds: 1, sets: 0);
      expect(held.holdSeconds, kMinHoldSeconds);
      expect(held.reps, isNull);
      expect(held.sets, kMinSets);
    });

    test('a weight under the minimum is bodyweight, never zero', () {
      final move = const CustomMove(
        exerciseId: 'a',
        reps: 10,
        weightKg: 5,
      ).copyWith(weightKg: 0.2);
      expect(move.weightKg, isNull);
    });

    test('a hostile row costs that row, not the workout', () {
      final parsed = CustomWorkout.tryParse(<String, Object?>{
        'id': 'w1',
        'name': '  A   very  long name ' * 10,
        'moves': [
          'nonsense',
          <String, Object?>{'exerciseId': 'ok', 'sets': 1e9, 'reps': -4},
        ],
      });
      expect(parsed, isNotNull);
      expect(parsed!.moves, hasLength(1));
      expect(parsed.moves.single.sets, kMaxSets);
      expect(parsed.moves.single.reps, kMinReps);
      expect(parsed.name.length, lessThanOrEqualTo(kMaxCustomNameLength));
      expect(
        CustomWorkout.tryParse(<String, Object?>{'id': 'Bad Id!'}),
        isNull,
      );
    });
  });

  group('saving, deleting and undo', () {
    test('delete remembers the id and Undo puts it back where it was', () {
      state.save(_workout('wa'));
      state.save(_workout('wb', name: 'Arms'));
      expect(state.workouts.map((w) => w.id), ['wb', 'wa']);

      final removed = state.remove('wb')!;
      expect(state.workouts.map((w) => w.id), ['wa']);
      expect(state.deletedIds, ['wb']);

      state.restore(removed.workout, removed.index);
      expect(state.workouts.map((w) => w.id), ['wb', 'wa']);
      expect(state.deletedIds, isEmpty);
    });

    test('a workout she deleted does not come back from the cloud', () {
      state.save(_workout('wa'));
      state.remove('wa');
      expect(state.adoptRemote(_workout('wa')), isFalse);
      expect(state.workouts, isEmpty);
    });

    test('Save as my workout twice updates the same one', () {
      state.pin(
        const WorkoutDay(
          id: '2026-10-20',
          title: 'x',
          summary: '',
          constraints: '',
          moves: [],
        ),
      );
      final id = state.newId();
      state.save(_workout(id));
      state.linkDraft(id);
      state.save(_workout(id, name: 'Renamed'));
      expect(state.workouts, hasLength(1));
      expect(state.workouts.single.name, 'Renamed');
      expect(state.draft?.customId, id);
    });
  });

  group('keeping them', () {
    test('the 31st is refused, and an existing one can still be updated', () {
      for (var i = 0; i < kMaxCustomWorkouts; i++) {
        expect(state.save(_workout('w$i')), isTrue);
      }
      expect(state.save(_workout('extra')), isFalse);
      expect(state.workouts, hasLength(kMaxCustomWorkouts));
      expect(state.byId('extra'), isNull);
      expect(state.byId('w0'), isNotNull, reason: 'nothing is lost silently');
      expect(state.save(_workout('w0', name: 'Renamed')), isTrue);
      expect(state.byId('w0')!.name, 'Renamed');
    });

    test('ids stay unique under a frozen clock', () {
      AppClock.debugNow = () => DateTime(2026, 10, 20, 9);
      addTearDown(() => AppClock.debugNow = null);
      final ids = <String>{};
      for (var i = 0; i < 5; i++) {
        final id = state.newId();
        expect(ids.add(id), isTrue);
        state.save(_workout(id));
      }
      expect(state.workouts, hasLength(5));
    });

    test('a copy from the cloud replaces mine only when it is newer', () {
      final old = DateTime(2026, 10, 1);
      final newer = DateTime(2026, 10, 2);
      state.workouts = [
        CustomWorkout(
          id: 'wa',
          name: 'Mine',
          moves: _workout('wa').moves,
          updatedAt: newer,
        ),
      ];
      final stale = CustomWorkout(
        id: 'wa',
        name: 'Stale',
        moves: _workout('wa').moves,
        updatedAt: old,
      );
      expect(state.adoptRemote(stale), isFalse);
      expect(state.byId('wa')!.name, 'Mine');
      final fresh = CustomWorkout(
        id: 'wa',
        name: 'Fresh',
        moves: _workout('wa').moves,
        updatedAt: DateTime(2026, 10, 3),
      );
      expect(state.adoptRemote(fresh), isTrue);
      expect(state.byId('wa')!.name, 'Fresh');
      expect(state.workouts, hasLength(1));
    });

    test('the key does not depend on the language of the title', () {
      WorkoutDay day(String title) => WorkoutDay(
        id: '2026-10-20',
        title: title,
        summary: '',
        constraints: '',
        moves: [
          PlannedMove(
            exerciseId: 'goblet_squat',
            name: title,
            prescriptionLabel: '',
            sets: const [],
          ),
        ],
      );
      expect(
        CustomWorkoutState.keyOf(day('Legs')),
        CustomWorkoutState.keyOf(day('رجلين')),
      );
    });
  });

  group('today\'s edits', () {
    WorkoutDay day(String id) => WorkoutDay(
      id: id,
      title: 'x',
      summary: '',
      constraints: '',
      moves: const [],
    );

    test('a draft from yesterday is dropped', () {
      AppClock.debugNow = () => DateTime(2026, 10, 19, 9);
      addTearDown(() => AppClock.debugNow = null);
      state.setDraft(day('2026-10-19'), baseKey: 'k');
      expect(state.draftFor('k'), isNotNull);
      AppClock.debugNow = () => DateTime(2026, 10, 20, 9);
      expect(state.draftFor('k'), isNull);
      expect(state.draft, isNull);
    });

    test('edits made to one session are not applied to another', () {
      state.setDraft(day('2026-10-20'), baseKey: 'session-a');
      expect(state.draftFor('session-a'), isNotNull);
      expect(state.draftFor('session-b'), isNull);
    });

    test('opening another session clears them', () {
      state.setDraft(day('2026-10-20'), baseKey: 'session-a');
      state.clearDraft();
      expect(state.draftFor('session-a'), isNull);
    });
  });

  group('the snapshot', () {
    test('round-trips her workouts and her deletions', () {
      state.save(_workout('wa'));
      state.save(_workout('wb'));
      state.remove('wb');

      final json = jsonEncode(AppSnapshot.capture());
      state.reset();
      expect(state.workouts, isEmpty);

      AppSnapshot.restore(json);
      expect(state.workouts.map((w) => w.id), ['wa']);
      expect(state.workouts.single.moves, _workout('wa').moves);
      expect(state.deletedIds, ['wb']);
    });

    test('today\'s edits are not saved', () {
      state.pin(
        const WorkoutDay(
          id: '2026-10-20',
          title: 'x',
          summary: '',
          constraints: '',
          moves: [],
        ),
      );
      final json = jsonEncode(AppSnapshot.capture());
      expect(json, isNot(contains('"draft"')));
    });
  });

  group('the cloud documents', () {
    test('each workout is a self-owned split the rules accept', () {
      state.save(_workout('wa'));
      final docs = [
        for (final d in CloudDocuments.capture())
          if (d.collection == 'splits') d,
      ];
      expect(docs, hasLength(1));
      final doc = docs.single;
      expect(doc.id, 'wa');
      // `ownerKind: 'self'`, no run counter, `updatedAt` the server's clock:
      // the three things `firestore.rules` checks on a split.
      expect(doc.data['ownerKind'], 'self');
      expect(doc.data.keys, isNot(contains('runCounter')));
      expect(doc.data['updatedAt'], kServerTime);
      expect(doc.data.keys.toSet(), {
        'ownerKind',
        'schemaV',
        'name',
        'moves',
        'updatedAt',
      });
    });

    test('a deletion is a tombstone with the same guards', () {
      state.save(_workout('wa'));
      state.remove('wa');
      final doc = CloudDocuments.capture().firstWhere(
        (d) => d.collection == 'splits',
      );
      expect(doc.data['deleted'], isTrue);
      expect(doc.data['ownerKind'], 'self');
      expect(doc.data.keys, isNot(contains('moves')));
    });

    test('folding the cloud in adds what is missing and honours deletions', () {
      state.save(_workout('keep'));
      final taken = CloudDocuments.mergeIn([
        CloudDoc(
          collection: 'splits',
          id: 'fromcloud',
          data: <String, Object?>{
            'ownerKind': 'self',
            'name': 'Cloud one',
            'moves': [_workout('x').moves.first.toJson()],
          },
        ),
        CloudDoc(
          collection: 'splits',
          id: 'keep',
          data: <String, Object?>{'ownerKind': 'self', 'deleted': true},
        ),
        // Not hers to fold in: a coach's split carries another owner kind.
        CloudDoc(
          collection: 'splits',
          id: 'coachs',
          data: <String, Object?>{
            'ownerKind': 'coach',
            'name': 'Coach',
            'moves': [_workout('x').moves.first.toJson()],
          },
        ),
      ]);
      expect(taken, 2, reason: 'one added, one deleted; the coach\'s skipped');
      expect(state.workouts.map((w) => w.id), ['fromcloud']);
    });
  });

  group('the weekly goal', () {
    test(
      'a finished custom session counts like any finished session',
      () async {
        final now = DateTime(2026, 10, 14, 9);
        final repo = InMemoryTrainRepository();
        final day = customWorkoutDay(
          AppL10nEn(),
          name: 'My workout',
          now: now,
          moves: [
            PlannedMove(
              exerciseId: 'goblet_squat',
              name: 'Goblet squat',
              prescriptionLabel: '4 × 8',
              sets: [
                for (var i = 1; i <= 4; i++)
                  PrescribedSet(
                    exerciseId: 'goblet_squat',
                    order: i,
                    reps: 8,
                    weightKg: 12.5,
                  ),
              ],
            ),
          ],
        );
        final session = await repo.startSession(day);
        expect(sessionsDoneThisWeek(repo.sessions, now: now), 0);
        await repo.finishSession(sessionId: session.id, durationSec: 900);
        expect(sessionsDoneThisWeek(repo.sessions, now: now), 1);
      },
    );
  });
}
