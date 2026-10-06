// What Train says about her, walked in the real app.
//
// Three defects a first-time user review found, each of which passed every
// widget test the screen had:
//
//  * `R11` listed three workouts credited to three women who do not exist, and
//    all three opened the same session, because the router discarded the id of
//    the row she tapped.
//  * `R07` told a woman on her very first set what she had lifted "last
//    Tuesday", because the guard compared the prescription against the
//    prototype's `(12, 10)` and the one workout in the build prescribed exactly
//    that to everybody.
//  * `R01` and `R02` both fell back to naming a programme called "Postpartum
//    rebuild" that nobody had chosen.
//
// Each of these is a statement about her, so each is tested by asking what the
// running app actually puts on the screen.

import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:own_hub/app_state/workout_session_state.dart';
import 'package:own_hub/domain/flags/feature_flags.dart';
import 'package:own_hub/domain/training/prescribed_set.dart';
import 'package:own_hub/features/onboarding/domain/intake.dart';
import 'package:own_hub/features/train/domain/set_history.dart';
import 'package:own_hub/features/train/domain/train_repository.dart';
import 'package:own_hub/features/train/presentation/workout_day_view.dart';
import 'package:own_hub/l10n/app_l10n.dart';
import 'package:own_hub/main.dart';
import 'package:own_hub/routing/app_router.dart';

/// The women R11 invented and credited as instructors, in both languages.
///
/// "No invented people" is one of the product's stated rules. These three were
/// two taps from Home.
const _inventedEnglish = ['Nour', 'Mariam', 'Habiba'];
const _inventedArabic = ['نور', 'مريم', 'حبيبة'];

Future<void> _open(WidgetTester tester, String id) async {
  await tester.pumpWidget(OwnHubApp(key: UniqueKey()));
  await tester.pumpAndSettle();
  tester
      .state<NavigatorState>(find.byType(Navigator).first)
      .pushNamed(appDestinations[id]!.name);
  await tester.pumpAndSettle();
}

