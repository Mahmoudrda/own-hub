// What every programme move is measured on, and that a best on one is
// detected, kept in step with a corrected set, and shown by name.

import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:own_hub/domain/rewards/personal_best_detector.dart';
import 'package:own_hub/domain/rewards/personal_best_ledger.dart';
import 'package:own_hub/domain/training/prescribed_set.dart';
import 'package:own_hub/features/progress/presentation/personal_bests_view.dart';
import 'package:own_hub/features/train/domain/exercise_library.dart';
import 'package:own_hub/features/train/domain/exercise_metrics.dart';
import 'package:own_hub/features/train/domain/exercise_traits.dart';
import 'package:own_hub/features/train/domain/session_bests_bridge.dart';
import 'package:own_hub/features/train/domain/train_repository.dart';
import 'package:own_hub/l10n/app_l10n.dart';
import 'package:own_hub/theme/app_tokens.dart';

Set<String> _splitIds() {
  final json = jsonDecode(
    File('assets/content/starting_programmes.json').readAsStringSync(),
  ) as Map<String, Object?>;
  return {
    for (final p in json['programmes']! as List)
      for (final s in (p as Map)['sessions'] as List)
        for (final m in (s as Map)['moves'] as List)
          (m as Map)['exerciseId'] as String,
  };
}

const WorkoutDay _day = WorkoutDay(
  id: '2026-10-01',
  title: 'Lower',
  summary: '',
  constraints: '',
  moves: <PlannedMove>[],
);

PrescribedSet _set(String id) => PrescribedSet(exerciseId: id, order: 1);

LoggedSet _logged(String id, SetOutcome outcome) =>
    LoggedSet(prescribed: _set(id)).recording(outcome);

class _Wired {
  _Wired() {
    ledger = PersonalBestLedger();
    bridge = SessionBestsBridge(ledger: ledger);
    repository = InMemoryTrainRepository(day: _day, onFlushed: bridge.record);
  }
  late final PersonalBestLedger ledger;
  late final SessionBestsBridge bridge;
  late final InMemoryTrainRepository repository;

  Future<TrainSession> session(
    String dateKey,
    String id,
    SetOutcome outcome, {
    bool finish = true,
  }) async {
    final s = await repository.startSession(_day);
    await repository.flushMove(
      sessionId: s.id,
      exerciseId: id,
      sets: [_logged(id, outcome)],
    );
    return finish
        ? repository.finishSession(sessionId: s.id, durationSec: 900)
        : s;
  }
}

void _phone(WidgetTester tester) {
  tester.view.physicalSize = const Size(1170, 2532);
  tester.view.devicePixelRatio = 3.0;
  addTearDown(tester.view.reset);
}

Widget _host(Widget child, Locale locale, double scale) => MaterialApp(
  locale: locale,
  localizationsDelegates: AppL10n.localizationsDelegates,
  supportedLocales: AppL10n.supportedLocales,
  theme: buildTheme(locale),
  home: Builder(
    builder: (context) => MediaQuery(
      data: MediaQuery.of(context)
          .copyWith(textScaler: TextScaler.linear(scale)),
      child: child,
    ),
  ),
);

