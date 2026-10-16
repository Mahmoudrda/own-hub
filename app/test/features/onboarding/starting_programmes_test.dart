// The three starting plans (D47): content, safety and selection.
//
// The plans are a JSON asset, so nothing below trusts the file: every exercise
// is looked up in the catalogue or the seed library, every move's tags are
// compared with its source's, every session is held to `workoutProblems` before
// and after it is cut to her minutes, and every answer she can give is checked
// to land on a programme.

import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:own_hub/domain/safety/life_stage_safety_policy.dart'
    show LifeStageSafetyPolicy;
import 'package:own_hub/features/admin/domain/content_schema.dart';
import 'package:own_hub/features/admin/domain/seed_library.dart';
import 'package:own_hub/features/onboarding/domain/intake.dart';
import 'package:own_hub/features/onboarding/domain/intake_repository.dart';
import 'package:own_hub/features/onboarding/domain/starting_program.dart';
import 'package:own_hub/features/onboarding/presentation/starting_program_view.dart';
import 'package:own_hub/features/train/domain/programme_week.dart';
import 'package:own_hub/features/train/domain/workout_library.dart';
import 'package:own_hub/l10n/app_l10n.dart';
import 'package:own_hub/theme/app_tokens.dart';
import 'package:own_hub/ui/hand/hand.dart';

const _assetPath = 'assets/content/starting_programmes.json';
const _cataloguePath = '../6-v2/content/exercise_library/catalogue.json';

typedef _Source = ({Set<String> tags, String pattern, bool lower, bool core});

/// Every exercise the plans may use, with the tags and the pattern of its row.
/// The catalogue wins over the seed where both hold an id, as the generator
/// does: it is the one with clips.
Map<String, _Source> _sources() {
  final out = <String, _Source>{};
  for (final row in seedRowsFor(ContentCollection.exercises)) {
    final v = row.values;
    final pattern = v['pattern'] ?? '';
    out[row.id] = (
      tags: (v['contraindicationTags'] ?? '').split('|').toSet(),
      pattern: pattern,
      lower: const {'squat', 'lunge', 'hinge', 'calf'}.contains(pattern),
      core: pattern == 'core',
    );
  }
  final catalogue = jsonDecode(File(_cataloguePath).readAsStringSync()) as Map;
  for (final raw in catalogue['exercises'] as List) {
    final row = (raw as Map).cast<String, Object?>();
    out[row['exerciseId'] as String] = (
      tags: {for (final t in row['contraindicationTags'] as List) t as String},
      pattern: row['pattern'] as String,
      lower: row['bodyRegion'] == 'lower_body',
      core: row['bodyRegion'] == 'core',
    );
  }
  return out;
}

const _kit = <Set<Equipment>>[
  {Equipment.none},
  {Equipment.mat},
  {Equipment.dumbbells},
  {Equipment.bands},
  {Equipment.mat, Equipment.dumbbells},
  {Equipment.dumbbells, Equipment.bands},
  {Equipment.mat, Equipment.dumbbells, Equipment.bands},
];

Iterable<Intake> _everyAnswer() sync* {
  for (final goal in TrainingGoal.values) {
    for (final place in TrainingPlace.values) {
      for (final equipment in _kit) {
        for (final days in Intake.allowedDays) {
          for (final minutes in Intake.allowedMinutes) {
            yield Intake(
              goal: goal,
              place: place,
              equipment: equipment,
              days: days,
              minutes: minutes,
            );
          }
        }
      }
    }
  }
}

