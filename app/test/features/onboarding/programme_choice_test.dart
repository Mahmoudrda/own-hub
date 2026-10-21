// O05 and R02 — choosing between the programmes that fit her.
//
// The ranking is the one `selectStartingProgram` always made, now handed back
// whole; the screens show the best three, say why the first is first, and start
// the one she chose.

import 'dart:convert';

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
import 'package:own_hub/theme/app_tokens.dart';

Widget _host(Widget child, {Locale locale = const Locale('en')}) {
  return MaterialApp(
    locale: locale,
    localizationsDelegates: AppL10n.localizationsDelegates,
    supportedLocales: AppL10n.supportedLocales,
    theme: buildTheme(locale),
    home: child,
  );
}

StartingProgram _plan(
  String id,
  TrainingGoal goal, {
  TrainingLevel tier = TrainingLevel.beginner,
  int rank = 1,
}) => StartingProgram(
  programId: id,
  weeks: 8,
  daysPerWeek: 3,
  sessionLength: 15,
  quiet: true,
  equipment: const {},
  goals: {goal},
  adapts: true,
  rank: rank,
  tier: tier,
  family: programmeFamily(id),
);

final _catalogue = [
  _plan('feel_better_home', TrainingGoal.feelBetter),
  _plan('lose_steadily_home', TrainingGoal.loseSteadily),
  _plan('stronger_home', TrainingGoal.stronger),
  _plan(
    'stronger_home_intermediate',
    TrainingGoal.stronger,
    tier: TrainingLevel.intermediate,
  ),
];

const _herAnswers = Intake(
  goal: TrainingGoal.stronger,
  place: TrainingPlace.home,
);

