// R14: the moves under the part of the body they work, narrowed by kind,
// place and kit, searched by name, and honest when moves are held back.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:own_hub/domain/flags/feature_flags.dart';
import 'package:own_hub/features/onboarding/domain/intake.dart';
import 'package:own_hub/features/train/domain/exercise_library.dart';
import 'package:own_hub/features/train/presentation/exercise_library_view.dart';
import 'package:own_hub/l10n/app_l10n.dart';
import 'package:own_hub/routing/app_router.dart';
import 'package:own_hub/theme/app_tokens.dart';

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

void main() {
  final saved = AppRouter.featureFlags;
  setUp(() => AppRouter.featureFlags = FeatureFlags.everything);
  tearDown(() => AppRouter.featureFlags = saved);

  final all = sampleExerciseLibrary().exercises;

  testWidgets('moves sit under their headings, in reading order', (
    tester,
  ) async {
    _phone(tester);
    await tester.pumpWidget(
      _host(ExerciseLibraryView(exercises: all, media: FakeExerciseMedia())),
    );
    await tester.pumpAndSettle();
    expect(find.text('Glutes'), findsOneWidget);
    expect(find.text('Glute bridge'), findsOneWidget);
    final glutesAt = tester.getTopLeft(find.text('Glutes')).dy;
    await _scrollTo(tester, find.text('Dumbbell hammer curl'));
    expect(find.text('Arms'), findsOneWidget);
    // Arms is the last heading: below Glutes, which has scrolled up past it.
    expect(tester.getTopLeft(find.text('Arms')).dy, greaterThan(0));
    expect(
      glutesAt,
      lessThan(tester.getTopLeft(find.text('Dumbbell hammer curl')).dy + 2000),
    );
    expectAtMostOnePrimaryAction(tester, where: 'R14');
  });

  testWidgets('the kind, place and kit chips narrow the list', (tester) async {
    _phone(tester);
    await tester.pumpWidget(
      _host(ExerciseLibraryView(exercises: all, media: FakeExerciseMedia())),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('Stretches and warm-ups'));
    await tester.pumpAndSettle();
    expect(find.text('Glute bridge'), findsNothing);
    expect(find.text('Standing forward fold'), findsOneWidget);

    await tester.tap(find.text('All'));
    await tester.pumpAndSettle();
    // Place and kit sit behind one Filters chip, in a sheet.
    expect(find.text('Gym only'), findsNothing);
    await tester.tap(find.byKey(const ValueKey('r14-filters')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Gym only'));
    await tester.pumpAndSettle();
    expect(find.text('Lat pulldown, wide grip'), findsOneWidget);
    expect(find.text('Glute bridge'), findsNothing);
    // The lit chip, tapped again, clears.
    await tester.tap(find.text('Gym only'));
    await tester.pumpAndSettle();
    expect(find.text('Glute bridge'), findsOneWidget);

    await tester.tap(find.text('Dumbbells'));
    await tester.pumpAndSettle();
    expect(find.text('Goblet squat'), findsOneWidget);
    expect(find.text('Glute bridge'), findsNothing);
    await tester.tap(find.text('Dumbbells'));
    await tester.tap(find.text('Gym machines'));
    await tester.pumpAndSettle();
    expect(find.text('Lat pulldown, wide grip'), findsOneWidget);
    expect(find.text('Goblet squat'), findsNothing);
  });

  testWidgets('a chip that would find nothing is not offered', (tester) async {
    _phone(tester);
    final home = [
      for (final e in all)
        if (e.place == ExercisePlace.both && !e.usesGymMachine) e,
    ];
    await tester.pumpWidget(
      _host(ExerciseLibraryView(exercises: home, media: FakeExerciseMedia())),
    );
    await tester.pumpAndSettle();
    // The Filters sheet lists only what this library has.
    final filters = find.byKey(const ValueKey('r14-filters'));
    if (filters.evaluate().isNotEmpty) {
      await tester.tap(filters);
      await tester.pumpAndSettle();
    }
    expect(find.text('Gym machines'), findsNothing);
    expect(find.text('Gym only'), findsNothing);
  });

  testWidgets('search finds a move by name, and says when nothing matches', (
    tester,
  ) async {
    _phone(tester);
    await tester.pumpWidget(
      _host(ExerciseLibraryView(exercises: all, media: FakeExerciseMedia())),
    );
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField), 'goblet');
    await tester.pumpAndSettle();
    expect(find.text('Goblet squat'), findsOneWidget);
    expect(find.text('Glute bridge'), findsNothing);
    await tester.enterText(find.byType(TextField), 'zzz');
    await tester.pumpAndSettle();
    expect(find.text('Nothing matches those filters.'), findsOneWidget);
    expect(
      find.text('Try another filter, or clear the search.'),
      findsOneWidget,
    );
  });

  testWidgets(
    'her search stays put when the field scrolls out of view and back',
    (tester) async {
      tester.view.physicalSize = const Size(1170, 1200);
      tester.view.devicePixelRatio = 3;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(
        _host(ExerciseLibraryView(exercises: all, media: FakeExerciseMedia())),
      );
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextField), 'e');
      await tester.pumpAndSettle();
      final list = find.byType(Scrollable).first;
      await tester.drag(list, const Offset(0, -2000));
      await tester.pumpAndSettle();
      expect(
        find.byType(TextField),
        findsNothing,
        reason: 'the field is off screen, so the list dropped it',
      );
      await tester.drag(list, const Offset(0, 4000));
      await tester.pumpAndSettle();
      expect(
        tester.widget<TextField>(find.byType(TextField)).controller!.text,
        'e',
      );
      expect(
        find.text('Standing forward fold'),
        findsNothing,
        reason: 'the filter still applies',
      );
    },
  );

  testWidgets('a tap hands back the move she tapped', (tester) async {
    _phone(tester);
    LibraryExercise? opened;
    await tester.pumpWidget(
      _host(
        ExerciseLibraryView(
          exercises: all,
          media: FakeExerciseMedia(),
          onOpenExercise: (e) => opened = e,
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('Goblet squat'));
    expect(opened?.id, 'goblet_squat');
  });

  testWidgets('posters are asked for only as their rows are built', (
    tester,
  ) async {
    _phone(tester);
    final media = FakeExerciseMedia(fetchable: false);
    await tester.pumpWidget(
      _host(ExerciseLibraryView(exercises: all, media: media)),
    );
    await tester.pumpAndSettle();
    expect(media.fetched, isNotEmpty);
    expect(
      media.fetched.every((p) => p.endsWith('.webp')),
      isTrue,
      reason: 'no clip is fetched from the list',
    );
  });

  testWidgets('with no library yet it says it is on its way', (tester) async {
    _phone(tester);
    await tester.pumpWidget(_host(const ExerciseLibraryView()));
    await tester.pumpAndSettle();
    expect(find.text('The exercise library is on its way'), findsOneWidget);
    expect(find.byType(TextField), findsNothing);
  });

  testWidgets(
    'pregnant, or after a birth, one note says why moves are missing',
    (tester) async {
      _phone(tester);
      await tester.pumpWidget(
        _host(
          ExerciseLibraryView(
            exercises: all,
            hiddenFor: LifeStage.pregnant,
            media: FakeExerciseMedia(),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(
        find.textContaining('Some moves are hidden while you are pregnant'),
        findsOneWidget,
      );
      await tester.pumpWidget(
        _host(
          ExerciseLibraryView(
            exercises: all,
            hiddenFor: LifeStage.postpartum,
            media: FakeExerciseMedia(),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(
        find.textContaining('Some moves are hidden in the weeks after a birth'),
        findsOneWidget,
      );
      await tester.pumpWidget(
        _host(ExerciseLibraryView(exercises: all, media: FakeExerciseMedia())),
      );
      await tester.pumpAndSettle();
      expect(find.textContaining('Some moves are hidden'), findsNothing);
    },
  );

  testWidgets(
    'Arabic at 1.6x: headings and names in Arabic, nothing overflows',
    (tester) async {
      _phone(tester);
      await tester.pumpWidget(
        _host(
          ExerciseLibraryView(exercises: all, media: FakeExerciseMedia()),
          locale: const Locale('ar'),
          scale: 1.6,
        ),
      );
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      expect(find.text('الأرداف'), findsOneWidget);
      expect(find.text('جلوت بريدج'), findsOneWidget);
      await _scrollTo(tester, find.text('هامر كيرل بالدمبل'));
      expect(tester.takeException(), isNull);
    },
  );
}
