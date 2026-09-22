// The ledger that makes a detected best durable — and countable.
//
// `PersonalBestDetector` computes; it stores nothing and counts nothing. This
// is the half that was missing: the running maximum per exercise, and
// `rewards.bestsCount`, which `TierLadder.shipped` gates Regular, Strong and
// Unshakeable on.
//
// Figures are unlike the detector's own fixtures (18/20/16/22/14 kg, 22 reps,
// 62 s) and unlike the prototype's (12 kg x 10, 3 x 15, 45 s), so a ledger that
// recited either would fail here.

import 'package:flutter_test/flutter_test.dart';

import 'package:own_hub/domain/rewards/personal_best_detector.dart';
import 'package:own_hub/domain/rewards/personal_best_ledger.dart';
import 'package:own_hub/domain/rewards/tier_policy.dart';
import 'package:own_hub/domain/rewards/week_rollup.dart';
import 'package:own_hub/domain/training/session.dart';
import 'package:own_hub/domain/week/week_key.dart';

const String _date = '2026-09-19';

const Map<String, ExerciseMeta> _library = <String, ExerciseMeta>{
  'goblet_squat': ExerciseMeta(
    exerciseId: 'goblet_squat',
    metric: BestMetric.load,
  ),
  'hip_thrust': ExerciseMeta(exerciseId: 'hip_thrust', metric: BestMetric.load),
  'row': ExerciseMeta(exerciseId: 'row', metric: BestMetric.load),
  'glute_bridge': ExerciseMeta(
    exerciseId: 'glute_bridge',
    metric: BestMetric.reps,
  ),
  'plank_hold': ExerciseMeta(exerciseId: 'plank_hold', metric: BestMetric.hold),
};

SessionBests _apply(
  PersonalBestLedger ledger,
  List<MeasuredSet> sets, {
  String sessionId = 'sess-7k2',
  String dateKey = _date,
  SessionSource source = SessionSource.live,
}) {
  return ledger.apply(
    source: source,
    sessionId: sessionId,
    dateKey: dateKey,
    measuredSets: sets,
    exercises: _library,
  );
}

/// Eight closed weeks that counted — enough recency to hold any rung.
List<WeekBar> _eightCountedWeeks() => [
  for (var i = 0; i < 8; i++)
    WeekBar(
      week: WeekKey.of(DateTime(2026, 7, 6).add(Duration(days: 7 * i))),
      sessionsLogged: 3,
      sessionsTarget: 3,
      counted: true,
    ),
];

