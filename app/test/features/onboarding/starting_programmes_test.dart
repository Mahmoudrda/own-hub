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
            for (final level in TrainingLevel.values) {
              yield Intake(
                goal: goal,
                place: place,
                equipment: equipment,
                days: days,
                minutes: minutes,
                level: level,
              );
            }
          }
        }
      }
    }
  }
}

/// The kit each variant of a plan may use: nothing but the floor and a mat at
/// home, dumbbells added for the second, the gym's kit for the third.
const _variantKit = <String, Set<String>>{
  'home': {'none', 'mat'},
  'weights': {'none', 'mat', 'dumbbells'},
  'gym': {
    'none',
    'mat',
    'dumbbells',
    'bands',
    'bench',
    'barbell',
    'cable',
    'smith_machine',
    'machine',
  },
};

Map<String, Map<String, Object?>> _catalogueRows() {
  final catalogue = jsonDecode(File(_cataloguePath).readAsStringSync()) as Map;
  return {
    for (final raw in catalogue['exercises'] as List)
      (raw as Map)['exerciseId'] as String: raw.cast<String, Object?>(),
  };
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
    'twenty-seven programmes: three plans, each at home, with dumbbells, at a '
    'gym, in three tiers',
    () {
      expect(plans.all, hasLength(27));
      for (final plan in ['stronger', 'feel_better', 'lose_steadily']) {
        for (final variant in ['home', 'weights', 'gym']) {
          for (final tier in ['', '_intermediate', '_advanced']) {
            expect(
              plans.all.map((p) => p.programId),
              contains('${plan}_$variant$tier'),
            );
          }
        }
      }
      expect(StartingProgrammes.catalogue, hasLength(27));
      for (final tier in TrainingLevel.values) {
        expect(
          StartingProgrammes.catalogue.where((p) => p.tier == tier),
          hasLength(9),
          reason: tier.wireName,
        );
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
      expect(chosen.tier, intake.level, reason: '$intake');
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
      final tier = intake.level == TrainingLevel.beginner
          ? ''
          : '_${intake.level.wireName}';
      expect(id, '${plan}_$variant$tier', reason: '$intake');

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
    expect(checked, 4 * 3 * _kit.length * 6 * 6 * 3);
  });

  test('every tier row says its tier and carries the same six sessions', () {
    final raw = (jsonDecode(File(_assetPath).readAsStringSync()) as Map)
        .cast<String, Object?>();
    for (final row in (raw['programmes'] as List).cast<Map<String, Object?>>()) {
      final id = row['programId'] as String;
      final tier = TrainingLevel.fromWire(row['tier']);
      expect(tier, isNotNull, reason: id);
      expect(
        id.endsWith('_${tier!.wireName}'),
        tier != TrainingLevel.beginner,
        reason: id,
      );
      expect(programmeFamily(id), isNot(endsWith(tier.wireName)));
    }
  });

  test('every tier uses only filmed moves its kit allows', () {
    final rows = _catalogueRows();
    for (final p in plans.all) {
      final variant = programmeFamily(p.programId).split('_').last;
      for (final s in p.sessions) {
        for (final m in s.moves) {
          final row = rows[m.exerciseId];
          expect(row, isNotNull, reason: '${p.programId} ${m.exerciseId}');
          expect(
            (row!['clips'] as List?) ?? const [],
            isNotEmpty,
            reason: '${p.programId} ${m.exerciseId} has no clip',
          );
          final kit = (row['equipment'] as List).cast<String>().toSet();
          expect(
            kit.difference(_variantKit[variant]!),
            isEmpty,
            reason: '${p.programId} ${s.sessionId} ${m.exerciseId}',
          );
          if (variant == 'home' || variant == 'weights') {
            expect(row['place'], isNot('gym'), reason: m.exerciseId);
          }
        }
      }
    }
  });

  test('the tiers differ in sets, rest and pairing, and only as written', () {
    for (final plan in ['stronger', 'feel_better', 'lose_steadily']) {
      for (final variant in ['home', 'weights', 'gym']) {
        final id = '${plan}_$variant';
        final beginner = StartingProgrammes.programme(id)!;
        final intermediate = StartingProgrammes.programme(
          '${id}_intermediate',
        )!;
        final advanced = StartingProgrammes.programme('${id}_advanced')!;
        for (var i = 0; i < beginner.sessions.length; i++) {
          final b = beginner.sessions[i];
          final im = intermediate.sessions[i];
          final ad = advanced.sessions[i];
          final gentle = b.lifeStages.contains(LifeStage.pregnant);
          expect(im.sessionId, b.sessionId);
          expect(ad.sessionId, b.sessionId);
          // The first six moves of the beginner session are the beginner
          // programme as it was; the rest were added for the longer sessions.
          expect(b.moves.length, greaterThanOrEqualTo(7));
          for (final m in b.moves.take(b.moves.length - 1)) {
            expect(m.sets, 3, reason: '$id ${b.sessionId}');
          }
          if (gentle) {
            // No superset, no shorter rest, no heavier move for pregnancy or
            // after a birth, whatever the tier.
            expect(im.moves, b.moves, reason: '$id ${b.sessionId}');
            expect(ad.moves, b.moves, reason: '$id ${b.sessionId}');
            continue;
          }
          final workIm = im.moves.take(im.moves.length - 1).toList();
          final workAd = ad.moves.take(ad.moves.length - 1).toList();
          for (final (index, m) in workIm.indexed) {
            expect(m.sets, 4, reason: '$id ${im.sessionId} $index');
          }
          for (final (index, m) in workAd.indexed) {
            expect(m.sets, index < 6 ? 5 : 4);
          }
          // Pairs: the first move of each pair goes straight to the next.
          for (final work in [workIm, workAd]) {
            for (var j = 0; j + 1 < work.length; j += 2) {
              expect(work[j].restSeconds, lessThanOrEqualTo(15));
              expect(work[j].notesEn, contains('Superset'));
              expect(work[j + 1].restSeconds, greaterThanOrEqualTo(30));
            }
          }
          // Intermediate rests 25% shorter; advanced rests 30 to 45 s.
          final beginnerRest = b.moves.first.restSeconds;
          expect(
            workIm[1].restSeconds,
            ((beginnerRest * 0.75) / 5).round() * 5,
          );
          for (var j = 1; j < workAd.length; j += 2) {
            expect(workAd[j].restSeconds, inInclusiveRange(30, 45));
          }
          // The intermediate and advanced tiers use at least one of the
          // catalogue's intermediate moves where the kit allows it.
          final rows = _catalogueRows();
          final harder = [
            ...workIm,
            ...workAd,
          ].where((m) => rows[m.exerciseId]!['level'] == 'intermediate');
          if (b.lifeStages.contains(LifeStage.none)) {
            expect(harder, isNotEmpty, reason: '$id ${b.sessionId}');
          }
        }
      }
    }
  });

  test('every tier fits the minutes she has, from 31 to 180', () {
    for (final p in plans.all) {
      for (final s in p.sessions) {
        for (final minutes in [31, 35, 45, 52, 60, 75, 100, 180]) {
          final cut = scaleSession(s, minutes);
          expect(
            estimatedMinutes(cut),
            lessThanOrEqualTo(minutes),
            reason: '${p.programId} ${s.sessionId} at $minutes min',
          );
          expect(cut.moves.last, s.moves.last, reason: 'the stretch is kept');
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
          );
        }
        // The long presets are really filled, not just fitted: the ordinary
        // sessions run at least half the time she asked for.
        if (s.lifeStages.contains(LifeStage.none)) {
          for (final minutes in [45, 60, 75]) {
            expect(
              estimatedMinutes(scaleSession(s, minutes)),
              greaterThanOrEqualTo(minutes * 0.5),
              reason: '${p.programId} ${s.sessionId} at $minutes min',
            );
          }
        }
      }
    }
  });

  test('a tier is chosen by her level, and any tier can be asked for', () {
    const intake = Intake(level: TrainingLevel.intermediate);
    expect(
      selectStartingProgram(intake)!.programId,
      'stronger_home_intermediate',
    );
    expect(
      selectStartingProgram(intake, tier: TrainingLevel.advanced)!.programId,
      'stronger_home_advanced',
    );
    expect(
      selectStartingProgram(intake, tier: TrainingLevel.beginner)!.programId,
      'stronger_home',
    );
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