void main() {
  final saved = AppRouter.featureFlags;

  setUp(() {
    AppRouter.featureFlags = FeatureFlags.allOff.with_({
      for (final f in Feature.values) f: f != Feature.accountRequired,
    });
    WorkoutSessionState.instance.reset();
    AppRouter.trainRepository.reset();
  });

  tearDown(() {
    AppRouter.featureFlags = saved;
    WorkoutSessionState.instance.reset();
    AppRouter.trainRepository.reset();
  });

  group('R11 — the row she taps is the session she gets', () {
    testWidgets('tapping the library row opens that row, not another one', (
      tester,
    ) async {
      await _open(tester, 'R11');

      // The library offers what the app has, by name.
      final row = find.text('Legs and glutes');
      expect(row, findsOneWidget, reason: 'the library has a row to tap');

      await tester.tap(row);
      await tester.pumpAndSettle();

      // R03, showing the session that row named — not a different one.
      expect(find.text("Start, everything's ready"), findsOneWidget);
      expect(find.text('Legs and glutes'), findsWidgets);
    });

    test('every library row resolves to the session it names', () {
      // The structural half of the same promise, and the one that keeps
      // holding when the library grows: a row the app cannot open must never
      // reach the list, because that is how three rows came to open one
      // workout.
      final l10n = lookupAppL10n(const Locale('en'));
      final library = sampleWorkoutLibrary(l10n);

      expect(library, isNotEmpty);
      for (final row in library) {
        final day = workoutDayFor(l10n, row.id);
        expect(day, isNotNull, reason: '${row.id} opens nothing');
        expect(day!.title, row.title, reason: '${row.id} names another day');
      }
    });

    testWidgets('and it credits nobody, in either language', (tester) async {
      for (final locale in [const Locale('en'), const Locale('ar')]) {
        await tester.pumpWidget(
          MaterialApp(
            locale: locale,
            localizationsDelegates: AppL10n.localizationsDelegates,
            supportedLocales: AppL10n.supportedLocales,
            home: Builder(
              builder: (context) {
                final rows = sampleWorkoutLibrary(AppL10n.of(context));
                return Column(
                  children: [
                    for (final r in rows) Text('${r.title} ${r.detail}'),
                  ],
                );
              },
            ),
          ),
        );
        await tester.pumpAndSettle();

        for (final name in [..._inventedEnglish, ..._inventedArabic]) {
          expect(find.textContaining(name), findsNothing, reason: name);
        }
      }
    });
  });

  group('no screen in Train or Notifications renders an invented woman', () {
    // Checked against the dictionary rather than by pumping fourteen screens:
    // a screen renders what it asks the dictionary for, and this catches a
    // string added to a widget that no widget test happens to cover — which is
    // exactly how "10 min · beginner · Nour" survived.
    test('in English and in Arabic', () {
      final en = jsonDecode(
        File('lib/l10n/app_en.arb').readAsStringSync(),
      ) as Map<String, dynamic>;
      final ar = jsonDecode(
        File('lib/l10n/app_ar.arb').readAsStringSync(),
      ) as Map<String, dynamic>;

      final mine = [
        ...Directory('lib/features/train')
            .listSync(recursive: true)
            .whereType<File>()
            .where((f) => f.path.endsWith('.dart')),
        File('lib/features/account/presentation/notifications_view.dart'),
        ...Directory('lib/ui')
            .listSync(recursive: true)
            .whereType<File>()
            .where((f) => f.path.endsWith('.dart')),
      ];

      final offenders = <String>[];
      for (final file in mine) {
        final source = file.readAsStringSync();
        for (final match in RegExp(
          r'l10n\.([A-Za-z0-9_]+)',
        ).allMatches(source)) {
          final key = match.group(1)!;
          final english = en[key];
          final arabic = ar[key];
          final names = [
            for (final n in _inventedEnglish)
              if (english is String && english.contains(n)) '$key: $n',
            for (final n in _inventedArabic)
              if (arabic is String && arabic.contains(n)) '$key: $n',
          ];
          for (final hit in names) {
            offenders.add('${file.path} → $hit');
          }
        }
      }

      expect(
        offenders,
        isEmpty,
        reason:
            'These screens name a woman the product invented. The rule is no '
            'invented people at all, in either language:\n'
            '${offenders.join('\n')}',
      );
    });
  });

  group('R07 — she is never told about a session she did not have', () {
    testWidgets('the first set of the first session cites no last Tuesday', (
      tester,
    ) async {
      await _open(tester, 'R03');
      await tester.tap(find.text("Start, everything's ready"));
      await tester.pumpAndSettle();

      // She has logged nothing, ever.
      expect(AppRouter.trainRepository.flushes, isEmpty);

      expect(find.textContaining('Last Tuesday'), findsNothing);
      expect(find.textContaining('Last time'), findsNothing);
      expect(
        find.textContaining('No history for this move yet'),
        findsOneWidget,
        reason: 'the true thing to say when there is no last time',
      );
    });

    testWidgets('and the first session asks for nothing she has to own', (
      tester,
    ) async {
      // The session's own subtitle promises "quiet, no equipment, floor" and
      // it then prescribed a 12 kg goblet squat, to a woman the app had never
      // asked whether she owns a dumbbell.
      await _open(tester, 'R03');

      expect(find.text('Quiet · no equipment · floor'), findsOneWidget);
      expect(find.textContaining('12 kg'), findsNothing);
      expect(find.text('Goblet squat'), findsNothing);
    });

    testWidgets('a bodyweight set is never logged as zero kilos', (
      tester,
    ) async {
      await _open(tester, 'R03');
      await tester.tap(find.text("Start, everything's ready"));
      await tester.pumpAndSettle();

      expect(find.textContaining('0 kg'), findsNothing);
      expect(find.text('Done · 12 reps'), findsOneWidget);
    });

    test('the note comes from her logged sets, not from her prescription', () {
      // `lastLoggedOutcome` is the read the note is built on, so the rule it
      // enforces is pinned here: a prescription is never a result.
      final repository = InMemoryTrainRepository();

      expect(lastLoggedOutcome(repository, 'goblet_squat'), isNull);

      // A prescribed set that was never performed says nothing.
      repository.flushMove(
        sessionId: 'live-1',
        exerciseId: 'goblet_squat',
        sets: const [
          LoggedSet(
            prescribed: PrescribedSet(
              exerciseId: 'goblet_squat',
              order: 1,
              weightKg: 12,
              reps: 10,
            ),
          ),
        ],
      );
      expect(lastLoggedOutcome(repository, 'goblet_squat'), isNull);

      // One she actually did, in an earlier session, does.
      repository.flushMove(
        sessionId: 'live-1',
        exerciseId: 'goblet_squat',
        sets: [
          const LoggedSet(
            prescribed: PrescribedSet(
              exerciseId: 'goblet_squat',
              order: 1,
              weightKg: 10,
              reps: 10,
            ),
          ).recording(const SetOutcome(weightKg: 10, reps: 10)),
        ],
      );
      expect(lastLoggedOutcome(repository, 'goblet_squat')?.weightKg, 10);

      // "Last time" means an earlier session, not the set she did ninety
      // seconds ago.
      expect(
        lastLoggedOutcome(
          repository,
          'goblet_squat',
          exceptSessionId: 'live-1',
        ),
        isNull,
      );
    });
  });

  group('R01 and R02 name no programme she never chose', () {
    testWidgets('Train', (tester) async {
      await _open(tester, 'R01');
      expect(find.text('Postpartum rebuild'), findsNothing);
    });

    testWidgets('and the programme page', (tester) async {
      await _open(tester, 'R02');
      expect(find.text('Postpartum rebuild'), findsNothing);
      expect(find.text('Your training'), findsOneWidget);
    });
  });

  // B10. Day one was not written for a pregnancy or for the weeks after a
  // birth, and nothing in this build is clinically reviewed for either. R03
  // says so before she starts, and only for those two answers.
  group('R03 asks for her doctor first, when it should', () {
    tearDown(() => AppRouter.intakeRepository.reset());

    for (final stage in LifeStage.values) {
      final asks = stage == LifeStage.pregnant || stage == LifeStage.postpartum;
      testWidgets('${stage.name}: ${asks ? 'the card' : 'no card'}', (
        tester,
      ) async {
        AppRouter.intakeRepository.restore(Intake(lifeStage: stage));
        await _open(tester, 'R03');

        final card = find.byKey(const ValueKey('r03-doctor-first'));
        if (asks) {
          expect(card, findsOneWidget);
          expect(find.text("I have my doctor's OK, start"), findsOneWidget);
          expect(find.text('Not today'), findsOneWidget);
          expect(find.text("Start, everything's ready"), findsNothing);
        } else {
          expect(card, findsNothing);
          expect(find.text("I have my doctor's OK, start"), findsNothing);
        }
      });
    }

    testWidgets('"Not today" leaves without starting anything', (tester) async {
      AppRouter.intakeRepository.restore(
        const Intake(lifeStage: LifeStage.pregnant),
      );
      await _open(tester, 'R03');

      await tester.tap(find.text('Not today'));
      await tester.pumpAndSettle();

      expect(find.byType(WorkoutDayView), findsNothing);
      expect(WorkoutSessionState.instance.session, isNull);
    });
  });
}
