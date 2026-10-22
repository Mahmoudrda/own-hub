import 'package:flutter_test/flutter_test.dart';
import 'package:own_hub/domain/training/prescribed_set.dart';
import 'package:own_hub/features/onboarding/domain/intake.dart';
import 'package:own_hub/features/train/domain/my_plan.dart';
import 'package:own_hub/features/train/domain/programme_week.dart';
import 'package:own_hub/features/train/domain/train_repository.dart';
import 'package:own_hub/features/train/domain/workout_library.dart';

AuthoredMove _move(String id, {int sets = 3, int reps = 10, int rest = 60}) =>
    AuthoredMove(
      exerciseId: id,
      nameEn: id,
      nameAr: id,
      sets: sets,
      reps: reps,
      restSeconds: rest,
      safetyEn: 'Stop if it hurts.',
    );

AuthoredSession _session(
  String id,
  List<String> moves, {
  Set<LifeStage> stages = const {LifeStage.none},
}) => AuthoredSession(
  sessionId: id,
  titleEn: 'Day $id',
  titleAr: 'يوم $id',
  minutes: 45,
  lifeStages: stages,
  moves: [for (final m in moves) _move(m)],
);

AuthoredProgramme _template() => AuthoredProgramme(
  programId: 'split_fixture',
  titleEn: 'Split',
  titleAr: 'خطة',
  status: ProgrammeStatus.published,
  sessions: [
    _session('a', ['m1', 'm2', 'm3', 'm4', 'm5', 'm6', 'm7']),
    _session('b', ['m8', 'm9', 'm10', 'm11']),
    _session('c', ['m1'], stages: const {LifeStage.pregnant}),
  ],
);

PlannedMove _planned(String id, {int sets = 3, int reps = 10, double? kg}) =>
    PlannedMove(
      exerciseId: id,
      name: id,
      prescriptionLabel: '',
      sets: [
        for (var i = 1; i <= sets; i++)
          PrescribedSet(exerciseId: id, order: i, reps: reps, weightKg: kg),
      ],
    );

MyPlan _newDay(MyPlan plan, String name, List<PlannedMove> moves) =>
    plan.withNewDay(
      name,
      moves,
      titleEn: 'Day ${plan.days.length + 1}',
      titleAr: 'يوم ${plan.days.length + 1}',
    );

