// The exercise library through the REAL router: Train offers it only once
// the phone holds one, R14 opens R15 on the move she tapped, and a move her
// life stage hides cannot be reached at all.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:own_hub/app_state/exercise_library_state.dart';
import 'package:own_hub/domain/flags/feature_flags.dart';
import 'package:own_hub/features/onboarding/domain/intake.dart';
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

Future<void> _as(LifeStage stage) =>
    AppRouter.intakeRepository.merge(lifeStage: stage);

void main() {
  final savedFlags = AppRouter.featureFlags;
  final state = ExerciseLibraryState.instance;

  setUp(() {
    AppRouter.featureFlags = FeatureFlags.everything;
    state.reset();
    FakeClipPlayer.made.clear();
    state.media = FakeExerciseMedia();
    state.players = FakeClipPlayer.make;
  });
  tearDown(() async {
    AppRouter.featureFlags = savedFlags;
    state.reset();
    await _as(LifeStage.none);
  });

  Future<void> scrollTo(WidgetTester tester, Finder finder) =>
      tester.scrollUntilVisible(
        finder,
        300,
        scrollable: find.byType(Scrollable).first,
      );

  testWidgets('with no library on the phone, Train does not offer one', (
    tester,
  ) async {
    _phone(tester);
    await tester.pumpWidget(_app('R01'));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('r01-exercise-library')), findsNothing);
  });

  testWidgets('Train, then the library, then the move she tapped, playing', (
    tester,
  ) async {
    _phone(tester);
    state.library = sampleExerciseLibrary();
    await tester.pumpWidget(_app('R01'));
    await tester.pumpAndSettle();
    final row = find.byKey(const ValueKey('r01-exercise-library'));
    await scrollTo(tester, row);
    await tester.tap(row);
    await tester.pumpAndSettle();
    expect(find.text('Glute bridge'), findsOneWidget);

    await tester.ensureVisible(find.text('Goblet squat'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Goblet squat'));
    await tester.pumpAndSettle();
    expect(state.openExerciseId, 'goblet_squat');
    expect(find.text('Front of thighs'), findsOneWidget);
    expect(find.byKey(const ValueKey('fake-clip')), findsOneWidget);
    expect(FakeClipPlayer.made.single.playing, isTrue);
  });

  testWidgets('R11 keeps one door to it, from Train', (tester) async {
    _phone(tester);
    state.library = sampleExerciseLibrary();
    await tester.pumpWidget(_app('R11'));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('r11-exercise-library')), findsNothing);
  });

  testWidgets(
    'pregnant: the floor-tagged move is not listed, and cannot be opened',
    (tester) async {
      _phone(tester);
      await _as(LifeStage.pregnant);
      state.library = sampleExerciseLibrary();
      await tester.pumpWidget(_app('R14'));
      await tester.pumpAndSettle();
      expect(find.text('Glute bridge'), findsNothing);
      expect(
        find.textContaining('Some moves are hidden while you are pregnant'),
        findsOneWidget,
      );

      // An id left over from before her answers changed opens nothing.
      state.openExerciseId = 'glute_bridge';
      // A new app, so the route is read again rather than kept from above.
      await tester.pumpWidget(const SizedBox());
      await tester.pumpWidget(_app('R15'));
      await tester.pumpAndSettle();
      expect(find.text('Choose a move from the library'), findsOneWidget);
      expect(FakeClipPlayer.made, isEmpty);
    },
  );
}
