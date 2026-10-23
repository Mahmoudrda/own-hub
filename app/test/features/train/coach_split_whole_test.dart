// The coach's lists are the plan. At any length from 30 minutes up, every day
// of every split keeps every move and every set, and the three tiers of a split
// still hold the same moves. Only a short day (under 30 minutes) is cut.

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

import 'package:own_hub/domain/training/prescribed_set.dart';
import 'package:own_hub/features/onboarding/domain/intake.dart';
import 'package:own_hub/features/onboarding/domain/starting_program.dart';
import 'package:own_hub/features/train/domain/my_plan.dart';
import 'package:own_hub/features/train/domain/programme_week.dart';
import 'package:own_hub/features/train/domain/tier_facts.dart';
import 'package:own_hub/features/train/domain/train_repository.dart';
import 'package:own_hub/features/train/domain/workout_library.dart';

const _families = ['split_3day', 'split_4day', 'split_5day'];
const _tiers = ['', '_intermediate', '_advanced'];

AuthoredProgramme _programme(String id) => StartingProgrammes.programme(id)!;

List<String> _ids(AuthoredSession s) => [for (final m in s.moves) m.exerciseId];

void main() {
  setUpAll(() {
    StartingProgrammes.adopt(
      File('assets/content/starting_programmes.json').readAsStringSync(),
    );
  });
  tearDownAll(StartingProgrammes.reset);

  test(
    'every day of every split keeps every move at 30, 45 and 60 minutes',
    () {
      for (final family in _families) {
        for (final tier in _tiers) {
          final programme = _programme('$family$tier');
          for (final session in programme.sessions) {
            for (final minutes in [30, 45, 60]) {
              final shown = scaleSession(session, minutes);
              expect(
                _ids(shown),
                _ids(session),
                reason: '$family$tier ${session.sessionId} at $minutes min',
              );
              expect(
                [for (final m in shown.moves) m.sets],
                [for (final m in session.moves) m.sets],
                reason: '$family$tier ${session.sessionId} sets at $minutes',
              );
              expect(shown.minutes, session.minutes);
            }
          }
        }
      }
    },
  );

  test('the week Train draws holds the whole days at the default length', () {
    for (final family in _families) {
      final programme = _programme(family);
      final sessions = programmeSessionsFor(programme, LifeStage.none);
      final week = weekSlotsFor(
        programme,
        sessions,
        days: sessions.length,
        minutes: Intake.defaultMinutes,
        done: 0,
      );
      expect(
        [for (final slot in week) slot.session.moves.length],
        [for (final s in sessions) s.moves.length],
        reason: family,
      );
      for (var i = 0; i < sessions.length; i++) {
        expect(
          fitSession(programme, sessions[i], Intake.defaultMinutes),
          same(sessions[i]),
        );
      }
    }
  });

  test('the three tiers hold the same moves at every length from 30', () {
    for (final family in _families) {
      final beginner = _programme(family);
      for (final tier in _tiers.skip(1)) {
        final other = _programme('$family$tier');
        expect(other.sessions.length, beginner.sessions.length);
        for (var i = 0; i < beginner.sessions.length; i++) {
          for (final minutes in [30, 45, 60]) {
            expect(
              _ids(scaleSession(other.sessions[i], minutes)),
              _ids(scaleSession(beginner.sessions[i], minutes)),
              reason: '$family$tier ${beginner.sessions[i].sessionId} $minutes',
            );
          }
        }
      }
    }
  });

  test('Home reports no moves lost between tiers at her default length', () {
    for (final family in _families) {
      for (final tier in _tiers.skip(1)) {
        final sessions = programmeSessionsFor(
          _programme(family),
          LifeStage.none,
        ).length;
        for (var slot = 0; slot < sessions; slot++) {
          final facts = TierFacts.ofProgrammes(
            viewed: _programme('$family$tier'),
            own: _programme(family),
            stage: LifeStage.none,
            slot: slot,
            minutes: Intake.defaultMinutes,
            isOwnLevel: false,
          )!;
          expect(facts.versusOwn!.moves, 0, reason: '$family$tier day $slot');
        }
      }
    }
  });

  test('a copy of a split is the day as the coach wrote it', () {
    for (final family in _families) {
      final programme = _programme(family);
      final plan = MyPlan.fork(programme, stage: LifeStage.none);
      final written = programmeSessionsFor(programme, LifeStage.none);
      for (var i = 0; i < plan.days.length; i++) {
        expect(_ids(plan.days[i].session), _ids(written[i]), reason: family);
        expect(plan.days[i].session.minutes, written[i].minutes);
      }
    }
  });

  test('putting a day back, or taking another day, returns the whole day', () {
    final programme = _programme('split_3day_advanced');
    final written = programmeSessionsFor(programme, LifeStage.none);
    final one = PlannedMove(
      exerciseId: 'plank',
      name: 'Plank',
      prescriptionLabel: '3 × 10',
      sets: [
        for (var i = 1; i <= 3; i++)
          PrescribedSet(exerciseId: 'plank', order: i, reps: 10),
      ],
    );
    final edited = MyPlan.fork(
      programme,
      stage: LifeStage.none,
    ).withMoves(1, [one]);
    expect(edited.days[1].session.moves, hasLength(1));

    final back = edited.restoreDay(1, programme, stage: LifeStage.none);
    expect(_ids(back.days[1].session), _ids(written[1]));

    final other = edited.withDayFrom(0, written[2]);
    expect(_ids(other.days[0].session), _ids(written[2]));
    expect(other.days[0].session.minutes, written[2].minutes);
  });

  test('a short day is still cut to its minutes', () {
    final session = _programme('split_3day').sessions.first;
    final short = scaleSession(session, 15);
    expect(short.moves.length, lessThan(session.moves.length));
    expect(short.minutes, 15);
  });
}