void main() {
  group('a heavier set becomes a best, and the best becomes a count', () {
    test('her first logged lift on a move is a best', () {
      final ledger = PersonalBestLedger();

      final recorded = _apply(ledger, [
        const MeasuredSet(
          exerciseId: 'goblet_squat',
          actualWeight: 27.5,
          actualReps: 13,
        ),
      ]);

      expect(recorded.counted, hasLength(1));
      expect(ledger.bests['goblet_squat']!.loadKg, 27.5);
      expect(ledger.bests['goblet_squat']!.reps, 13);
      expect(ledger.bestsCount, 1);
    });

    test('a heavier lift than the one she holds replaces it', () {
      final ledger = PersonalBestLedger(
        bests: {
          'goblet_squat': const PersonalBest(
            exerciseId: 'goblet_squat',
            metric: BestMetric.load,
            dateKey: '2026-08-31',
            sessionId: 'older',
            loadKg: 27.5,
            reps: 13,
          ),
        },
        bestsCount: 1,
      );

      final recorded = _apply(ledger, [
        const MeasuredSet(
          exerciseId: 'goblet_squat',
          actualWeight: 34,
          actualReps: 9,
        ),
      ]);

      expect(recorded.counted, hasLength(1));
      expect(ledger.bests['goblet_squat']!.loadKg, 34);
      expect(
        ledger.bests['goblet_squat']!.previous?.loadKg,
        27.5,
        reason: 'P03 renders "was 27.5 kg" from this',
      );
      expect(ledger.bestsCount, 2);
    });

    test('D19 — a longer hold is a best, end to end', () {
      final ledger = PersonalBestLedger(
        bests: {
          'plank_hold': const PersonalBest(
            exerciseId: 'plank_hold',
            metric: BestMetric.hold,
            dateKey: '2026-09-02',
            sessionId: 'older',
            holdSec: 71,
          ),
        },
      );

      _apply(ledger, [
        const MeasuredSet(exerciseId: 'plank_hold', actualHoldSec: 96),
      ]);

      expect(ledger.bests['plank_hold']!.holdSec, 96);
      expect(ledger.bestsCount, 1);
    });
  });

  group('NEGATIVE CONTROLS — what must never become a best', () {
    test(
      'a lighter set is not a best and does not overwrite the one she holds',
      () {
        final ledger = PersonalBestLedger(
          bests: {
            'hip_thrust': const PersonalBest(
              exerciseId: 'hip_thrust',
              metric: BestMetric.load,
              dateKey: '2026-09-11',
              sessionId: 'older',
              loadKg: 41,
              reps: 11,
            ),
          },
          bestsCount: 1,
        );

        final recorded = _apply(ledger, [
          const MeasuredSet(
            exerciseId: 'hip_thrust',
            actualWeight: 27.5,
            actualReps: 13,
          ),
        ]);

        expect(recorded.written, isEmpty);
        expect(recorded.counted, isEmpty);
        expect(
          ledger.bests['hip_thrust']!.loadKg,
          41,
          reason: 'nothing earned is ever taken away',
        );
        expect(ledger.bestsCount, 1);
      },
    );

    test('a set she logged nothing on is not a best', () {
      // What an unlogged set looks like after the conversion drops it: an
      // absence. The ledger must not read it as a lift of no weight.
      final ledger = PersonalBestLedger();
      final recorded = _apply(ledger, const <MeasuredSet>[]);

      expect(recorded.written, isEmpty);
      expect(ledger.bestsCount, 0);
      expect(ledger.bests, isEmpty);
    });

    test('a recalled session records nothing and counts nothing', () {
      final ledger = PersonalBestLedger();

      final recorded = _apply(ledger, [
        const MeasuredSet(
          exerciseId: 'goblet_squat',
          actualWeight: 34,
          actualReps: 9,
        ),
      ], source: SessionSource.recalled);

      expect(recorded.written, isEmpty);
      expect(ledger.bestsCount, 0);
    });

    test('an unplanned session records nothing either', () {
      final ledger = PersonalBestLedger();

      _apply(ledger, [
        const MeasuredSet(
          exerciseId: 'goblet_squat',
          actualWeight: 34,
          actualReps: 9,
        ),
      ], source: SessionSource.unplanned);

      expect(ledger.bestsCount, 0);
    });

    test('an exercise the pack does not describe counts nothing', () {
      final ledger = PersonalBestLedger();

      _apply(ledger, [
        const MeasuredSet(
          exerciseId: 'not_in_the_pack',
          actualWeight: 34,
          actualReps: 9,
        ),
      ]);

      expect(
        ledger.bestsCount,
        0,
        reason: 'a missing content tag fails closed rather than guessing',
      );
    });

    test('bestsCount never falls', () {
      final ledger = PersonalBestLedger();

      _apply(ledger, [
        const MeasuredSet(
          exerciseId: 'goblet_squat',
          actualWeight: 34,
          actualReps: 9,
        ),
      ]);
      expect(ledger.bestsCount, 1);

      // A lighter session afterwards, then a skipped one.
      _apply(ledger, [
        const MeasuredSet(
          exerciseId: 'goblet_squat',
          actualWeight: 20,
          actualReps: 5,
        ),
      ], sessionId: 'sess-later');
      _apply(ledger, const <MeasuredSet>[], sessionId: 'sess-later-still');

      expect(ledger.bestsCount, 1);
    });
  });

  group('idempotent — a replayed flush mints nothing', () {
    test('applying the same flush twice counts once', () {
      final ledger = PersonalBestLedger();
      final sets = [
        const MeasuredSet(
          exerciseId: 'goblet_squat',
          actualWeight: 34,
          actualReps: 9,
        ),
      ];

      final first = _apply(ledger, sets);
      final second = _apply(ledger, sets);

      expect(first.counted, hasLength(1));
      expect(second.counted, isEmpty);
      expect(ledger.bestsCount, 1);
      expect(ledger.bests['goblet_squat']!.loadKg, 34);
    });

    test('the id ledger bites even when the held best is stale', () {
      // Belt and braces. The detector is self-idempotent once the best is
      // materialised, so a replay normally finds nothing to beat. This is the
      // case where that protection is absent — a retry that arrives before the
      // best was persisted — and the deterministic id is all that stands
      // between her and a double count.
      final ledger = PersonalBestLedger(
        countedIds: const ['best:goblet_squat:sess-7k2'],
      );

      final recorded = _apply(ledger, [
        const MeasuredSet(
          exerciseId: 'goblet_squat',
          actualWeight: 34,
          actualReps: 9,
        ),
      ]);

      expect(
        recorded.written,
        hasLength(1),
        reason: 'the running best is still brought up to date',
      );
      expect(recorded.counted, isEmpty);
      expect(ledger.bestsCount, 0);
    });

    test('a second improvement in the same session raises the best once', () {
      // R07 flushes per set. Two sets of one move are two flushes of the same
      // session, and the second may beat the first.
      final ledger = PersonalBestLedger();

      _apply(ledger, [
        const MeasuredSet(
          exerciseId: 'goblet_squat',
          actualWeight: 27.5,
          actualReps: 13,
        ),
      ]);
      _apply(ledger, [
        const MeasuredSet(
          exerciseId: 'goblet_squat',
          actualWeight: 34,
          actualReps: 9,
        ),
      ]);

      expect(
        ledger.bests['goblet_squat']!.loadKg,
        34,
        reason: 'she lifted it, so P03 must show it',
      );
      expect(
        ledger.bestsCount,
        1,
        reason: 'one best per exercise per session, exactly as the award is',
      );
    });

    test('the next session counts again', () {
      final ledger = PersonalBestLedger();

      _apply(ledger, [
        const MeasuredSet(
          exerciseId: 'goblet_squat',
          actualWeight: 27.5,
          actualReps: 13,
        ),
      ]);
      _apply(
        ledger,
        [
          const MeasuredSet(
            exerciseId: 'goblet_squat',
            actualWeight: 34,
            actualReps: 9,
          ),
        ],
        sessionId: 'sess-9m4',
        dateKey: '2026-09-26',
      );

      expect(ledger.bestsCount, 2);
    });

    test('the id is the one the award table already mints', () {
      // `AwardTable` awards a best under `best:$exerciseId:$sessionId`. If the
      // two ever diverge, points and counts would disagree about what happened.
      expect(
        personalBestId(exerciseId: 'goblet_squat', sessionId: 'sess-7k2'),
        'best:goblet_squat:sess-7k2',
      );
    });
  });

  group('RULE 11 — a best is a load on a bar, never the woman', () {
    test('the ledger stores loadKg and has no field naming her weight', () {
      final ledger = PersonalBestLedger();

      _apply(ledger, [
        const MeasuredSet(
          exerciseId: 'goblet_squat',
          actualWeight: 34,
          actualReps: 9,
        ),
      ]);

      final best = ledger.bests['goblet_squat']!;
      expect(best.loadKg, 34);
      expect(
        best.toString(),
        contains('load:34'),
        reason: 'the dumbbell, and it cannot be mistaken for the woman',
      );
    });
  });

  group('D14 — the tier ladder is reachable because the count moves', () {
    // The reason this was urgent. `TierLadder.shipped` gates Regular on 3
    // bests, Strong on 8 and Unshakeable on 15. With nothing incrementing
    // `bestsCount`, those three rungs were unreachable however long she trained.
    const policy = TierPolicy();

    PersonalBestLedger afterSessions(int count) {
      final ledger = PersonalBestLedger();
      const moves = ['goblet_squat', 'hip_thrust', 'row'];
      for (var i = 0; i < count; i++) {
        _apply(
          ledger,
          [
            MeasuredSet(
              exerciseId: moves[i % moves.length],
              actualWeight: 27.5 + i,
              actualReps: 9,
            ),
          ],
          sessionId: 'sess-$i',
          dateKey: '2026-09-0${i + 1}',
        );
      }
      return ledger;
    }

    test('three bests promote her to Regular', () {
      final ledger = afterSessions(3);
      expect(ledger.bestsCount, 3);

      final standing = policy.evaluate(
        ladder: TierLadder.shipped,
        countedWeeks: 12,
        bestsCount: ledger.bestsCount,
        recentClosedWeeks: _eightCountedWeeks(),
      );

      expect(standing.earned, Tier.regular);
      expect(standing.display, Tier.regular);
    });

    test('NEGATIVE — two bests do not', () {
      final ledger = afterSessions(2);
      expect(ledger.bestsCount, 2);

      final standing = policy.evaluate(
        ladder: TierLadder.shipped,
        countedWeeks: 12,
        bestsCount: ledger.bestsCount,
        recentClosedWeeks: _eightCountedWeeks(),
      );

      expect(
        standing.earned,
        Tier.showingUp,
        reason: 'promotion needs both axes, so weeks alone do not get there',
      );
    });

    test('a ledger that never counted leaves Regular unreachable', () {
      // The defect this whole change exists to fix, stated as a test: with
      // bestsCount stuck at zero, a woman with a year of counted weeks tops out
      // below Regular forever.
      final standing = policy.evaluate(
        ladder: TierLadder.shipped,
        countedWeeks: 52,
        bestsCount: 0,
        recentClosedWeeks: _eightCountedWeeks(),
      );

      expect(standing.earned, Tier.showingUp);
    });
  });
}
