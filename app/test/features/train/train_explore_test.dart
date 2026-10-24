// R01 Explore: the workouts and the moves under one search box, one chip row
// and a Filters sheet. Local lists only, so none of this needs a signal.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:own_hub/domain/flags/feature_flags.dart';
import 'package:own_hub/features/onboarding/domain/intake.dart';
import 'package:own_hub/features/train/domain/exercise_library.dart';
import 'package:own_hub/features/train/domain/train_repository.dart';
import 'package:own_hub/features/train/presentation/train_explore.dart';
import 'package:own_hub/features/train/presentation/train_view.dart';
import 'package:own_hub/l10n/app_l10n.dart';
import 'package:own_hub/routing/app_router.dart';
import 'package:own_hub/theme/app_tokens.dart';
import 'package:own_hub/ui/app_button.dart';

import '../../helpers/exercise_library_fixture.dart';
import '../../helpers/primary_actions.dart';

Widget _host(
  Widget child, {
  Locale locale = const Locale('en'),
  double scale = 1,
}) => MaterialApp(
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

void _phone(WidgetTester tester) {
  tester.view.physicalSize = const Size(1170, 2532);
  tester.view.devicePixelRatio = 3;
  addTearDown(tester.view.reset);
}

Future<void> _scrollTo(WidgetTester tester, Finder finder) => tester
    .scrollUntilVisible(finder, 300, scrollable: find.byType(Scrollable).first);

Future<void> _tap(WidgetTester tester, Finder finder) async {
  await tester.ensureVisible(finder);
  await tester.pumpAndSettle();
  await tester.tap(finder);
  await tester.pumpAndSettle();
}

const _workout = LibraryWorkout(
  id: 'legs',
  title: 'Legs and glutes',
  detail: '15 min · beginner · no equipment',
  exerciseIds: ['glute_bridge'],
);
const _gear = LibraryWorkout(
  id: 'upper',
  title: 'Upper body',
  detail: '20 min',
  needsEquipment: true,
  exerciseIds: ['goblet_squat'],
);

void main() {
  final saved = AppRouter.featureFlags;
  setUp(() => AppRouter.featureFlags = FeatureFlags.everything);
  tearDown(() => AppRouter.featureFlags = saved);

  final all = sampleExerciseLibrary().exercises;

  Widget train({
    List<LibraryExercise>? exercises,
    List<LibraryWorkout> workouts = const [_workout, _gear],
    ExploreFocus? focus,
    Key? key,
    LifeStage? hiddenFor,
    ValueChanged<LibraryExercise>? onOpenExercise,
    ValueChanged<LibraryWorkout>? onOpenWorkout,
    bool Function(LibraryWorkout)? workoutIsFilmed,
    FakeExerciseMedia? media,
  }) => TrainView(
    key: key,
    exercises: exercises ?? all,
    workouts: workouts,
    focus: focus,
    hiddenFor: hiddenFor,
    onOpenExercise: onOpenExercise,
    onOpenWorkout: onOpenWorkout,
    workoutIsFilmed: workoutIsFilmed,
    media: media ?? FakeExerciseMedia(),
  );

  testWidgets('lists workouts, then moves as poster cards', (tester) async {
    _phone(tester);
    await tester.pumpWidget(_host(train()));
    await tester.pumpAndSettle();
    await _scrollTo(tester, find.text('Workouts'));
    expect(find.text('Legs and glutes'), findsOneWidget);
    await _scrollTo(
      tester,
      find.byKey(const ValueKey('r01-move-glute_bridge')),
    );
    expect(find.byKey(const ValueKey('r01-move-glute_bridge')), findsOneWidget);
    expect(find.byIcon(Icons.play_arrow_rounded), findsWidgets);
    expectAtMostOnePrimaryAction(tester, where: 'R01');
  });

  testWidgets('a workout is listed only when every move in it has a clip', (
    tester,
  ) async {
    _phone(tester);
    await tester.pumpWidget(
      _host(train(workoutIsFilmed: (w) => w.id == 'legs')),
    );
    await tester.pumpAndSettle();
    await _scrollTo(tester, find.text('Workouts'));
    expect(find.text('Legs and glutes'), findsOneWidget);
    expect(find.text('Upper body'), findsNothing);
  });

  testWidgets('the Filters sheet narrows by kind and by part of the body', (
    tester,
  ) async {
    _phone(tester);
    await tester.pumpWidget(_host(train()));
    await tester.pumpAndSettle();

    await _tap(tester, find.byKey(const ValueKey('r01-filters')));
    await tester.tap(find.text('Stretches and warm-ups'));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('r01-filters-apply')));
    await tester.pumpAndSettle();
    await _scrollTo(tester, find.text('Standing forward fold'));
    expect(find.byKey(const ValueKey('r01-move-glute_bridge')), findsNothing);
    expect(find.text('Standing forward fold'), findsOneWidget);
    // Workouts carry no body-part data, so a stretch filter leaves them out.
    expect(find.text('Workouts'), findsNothing);

    await _tap(tester, find.byKey(const ValueKey('r01-filters')));
    await tester.tap(find.text('Glutes'));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('r01-filters-apply')));
    await tester.pumpAndSettle();
    await _scrollTo(tester, find.text('Moves'));
    expect(find.text('Glute bridge'), findsOneWidget);
    expect(find.text('Goblet squat'), findsNothing);
  });

  testWidgets('place and kit sit behind the Filters sheet', (tester) async {
    _phone(tester);
    await tester.pumpWidget(_host(train()));
    await tester.pumpAndSettle();
    expect(find.text('Gym only'), findsNothing);
    await _tap(tester, find.byKey(const ValueKey('r01-filters')));
    await tester.tap(find.text('Gym only'));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('r01-filters-apply')));
    await tester.pumpAndSettle();
    await _scrollTo(tester, find.text('Moves'));
    expect(find.text('Lat pulldown, wide grip'), findsOneWidget);
    expect(find.byKey(const ValueKey('r01-move-glute_bridge')), findsNothing);
  });

  testWidgets('the apply button shows the live count and handles none', (
    tester,
  ) async {
    _phone(tester);
    await tester.pumpWidget(_host(train()));
    await tester.pumpAndSettle();
    final apply = find.byKey(const ValueKey('r01-filters-apply'));
    String label() => tester
        .widget<Text>(find.descendant(of: apply, matching: find.byType(Text)))
        .data!;
    await _tap(tester, find.byKey(const ValueKey('r01-filters')));
    // R01 counts workouts and moves together.
    int results(ExploreFilter f) =>
        const [_workout, _gear].where(f.keepWorkout).length +
        all.where(f.keepMove).length;
    final everything = results(ExploreFilter());
    expect(label(), 'Show $everything results');
    expect(find.byKey(const ValueKey('r01-filters-empty')), findsNothing);

    await tester.tap(find.text('Gym only'));
    await tester.pumpAndSettle();
    final gym = results(ExploreFilter()..place = ExercisePlace.gym);
    expect(label(), 'Show $gym results');
    expect(gym, lessThan(everything));
  });

  testWidgets('the count leaves out a workout that is not filmed', (
    tester,
  ) async {
    _phone(tester);
    await tester.pumpWidget(
      _host(train(workoutIsFilmed: (w) => w.id == 'legs')),
    );
    await tester.pumpAndSettle();
    await _tap(tester, find.byKey(const ValueKey('r01-filters')));
    final apply = find.byKey(const ValueKey('r01-filters-apply'));
    final text = tester
        .widget<Text>(find.descendant(of: apply, matching: find.byType(Text)))
        .data!;
    // One workout of the two is filmed, so it is the only one counted.
    expect(text, 'Show ${all.length + 1} results');
  });

  testWidgets('with nothing left the button is unavailable and kind', (
    tester,
  ) async {
    _phone(tester);
    final kills = ExploreFilter()
      ..place = ExercisePlace.gym
      ..kit = ExploreKit.nothing;
    final survivors = [
      for (final e in all)
        if (!kills.keepMove(e)) e,
    ];
    // The home workout passes the filters but is not filmed, so it is not
    // listed and must not be counted either.
    await tester.pumpWidget(
      _host(
        train(
          exercises: survivors,
          workouts: const [_workout, _gear],
          workoutIsFilmed: (w) => w.id == 'upper',
        ),
      ),
    );
    await tester.pumpAndSettle();
    await _tap(tester, find.byKey(const ValueKey('r01-filters')));
    final apply = find.byKey(const ValueKey('r01-filters-apply'));
    await tester.tap(find.text('Gym only'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('No equipment'));
    await tester.pumpAndSettle();
    expect(
      tester
          .widget<Text>(find.descendant(of: apply, matching: find.byType(Text)))
          .data,
      'Show 0 results',
    );
    expect(tester.widget<AppButton>(apply).onPressed, isNull);
    expect(find.byKey(const ValueKey('r01-filters-empty')), findsOneWidget);
    await tester.tap(find.text('No equipment'));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('r01-filters-empty')), findsNothing);
  });

  testWidgets('a chip that would find nothing is not offered', (tester) async {
    _phone(tester);
    final home = [
      for (final e in all)
        if (e.place == ExercisePlace.both && !e.usesGymMachine) e,
    ];
    await tester.pumpWidget(_host(train(exercises: home)));
    await tester.pumpAndSettle();
    final filters = find.byKey(const ValueKey('r01-filters'));
    if (filters.evaluate().isNotEmpty) {
      await _tap(tester, filters);
    }
    expect(find.text('Gym machines'), findsNothing);
    expect(find.text('Gym only'), findsNothing);
  });

  testWidgets('search finds a move by name and says when nothing matches', (
    tester,
  ) async {
    _phone(tester);
    await tester.pumpWidget(_host(train()));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField), 'goblet');
    await tester.pumpAndSettle();
    await _scrollTo(tester, find.text('Moves'));
    expect(find.text('Goblet squat'), findsOneWidget);
    expect(find.byKey(const ValueKey('r01-move-glute_bridge')), findsNothing);
    await tester.enterText(find.byType(TextField), 'zzz');
    await tester.pumpAndSettle();
    expect(find.text('Nothing matches those filters.'), findsOneWidget);
  });

  testWidgets('a door can open Train already filtered, scrolled to Explore', (
    tester,
  ) async {
    _phone(tester);
    await tester.pumpWidget(
      _host(train(focus: const ExploreFocus(section: MuscleSection.glutes))),
    );
    await tester.pumpAndSettle();
    expect(find.text('Explore'), findsOneWidget);
    expect(
      tester.getTopLeft(find.text('Explore')).dy,
      lessThan(340),
      reason: 'the page scrolled so Explore is at the top',
    );
    expect(find.text('Goblet squat'), findsNothing);
    expect(find.byKey(const ValueKey('r01-move-glute_bridge')), findsOneWidget);

    await tester.pumpWidget(
      _host(
        train(
          key: UniqueKey(),
          focus: const ExploreFocus(query: 'goblet'),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(
      tester.widget<TextField>(find.byType(TextField)).controller!.text,
      'goblet',
    );
  });

  testWidgets('a tap hands back the move or the workout she tapped', (
    tester,
  ) async {
    _phone(tester);
    LibraryExercise? move;
    LibraryWorkout? workout;
    await tester.pumpWidget(
      _host(
        train(
          onOpenExercise: (e) => move = e,
          onOpenWorkout: (w) => workout = w,
        ),
      ),
    );
    await tester.pumpAndSettle();
    await _scrollTo(tester, find.text('Legs and glutes'));
    await tester.tap(find.text('Legs and glutes'));
    expect(workout?.id, 'legs');
    await _scrollTo(tester, find.text('Goblet squat'));
    await tester.tap(find.text('Goblet squat'));
    expect(move?.id, 'goblet_squat');
  });

  testWidgets('posters are asked for only as their cards are built', (
    tester,
  ) async {
    _phone(tester);
    final media = FakeExerciseMedia(fetchable: false);
    await tester.pumpWidget(_host(train(media: media)));
    await tester.pumpAndSettle();
    expect(media.fetched.length, lessThan(all.length));
    expect(media.fetched.every((p) => p.endsWith('.webp')), isTrue);
  });

  testWidgets('with no library yet it says it is on its way', (tester) async {
    _phone(tester);
    await tester.pumpWidget(
      _host(train(exercises: const [], workouts: const [])),
    );
    await tester.pumpAndSettle();
    await _scrollTo(tester, find.text('The exercise library is on its way'));
    expect(find.text('The exercise library is on its way'), findsOneWidget);
  });

  testWidgets(
    'pregnant, or after a birth, one note says why moves are missing',
    (tester) async {
      _phone(tester);
      await tester.pumpWidget(_host(train(hiddenFor: LifeStage.pregnant)));
      await tester.pumpAndSettle();
      expect(
        find.textContaining('Some moves are hidden while you are pregnant'),
        findsOneWidget,
      );
      await tester.pumpWidget(_host(train(hiddenFor: LifeStage.postpartum)));
      await tester.pumpAndSettle();
      expect(
        find.textContaining('Some moves are hidden in the weeks after a birth'),
        findsOneWidget,
      );
      await tester.pumpWidget(_host(train()));
      await tester.pumpAndSettle();
      expect(find.textContaining('Some moves are hidden'), findsNothing);
    },
  );

  for (final (locale, scale) in [
    (const Locale('ar'), 1.6),
    (const Locale('ar'), 2.0),
    (const Locale('en'), 2.0),
  ]) {
    testWidgets('${locale.languageCode} at ${scale}x scrolls end to end', (
      tester,
    ) async {
      _phone(tester);
      await tester.pumpWidget(_host(train(), locale: locale, scale: scale));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      final list = find.byType(Scrollable).first;
      for (var i = 0; i < 40; i++) {
        await tester.drag(list, const Offset(0, -500));
        await tester.pump();
        expect(tester.takeException(), isNull, reason: 'after scroll $i');
      }
    });
  }
}
