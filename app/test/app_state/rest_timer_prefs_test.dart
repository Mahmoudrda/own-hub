// The rest she sets on R09 is kept per move, on this phone only: it survives
// being closed, an old snapshot reads as none, and Delete everything clears it.

import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:own_hub/app_state/account_data.dart';
import 'package:own_hub/app_state/app_snapshot.dart';
import 'package:own_hub/app_state/rest_timer_prefs.dart';
import 'package:own_hub/app_state/workout_session_state.dart';
import 'package:own_hub/domain/training/prescribed_set.dart';
import 'package:own_hub/features/train/domain/rest_policy.dart';
import 'package:own_hub/features/train/domain/train_repository.dart';
import 'package:shared_preferences/shared_preferences.dart';

PlannedMove _move(String id, int sets) => PlannedMove(
  exerciseId: id,
  name: id,
  prescriptionLabel: '',
  sets: [
    for (var i = 1; i <= sets; i++)
      PrescribedSet(exerciseId: id, order: i, reps: 10),
  ],
);

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  final prefs = RestTimerPrefs.instance;
  final session = WorkoutSessionState.instance;

  setUp(() async {
    SharedPreferences.setMockInitialValues(const <String, Object>{});
    prefs.reset();
    session.reset();
  });

  tearDown(() {
    prefs.reset();
    session.reset();
  });

  group('per move', () {
    test('a move she never changed rests the standard time', () {
      expect(prefs.forMove('squat'), isNull);
      expect(prefs.restFor('squat'), kRestDuration);
      expect(prefs.restFor(null), kRestDuration);
    });

    test('the new total is that move\'s rest, and only that move\'s', () {
      prefs.setFor('squat', const Duration(seconds: 75));
      expect(prefs.restFor('squat'), const Duration(seconds: 75));
      expect(prefs.restFor('bridge'), kRestDuration);
      prefs.setFor('squat', const Duration(seconds: 45));
      expect(prefs.restFor('squat'), const Duration(seconds: 45));
    });

    test('a value that should not exist is never kept', () {
      prefs.setFor('squat', const Duration(seconds: 3));
      expect(prefs.restFor('squat'), const Duration(seconds: 15));
      prefs.setFor('squat', const Duration(seconds: 5000));
      expect(prefs.restFor('squat'), const Duration(seconds: 600));
    });
  });

  group('the rest the session starts from', () {
    final day = WorkoutDay(
      id: '2026-10-13',
      title: 'Legs',
      summary: '',
      constraints: '',
      moves: [_move('squat', 2), _move('bridge', 2)],
    );

    Future<void> started() async {
      session.start(day, InMemoryTrainRepository());
      await Future<void>.delayed(Duration.zero);
    }

    test('a move she has set starts from her total', () async {
      prefs.setFor('squat', const Duration(seconds: 90));
      await started();
      session.setLogged();
      expect(session.restMoveId, 'squat');
      expect(session.restDuration, const Duration(seconds: 90));
    });

    test('the rest after a move\'s last set is still that move\'s', () async {
      prefs.setFor('squat', const Duration(seconds: 90));
      await started();
      session.setLogged();
      session.setLogged();
      // currentMove is already the next move; the rest is for the one done.
      expect(session.currentMove?.exerciseId, 'bridge');
      expect(session.restMoveId, 'squat');
      expect(session.restDuration, const Duration(seconds: 90));
    });

    test(
      'changing the rest keeps it for next time, not for this rest',
      () async {
        await started();
        session.setLogged();
        expect(session.restDuration, kRestDuration);
        session.rememberRest(const Duration(seconds: 75));
        expect(prefs.restFor('squat'), const Duration(seconds: 75));
        expect(
          session.restDuration,
          kRestDuration,
          reason: 'where this rest began must not move under the running clock',
        );
      },
    );

    test(
      'the next time she trains the move it starts from her total',
      () async {
        await started();
        session.setLogged();
        session.rememberRest(const Duration(seconds: 75));
        session.reset();
        await started();
        session.setLogged();
        expect(session.restDuration, const Duration(seconds: 75));
      },
    );
  });

  group('phone only', () {
    test('the snapshot carries it and restores it', () async {
      prefs.setFor('squat', const Duration(seconds: 75));
      prefs.setFor('bridge', const Duration(seconds: 30));
      final document = jsonEncode(AppSnapshot.capture());
      prefs.reset();
      expect(prefs.touched, isFalse);

      AppSnapshot.restore(document);
      expect(prefs.restFor('squat'), const Duration(seconds: 75));
      expect(prefs.restFor('bridge'), const Duration(seconds: 30));
    });

    test(
      'a snapshot with none writes no section, and an old one reads as none',
      () {
        final captured = AppSnapshot.capture();
        expect(captured.containsKey('restTimer'), isFalse);

        prefs.setFor('squat', const Duration(seconds: 75));
        final withOne = AppSnapshot.capture();
        expect(withOne['restTimer'], isNotNull);

        // A snapshot from before the section existed.
        withOne.remove('restTimer');
        prefs.reset();
        AppSnapshot.restore(jsonEncode(withOne));
        expect(prefs.touched, isFalse);
        expect(prefs.restFor('squat'), kRestDuration);
      },
    );

    test('damaged entries are dropped rather than trusted', () {
      final document = jsonEncode({
        'schema': 2,
        'restTimer': {
          'moves': {'squat': 75, 'bridge': 'soon', '': 40, 'lunge': -5},
        },
      });
      AppSnapshot.restore(document);
      expect(prefs.toJson(), {'squat': 75});
    });

    test('Delete everything clears it', () async {
      prefs.setFor('squat', const Duration(seconds: 75));
      expect(nothingOfHersRemains, isFalse);

      await const ThisPhoneWipe().clearPersistence();
      expect(prefs.touched, isFalse);
      expect(prefs.restFor('squat'), kRestDuration);
      expect(nothingOfHersRemains, isTrue);
    });

    test('it is in no cloud document', () {
      final cloud = File('lib/app_state/cloud_documents.dart')
          .readAsStringSync();
      expect(cloud.contains('RestTimerPrefs'), isFalse);
      expect(cloud.contains('restTimer'), isFalse);
    });
  });
}
