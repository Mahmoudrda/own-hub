// What each tier's session holds, read from the bundled programmes cut to her
// minutes: the numbers Home shows when she switches Beginner, Intermediate and
// Advanced.

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

import 'package:own_hub/features/onboarding/domain/intake.dart';
import 'package:own_hub/features/onboarding/domain/starting_program.dart';
import 'package:own_hub/features/train/domain/programme_week.dart';
import 'package:own_hub/features/train/domain/tier_facts.dart';
import 'package:own_hub/features/train/domain/workout_library.dart';

AuthoredSession _session(String programmeId, int minutes, {int slot = 0}) {
  final programme = StartingProgrammes.programme(programmeId)!;
  return scaleSession(programme.sessions[slot], minutes);
}

String _id(String family, TrainingLevel tier) =>
    tier == TrainingLevel.beginner ? family : '${family}_${tier.wireName}';

TierFacts _facts(
  String family,
  TrainingLevel tier,
  int minutes, {
  TrainingLevel own = TrainingLevel.beginner,
  int slot = 0,
}) => TierFacts.of(
  _session(_id(family, tier), minutes, slot: slot),
  own: _session(_id(family, own), minutes, slot: slot),
  isOwnLevel: tier == own,
)!;

const _splits = ['split_3day', 'split_4day', 'split_5day'];

