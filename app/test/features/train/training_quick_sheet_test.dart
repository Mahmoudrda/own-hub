// "Your training": the quick sheet that changes split, level and goal.
//
// It writes nothing itself. What is worth testing is that the chips open on
// her answers, that Apply hands over exactly what she chose, that the preview
// names the split she would get, that Place is gone, and that it holds up in
// Arabic at the largest text size.

import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:own_hub/app_state/app_changes.dart';
import 'package:own_hub/app_state/chosen_programme.dart';
import 'package:own_hub/app_state/workout_library_state.dart';
import 'package:own_hub/features/onboarding/domain/intake.dart';
import 'package:own_hub/features/onboarding/domain/intake_repository.dart';
import 'package:own_hub/features/train/domain/viewed_tier.dart';
import 'package:own_hub/features/onboarding/domain/starting_program.dart';
import 'package:own_hub/features/train/presentation/training_quick_sheet.dart';
import 'package:own_hub/l10n/app_l10n.dart';
import 'package:own_hub/l10n/app_l10n_ar.dart';
import 'package:own_hub/l10n/app_l10n_en.dart';
import 'package:own_hub/theme/app_tokens.dart';
import 'package:own_hub/ui/app_chip_row.dart';

Widget _host(
  Widget child, {
  Locale locale = const Locale('en'),
  double textScale = 1.0,
}) => MaterialApp(
  locale: locale,
  localizationsDelegates: AppL10n.localizationsDelegates,
  supportedLocales: AppL10n.supportedLocales,
  theme: buildTheme(locale),
  home: MediaQuery(
    data: MediaQueryData(
      size: const Size(390, 844),
      textScaler: TextScaler.linear(textScale),
    ),
    child: Scaffold(
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: child,
      ),
    ),
  ),
);

({int days, TrainingGoal goal, TrainingLevel level})? _applied;
int _closed = 0;

TrainingQuickSheet _sheet(Intake current) => TrainingQuickSheet(
  current: current,
  onApplySplit: (days, goal, level) =>
      _applied = (days: days, goal: goal, level: level),
  onClose: () => _closed++,
);

Set<int> _selected(WidgetTester tester, String key) =>
    tester.widget<AppChipRow>(find.byKey(ValueKey(key))).selected;