void main() {
  setUp(() {
    ExerciseTraits.resetForTest();
    ExerciseTraits.adopt(
      File('assets/content/exercise_traits.json').readAsStringSync(),
    );
  });

  group('the bundled traits', () {
    test('cover every programme move with a metric and a name', () {
      final json = jsonDecode(
        File('assets/content/exercise_traits.json').readAsStringSync(),
      ) as Map<String, Object?>;
      final moves = (json['moves']! as Map<String, Object?>)
          .cast<String, Map<String, Object?>>();
      for (final id in _splitIds()) {
        final row = moves[id];
        expect(row, isNotNull, reason: '$id has no traits');
        expect(['load', 'reps', 'hold'], contains(row!['metric']));
        expect((row['nameEn'] as String).trim(), isNotEmpty, reason: id);
      }
    });

    test('the metric follows the kit and the prescription', () {
      expect(ExerciseTraits.of('barbell_hip_thrust')!.metric, BestMetric.load);
      expect(ExerciseTraits.of('plank')!.metric, BestMetric.hold);
      expect(ExerciseTraits.of('mountain_climbers')!.metric, BestMetric.reps);
      expect(ExerciseTraits.of('not_a_move'), isNull);
    });

    test('the six legacy moves are in the file with their own metric', () {
      for (final entry in bundledExerciseMetrics.entries) {
        final traits = ExerciseTraits.of(entry.key);
        expect(traits, isNotNull, reason: entry.key);
        expect(traits!.metric, entry.value.metric, reason: entry.key);
        expect(traits.nameEn.trim(), isNotEmpty, reason: entry.key);
      }
    });

    test('nameOf: traits, then the legacy words, then the id as words', () {
      expect(ExerciseTraits.nameOf('barbell_hip_thrust'), 'Barbell hip thrust');
      expect(ExerciseTraits.nameOf('dead_bug'), 'Dead bug');
      ExerciseTraits.resetForTest();
      // Nothing loaded: the six legacy moves still have their words.
      expect(ExerciseTraits.nameOf('goblet_squat'), 'Goblet squat');
      expect(ExerciseTraits.nameOf('some_new_move'), 'Some new move');
    });

    test('the file is current: the tool says so', () async {
      final result = await Process.run('python3', [
        'tool/build_exercise_traits.py',
        '--check',
      ]);
      expect(result.exitCode, 0, reason: '${result.stdout}${result.stderr}');
    });

    test('the metrics map covers every programme move and the legacy six', () {
      final all = allExerciseMetrics();
      for (final id in _splitIds()) {
        expect(all[id], isNotNull, reason: id);
      }
      for (final id in bundledExerciseMetrics.keys) {
        expect(all[id]!.metric, bundledExerciseMetrics[id]!.metric);
      }
    });

    test('a library row names a move the bundle lacks, and the bundle keeps '
        'the metric it knows', () {
      const library = ExerciseLibrary(
        version: 1,
        exercises: [
          LibraryExercise(
            id: 'plank',
            nameEn: 'Plank, from the library',
            nameAr: 'بلانك',
            kind: ExerciseKind.strength,
            primaryMuscles: [Muscle.core],
            bodyRegion: 'core',
            pattern: 'core',
            equipment: [LibraryEquipment.mat],
            place: ExercisePlace.both,
            level: ExerciseLevel.beginner,
            quiet: true,
            floorOnly: true,
            tags: {},
            clips: [],
            poster: ExerciseMedia(path: 'p.webp', bytes: 1),
          ),
          LibraryExercise(
            id: 'library_only_press',
            nameEn: 'Library only press',
            nameAr: 'ضغط',
            kind: ExerciseKind.strength,
            primaryMuscles: [Muscle.chest],
            bodyRegion: 'upper',
            pattern: 'press',
            equipment: [LibraryEquipment.dumbbells],
            place: ExercisePlace.both,
            level: ExerciseLevel.beginner,
            quiet: true,
            floorOnly: false,
            tags: {},
            clips: [],
            poster: ExerciseMedia(path: 'q.webp', bytes: 1),
          ),
        ],
      );
      expect(
        ExerciseTraits.of('library_only_press', library: library)!.metric,
        BestMetric.load,
      );
      expect(
        ExerciseTraits.traitsMetrics(library: library)['library_only_press'],
        isNotNull,
      );
      final traits = ExerciseTraits.of('plank', library: library)!;
      expect(traits.nameEn, 'Plank, from the library');
      expect(traits.metric, BestMetric.hold);
    });
  });

  group('a best on a programme move', () {
    test(
      'fixing a middle session teaches the next best what it beat',
      () async {
        final w = _Wired();
        const id = 'barbell_hip_thrust';
        await w.session('a', id, const SetOutcome(weightKg: 50, reps: 8));
        final b = await w.session(
          'b',
          id,
          const SetOutcome(weightKg: 500, reps: 8),
        );
        await w.session('c', id, const SetOutcome(weightKg: 510, reps: 8));
        expect(w.ledger.bests[id]!.previous!.loadKg, 500);

        await w.repository.replaceSet(
          sessionId: b.id,
          exerciseId: id,
          set: _logged(id, const SetOutcome(weightKg: 55, reps: 8)),
        );
        w.bridge.reworkSession(b.id, repository: w.repository);

        expect(w.ledger.bests[id]!.loadKg, 510);
        expect(w.ledger.bests[id]!.previous!.loadKg, 55);
      },
    );

    test('is detected on a load, a hold and a reps move', () async {
      final w = _Wired();
      await w.session(
        'd',
        'barbell_hip_thrust',
        const SetOutcome(weightKg: 60, reps: 8),
      );
      await w.session('d', 'plank', const SetOutcome(holdSeconds: 45));
      await w.session('d', 'mountain_climbers', const SetOutcome(reps: 20));

      expect(w.ledger.bests['barbell_hip_thrust']!.loadKg, 60);
      expect(w.ledger.bests['plank']!.holdSec, 45);
      expect(w.ledger.bests['mountain_climbers']!.reps, 20);
      expect(w.ledger.bestsCount, 3);
    });
  });

  group('backfill and rework', () {
    test('backfill pays nothing, keeps the count, and is idempotent', () async {
      final w = _Wired();
      await w.session(
        'd',
        'barbell_hip_thrust',
        const SetOutcome(weightKg: 50, reps: 8),
      );
      await w.session(
        'd',
        'barbell_hip_thrust',
        const SetOutcome(weightKg: 60, reps: 8),
      );
      final count = w.ledger.bestsCount;
      final counted = w.ledger.countedIds.toSet();

      // Her bests as they were before this build knew the move.
      w.ledger.bests.clear();
      w.bridge.backfill(repository: w.repository);
      final once = {
        for (final e in w.ledger.bests.entries) e.key: e.value.loadKg,
      };
      expect(once['barbell_hip_thrust'], 60);

      w.bridge.backfill(repository: w.repository);
      expect({
        for (final e in w.ledger.bests.entries) e.key: e.value.loadKg,
      }, once);
      expect(w.ledger.bestsCount, count);
      expect(w.ledger.countedIds, counted);
    });

    test('backfill leaves out a discarded workout', () async {
      final w = _Wired();
      final s = await w.repository.startSession(_day);
      await w.repository.flushMove(
        sessionId: s.id,
        exerciseId: 'barbell_hip_thrust',
        sets: [
          _logged(
            'barbell_hip_thrust',
            const SetOutcome(weightKg: 90, reps: 5),
          ),
        ],
      );
      await w.repository.finishSession(
        sessionId: s.id,
        durationSec: 10,
        reason: EndedReason.abandoned,
      );
      w.ledger.bests.clear();
      w.bridge.backfill(repository: w.repository);
      expect(w.ledger.bests, isEmpty);
    });

    test(
      'reworkSession after a typo removes the false best, keeps points',
      () async {
        final w = _Wired();
        await w.session(
          'd',
          'barbell_hip_thrust',
          const SetOutcome(weightKg: 50, reps: 8),
        );
        final typo = await w.session(
          'd',
          'barbell_hip_thrust',
          const SetOutcome(weightKg: 500, reps: 8),
        );
        expect(w.ledger.bests['barbell_hip_thrust']!.loadKg, 500);
        final count = w.ledger.bestsCount;
        final counted = w.ledger.countedIds.toSet();

        await w.repository.replaceSet(
          sessionId: typo.id,
          exerciseId: 'barbell_hip_thrust',
          set: _logged(
            'barbell_hip_thrust',
            const SetOutcome(weightKg: 40, reps: 8),
          ),
        );
        w.bridge.reworkSession(typo.id, repository: w.repository);

        expect(w.ledger.bests['barbell_hip_thrust']!.loadKg, 50);
        expect(w.ledger.bestsCount, count);
        expect(w.ledger.countedIds, counted);
      },
    );

    test('reworkSession keeps a correction that is still a best', () async {
      final w = _Wired();
      final s = await w.session(
        'd',
        'barbell_hip_thrust',
        const SetOutcome(weightKg: 500, reps: 8),
      );
      await w.repository.replaceSet(
        sessionId: s.id,
        exerciseId: 'barbell_hip_thrust',
        set: _logged(
          'barbell_hip_thrust',
          const SetOutcome(weightKg: 50, reps: 8),
        ),
      );
      final count = w.ledger.bestsCount;
      w.bridge.reworkSession(s.id, repository: w.repository);
      expect(w.ledger.bests['barbell_hip_thrust']!.loadKg, 50);
      expect(w.ledger.bestsCount, count);
    });
  });

  group('P03 and Insights name any move', () {
    const best = PersonalBest(
      exerciseId: 'barbell_hip_thrust',
      metric: BestMetric.load,
      dateKey: '2026-10-02',
      sessionId: 's1',
      loadKg: 62.5,
      reps: 8,
      previous: PreviousBest(loadKg: 60),
    );
    const hold = PersonalBest(
      exerciseId: 'plank',
      metric: BestMetric.hold,
      dateKey: '2026-10-05',
      sessionId: 's2',
      holdSec: 75,
    );

    for (final locale in [const Locale('en'), const Locale('ar')]) {
      testWidgets(
        'P03 in ${locale.languageCode} at text scale 2.0, newest first',
        (tester) async {
          _phone(tester);
          await tester.pumpWidget(
            _host(
              PersonalBestsView(
                bests: const [best, hold],
                onBack: () {},
                onSelectTab: (_) {},
              ),
              locale,
              2.0,
            ),
          );
          await tester.pumpAndSettle();

          expect(find.text('Barbell hip thrust'), findsOneWidget);
          expect(find.text('High plank'), findsOneWidget);
          expect(
            tester.getTopLeft(find.text('High plank')).dy,
            lessThan(tester.getTopLeft(find.text('Barbell hip thrust')).dy),
            reason: 'the 5 October plank is newer than the 2 October thrust',
          );
          expect(tester.takeException(), isNull);
        },
      );
    }

    testWidgets('the row states the figure by metric, Western digits', (
      tester,
    ) async {
      _phone(tester);
      await tester.pumpWidget(
        _host(
          PersonalBestsView(bests: const [best, hold], onBack: () {}),
          const Locale('ar'),
          1.0,
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('62.5 كجم × 8'), findsOneWidget);
      expect(find.textContaining('75'), findsWidgets);
      expect(find.textContaining(RegExp('[٠-٩]')), findsNothing);
    });
  });
}