void main() {
  group('rankStartingPrograms', () {
    test('puts her goal first and keeps the catalogue order among equals', () {
      final ranked = rankStartingPrograms(_herAnswers, _catalogue);
      expect(ranked.map((p) => p.programId), [
        'stronger_home',
        'feel_better_home',
        'lose_steadily_home',
        'stronger_home_intermediate',
      ]);
    });

    test('selectStartingProgram is the first of the ranking', () {
      expect(
        selectStartingProgram(_herAnswers, catalogue: _catalogue),
        rankStartingPrograms(_herAnswers, _catalogue).first,
      );
      expect(selectStartingProgram(_herAnswers, catalogue: const []), isNull);
      expect(rankStartingPrograms(_herAnswers, const []), isEmpty);
    });

    test('offers a plan once, however many tiers of it fit', () {
      final top = topStartingPrograms(_herAnswers, catalogue: _catalogue);
      expect(top.map((p) => p.family), [
        'stronger_home',
        'feel_better_home',
        'lose_steadily_home',
      ]);
    });
  });

  group('the programme she chose', () {
    tearDown(ChosenProgramme.reset);

    test('is followed while it still fits, and the best fit otherwise', () {
      final fits = rankStartingPrograms(_herAnswers, _catalogue);
      expect(ChosenProgramme.among(fits)!.programId, 'stronger_home');
      ChosenProgramme.family = 'lose_steadily_home';
      expect(ChosenProgramme.among(fits)!.programId, 'lose_steadily_home');
      ChosenProgramme.family = 'gone_home';
      expect(ChosenProgramme.among(fits)!.programId, 'stronger_home');
      expect(ChosenProgramme.among(const []), isNull);
    });

    test('survives a restart through the snapshot', () {
      ChosenProgramme.family = 'feel_better_home';
      final saved = jsonEncode(AppSnapshot.capture());
      ChosenProgramme.reset();
      AppSnapshot.restore(saved);
      expect(ChosenProgramme.family, 'feel_better_home');

      ChosenProgramme.reset();
      expect(AppSnapshot.capture().containsKey('chosenProgramme'), isFalse);
    });
  });

  group('O05', () {
    Widget view({
      List<StartingProgram>? catalogue,
      ValueChanged<StartingProgram>? onChoose,
      VoidCallback? onStartNow,
      VoidCallback? onBuildOwn,
    }) => _host(
      StartingProgramView(
        repository: InMemoryIntakeRepository(_herAnswers),
        catalogue: catalogue ?? _catalogue,
        onChoose: onChoose,
        onStartNow: onStartNow,
        onBuildOwn: onBuildOwn,
      ),
    );

    testWidgets('shows the three best fits, the first marked and explained', (
      tester,
    ) async {
      await tester.pumpWidget(view());
      await tester.pumpAndSettle();

      for (final id in [
        'stronger_home',
        'feel_better_home',
        'lose_steadily_home',
      ]) {
        expect(find.byKey(ValueKey('program-card-$id')), findsOneWidget);
      }
      expect(
        find.byKey(const ValueKey('program-card-stronger_home_intermediate')),
        findsNothing,
      );
      expect(find.text('Recommended for you'), findsOneWidget);
      final first = find.byKey(const ValueKey('program-card-stronger_home'));
      expect(
        find.descendant(of: first, matching: find.text('Recommended for you')),
        findsOneWidget,
      );
      // Her goal, where she trains and how long a session is.
      expect(
        find.descendant(of: first, matching: find.text('At home')),
        findsOneWidget,
      );
      expect(
        find.descendant(of: first, matching: find.text('15 min a session')),
        findsOneWidget,
      );
    });

    testWidgets('says the pill in Egyptian Arabic', (tester) async {
      await tester.pumpWidget(
        _host(
          StartingProgramView(
            repository: InMemoryIntakeRepository(_herAnswers),
            catalogue: _catalogue,
          ),
          locale: const Locale('ar'),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('الأنسب لاختياراتك'), findsOneWidget);
    });

    testWidgets('starts the first by default', (tester) async {
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
      expect(chosen, ['stronger_home']);
      expect(started, 1);
    });

    testWidgets('tapping the second card then Start starts the second', (
      tester,
    ) async {
      final chosen = <String>[];
      var started = 0;
      await tester.pumpWidget(
        view(
          onChoose: (p) => chosen.add(p.programId),
          onStartNow: () => started++,
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(
        find.byKey(const ValueKey('program-card-feel_better_home')),
      );
      await tester.pumpAndSettle();
      expect(chosen, isEmpty, reason: 'looking is not choosing');

      await tester.tap(find.text('Start day 1 now'));
      await tester.pump();
      expect(chosen, ['feel_better_home']);
      expect(started, 1);
    });

    testWidgets('Save keeps the plan she already chose', (tester) async {
      addTearDown(ChosenProgramme.reset);
      ChosenProgramme.family = 'lose_steadily_home';
      final chosen = <String>[];
      var saved = 0;
      await tester.pumpWidget(
        _host(
          StartingProgramView(
            repository: InMemoryIntakeRepository(_herAnswers),
            catalogue: _catalogue,
            onChoose: (p) => chosen.add(p.programId),
            onSaveMyWeek: () => saved++,
          ),
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const ValueKey('o05-save-my-week')));
      await tester.pump();
      expect(chosen, ['lose_steadily_home']);
      expect(saved, 1);
    });

    testWidgets('shows only what fits when fewer than three do', (
      tester,
    ) async {
      await tester.pumpWidget(view(catalogue: [_catalogue[2], _catalogue[0]]));
      await tester.pumpAndSettle();

      expect(
        find.byKey(const ValueKey('program-card-stronger_home')),
        findsOneWidget,
      );
      expect(
        find.byKey(const ValueKey('program-card-feel_better_home')),
        findsOneWidget,
      );
      expect(
        find.byKey(const ValueKey('program-card-lose_steadily_home')),
        findsNothing,
      );
    });

    testWidgets('offers building her own, and only when it is wired', (
      tester,
    ) async {
      await tester.pumpWidget(view());
      await tester.pumpAndSettle();
      expect(find.text('Build my own workout'), findsNothing);

      var built = 0;
      await tester.pumpWidget(view(onBuildOwn: () => built++));
      await tester.pumpAndSettle();
      await tester.ensureVisible(find.text('Build my own workout'));
      await tester.tap(find.text('Build my own workout'));
      expect(built, 1);
    });
  });

  group('R02 chooser', () {
    testWidgets('opens the same cards with a way to all programmes', (
      tester,
    ) async {
      final top = topStartingPrograms(_herAnswers, catalogue: _catalogue);
      final chosen = <String>[];
      var all = 0;
      tester.view.physicalSize = const Size(1170, 2532);
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
                    intake: _herAnswers,
                    current: top.first,
                    onChoose: (p) => chosen.add(p.programId),
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
      expect(
        find.byKey(const ValueKey('program-card-stronger_home')),
        findsOneWidget,
      );
      expect(
        find.byKey(const ValueKey('program-card-feel_better_home')),
        findsOneWidget,
      );
      expect(
        find.byKey(const ValueKey('program-card-lose_steadily_home')),
        findsOneWidget,
      );

      await tester.ensureVisible(
        find.byKey(const ValueKey('program-card-lose_steadily_home')),
      );
      await tester.pumpAndSettle();
      await tester.tap(
        find.byKey(const ValueKey('program-card-lose_steadily_home')),
      );
      await tester.pumpAndSettle();
      expect(chosen, ['lose_steadily_home']);
      expect(find.text('Choose your program'), findsNothing);

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
