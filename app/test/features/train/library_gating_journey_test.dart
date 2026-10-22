// The owner's sessions through the REAL router: Explore on R01 lists only what suits her
// life stage, tapping one opens it on R03, and the bundled session stays what
// day one and an empty library show.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:own_hub/app_state/exercise_library_state.dart';
import 'package:own_hub/app_state/workout_library_state.dart';
import 'package:own_hub/domain/flags/feature_flags.dart';
import 'package:own_hub/features/onboarding/domain/intake.dart';
import 'package:own_hub/features/train/domain/workout_library.dart';
import 'package:own_hub/l10n/app_l10n.dart';
import 'package:own_hub/routing/app_router.dart';
import 'package:own_hub/routing/app_routes.dart';
import 'package:own_hub/theme/app_tokens.dart';

import '../../helpers/exercise_library_fixture.dart';

void _phone(WidgetTester tester) {
  tester.view.physicalSize = const Size(1170, 2532);
  tester.view.devicePixelRatio = 3.0;
  addTearDown(tester.view.reset);
}

Widget _app(String id) => MaterialApp(
  localizationsDelegates: AppL10n.localizationsDelegates,
  supportedLocales: AppL10n.supportedLocales,
  theme: buildTheme(const Locale('en')),
  onGenerateRoute: AppRouter.onGenerateRoute,
  onUnknownRoute: AppRouter.onUnknownRoute,
  initialRoute: appRoutes[id]!.name,
);

AuthoredSession _session(String id, String title, Set<LifeStage> stages) =>
    AuthoredSession(
      sessionId: id,
      titleEn: title,
      titleAr: title,
      minutes: 20,
      lifeStages: stages,
      moves: const [
        AuthoredMove(
          exerciseId: 'glute_bridge',
          nameEn: 'Side-lying leg lift',
          nameAr: 'raf3',
          sets: 2,
          reps: 10,
          contraindications: ['none'],
          quiet: true,
        ),
      ],
    );

Future<void> _scrollTo(WidgetTester tester, Finder finder) => tester
    .scrollUntilVisible(finder, 300, scrollable: find.byType(Scrollable).first);

Future<void> _as(LifeStage stage) =>
    AppRouter.intakeRepository.merge(lifeStage: stage);

void main() {
  final savedFlags = AppRouter.featureFlags;
  setUp(() {
    AppRouter.featureFlags = FeatureFlags.everything;
    WorkoutLibraryState.instance.reset();
    ExerciseLibraryState.instance.reset();
    ExerciseLibraryState.instance.media = FakeExerciseMedia();
    ExerciseLibraryState.instance.library = sampleExerciseLibrary();
    WorkoutLibraryState.instance.library = WorkoutLibrary(
      version: 1,
      programmes: [
        AuthoredProgramme(
          programId: 'p',
          titleEn: 'Library',
          titleAr: 'Library',
          status: ProgrammeStatus.published,
          sessions: [
            _session('general', 'Everyday strength', {LifeStage.none}),
            _session('pregnancy', 'Gentle pregnancy session', {
              LifeStage.pregnant,
            }),
          ],
        ),
      ],
    );
  });
  tearDown(() async {
    AppRouter.featureFlags = savedFlags;
    WorkoutLibraryState.instance.reset();
    ExerciseLibraryState.instance.reset();
    await _as(LifeStage.none);
  });

  testWidgets('nothing to train around: the general session, not pregnancy', (
    tester,
  ) async {
    _phone(tester);
    await _as(LifeStage.none);
    await tester.pumpWidget(_app('R01'));
    await tester.pumpAndSettle();
    await _scrollTo(tester, find.text('Everyday strength'));
    expect(find.text('Everyday strength'), findsOneWidget);
    expect(find.text('Gentle pregnancy session'), findsNothing);
  });

  testWidgets('pregnant: only the session marked for pregnancy, with the '
      'doctor card on R03', (tester) async {
    _phone(tester);
    await _as(LifeStage.pregnant);
    await tester.pumpWidget(_app('R01'));
    await tester.pumpAndSettle();
    final row = find.text('Gentle pregnancy session');
    await _scrollTo(tester, row);
    expect(find.text('Everyday strength'), findsNothing);
    expect(row, findsOneWidget);

    // Clear of the edge before the tap.
    await Scrollable.ensureVisible(tester.element(row), alignment: 0.3);
    await tester.pumpAndSettle();
    await tester.tap(row);
    await tester.pumpAndSettle();
    expect(find.text('Gentle pregnancy session'), findsWidgets);
    expect(find.text('Side-lying leg lift'), findsOneWidget);
    expect(find.byKey(const ValueKey('r03-doctor-first')), findsOneWidget);
    expect(
      find.textContaining('Written for pregnancy. Check with your doctor'),
      findsOneWidget,
    );
  });

  testWidgets('nothing chosen: R03 is the bundled session, as on day one', (
    tester,
  ) async {
    _phone(tester);
    await tester.pumpWidget(_app('R03'));
    await tester.pumpAndSettle();
    expect(find.text('Legs and glutes'), findsOneWidget);
  });

  testWidgets('a chosen session that no longer suits her is not opened', (
    tester,
  ) async {
    _phone(tester);
    WorkoutLibraryState.instance.chosenRowId = libraryRowId('p', 'general');
    await _as(LifeStage.pregnant);
    await tester.pumpWidget(_app('R03'));
    await tester.pumpAndSettle();
    expect(find.text('Everyday strength'), findsNothing);
    expect(find.text('Legs and glutes'), findsOneWidget);
  });
}