void main() {
  late AuthoredProgrammeSet plans;

  setUpAll(() {
    final text = File(_assetPath).readAsStringSync();
    StartingProgrammes.adopt(text);
    plans = AuthoredProgrammeSet(
      WorkoutLibrary.parse((jsonDecode(text) as Map).cast<String, Object?>())
          .programmes,
    );
  });
  tearDownAll(StartingProgrammes.reset);

  test('the file says its content is drafted and not yet signed off', () {
    expect(StartingProgrammes.review, contains('pending Rahma'));
  });

  test(
    'nine programmes: three plans, each at home, with dumbbells, at a gym',
    () {
      expect(plans.all, hasLength(9));
      for (final plan in ['stronger', 'feel_better', 'lose_steadily']) {
        for (final variant in ['home', 'weights', 'gym']) {
          expect(
            plans.all.map((p) => p.programId),
            contains('${plan}_$variant'),
          );
        }
      }
      for (final p in plans.all) {
        expect(workoutProblems(p), isEmpty, reason: p.programId);
        expect(p.status, ProgrammeStatus.published);
        expect(p.sessions, hasLength(6), reason: p.programId);
      }
    },
  );

  test('every exercise is a catalogue or seed exercise with its own tags', () {
    final sources = _sources();
    for (final p in plans.all) {
      for (final s in p.sessions) {
        for (final m in s.moves) {
          final source = sources[m.exerciseId];
          expect(source, isNotNull, reason: '${p.programId} ${m.exerciseId}');
          expect(
            m.contraindications.toSet(),
            source!.tags,
            reason: '${p.programId} ${s.sessionId} ${m.exerciseId}',
          );
        }
      }
    }
  });

  test('pregnancy and after a birth are offered only floor-safe sessions', () {
    final floor = {
      for (final t in LifeStageSafetyPolicy.pregnancyAndEarlyPostpartumFloor)
        t.wireName,
    };
    for (final p in plans.all) {
      for (final s in p.sessions) {
        final protected = s.lifeStages.any(kProtectedStages.contains);
        final flagged = s.moves.any(
          (m) => m.contraindications.any(floor.contains),
        );
        if (protected) {
          expect(flagged, isFalse, reason: '${p.programId} ${s.sessionId}');
          expect(s.lifeStages, {LifeStage.pregnant, LifeStage.postpartum});
        } else {
          // An ordinary session still reaches a woman with a pain or injury
          // answer, who is otherwise offered nothing.
          expect(s.lifeStages, {LifeStage.none, LifeStage.painInjury});
        }
      }
      for (final stage in LifeStage.values) {
        expect(
          programmeSessionsFor(p, stage),
          hasLength(3),
          reason: '${p.programId} $stage',
        );
      }
    }
  });

  test('every session is balanced, even cut to ten minutes', () {
    final sources = _sources();
    for (final p in plans.all) {
      for (final s in p.sessions) {
        final first = s.moves.take(4).map((m) => sources[m.exerciseId]!);
        expect(first.any((m) => m.core), isTrue, reason: '${s.sessionId} core');
        expect(
          first.any(
            (m) =>
                !m.core &&
                !m.lower &&
                (m.pattern.startsWith('push') ||
                    m.pattern.startsWith('pull') ||
                    m.pattern == 'isolation_upper'),
          ),
          isTrue,
          reason: '${p.programId} ${s.sessionId} an upper push or pull',
        );
        expect(
          first.any((m) => m.pattern == 'squat' || m.pattern == 'lunge'),
          isTrue,
          reason: '${p.programId} ${s.sessionId} a lower-body pattern',
        );
        expect(
          first.any(
            (m) =>
                m.pattern == 'hinge' ||
                m.pattern == 'hip_thrust_bridge' ||
                m.pattern == 'isolation_lower',
          ),
          isTrue,
          reason: '${p.programId} ${s.sessionId} a hinge or glute move',
        );
      }
    }
  });

  test('minutes scale the work, and every cut session is still valid', () {
    for (final p in plans.all) {
      for (final s in p.sessions) {
        for (final (minutes, moves, sets) in [
          (10, 4, 2),
          (15, 4, 3),
          (20, 5, 3),
          (30, 7, 3),
        ]) {
          final cut = scaleSession(s, minutes);
          expect(cut.minutes, minutes);
          expect(cut.moves, hasLength(moves), reason: '$minutes min');
          for (final m in cut.moves.take(moves == 7 ? 6 : moves)) {
            expect(m.sets, sets, reason: '${s.sessionId} $minutes min');
          }
          expect(
            workoutProblems(
              AuthoredProgramme(
                programId: p.programId,
                titleEn: p.titleEn,
                titleAr: p.titleAr,
                status: ProgrammeStatus.published,
                sessions: [cut],
              ),
            ),
            isEmpty,
            reason: '${p.programId} ${s.sessionId} $minutes min',
          );
        }
      }
    }
  });

  test('every goal, place, kit, days and minutes selects a plan', () {
    var checked = 0;
    for (final intake in _everyAnswer()) {
      final chosen = selectStartingProgram(intake);
      expect(chosen, isNotNull, reason: '$intake');
      final id = chosen!.programId;
      final plan = switch (intake.goal) {
        TrainingGoal.stronger => 'stronger',
        TrainingGoal.loseSteadily => 'lose_steadily',
        _ => 'feel_better',
      };
      final variant = intake.place != TrainingPlace.home
          ? 'gym'
          : intake.equipment.contains(Equipment.dumbbells)
          ? 'weights'
          : 'home';
      expect(id, '${plan}_$variant', reason: '$intake');

      final programme = StartingProgrammes.programme(id)!;
      final sessions = programmeSessionsFor(programme, intake.lifeStage);
      final week = weekSlots(
        sessions,
        days: intake.days,
        minutes: intake.minutes,
        done: 1,
      );
      expect(week, hasLength(intake.days), reason: '$intake');
      expect(week.first.done, isTrue);
      expect(week.last.done, intake.days == 1);
      checked++;
    }
    expect(checked, 4 * 3 * _kit.length * 3 * 4);
  });

  test('kit she does not have returns no programme, not a poor match', () {
    final dumbbellsOnly = StartingProgrammes.catalogue
        .where((p) => p.equipment.contains(Equipment.dumbbells))
        .toList();
    expect(
      selectStartingProgram(const Intake(), catalogue: dumbbellsOnly),
      isNull,
    );
  });

  test(
    'the gym kit is implied by the place, never written into her answers',
    () {
      const intake = Intake(place: TrainingPlace.ladiesGym);
      expect(selectStartingProgram(intake)!.programId, endsWith('_gym'));
      expect(intake.equipment, {Equipment.none});
    },
  );

  test('a gentle session is what pregnancy and after a birth are given', () {
    for (final stage in [LifeStage.pregnant, LifeStage.postpartum]) {
      final programme = StartingProgrammes.programme('stronger_gym')!;
      final sessions = programmeSessionsFor(programme, stage);
      expect(sessions.map((s) => s.sessionId), [
        'a-gentle',
        'b-gentle',
        'c-gentle',
      ]);
    }
  });

  testWidgets('O05 has a card for every programme, in both languages', (
    tester,
  ) async {
    for (final locale in [const Locale('en'), const Locale('ar')]) {
      for (final p in StartingProgrammes.catalogue) {
        await tester.pumpWidget(
          MaterialApp(
            key: UniqueKey(),
            locale: locale,
            localizationsDelegates: AppL10n.localizationsDelegates,
            supportedLocales: AppL10n.supportedLocales,
            theme: buildTheme(locale),
            home: StartingProgramView(
              repository: InMemoryIntakeRepository(
                // The answers that select this one.
                Intake(
                  goal: p.goals.first,
                  place: p.places.isEmpty ? TrainingPlace.home : p.places.first,
                  equipment: p.equipment.isEmpty
                      ? const {Equipment.none}
                      : p.equipment,
                ),
              ),
              catalogue: [p],
            ),
          ),
        );
        await tester.pumpAndSettle();
        expect(
          find.byType(MarkerHighlight),
          findsOneWidget,
          reason: '${p.programId} ${locale.languageCode}',
        );
      }
    }
  });
}

/// The parsed programmes, so a test can read them without a second parse.
class AuthoredProgrammeSet {
  AuthoredProgrammeSet(this.all);
  final List<AuthoredProgramme> all;
}
