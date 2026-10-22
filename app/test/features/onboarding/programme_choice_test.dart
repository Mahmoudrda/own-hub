// O05 and R02 — choosing between the coach's splits.
//
// The ranking puts her days a week first and her level second; the screens show
// the three splits in the order of their days, tag the one that suits her days,
// give each a Choose and a Customize button, add a fourth card for building her
// own workout, and start the one she chose.

import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:own_hub/app_state/app_snapshot.dart';
import 'package:own_hub/app_state/chosen_programme.dart';
import 'package:own_hub/features/onboarding/domain/intake.dart';
import 'package:own_hub/features/onboarding/domain/intake_repository.dart';
import 'package:own_hub/features/onboarding/domain/starting_program.dart';
import 'package:own_hub/features/onboarding/presentation/programme_cards.dart';
import 'package:own_hub/features/onboarding/presentation/starting_program_view.dart';
import 'package:own_hub/l10n/app_l10n.dart';
import 'package:own_hub/routing/app_router.dart';
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

StartingProgram _plan(
  int days, {
  TrainingLevel tier = TrainingLevel.beginner,
  int rank = 0,
}) => StartingProgram(
  programId: tier == TrainingLevel.beginner
      ? 'split_${days}day'
      : 'split_${days}day_${tier.wireName}',
  weeks: 8,
  daysPerWeek: days,
  sessionLength: 50,
  quiet: true,
  equipment: const {},
  rank: rank,
  tier: tier,
  family: 'split_${days}day',
);

final _synthetic = [
  _plan(3),
  _plan(3, tier: TrainingLevel.intermediate),
  _plan(4),
  _plan(5),
];

const _fourDays = Intake(days: 4);

/// A phone-sized screen tall enough for all four cards.
void _tall(WidgetTester tester) {
  tester.view.physicalSize = const Size(1170, 3600);
  tester.view.devicePixelRatio = 3;
  addTearDown(tester.view.reset);
}