void main() {
  setUpAll(() {
    StartingProgrammes.adopt(
      File('assets/content/starting_programmes.json').readAsStringSync(),
    );
  });
  tearDownAll(StartingProgrammes.reset);
  setUp(() {
    _applied = null;
    _closed = 0;
  });

  testWidgets('three rows of chips open on her answers', (tester) async {
    await tester.pumpWidget(
      _host(
        _sheet(
          const Intake(
            days: 4,
            goal: TrainingGoal.loseSteadily,
            level: TrainingLevel.intermediate,
          ),
        ),
      ),
    );

    expect(find.text('Your training'), findsOneWidget);
    for (final label in [
      'Split',
      '3 days',
      '4 days',
      '5 days',
      'Get stronger',
      'Build muscle',
      'Feel good and move',
      'Lose steadily',
      'Get back into it',
      'Beginner',
      'Intermediate',
      'Advanced',
    ]) {
      expect(find.text(label), findsOneWidget, reason: label);
    }
    expect(_selected(tester, 'quick-split'), {1});
    // Stronger, Build muscle, Feel good, Lose steadily, Back into it.
    expect(_selected(tester, 'quick-goal'), {3});
    expect(_selected(tester, 'quick-level'), {1});
  });

  testWidgets('Place is not asked any more, and neither is a muscle fallback', (
    tester,
  ) async {
    await tester.pumpWidget(_host(_sheet(const Intake())));

    expect(find.byKey(const ValueKey('quick-place')), findsNothing);
    expect(find.text('Where you train'), findsNothing);
    expect(find.text('Gym'), findsNothing);
    expect(find.text('Both'), findsNothing);

    await tester.tap(find.text('Build muscle'));
    await tester.pump();
    expect(find.textContaining('Build muscle needs a gym'), findsNothing);
    expect(
      find.textContaining('Your plan will be 3-day split'),
      findsOneWidget,
    );
  });

  testWidgets('a week of another size opens on the nearest split', (
    tester,
  ) async {
    for (final (days, chip) in [
      (2, 0),
      (3, 0),
      (4, 1),
      (5, 2),
      (6, 2),
      (7, 2),
    ]) {
      await tester.pumpWidget(const SizedBox());
      await tester.pumpWidget(_host(_sheet(Intake(days: days))));
      expect(_selected(tester, 'quick-split'), {chip}, reason: '$days days');
      expect(find.text('Same plan as now.'), findsOneWidget);
    }
  });

  testWidgets('nothing changed: the preview says so and Apply waits', (
    tester,
  ) async {
    await tester.pumpWidget(_host(_sheet(const Intake())));

    expect(find.text('Same plan as now.'), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('quick-apply')));
    await tester.pump();
    expect(_applied, isNull);
    expect(_closed, 0);
  });

  testWidgets('Apply hands over exactly what she chose, then closes', (
    tester,
  ) async {
    await tester.pumpWidget(_host(_sheet(const Intake())));

    await tester.tap(find.text('5 days'));
    await tester.pump();
    await tester.tap(find.text('Build muscle'));
    await tester.pump();
    await tester.tap(find.text('Advanced'));
    await tester.pump();

    expect(
      find.textContaining('Your plan will be 5-day split · '),
      findsOneWidget,
    );
    expect(find.textContaining('· Advanced.'), findsOneWidget);

    await tester.tap(find.byKey(const ValueKey('quick-apply')));
    await tester.pump();

    expect(_applied, isNotNull);
    expect(_applied!.days, 5);
    expect(_applied!.goal, TrainingGoal.buildMuscle);
    expect(_applied!.level, TrainingLevel.advanced);
    expect(_closed, 1);
  });

  testWidgets('the older place callback still hears goal and level', (
    tester,
  ) async {
    ({TrainingPlace place, TrainingGoal goal, TrainingLevel level})? heard;
    await tester.pumpWidget(
      _host(
        TrainingQuickSheet(
          current: const Intake(place: TrainingPlace.ladiesGym),
          onApply: (place, goal, level) =>
              heard = (place: place, goal: goal, level: level),
        ),
      ),
    );
    await tester.tap(find.text('Intermediate'));
    await tester.pump();
    await tester.tap(find.byKey(const ValueKey('quick-apply')));
    await tester.pump();
    expect(heard!.place, TrainingPlace.ladiesGym);
    expect(heard!.level, TrainingLevel.intermediate);
  });

  testWidgets('Cancel closes without applying', (tester) async {
    await tester.pumpWidget(_host(_sheet(const Intake())));

    await tester.tap(find.text('4 days'));
    await tester.pump();
    await tester.tap(find.byKey(const ValueKey('quick-cancel')));
    await tester.pump();

    expect(_applied, isNull);
    expect(_closed, 1);
  });

  testWidgets('every goal can be chosen', (tester) async {
    await tester.pumpWidget(_host(_sheet(const Intake())));
    expect(TrainingQuickSheet.goalOrder.toSet(), TrainingGoal.values.toSet());

    final labels = {
      TrainingGoal.stronger: 'Get stronger',
      TrainingGoal.buildMuscle: 'Build muscle',
      TrainingGoal.feelBetter: 'Feel good and move',
      TrainingGoal.loseSteadily: 'Lose steadily',
      TrainingGoal.backIntoIt: 'Get back into it',
    };
    for (final goal in TrainingGoal.values) {
      if (goal == TrainingGoal.stronger) continue;
      await tester.tap(find.text(labels[goal]!));
      await tester.pump();
      await tester.tap(find.byKey(const ValueKey('quick-apply')));
      await tester.pump();
      expect(_applied!.goal, goal);
      _applied = null;
    }
  });

  testWidgets('a tap target is never under 48 high', (tester) async {
    await tester.pumpWidget(_host(_sheet(const Intake())));

    for (final chip in find.byType(AppChip).evaluate()) {
      expect(tester.getSize(find.byWidget(chip.widget)).height, 48);
    }
    expect(
      tester.getSize(find.byKey(const ValueKey('quick-apply'))).height,
      greaterThanOrEqualTo(48),
    );
  });

  for (final scale in [1.0, 2.0]) {
    testWidgets('Arabic, right to left, text scale $scale', (tester) async {
      await tester.pumpWidget(
        _host(
          _sheet(const Intake()),
          locale: const Locale('ar'),
          textScale: scale,
        ),
      );
      await tester.pumpAndSettle();

      expect(
        Directionality.of(tester.element(find.byType(TrainingQuickSheet))),
        TextDirection.rtl,
      );
      expect(find.text('التقسيمة'), findsOneWidget);
      expect(find.text('3 أيام'), findsOneWidget);
      expect(find.text('4 أيام'), findsOneWidget);
      expect(find.text('5 أيام'), findsOneWidget);
      expect(find.text('ابني عضلاتك'), findsOneWidget);
      expect(find.text('نفس خطتك الحالية.'), findsOneWidget);

      await tester.tap(find.text('4 أيام'));
      await tester.pump();
      expect(find.textContaining('خطتك هتبقى سبليت 4 أيام'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('English at text scale $scale does not overflow', (
      tester,
    ) async {
      await tester.pumpWidget(_host(_sheet(const Intake()), textScale: scale));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Advanced'));
      await tester.pump();

      expect(tester.takeException(), isNull);
    });
  }

  test('the Home line reads Split, days and level', () {
    final en = AppL10nEn();
    expect(
      trainingSummaryLine(
        en,
        const Intake(days: 4, level: TrainingLevel.intermediate),
      ),
      'Split · 4 days · Intermediate',
    );
    expect(
      trainingSummaryLine(en, const Intake()),
      'Split · 3 days · Beginner',
    );
    expect(
      trainingSummaryLine(
        en,
        const Intake(days: 7, level: TrainingLevel.advanced),
      ),
      'Split · 5 days · Advanced',
    );
    expect(
      trainingSummaryLine(en, const Intake(days: 2)),
      'Split · 3 days · Beginner',
    );
    final ar = AppL10nAr();
    expect(
      trainingSummaryLine(ar, const Intake(days: 5)),
      'التقسيمة · 5 أيام · مبتدئة',
    );
  });

  testWidgets('the sheet opens over a screen and Apply closes it', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        localizationsDelegates: AppL10n.localizationsDelegates,
        supportedLocales: AppL10n.supportedLocales,
        theme: buildTheme(const Locale('en')),
        home: Builder(
          builder: (context) => Scaffold(
            body: TextButton(
              onPressed: () => showTrainingQuickSheet(
                context,
                current: const Intake(),
                onApplySplit: (days, goal, level) =>
                    _applied = (days: days, goal: goal, level: level),
              ),
              child: const Text('open'),
            ),
          ),
        ),
      ),
    );

    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
    expect(find.text('Your training'), findsOneWidget);

    // The sheet scrolls inside the short test window.
    await tester.ensureVisible(find.text('Intermediate'));
    await tester.tap(find.text('Intermediate'));
    await tester.pump();
    await tester.ensureVisible(find.byKey(const ValueKey('quick-apply')));
    await tester.pump();
    await tester.tap(find.byKey(const ValueKey('quick-apply')));
    await tester.pumpAndSettle();

    expect(_applied!.level, TrainingLevel.intermediate);
    expect(find.text('Your training'), findsNothing);
  });

  group('applyTrainingChoice', () {
    tearDown(() {
      ChosenProgramme.reset();
      ViewedTier.clear();
      WorkoutLibraryState.instance
        ..openedSlot = null
        ..chosenRowId = null;
    });

    test('merges days, goal and level and lets go of the old plan', () async {
      final repository = InMemoryIntakeRepository(const Intake(days: 3));
      ChosenProgramme.family = 'split_3day';
      ViewedTier.show(TrainingLevel.advanced);
      WorkoutLibraryState.instance
        ..openedSlot = 2
        ..chosenRowId = 'library:old/a';
      var bumped = 0;
      void listener() => bumped++;
      AppChanges.instance.addListener(listener);

      await applyTrainingChoice(
        repository,
        days: 5,
        goal: TrainingGoal.buildMuscle,
        level: TrainingLevel.intermediate,
      );
      AppChanges.instance.removeListener(listener);

      final intake = repository.read();
      expect(intake.days, 5);
      expect(intake.goal, TrainingGoal.buildMuscle);
      expect(intake.level, TrainingLevel.intermediate);
      expect(repository.writes.last, {'goal', 'level', 'days', 'weekdays'});
      expect(ViewedTier.notifier.value, isNull);
      expect(ChosenProgramme.family, isNull);
      expect(WorkoutLibraryState.instance.openedSlot, isNull);
      expect(WorkoutLibraryState.instance.chosenRowId, isNull);
      expect(bumped, greaterThan(0));
      // Home now follows the 5 day split at her level. Without letting go of
      // the plan she had picked, the 3 day split would still have won.
      final fits = rankStartingPrograms(
        intake,
        null,
        tier: ViewedTier.of(intake),
      );
      expect(ChosenProgramme.among(fits)!.programId, 'split_5day_intermediate');
      ChosenProgramme.family = 'split_3day';
      expect(ChosenProgramme.among(fits)!.family, 'split_3day');
    });

    test('the same days leave her custom weekdays alone', () async {
      final repository = InMemoryIntakeRepository(
        const Intake(days: 3, weekdays: {6, 1, 3}),
      );
      await applyTrainingChoice(
        repository,
        days: 3,
        goal: TrainingGoal.stronger,
        level: TrainingLevel.advanced,
      );
      expect(repository.read().weekdays, {6, 1, 3});
      expect(repository.writes.last, {'goal', 'level'});
    });

    test('new days let go of weekdays that no longer match', () async {
      final repository = InMemoryIntakeRepository(
        const Intake(days: 3, weekdays: {6, 1, 3}),
      );
      await applyTrainingChoice(
        repository,
        days: 4,
        goal: TrainingGoal.stronger,
        level: TrainingLevel.beginner,
      );
      expect(repository.read().days, 4);
      expect(repository.read().weekdays, isEmpty);
    });
  });
}