void main() {
  group('fork', () {
    test('copies the sessions she is offered, uncut at 60 minutes', () {
      final plan = MyPlan.fork(_template(), stage: LifeStage.none);
      expect(plan.days.length, 2);
      expect(plan.sourceProgrammeId, 'split_fixture');
      expect(plan.days.first.session.sessionId, 'mine_1');
      expect(plan.days.first.sourceId, 'a');
      expect(plan.days.first.session.moves.length, 7);
      expect(isMyPlanSession(plan.days.first.session), isTrue);
    });

    test('a different stage forks different days', () {
      final plan = MyPlan.fork(_template(), stage: LifeStage.pregnant);
      expect(plan.days.map((d) => d.sourceId), ['c']);
    });
  });

  group('editing a day', () {
    final base = MyPlan.fork(_template(), stage: LifeStage.none);

    test('swap, remove, add and reorder come out as written', () {
      final moves = [
        _planned('m3'),
        _planned('m1'),
        _planned('new_move', sets: 4, reps: 8, kg: 20),
      ];
      final next = base.withMoves(0, moves);
      final day = next.days[0];
      expect(day.session.moves.map((m) => m.exerciseId), [
        'm3',
        'm1',
        'new_move',
      ]);
      expect(day.session.moves[2].sets, 4);
      expect(day.session.moves[2].reps, 8);
      expect(day.kgAt(2), 20);
      expect(day.kgAt(0), isNull);
      // A move she kept keeps its safety line and its rest.
      expect(day.session.moves[0].safetyEn, 'Stop if it hurts.');
      expect(day.session.moves[0].restSeconds, 60);
      expect(day.session.titleEn, 'Day a');
      expect(day.sourceId, 'a');
      expect(next.days[1], same(base.days[1]));
      expect(next.revision, base.revision + 1);
    });

    test('an empty list changes nothing', () {
      expect(base.withMoves(0, const []), same(base));
    });

    test('remove, copy, move and add a day', () {
      expect(base.withoutDay(0).days.length, 1);
      final copy = base.withCopyOf(1);
      expect(copy.days.length, 3);
      expect(copy.days[2].session.sessionId, isNot('mine_1'));
      expect(copy.days[2].session.sessionId, isNot('mine_2'));
      expect(copy.days[2].sourceId, isNull);
      final moved = base.withDayMoved(1, 0);
      expect(moved.days[0].sourceId, 'b');
      final added = _newDay(base, ' Arms ', [_planned('m9')]);
      expect(added.days.last.session.titleEn, 'Arms');
      final unnamed = _newDay(base, '', [_planned('m9')]);
      expect(unnamed.days.last.session.titleEn, 'Day 3');
      expect(unnamed.days.last.session.titleAr, 'يوم 3');
    });

    test('a plan never holds more than the most days', () {
      expect(kMaxPlanDays, 7);
      var plan = const MyPlan.blank();
      for (var i = 0; i < kMaxPlanDays + 3; i++) {
        plan = _newDay(plan, 'd$i', [_planned('m1')]);
      }
      expect(plan.days.length, kMaxPlanDays);
      expect(plan.withCopyOf(0).days.length, kMaxPlanDays);
    });

    test('restore puts a day back from the split, replace takes another', () {
      final edited = base.withMoves(0, [_planned('only')]);
      expect(edited.days[0].session.moves.length, 1);
      expect(edited.canRestore(0, _template(), LifeStage.none), isTrue);
      final back = edited.restoreDay(0, _template(), stage: LifeStage.none);
      expect(back.days[0].session.moves.length, 7);
      expect(back.days[0].session.sessionId, 'mine_1');
      final other = base.withDayFrom(0, _template().sessions[1]);
      expect(other.days[0].session.titleEn, 'Day b');
      expect(other.days[0].sourceId, 'a');
      // A day she made has nothing to go back to.
      final mine = _newDay(base, 'Mine', [_planned('m1')]);
      expect(mine.canRestore(2, _template(), LifeStage.none), isFalse);
      expect(
        mine.restoreDay(2, _template(), stage: LifeStage.none),
        same(mine),
      );
    });
  });

  group('what she keeps of a move', () {
    test('a long hold and many reps are not cut to the stepper bounds', () {
      final template = AuthoredProgramme(
        programId: 'split_fixture',
        titleEn: 's',
        titleAr: 's',
        status: ProgrammeStatus.published,
        sessions: [
          AuthoredSession(
            sessionId: 'a',
            titleEn: 'A',
            titleAr: 'A',
            minutes: 45,
            lifeStages: const {LifeStage.none},
            moves: [
              _move('crunch'),
              const AuthoredMove(
                exerciseId: 'mountain_climbers',
                nameEn: 'Mountain climbers',
                nameAr: 'Mountain climbers',
                sets: 1,
                holdSeconds: 600,
                restSeconds: 0,
              ),
              const AuthoredMove(
                exerciseId: 'walk',
                nameEn: 'Walk',
                nameAr: 'Walk',
                sets: 2,
                reps: 80,
              ),
            ],
          ),
        ],
      );
      final plan = MyPlan.fork(template, stage: LifeStage.none);
      // She removes the crunch; the rest go through unchanged.
      final moves = [
        PlannedMove(
          exerciseId: 'mountain_climbers',
          name: 'Mountain climbers',
          prescriptionLabel: '',
          sets: const [
            PrescribedSet(
              exerciseId: 'mountain_climbers',
              order: 1,
              holdSeconds: 600,
            ),
          ],
        ),
        PlannedMove(
          exerciseId: 'walk',
          name: 'Walk',
          prescriptionLabel: '',
          sets: const [
            PrescribedSet(exerciseId: 'walk', order: 1, reps: 80),
            PrescribedSet(exerciseId: 'walk', order: 2, reps: 80),
          ],
        ),
      ];
      final edited = plan.withMoves(0, moves).days[0].session.moves;
      expect(edited[0].holdSeconds, 600);
      expect(edited[0].restSeconds, 0);
      expect(edited[1].reps, 80);
      expect(edited[1].sets, 2);
    });

    test('a day she makes suits every stage', () {
      final plan = _newDay(const MyPlan.blank(), 'Mine', [_planned('m1')]);
      expect(plan.days.single.session.lifeStages, {...LifeStage.values});
    });

    test('put back returns the day she started with, even after a replace', () {
      final base = MyPlan.fork(_template(), stage: LifeStage.none);
      final replaced = base.withDayFrom(0, _template().sessions[1]);
      expect(replaced.days[0].sourceId, 'a');
      final back = replaced.restoreDay(0, _template(), stage: LifeStage.none);
      expect(back.days[0].session.titleEn, 'Day a');
      expect(back.days[0].session.moves.length, 7);
    });

    test('Undo puts one day back where it was and cleared keeps the split', () {
      final base = MyPlan.fork(_template(), stage: LifeStage.none);
      final gone = base.days[0];
      final without = base.withoutDay(0).withDayMoved(0, 0);
      final back = without.insertDay(0, gone);
      expect(back.days.map((d) => d.sourceId), ['a', 'b']);
      final cleared = base.cleared();
      expect(cleared.isBlank, isTrue);
      expect(cleared.sourceProgrammeId, 'split_fixture');
    });
  });

  group('json', () {
    test('a plan survives a round trip', () {
      final plan = MyPlan.fork(
        _template(),
        stage: LifeStage.none,
      ).withMoves(0, [_planned('m3', kg: 12.5), _planned('m1')]);
      final back = MyPlan.tryParse(plan.toJson())!;
      expect(back.toJson(), plan.toJson());
      expect(back.days[0].kgAt(0), 12.5);
    });

    test('rubbish reads as none and a bad day costs only that day', () {
      expect(MyPlan.tryParse(null), isNull);
      expect(MyPlan.tryParse('x'), isNull);
      expect(MyPlan.tryParse({'days': 3}), isNull);
      final good = MyPlan.fork(_template(), stage: LifeStage.none).toJson();
      (good['days']! as List).add({'session': 'nope'});
      (good['days']! as List).add(<String, Object?>{
        'session': {'sessionId': 'mine_9', 'moves': <Object?>[]},
      });
      (good['days']! as List).add(<String, Object?>{
        'session': {'sessionId': 'mine_8', 'moves': 'x', 'lifeStages': 3},
      });
      expect(MyPlan.tryParse(good)!.days.length, 2);
    });

    test('values are held inside their bounds', () {
      final plan = MyPlan.tryParse({
        'days': [
          {
            'session': {
              'sessionId': 'mine_1',
              'titleEn': 'x' * 300,
              'minutes': 9999,
              'moves': [
                {
                  'exerciseId': 'm1',
                  'sets': 99,
                  'reps': 9999,
                  'restSeconds': 99999,
                },
              ],
            },
            'kg': [9999],
          },
        ],
      })!;
      final day = plan.days.single;
      expect(day.session.titleEn.length, lessThanOrEqualTo(40));
      expect(day.session.moves.single.sets, 10);
      expect(day.session.moves.single.reps, 100);
      expect(day.session.moves.single.restSeconds, 600);
      expect(day.session.minutes, 180);
      expect(day.kgAt(0), 200);
    });
  });

  group('resolution', () {
    final template = _template();

    test('her plan beats the split', () {
      final plan = MyPlan.fork(template, stage: LifeStage.none);
      final programme = resolveProgramme(template, plan, LifeStage.none);
      expect(programme.programId, kMyPlanId);
      expect(isMyPlanProgramme(programme), isTrue);
      expect(programmeSessionsFor(programme, LifeStage.none).length, 2);
    });

    test('with no plan, a blank plan or no day for her stage: the split', () {
      expect(resolveProgramme(template, null, LifeStage.none), same(template));
      expect(
        resolveProgramme(template, const MyPlan.blank(), LifeStage.none),
        same(template),
      );
      final plan = MyPlan.fork(template, stage: LifeStage.none);
      expect(
        resolveProgramme(template, plan, LifeStage.postpartum),
        same(template),
      );
    });

    test('slots rotate through the days she is offered', () {
      final plan = MyPlan.fork(template, stage: LifeStage.none);
      expect(planDayForSlot(plan, 0, LifeStage.none), 0);
      expect(planDayForSlot(plan, 3, LifeStage.none), 1);
      expect(slotForPlanDay(plan, 1, LifeStage.none), 1);
      expect(planDayForSlot(plan, 0, LifeStage.postpartum), isNull);
      expect(slotForPlanDay(plan, 0, LifeStage.postpartum), isNull);
    });

    test('her days are not cut to her minutes, a split day is', () {
      final big = _session('z', [for (var i = 0; i < 14; i++) 'move$i']);
      final bigTemplate = AuthoredProgramme(
        programId: 'split_fixture',
        titleEn: 's',
        titleAr: 's',
        status: ProgrammeStatus.published,
        sessions: [big],
      );
      final plan = MyPlan.fork(bigTemplate, stage: LifeStage.none);
      final mine = resolveProgramme(bigTemplate, plan, LifeStage.none);
      final own = mine.sessions.single;
      expect(fitSession(mine, own, 30).moves.length, own.moves.length);
      // A split day is whole from 30 minutes and cut only for a short day.
      expect(fitSession(bigTemplate, big, 30).moves.length, 14);
      expect(fitSession(bigTemplate, big, 15).moves.length, lessThan(14));
      final slots = weekSlotsFor(
        mine,
        mine.sessions,
        days: 3,
        minutes: 15,
        done: 1,
      );
      expect(slots.length, 3);
      expect(slots.first.session.moves.length, own.moves.length);
      expect(slots.first.done, isTrue);
      expect(planDaysPerWeek(mine, mine.sessions, 5), 1);
      expect(planDaysPerWeek(bigTemplate, bigTemplate.sessions, 5), 5);
    });

    test('the first change she keeps forks the split', () {
      final plan = planWithDayMoves(
        current: null,
        template: template,
        stage: LifeStage.none,
        slot: 1,
        moves: [_planned('only')],
      )!;
      expect(plan.days[1].session.moves.single.exerciseId, 'only');
      expect(plan.days[0].session.moves.length, 7);
      final again = planWithDayMoves(
        current: plan,
        template: template,
        stage: LifeStage.none,
        slot: 1,
        moves: [_planned('two')],
      )!;
      expect(again.days.length, 2);
      expect(again.days[1].session.moves.single.exerciseId, 'two');
    });

    test('targets are read by the day id', () {
      final plan = MyPlan.fork(
        template,
        stage: LifeStage.none,
      ).withMoves(0, [_planned('m1', kg: 8)]);
      expect(targetsFor(plan, 'mine_1'), [8]);
      expect(targetsFor(plan, 'nope'), isEmpty);
      expect(targetsFor(null, 'mine_1'), isEmpty);
    });
  });
}
