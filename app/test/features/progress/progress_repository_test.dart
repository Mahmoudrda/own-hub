// The three Progress repositories, and the strictness of their fakes.
//
// PHASE1-QA-VERDICT singles this out as the pattern worth reusing: pinning the
// FAKE's strictness is what stops a case passing in memory and failing on a
// phone. So these tests are as much about what the fakes REFUSE as about what
// they return.

import 'package:flutter_test/flutter_test.dart';

// `Rewards` arrives via progress_repository.dart, which re-exports it so a
// screen reading progress needs one import rather than two.
import 'package:own_hub/domain/rewards/personal_best_detector.dart';
import 'package:own_hub/domain/rewards/week_rollup.dart';
import 'package:own_hub/domain/rewards/weekly_goal.dart';
import 'package:own_hub/domain/week/week_key.dart';
import 'package:own_hub/features/progress/domain/progress_repository.dart';

Measurement _m(
  String dayId, {
  num? weightKg,
  num? waistCm,
  num? hipsCm,
  DateTime? at,
}) => Measurement(
  dayId: dayId,
  takenAt: at ?? DateTime(2026, 9, 18, 7, 30),
  weightKg: weightKg,
  waistCm: waistCm,
  hipsCm: hipsCm,
);

void main() {
  group('weeks and bests are read-only to the client', () {
    test('a week is a point get by deterministic id', () async {
      final store = ProgressStore(
        weeks: {
          '2026-W38': WeekDoc(
            week: WeekKey.tryParse('2026-W38')!,
            sessionsTarget: 2,
            creditedSessionIds: const ['a'],
          ),
        },
      );
      final repo = InMemoryWeeksRepository(store: store);
      addTearDown(repo.dispose);

      final week = await repo.week(WeekKey.tryParse('2026-W38')!);
      expect(week?.sessionsLogged, 1);
      expect(await repo.week(WeekKey.tryParse('2026-W37')!), isNull);
    });

    test('only the server writes her counters', () async {
      // The fake models the Cloud Function explicitly, because the client has
      // no write path at all — firestore.rules publishes `write: if false`.
      final repo = InMemoryWeeksRepository();
      addTearDown(repo.dispose);

      expect((await repo.goal()).countedWeeks, 0);

      final emitted = <WeeklyGoal>[];
      repo.watchGoal().listen(emitted.add);
      repo.serverWrote(const WeeklyGoal(countedWeeks: 9, restWeeksBanked: 1));
      await Future<void>.delayed(Duration.zero);

      expect((await repo.goal()).countedWeeks, 9);
      expect(emitted.single.restWeeksBanked, 1);
    });

    test('rewards come back as the server wrote them', () async {
      final repo = InMemoryWeeksRepository(
        store: ProgressStore(
          rewards: const Rewards(points: 235, level: 3, bestsCount: 4),
        ),
      );
      addTearDown(repo.dispose);

      final rewards = await repo.rewards();
      expect(rewards.points, 235);
      expect(rewards.bestsCount, 4);
    });

    test('bests come back newest first, and by nothing else', () async {
      final repo = InMemoryBestsRepository(
        store: ProgressStore(
          bests: {
            'push_up': const PersonalBest(
              exerciseId: 'push_up',
              metric: BestMetric.reps,
              dateKey: '2026-08-02',
              sessionId: 'a',
              reps: 22,
            ),
            // The heaviest lift, but the oldest date. Date wins, because date
            // is the only ordering this collection has an index for.
            'hip_thrust': const PersonalBest(
              exerciseId: 'hip_thrust',
              metric: BestMetric.load,
              dateKey: '2026-07-14',
              sessionId: 'b',
              loadKg: 60,
            ),
            'side_plank': const PersonalBest(
              exerciseId: 'side_plank',
              metric: BestMetric.hold,
              dateKey: '2026-09-11',
              sessionId: 'c',
              holdSec: 62,
            ),
          },
        ),
      );
      addTearDown(repo.dispose);

      final recent = await repo.recent();
      expect(recent.map((b) => b.exerciseId).toList(), [
        'side_plank',
        'push_up',
        'hip_thrust',
      ]);

      expect((await repo.forExercise('hip_thrust'))?.loadKg, 60);
      expect(await repo.forExercise('nothing_here'), isNull);
    });

    test('the bests limit is a cost control, not paging', () async {
      final repo = InMemoryBestsRepository(
        store: ProgressStore(
          bests: {
            for (var i = 0; i < 30; i++)
              'e$i': PersonalBest(
                exerciseId: 'e$i',
                metric: BestMetric.load,
                dateKey: '2026-09-${(i % 28) + 1}',
                sessionId: 's$i',
                loadKg: i.toDouble(),
              ),
          },
        ),
      );
      addTearDown(repo.dispose);

      expect((await repo.recent(limit: 12)), hasLength(12));
    });
  });

  group('measurements are hers, and the fake is as strict as the rules', () {
    test('a saved measurement reads back', () async {
      final repo = InMemoryMeasurementsRepository();
      addTearDown(repo.dispose);

      await repo.save(_m('2026-09-18', weightKg: 63.5));

      expect((await repo.latest())?.weightKg, 63.5);
      expect(repo.saves, hasLength(1));
    });

    test('history is newest first by document id', () async {
      final repo = InMemoryMeasurementsRepository();
      addTearDown(repo.dispose);

      await repo.save(_m('2026-07-04', weightKg: 66));
      await repo.save(_m('2026-09-18', weightKg: 63.5));
      await repo.save(_m('2026-08-15', weightKg: 64.8));

      final history = await repo.historyForOwner();
      expect(history.map((m) => m.dayId).toList(), [
        '2026-09-18',
        '2026-08-15',
        '2026-07-04',
      ]);
      expect(
        (await repo.latest())?.dayId,
        '2026-09-18',
        reason: 'the most recent date, never the largest or smallest figure',
      );
    });

    test('two devices on the same day both survive', () async {
      // Spine C3's lesson on G6's surface, and G8 K6: field-level merge on
      // distinct keys. Her phone records a weight, her tablet a waist; a
      // whole-document write would lose one of them.
      final store = ProgressStore();
      final phone = InMemoryMeasurementsRepository(store: store);
      final tablet = InMemoryMeasurementsRepository(store: store);
      addTearDown(phone.dispose);
      addTearDown(tablet.dispose);

      await phone.save(_m('2026-09-18', weightKg: 63.5));
      await tablet.save(_m('2026-09-18', waistCm: 76));

      final merged = await phone.latest();
      expect(merged?.weightKg, 63.5);
      expect(merged?.waistCm, 76);
    });

    test('a later null does not erase an earlier value', () async {
      final repo = InMemoryMeasurementsRepository();
      addTearDown(repo.dispose);

      await repo.save(_m('2026-09-18', weightKg: 63.5, waistCm: 76));
      await repo.save(
        _m('2026-09-18', weightKg: 63.1, at: DateTime(2026, 9, 18, 19)),
      );

      final merged = await repo.latest();
      expect(merged?.weightKg, 63.1, reason: 'the newer figure wins');
      expect(merged?.waistCm, 76, reason: 'and the untouched one survives');
    });

    test('a document id the rules would refuse is refused here too', () async {
      final repo = InMemoryMeasurementsRepository();
      addTearDown(repo.dispose);

      // Spine C1: a date-keyed id is what makes an offline retry idempotent.
      // A fake that accepted a random id would let a replay pass in memory and
      // create a duplicate on a phone.
      expect(
        () => repo.save(_m('18-09-2026', weightKg: 63.5)),
        throwsA(isA<StateError>()),
      );
      expect(
        () => repo.save(_m('a1b2c3', weightKg: 63.5)),
        throwsA(isA<StateError>()),
      );
    });

    test('a nonsense figure is refused rather than stored', () async {
      final repo = InMemoryMeasurementsRepository();
      addTearDown(repo.dispose);

      expect(
        () => repo.save(_m('2026-09-18', weightKg: -4)),
        throwsA(isA<StateError>()),
      );
      expect(
        () => repo.save(_m('2026-09-18', waistCm: 0)),
        throwsA(isA<StateError>()),
      );
    });

    test('an empty day is representable and is not an error', () async {
      expect(_m('2026-09-18').isEmpty, isTrue);
      expect(_m('2026-09-18', weightKg: 63.5).isEmpty, isFalse);
    });

    test('purgeLocal leaves nothing behind on the handset', () async {
      // G7's A02 manifest row 33. Without this, her data is still readable from
      // the offline cache after the account is gone — P0-DEL-01 fails on-device
      // while passing on the server.
      final repo = InMemoryMeasurementsRepository();
      addTearDown(repo.dispose);

      await repo.save(_m('2026-09-18', weightKg: 63.5));
      await repo.purgeLocal();

      expect(await repo.latest(), isNull);
      expect(await repo.historyForOwner(), isEmpty);
      expect(repo.saves, isEmpty);
      expect(repo.purged, isTrue);
    });
  });
}