void main() {
  setUpAll(() {
    StartingProgrammes.adopt(
      File('assets/content/starting_programmes.json').readAsStringSync(),
    );
  });
  tearDownAll(StartingProgrammes.reset);

  group('sessionShape', () {
    test('a short day keeps its caps', () {
      expect(sessionShape(10), (moves: 4, sets: 2, stretch: false));
      expect(sessionShape(15), (moves: 4, sets: 3, stretch: false));
      expect(sessionShape(20), (moves: 5, sets: 3, stretch: false));
      expect(sessionShape(25), (moves: 6, sets: 5, stretch: true));
    });

    test('30, 45 and 60 minutes keep every move the sets it was written', () {
      for (final family in _splits) {
        for (final tier in TrainingLevel.values) {
          final written = StartingProgrammes.programme(_id(family, tier))!
              .sessions
              .first;
          for (final minutes in [30, 45, 60]) {
            final cut = _session(_id(family, tier), minutes);
            for (final m in workMoves(cut)) {
              final original = written.moves.firstWhere(
                (o) => o.exerciseId == m.exerciseId,
              );
              expect(m.sets, original.sets, reason: '$family $tier $minutes');
            }
          }
        }
      }
    });

    test('from 30 minutes the whole day is kept', () {
      for (final family in _splits) {
        for (final tier in TrainingLevel.values) {
          final id = _id(family, tier);
          final day = StartingProgrammes.programme(id)!.sessions.first;
          for (final minutes in [30, 45, 60, 75]) {
            expect(
              workMoves(_session(id, minutes)).length,
              workMoves(day).length,
              reason: '$id $minutes',
            );
          }
        }
      }
    });

    test('a day takes the 45 to 60 minutes it was written for', () {
      for (final family in _splits) {
        for (final tier in TrainingLevel.values) {
          for (final minutes in [30, 45, 60]) {
            final took = estimatedMinutes(_session(_id(family, tier), minutes));
            expect(took, inInclusiveRange(45, 60), reason: '$family $tier');
          }
        }
      }
    });
  });

  group('workMoves', () {
    test('leaves out the closing stretch of a full session', () {
      final cut = _session('split_4day', 45);
      expect(workMoves(cut), hasLength(cut.moves.length - 1));
      expect(workMoves(cut).any((m) => m.restSeconds == 0), isFalse);
    });

    test('keeps every move of a short day, which has no stretch', () {
      final cut = _session('split_4day', 15);
      expect(workMoves(cut), hasLength(cut.moves.length));
    });
  });

  group('TierFacts.ofProgrammes', () {
    AuthoredProgramme p(String id) => StartingProgrammes.programme(id)!;

    test('reads the same slot of both programmes and compares them', () {
      final f = TierFacts.ofProgrammes(
        viewed: p('split_4day_advanced'),
        own: p('split_4day'),
        stage: LifeStage.none,
        slot: 5,
        minutes: 60,
        isOwnLevel: false,
      )!;
      final direct = TierFacts.of(
        _session('split_4day_advanced', 60, slot: 1),
        own: _session('split_4day', 60, slot: 1),
      )!;
      // Slot 5 wraps to the second of the four days of this split.
      expect(f.setsPerMove, direct.setsPerMove);
      expect(f.versusOwn, direct.versusOwn);
      expect(f.isOwnLevel, isFalse);
    });

    test('a woman with a pregnancy answer reads the gentle sessions', () {
      final f = TierFacts.ofProgrammes(
        viewed: p('split_3day'),
        own: p('split_3day'),
        stage: LifeStage.pregnant,
        slot: 2,
        minutes: 45,
        isOwnLevel: true,
      )!;
      final gentle = StartingProgrammes.programme('split_3day')!.sessions
          .firstWhere((s) => s.sessionId == 'a-gentle');
      expect(f.moves, workMoves(scaleSession(gentle, 45)).length);
    });

    test('her own level has no comparison', () {
      final f = TierFacts.ofProgrammes(
        viewed: p('split_3day'),
        own: p('split_3day'),
        stage: LifeStage.none,
        slot: 0,
        minutes: 30,
        isOwnLevel: true,
      )!;
      expect(f.isOwnLevel, isTrue);
      expect(f.versusOwn, isNull);
    });

    test('no programme, no facts', () {
      expect(
        TierFacts.ofProgrammes(
          viewed: null,
          own: null,
          stage: null,
          slot: 0,
          minutes: 45,
          isOwnLevel: true,
        ),
        isNull,
      );
    });
  });

  group('TierFacts', () {
    test(
      'the three tiers give different facts in every day of every split',
      () {
        for (final family in _splits) {
          final days = StartingProgrammes.programme(family)!.sessions
              .where((s) => suits(s, LifeStage.none))
              .length;
          for (var slot = 0; slot < days; slot++) {
            for (final minutes in [45, 60]) {
              final facts = {
                for (final tier in TrainingLevel.values)
                  tier: _facts(family, tier, minutes, slot: slot),
              };
              expect(
                facts.values.toSet(),
                hasLength(3),
                reason: '$family day ${slot + 1} at $minutes min',
              );
              // What she reads on Home, apart from the comparison.
              final read = {
                for (final f in facts.values)
                  (
                    f.moves,
                    f.setsPerMove,
                    f.repsLabel,
                    f.restSeconds,
                    f.estimatedMinutes,
                  ),
              };
              expect(
                read,
                hasLength(3),
                reason: '$family day ${slot + 1} at $minutes min: $read',
              );
              for (final f in facts.values) {
                expect(f.estimatedMinutes % 5, 0);
                // The day is whole, and every day is written for 45 to 60.
                expect(f.estimatedMinutes, lessThanOrEqualTo(60));
              }
            }
          }
        }
      },
    );

    test('the reps and the sets read as each tier is pitched', () {
      final beginner = _facts('split_4day', TrainingLevel.beginner, 60);
      final intermediate = _facts('split_4day', TrainingLevel.intermediate, 60);
      final advanced = _facts('split_4day', TrainingLevel.advanced, 60);
      expect(beginner.repsLabel, '12');
      expect(intermediate.repsLabel, '10');
      expect(advanced.repsLabel, anyOf('8', '12'));
      expect(advanced.restSeconds, 120);
      expect(intermediate.restSeconds, lessThan(advanced.restSeconds));
    });

    test('from 30 minutes the length she picks does not change the day', () {
      for (final family in _splits) {
        for (final tier in TrainingLevel.values) {
          final a = _facts(family, tier, 30);
          for (final minutes in [45, 60]) {
            expect(_facts(family, tier, minutes), a, reason: '$family $tier');
          }
        }
      }
    });

    test('a short day holds fewer moves and takes less time', () {
      for (final family in _splits) {
        for (final tier in TrainingLevel.values) {
          final short = _facts(family, tier, 15);
          final whole = _facts(family, tier, 45);
          expect(short.moves, lessThan(whole.moves), reason: '$family $tier');
          expect(short.estimatedMinutes, lessThan(whole.estimatedMinutes));
        }
      }
    });

    test('no comparison against her own level when she is looking at it', () {
      final own = _session('split_4day', 45);
      expect(TierFacts.of(own, isOwnLevel: true)!.versusOwn, isNull);
      expect(TierFacts.of(own, isOwnLevel: true)!.isOwnLevel, isTrue);
      expect(TierFacts.of(own)!.versusOwn, isNull);
      final facts = _facts('split_4day', TrainingLevel.beginner, 45);
      expect(facts.versusOwn, isNull);
      expect(facts.isOwnLevel, isTrue);
      expect(
        _facts('split_4day', TrainingLevel.advanced, 45).isOwnLevel,
        isFalse,
      );
    });

    test('a harder tier against a Beginner is a real difference', () {
      for (final family in _splits) {
        for (final tier in [
          TrainingLevel.intermediate,
          TrainingLevel.advanced,
        ]) {
          final delta = _facts(family, tier, 60).versusOwn!;
          expect(delta.isEmpty, isFalse, reason: '$family $tier');
        }
      }
    });

    test('Beginner against an Advanced level reads the other way round', () {
      final up = _facts('split_4day', TrainingLevel.advanced, 60).versusOwn!;
      final down = _facts(
        'split_4day',
        TrainingLevel.beginner,
        60,
        own: TrainingLevel.advanced,
      ).versusOwn!;
      expect(down.sets, -up.sets);
      expect(down.restSeconds, -up.restSeconds);
      expect(down.moves, -up.moves);
    });

    test('a session with no strength moves gives no facts', () {
      expect(TierFacts.of(null), isNull);
      const empty = AuthoredSession(
        sessionId: 'x',
        titleEn: '',
        titleAr: '',
        minutes: 30,
        lifeStages: {},
        moves: [],
      );
      expect(TierFacts.of(empty), isNull);
    });
  });
}
