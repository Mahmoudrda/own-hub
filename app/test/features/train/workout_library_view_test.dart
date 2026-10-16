// R11 — Workout library.
//
// The filters are the constraints she actually has, and the filtering is local:
// no query, no index, and it works with no signal.
//
// One test here documents a gap rather than a behaviour — see the D7 group.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:own_hub/features/train/domain/train_repository.dart';
import 'package:own_hub/features/train/presentation/workout_library_view.dart';
import 'package:own_hub/l10n/app_l10n.dart';
import 'package:own_hub/theme/app_tokens.dart';

Widget _host(
  Widget child, {
  Locale locale = const Locale('en'),
  double textScale = 1.0,
}) {
  return MaterialApp(
    locale: locale,
    localizationsDelegates: AppL10n.localizationsDelegates,
    supportedLocales: AppL10n.supportedLocales,
    theme: buildTheme(locale),
    home: MediaQuery(
      data: MediaQueryData(textScaler: TextScaler.linear(textScale)),
      child: child,
    ),
  );
}

void main() {
  testWidgets('searches the library, with her constraints as the filters', (
    tester,
  ) async {
    await tester.pumpWidget(_host(const WorkoutLibraryView()));
    await tester.pumpAndSettle();

    expect(find.text('Search'), findsOneWidget);
    // Constraints she has, not muscle-group jargon.
    expect(find.text('Quiet'), findsOneWidget);
    expect(find.text('No equipment'), findsOneWidget);
    // The workout the app actually ships, described without crediting anyone.
    expect(find.text('Legs and glutes'), findsOneWidget);
    expect(find.text('15 min · beginner · no equipment'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  group('the three coaches who did not exist', () {
    // R11 listed "Floor legs, no jumping · 10 min · beginner · Nour", "Quiet
    // full body · 15 min · beginner · Mariam" and "Upper body at home · 20 min
    // · easy · Habiba" — three invented Egyptian women credited as
    // instructors, in both languages, two taps from Home, against a rule that
    // forbids invented people outright. All three opened the same session.
    const invented = ['Nour', 'Mariam', 'Habiba'];

    testWidgets('no row credits a woman who does not exist', (tester) async {
      for (final locale in [const Locale('en'), const Locale('ar')]) {
        await tester.pumpWidget(
          _host(const WorkoutLibraryView(), locale: locale),
        );
        await tester.pumpAndSettle();

        for (final name in invented) {
          expect(
            find.textContaining(name),
            findsNothing,
            reason: '$name is invented, and $locale renders her',
          );
        }
      }
    });

    testWidgets('and no row is a title the app cannot open', (tester) async {
      await tester.pumpWidget(_host(const WorkoutLibraryView()));
      await tester.pumpAndSettle();

      for (final title in const [
        'Floor legs, no jumping',
        'Quiet full body',
        'Upper body at home',
      ]) {
        expect(find.text(title), findsNothing);
      }
    });
  });

  testWidgets('the list is not preceded by a count it cannot make', (
    tester,
  ) async {
    // This test was called "the result count explains the list", and what it
    // pinned was `n18WorkoutsQuietAndNoEquipment` — a fixed "18 workouts,
    // quiet and no equipment" above a list of three rows with no filter
    // selected. It said eighteen whatever `_visible` returned and whichever
    // chips were lit, so it explained nothing and contradicted what was under
    // it. The count is real; the dictionary has no "{n} workouts" to say it
    // in, so nothing is said and the rows answer for themselves.
    await tester.pumpWidget(_host(const WorkoutLibraryView()));
    await tester.pumpAndSettle();

    expect(find.textContaining('18 workouts'), findsNothing);
    expect(find.text('Legs and glutes'), findsOneWidget);
  });

  testWidgets('carries no note about the library being written', (
    tester,
  ) async {
    await tester.pumpWidget(_host(const WorkoutLibraryView()));
    await tester.pumpAndSettle();

    expect(find.textContaining('still being written'), findsNothing);
  });

  testWidgets('filtering happens locally, with no query', (tester) async {
    await tester.pumpWidget(_host(const WorkoutLibraryView()));
    await tester.pumpAndSettle();

    expect(find.text('Legs and glutes'), findsOneWidget);

    // Ten minutes only. The fifteen-minute session drops out immediately, and
    // the screen says so rather than going blank.
    await tester.tap(find.text('10 min'));
    await tester.pumpAndSettle();

    expect(find.text('Legs and glutes'), findsNothing);
    expect(find.text('Nothing matches those filters.'), findsOneWidget);
  });

  testWidgets('typing narrows the list without a network call', (tester) async {
    await tester.pumpWidget(_host(const WorkoutLibraryView()));
    await tester.pumpAndSettle();

    await tester.enterText(find.byType(TextField), 'Legs');
    await tester.pumpAndSettle();

    expect(find.text('Legs and glutes'), findsOneWidget);

    await tester.enterText(find.byType(TextField), 'Kettlebell');
    await tester.pumpAndSettle();

    expect(find.text('Legs and glutes'), findsNothing);
  });

  testWidgets('opening a workout hands back the row', (tester) async {
    // The router used to discard this argument, which is how three differently
    // titled rows all opened one session.
    LibraryWorkout? opened;
    await tester.pumpWidget(
      _host(WorkoutLibraryView(onOpenWorkout: (workout) => opened = workout)),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('Legs and glutes'));
    await tester.pumpAndSettle();

    expect(opened?.title, 'Legs and glutes');
  });

  testWidgets('rows come from data, and show no network image', (tester) async {
    await tester.pumpWidget(
      _host(
        const WorkoutLibraryView(
          workouts: [
            LibraryWorkout(
              id: 'x',
              title: 'Morning mobility',
              detail: '8 min',
              quiet: true,
            ),
          ],
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Morning mobility'), findsOneWidget);
    expect(find.text('Legs and glutes'), findsNothing);
    // The 124 posters do not exist yet; nothing here may fetch one.
    expect(find.byType(Image), findsNothing);
  });

  group('D7 — the split builder is missing from this screen', () {
    testWidgets('she can pick a workout, but cannot build her own split here', (
      tester,
    ) async {
      // DECISIONS.md D7 says she may choose a predefined split OR design her
      // own from this library. The prototype's R11 has no affordance for the
      // second half — every split-builder string in the dictionary belongs to
      // the coach screens. This test records the gap rather than inventing an
      // entry point for it, and will fail the day one is added, which is the
      // moment to delete it.
      await tester.pumpWidget(_host(const WorkoutLibraryView()));
      await tester.pumpAndSettle();

      expect(find.text('Build a split'), findsNothing);
      expect(find.text('My splits'), findsNothing);
    });
  });

  testWidgets('reads in Arabic, from the dictionary', (tester) async {
    await tester.pumpWidget(
      _host(const WorkoutLibraryView(), locale: const Locale('ar')),
    );
    await tester.pumpAndSettle();

    expect(find.text('دوّري'), findsOneWidget);
    expect(find.text('الرجلين والأرداف'), findsOneWidget);
    expect(find.text('15 دقيقة · مبتدئة · من غير أدوات'), findsOneWidget);
    expect(find.text('Legs and glutes'), findsNothing);
  });

  testWidgets('does not overflow at the largest system text size in Arabic', (
    tester,
  ) async {
    await tester.pumpWidget(
      _host(
        const WorkoutLibraryView(),
        locale: const Locale('ar'),
        textScale: 1.6,
      ),
    );
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
  });
}