void main() {
  setUpAll(() {
    StartingProgrammes.adopt(
      File('assets/content/starting_programmes.json').readAsStringSync(),
    );
  });
  tearDownAll(StartingProgrammes.reset);

  group('rankStartingPrograms', () {
    test(
      'puts her days first, then her level, and keeps the catalogue order',
      () {
        final ranked = rankStartingPrograms(_fourDays, _synthetic);
        expect(ranked.map((p) => p.programId), [
          'split_4day',
          'split_3day',
          'split_5day',
          'split_3day_intermediate',
        ]);
        final intermediate = rankStartingPrograms(
          const Intake(days: 3, level: TrainingLevel.intermediate),
          _synthetic,
        );
        expect(intermediate.first.programId, 'split_3day_intermediate');
      },
    );

    test('selectStartingProgram is the first of the ranking', () {
      expect(
        selectStartingProgram(_fourDays, catalogue: _synthetic),
        rankStartingPrograms(_fourDays, _synthetic).first,
      );
      expect(selectStartingProgram(_fourDays, catalogue: const []), isNull);
      expect(rankStartingPrograms(_fourDays, const []), isEmpty);
    });

    test('offers a split once, however many tiers of it fit', () {
      final top = topStartingPrograms(_fourDays, catalogue: _synthetic);
      expect(top.map((p) => p.family), [
        'split_4day',
        'split_3day',
        'split_5day',
      ]);
    });
  });

  group('alignDaysToSplit', () {
    test(
      'sets her days to the split and lets go of mismatched weekdays',
      () async {
        final repository = InMemoryIntakeRepository(
          const Intake(days: 3, weekdays: {6, 1, 3}),
        );
        alignDaysToSplit(repository, _plan(5));
        expect(repository.read().days, 5);
        expect(repository.read().weekdays, isEmpty);
      },
    );

    test('does nothing when the days already match or it is not a split', () {
      final repository = InMemoryIntakeRepository(
        const Intake(days: 3, weekdays: {6, 1, 3}),
      );
      alignDaysToSplit(repository, _plan(3));
      alignDaysToSplit(repository, beginnerFoundations);
      expect(repository.writes, isEmpty);
      expect(repository.read().weekdays, {6, 1, 3});
    });
  });

  group('the programme she chose', () {
    tearDown(ChosenProgramme.reset);

    test('is followed while it still fits, and the best fit otherwise', () {
      final fits = rankStartingPrograms(_fourDays, _synthetic);
      expect(ChosenProgramme.among(fits)!.programId, 'split_4day');
      ChosenProgramme.family = 'split_5day';
      expect(ChosenProgramme.among(fits)!.programId, 'split_5day');
      // A plan from before the splits is gone: the best fit stands, which is
      // the split with her days.
      ChosenProgramme.family = 'stronger_gym';
      expect(ChosenProgramme.among(fits)!.programId, 'split_4day');
      expect(ChosenProgramme.among(const []), isNull);
    });

    test(
      'a plan from before the splits brings her days to the new split',
      () async {
        final intake = AppRouter.intakeRepository;
        final saved = intake.read();
        addTearDown(
          () => intake.merge(days: saved.days, weekdays: saved.weekdays),
        );
        for (final (days, family, split) in [
          (2, 'stronger_gym', 3),
          (6, 'stronger_gym_intermediate', 5),
          (7, 'stronger_home', 5),
        ]) {
          await intake.merge(days: days, weekdays: const {});
          ChosenProgramme.family = family;
          final document = jsonEncode(AppSnapshot.capture());
          ChosenProgramme.reset();
          AppSnapshot.restore(document);
          await Future<void>.delayed(Duration.zero);
          expect(
            ChosenProgramme.family,
            startsWith('split_${split}day'),
            reason: '$days days',
          );
          expect(intake.read().days, split, reason: '$family at $days days');
        }
      },
    );

    test('a split she already chose is left as it is', () async {
      final intake = AppRouter.intakeRepository;
      final saved = intake.read();
      addTearDown(
        () => intake.merge(days: saved.days, weekdays: saved.weekdays),
      );
      await intake.merge(days: 4, weekdays: const {});
      ChosenProgramme.family = 'split_5day';
      final document = jsonEncode(AppSnapshot.capture());
      ChosenProgramme.reset();
      AppSnapshot.restore(document);
      await Future<void>.delayed(Duration.zero);
      expect(ChosenProgramme.family, 'split_5day');
      expect(intake.read().days, 4);
    });

    test('survives a restart through the snapshot', () {
      ChosenProgramme.family = 'split_5day';
      final saved = jsonEncode(AppSnapshot.capture());
      ChosenProgramme.reset();
      AppSnapshot.restore(saved);
      expect(ChosenProgramme.family, 'split_5day');

      ChosenProgramme.reset();
      expect(AppSnapshot.capture().containsKey('chosenProgramme'), isFalse);
    });
  });

  group('O05', () {
    Widget view({
      Intake intake = _fourDays,
      ValueChanged<StartingProgram>? onChoose,
      VoidCallback? onStartNow,
      VoidCallback? onBuildOwn,
      ValueChanged<String>? onCustomizeSplit,
      InMemoryIntakeRepository? repository,
      Locale locale = const Locale('en'),
      double textScale = 1.0,
    }) => _host(
      StartingProgramView(
        repository: repository ?? InMemoryIntakeRepository(intake),
        onChoose: onChoose,
        onStartNow: onStartNow,
        onBuildOwn: onBuildOwn,
        onCustomizeSplit: onCustomizeSplit,
      ),
      locale: locale,
      textScale: textScale,
    );

    testWidgets('shows exactly three split cards, in the order of their days', (
      tester,
    ) async {
      _tall(tester);
      await tester.pumpWidget(view());
      await tester.pumpAndSettle();

      final ids = ['split_3day', 'split_4day', 'split_5day'];
      for (final id in ids) {
        expect(find.byKey(ValueKey('program-card-$id')), findsOneWidget);
      }
      expect(
        find.byWidgetPredicate(
          (w) =>
              w.key is ValueKey<String> &&
              (w.key! as ValueKey<String>).value.startsWith(
                'program-card-split',
              ),
        ),
        findsNWidgets(3),
      );
      final tops = [
        for (final id in ids)
          tester.getTopLeft(find.byKey(ValueKey('program-card-$id'))).dy,
      ];
      expect(tops, orderedEquals([...tops]..sort()));

      expect(find.text('3-day split'), findsOneWidget);
      expect(find.text('Upper · Lower · Lower II'), findsOneWidget);
      expect(
        find.text('Upper · Lower · Lower II · Core and cardio'),
        findsOneWidget,
      );
      expect(find.textContaining('Glutes and legs'), findsOneWidget);
      expect(
        find.textContaining(RegExp(r'^\d+ min a session$')),
        findsNWidgets(3),
      );
    });

    testWidgets('the minutes are what a day takes at the length she chose', (
      tester,
    ) async {
      _tall(tester);
      Future<int> minutesOf(int minutes) async {
        await tester.pumpWidget(const SizedBox());
        await tester.pumpWidget(
          view(intake: Intake(days: 3, minutes: minutes)),
        );
        await tester.pumpAndSettle();
        final text = tester
            .widget<Text>(
              find.descendant(
                of: find.byKey(const ValueKey('program-card-split_3day')),
                matching: find.textContaining(RegExp(r'^\d+ min a session$')),
              ),
            )
            .data!;
        return int.parse(text.split(' ').first);
      }

      // From 30 minutes the day is the coach's, whole: the split's own 45 to 60.
      final thirty = await minutesOf(30);
      final sixty = await minutesOf(60);
      expect(thirty, inInclusiveRange(45, 60));
      expect(sixty, thirty);
      // Only a short day is cut.
      final fifteen = await minutesOf(15);
      expect(fifteen, lessThan(thirty));
    });

    testWidgets('the minutes are what a day takes at the length she chose', (
      tester,
    ) async {
      _tall(tester);
      Future<int> minutesOf(int minutes) async {
        await tester.pumpWidget(const SizedBox());
        await tester.pumpWidget(
          view(intake: Intake(days: 3, minutes: minutes)),
        );
        await tester.pumpAndSettle();
        final text = tester
            .widget<Text>(
              find.descendant(
                of: find.byKey(const ValueKey('program-card-split_3day')),
                matching: find.textContaining(RegExp(r'^\d+ min a session$')),
              ),
            )
            .data!;
        return int.parse(text.split(' ').first);
      }

      // From 30 minutes the day is the coach's, whole: the split's own 45 to 60.
      final thirty = await minutesOf(30);
      final sixty = await minutesOf(60);
      expect(thirty, inInclusiveRange(45, 60));
      expect(sixty, thirty);
      // Only a short day is cut.
      final fifteen = await minutesOf(15);
      expect(fifteen, lessThan(thirty));
    });

    testWidgets('tags the split that suits her days, and only that one', (
      tester,
    ) async {
      _tall(tester);
      for (final (days, id) in [
        (3, 'split_3day'),
        (4, 'split_4day'),
        (5, 'split_5day'),
        (7, 'split_5day'),
        (2, 'split_3day'),
      ]) {
        await tester.pumpWidget(view(intake: Intake(days: days)));
        await tester.pumpAndSettle();
        expect(find.text('Recommended for your days'), findsOneWidget);
        expect(
          find.descendant(
            of: find.byKey(ValueKey('program-card-$id')),
            matching: find.text('Recommended for your days'),
          ),
          findsOneWidget,
          reason: '$days days',
        );
      }
    });

    testWidgets('says the tag and the buttons in Egyptian Arabic', (
      tester,
    ) async {
      _tall(tester);
      await tester.pumpWidget(
        view(
          locale: const Locale('ar'),
          onCustomizeSplit: (_) {},
          onBuildOwn: () {},
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('الأنسب لأيامك'), findsOneWidget);
      expect(find.text('اختاري'), findsNWidgets(3));
      expect(find.text('عدّلي'), findsNWidgets(3));
      expect(find.text('سبليت 4 أيام'), findsOneWidget);
      // The days themselves are in Egyptian Arabic too, from the file.
      expect(find.text('علوي · سفلي · سفلي 2'), findsOneWidget);
      expect(find.text('علوي · سفلي · سفلي 2 · كور وكارديو'), findsOneWidget);
      expect(
        find.text('ابدئي من الصفر أو عدّلي واحدة من التلاتة.'),
        findsOneWidget,
      );
    });

    testWidgets('each card has Choose, and Customize only when it is wired', (
      tester,
    ) async {
      _tall(tester);
      await tester.pumpWidget(view());
      await tester.pumpAndSettle();
      expect(find.text('Choose'), findsNWidgets(3));
      expect(find.text('Customize'), findsNothing);

      await tester.pumpWidget(view(onCustomizeSplit: (_) {}));
      await tester.pumpAndSettle();
      expect(find.text('Customize'), findsNWidgets(3));
    });

    testWidgets('Customize hands over the id of the split at her level', (
      tester,
    ) async {
      _tall(tester);
      final customised = <String>[];
      final chosen = <String>[];
      await tester.pumpWidget(
        view(
          intake: const Intake(days: 4, level: TrainingLevel.intermediate),
          onChoose: (p) => chosen.add(p.programId),
          onCustomizeSplit: customised.add,
        ),
      );
      await tester.pumpAndSettle();

      final card = find.byKey(
        const ValueKey('program-card-split_5day_intermediate'),
      );
      await tester.ensureVisible(card);
      await tester.tap(
        find.descendant(of: card, matching: find.text('Customize')),
      );
      await tester.pump();
      expect(customised, ['split_5day_intermediate']);
      expect(chosen, ['split_5day_intermediate']);
    });

    testWidgets('the Build my own workout card is large, last, and fires', (
      tester,
    ) async {
      _tall(tester);
      await tester.pumpWidget(view());
      await tester.pumpAndSettle();
      expect(find.text('Build my own workout'), findsNothing);

      var built = 0;
      await tester.pumpWidget(view(onBuildOwn: () => built++));
      await tester.pumpAndSettle();
      final card = find.byKey(const ValueKey('program-card-build-own'));
      await tester.ensureVisible(card);
      await tester.pumpAndSettle();
      expect(find.text('Build my own workout'), findsOneWidget);
      expect(
        find.text('Start from scratch or edit one of the three.'),
        findsOneWidget,
      );
      expect(tester.getSize(card).height, greaterThanOrEqualTo(72));
      expect(
        tester.getTopLeft(card).dy,
        greaterThan(
          tester
              .getTopLeft(find.byKey(const ValueKey('program-card-split_5day')))
              .dy,
        ),
      );
      await tester.tap(card);
      expect(built, 1);
    });

    for (final locale in const [Locale('en'), Locale('ar')]) {
      testWidgets(
        'holds together at text scale 2.0 in ${locale.languageCode}',
        (tester) async {
          _tall(tester);
          tester.view.physicalSize = const Size(1170, 2532);
          tester.view.devicePixelRatio = 3;
          addTearDown(tester.view.reset);
          await tester.pumpWidget(
            view(
              locale: locale,
              textScale: 2.0,
              onCustomizeSplit: (_) {},
              onBuildOwn: () {},
            ),
          );
          await tester.pumpAndSettle();
          expect(tester.takeException(), isNull);
          final card = find.byKey(const ValueKey('program-card-build-own'));
          await tester.ensureVisible(card);
          await tester.pumpAndSettle();
          expect(tester.takeException(), isNull);
          expect(
            tester
                .getSize(find.byKey(const ValueKey('program-choose')).first)
                .height,
            greaterThanOrEqualTo(48),
          );
        },
      );
    }

    testWidgets('starts the best fit by default', (tester) async {
      _tall(tester);
      final chosen = <String>[];
      var started = 0;
      await tester.pumpWidget(
        view(
          onChoose: (p) => chosen.add(p.programId),
          onStartNow: () => started++,
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.text('Start day 1 now'));
      await tester.pump();
      expect(chosen, ['split_4day']);
      expect(started, 1);
    });

    testWidgets(
      'tapping Choose on another card then Start starts it, and her days follow',
      (tester) async {
        _tall(tester);
        final repository = InMemoryIntakeRepository(_fourDays);
        final chosen = <String>[];
        var started = 0;
        await tester.pumpWidget(
          view(
            repository: repository,
            onChoose: (p) => chosen.add(p.programId),
            onStartNow: () => started++,
          ),
        );
        await tester.pumpAndSettle();

        await tester.tap(
          find.descendant(
            of: find.byKey(const ValueKey('program-card-split_5day')),
            matching: find.text('Choose'),
          ),
        );
        await tester.pumpAndSettle();
        expect(chosen, isEmpty, reason: 'looking is not choosing');
        expect(repository.read().days, 4);

        await tester.tap(find.text('Start day 1 now'));
        await tester.pump();
        expect(chosen, ['split_5day']);
        expect(started, 1);
        expect(repository.read().days, 5, reason: 'the split sets her days');
      },
    );

    testWidgets('a custom week of another size is let go when the days move', (
      tester,
    ) async {
      _tall(tester);
      final repository = InMemoryIntakeRepository(
        const Intake(days: 3, weekdays: {6, 1, 3}),
      );
      await tester.pumpWidget(view(repository: repository));
      await tester.pumpAndSettle();
      await tester.tap(
        find.descendant(
          of: find.byKey(const ValueKey('program-card-split_4day')),
          matching: find.text('Choose'),
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text('Start day 1 now'));
      await tester.pump();
      expect(repository.read().days, 4);
      expect(repository.read().weekdays, isEmpty);

      // Her own weekdays stay when the split already has her count.
      final kept = InMemoryIntakeRepository(
        const Intake(days: 3, weekdays: {6, 1, 3}),
      );
      await tester.pumpWidget(const SizedBox());
      await tester.pumpWidget(view(repository: kept));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Start day 1 now'));
      await tester.pump();
      expect(kept.read().weekdays, {6, 1, 3});
    });

    testWidgets('going on with the suggested split leaves her days alone', (
      tester,
    ) async {
      _tall(tester);
      final repository = InMemoryIntakeRepository(const Intake(days: 6));
      await tester.pumpWidget(view(repository: repository));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Start day 1 now'));
      await tester.pump();
      expect(repository.read().days, 6);
      expect(repository.writes, isEmpty);
    });

    testWidgets('Save keeps the plan she already chose', (tester) async {
      _tall(tester);
      addTearDown(ChosenProgramme.reset);
      ChosenProgramme.family = 'split_5day';
      final chosen = <String>[];
      var saved = 0;
      await tester.pumpWidget(
        _host(
          StartingProgramView(
            repository: InMemoryIntakeRepository(_fourDays),
            onChoose: (p) => chosen.add(p.programId),
            onSaveMyWeek: () => saved++,
            onBuildOwn: () {},
            onCustomizeSplit: (_) {},
          ),
        ),
      );
      await tester.pumpAndSettle();
      // Saving her answers from her profile is not the place to leave for the
      // editor or the builder.
      expect(find.text('Customize'), findsNothing);
      expect(find.text('Build my own workout'), findsNothing);

      await tester.tap(find.byKey(const ValueKey('o05-save-my-week')));
      await tester.pump();
      expect(chosen, ['split_5day']);
      expect(saved, 1);
    });

    testWidgets('shows only what fits when fewer than three do', (
      tester,
    ) async {
      _tall(tester);
      await tester.pumpWidget(
        _host(
          StartingProgramView(
            repository: InMemoryIntakeRepository(_fourDays),
            catalogue: [
              for (final p in StartingProgrammes.catalogue)
                if (p.family != 'split_5day') p,
            ],
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(
        find.byKey(const ValueKey('program-card-split_3day')),
        findsOneWidget,
      );
      expect(
        find.byKey(const ValueKey('program-card-split_4day')),
        findsOneWidget,
      );
      expect(
        find.byKey(const ValueKey('program-card-split_5day')),
        findsNothing,
      );
    });
  });

  group('R02 chooser', () {
    testWidgets('opens the same cards with a way to all programmes', (
      tester,
    ) async {
      final top = topStartingPrograms(_fourDays);
      final chosen = <String>[];
      final customised = <String>[];
      var built = 0;
      var all = 0;
      tester.view.physicalSize = const Size(1170, 3200);
      tester.view.devicePixelRatio = 3;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(
        _host(
          Builder(
            builder: (context) => Scaffold(
              body: Center(
                child: TextButton(
                  onPressed: () => showProgrammeChooser(
                    context,
                    programs: top,
                    intake: _fourDays,
                    current: top.first,
                    onChoose: (p) => chosen.add(p.programId),
                    onCustomize: (p) => customised.add(p.programId),
                    onBuildOwn: () => built++,
                    onSeeAll: () => all++,
                  ),
                  child: const Text('open'),
                ),
              ),
            ),
          ),
        ),
      );
      await tester.tap(find.text('open'));
      await tester.pumpAndSettle();

      expect(find.text('Choose your program'), findsOneWidget);
      for (final id in ['split_3day', 'split_4day', 'split_5day']) {
        expect(find.byKey(ValueKey('program-card-$id')), findsOneWidget);
      }
      expect(find.text('Build my own workout'), findsOneWidget);

      await tester.tap(
        find.descendant(
          of: find.byKey(const ValueKey('program-card-split_5day')),
          matching: find.text('Choose'),
        ),
      );
      await tester.pumpAndSettle();
      expect(chosen, ['split_5day']);
      expect(find.text('Choose your program'), findsNothing);

      await tester.tap(find.text('open'));
      await tester.pumpAndSettle();
      await tester.tap(
        find.descendant(
          of: find.byKey(const ValueKey('program-card-split_3day')),
          matching: find.text('Customize'),
        ),
      );
      await tester.pumpAndSettle();
      expect(customised, ['split_3day']);

      await tester.tap(find.text('open'));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('program-card-build-own')));
      await tester.pumpAndSettle();
      expect(built, 1);

      await tester.tap(find.text('open'));
      await tester.pumpAndSettle();
      await tester.ensureVisible(find.text('See all programs'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('See all programs'));
      await tester.pumpAndSettle();
      expect(all, 1);
    });
  });
}
