// D38: one weekly challenge, against her own last week, always beatable by
// finishing the plan she has.

import 'package:flutter_test/flutter_test.dart';
import 'package:own_hub/domain/training/prescribed_set.dart';
import 'package:own_hub/domain/week/week_key.dart';
import 'package:own_hub/features/train/domain/own_best_challenge.dart';
import 'package:own_hub/features/train/domain/train_repository.dart';

PlannedMove move(String id, {int sets = 3, int? reps = 10, int? hold}) =>
    PlannedMove(
      exerciseId: id,
      name: id,
      prescriptionLabel: '',
      sets: [
        for (var i = 1; i <= sets; i++)
          PrescribedSet(
            exerciseId: id,
            order: i,
            reps: reps,
            holdSeconds: hold,
          ),
      ],
    );

LoggedSet done(String id, {int? reps, int? hold}) =>
    LoggedSet(prescribed: PrescribedSet(exerciseId: id, order: 1))
        .recording(SetOutcome(reps: reps, holdSeconds: hold));

final WeekKey thisWeek = WeekKey.of(DateTime(2026, 10, 13));
final WeekKey lastWeek = WeekKey.of(DateTime(2026, 10, 6));

void main() {
  const own = OwnBestChallenge();
  final plan = [
    move('squat'),
    move('bridge', reps: 12),
    move('plank', reps: null, hold: 30),
  ];

  test('no last week, no challenge', () {
    expect(
      own.choose(
        week: thisWeek,
        plan: plan,
        sessionsTarget: 3,
        lastWeek: const {},
      ),
      isNull,
    );
  });

  test('beat: the widest gap, one more than last week, never above the plan', () {
    final challenge = own.choose(
      week: thisWeek,
      plan: plan,
      sessionsTarget: 3,
      lastWeek: const {
        // squat planned 90, did 60 (gap 1/3); bridge planned 108, did 36 (2/3).
        'squat': (reps: 60, seconds: 0, sets: 6),
        'bridge': (reps: 36, seconds: 0, sets: 3),
      },
    )!;
    expect(challenge.exerciseId, 'bridge');
    expect(challenge.kind, ChallengeKind.beat);
    expect(challenge.target, 37);
    expect(challenge.planned, 108);
    expect(challenge.target, lessThanOrEqualTo(challenge.planned));
  });

  test('match: when last week met the plan exactly, the move she did most', () {
    final challenge = own.choose(
      week: thisWeek,
      plan: plan,
      sessionsTarget: 1,
      lastWeek: const {
        'squat': (reps: 30, seconds: 0, sets: 4),
        'plank': (reps: 0, seconds: 90, sets: 3),
      },
    )!;
    expect(challenge.kind, ChallengeKind.match);
    expect(challenge.exerciseId, 'squat');
    expect(challenge.target, 30); // the plan: 3 × 10 × 1
    expect(challenge.lastWeek, challenge.target);
  });

  test(
    'a week past the plan sets nothing: it would ask for more than the plan',
    () {
      expect(
        own.choose(
          week: thisWeek,
          plan: [move('squat')],
          sessionsTarget: 1,
          lastWeek: const {'squat': (reps: 40, seconds: 0, sets: 4)},
        ),
        isNull,
      );
    },
  );

  test('any challenge it sets asks for no more than the plan', () {
    for (final did in [1, 29, 30, 31, 90, 300]) {
      final challenge = own.choose(
        week: thisWeek,
        plan: [move('squat')],
        sessionsTarget: 1,
        lastWeek: {'squat': (reps: did, seconds: 0, sets: 3)},
      );
      if (challenge == null) continue;
      expect(challenge.target, lessThanOrEqualTo(challenge.planned));
      if (challenge.kind == ChallengeKind.match) {
        expect(challenge.lastWeek, challenge.target, reason: 'did $did');
      }
    }
  });

  test('a hold is challenged in seconds', () {
    final challenge = own.choose(
      week: thisWeek,
      plan: [move('plank', reps: null, hold: 30)],
      sessionsTarget: 2,
      lastWeek: const {'plank': (reps: 0, seconds: 60, sets: 2)},
    )!;
    expect(challenge.unit, ChallengeUnit.seconds);
    expect(challenge.target, 61);
  });

  test('finishing the plan always meets it', () {
    final lastWeeks = <Map<String, MoveTotal>>[
      const {'squat': (reps: 1, seconds: 0, sets: 1)},
      const {'squat': (reps: 89, seconds: 0, sets: 9)},
      const {'squat': (reps: 90, seconds: 0, sets: 9)},
      const {'squat': (reps: 300, seconds: 0, sets: 30)},
    ];
    for (final last in lastWeeks) {
      final challenge = own.choose(
        week: thisWeek,
        plan: [move('squat')],
        sessionsTarget: 3,
        lastWeek: last,
      );
      if (challenge == null) continue;
      final finished = own.progress(challenge, const {
        'squat': (reps: 90, seconds: 0, sets: 9),
      });
      expect(finished.met, isTrue, reason: 'last week $last');
    }
  });

  test('it is deterministic', () {
    final last = const {
      'squat': (reps: 60, seconds: 0, sets: 6),
      'bridge': (reps: 72, seconds: 0, sets: 6),
    };
    final a = own.choose(
      week: thisWeek,
      plan: plan,
      sessionsTarget: 3,
      lastWeek: last,
    )!;
    final b = own.choose(
      week: thisWeek,
      plan: plan,
      sessionsTarget: 3,
      lastWeek: last,
    )!;
    expect(a.exerciseId, b.exerciseId);
    expect(a.target, b.target);
  });

  test(
    'totals count her logged sets in that week only, live sessions only',
    () {
      final flushes = <FlushRecord>[
        (
          sessionId: 'live-1',
          exerciseId: 'squat',
          sets: [done('squat', reps: 10), done('squat', reps: 8)],
        ),
        (
          sessionId: 'live-2',
          exerciseId: 'squat',
          sets: [done('squat', reps: 10)],
        ),
        (
          sessionId: 'recalled',
          exerciseId: 'squat',
          sets: [done('squat', reps: 50)],
        ),
        (
          sessionId: 'live-1',
          exerciseId: 'plank',
          sets: [
            done('plank', hold: 30),
            LoggedSet(
              prescribed: const PrescribedSet(exerciseId: 'plank', order: 2),
            ).recording(const SetOutcome.skipped()),
          ],
        ),
      ];
      final totals = own.totals(
        lastWeek,
        flushes,
        liveDayOf: (id) => switch (id) {
          'live-1' => '2026-10-06',
          'live-2' => '2026-10-13', // this week, not last
          _ => null,
        },
      );
      expect(totals['squat'], (reps: 18, seconds: 0, sets: 2));
      expect(totals['plank'], (reps: 0, seconds: 30, sets: 1));
    },
  );
}
