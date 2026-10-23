// P0-CYC-02, P0-CYC-05, P0-CYC-06 and P1-RULE-05 — the three renderings of the
// Y03 route.
//
// Y11 and Y14 are **states of this route, not destinations** (HANDOFF rule 16),
// so they are reached by pumping one widget with different data rather than by
// navigating anywhere. That is the arrangement under test as much as the
// content: a test that had to push a route to reach the severe screen would be
// evidence the rule had been broken.
//
// The sharpest assertion here is the negative one. On a severe day **no workout
// affordance may appear anywhere on the screen, including the Train entry row**,
// and that is checked by looking for every control that could offer one.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:own_hub/features/cycle/domain/cycle_document.dart';
import 'package:own_hub/features/cycle/domain/period_entry.dart';
import 'package:own_hub/features/cycle/domain/today_check_in.dart';
import 'package:own_hub/features/cycle/presentation/cycle_hub_view.dart';
import 'package:own_hub/features/cycle/presentation/cycle_hub_view_model.dart';
import 'package:own_hub/l10n/app_l10n.dart';
import 'package:own_hub/theme/app_tokens.dart';

// March 2027, not the prototype's September 2026.
final DateTime _today = DateTime(2027, 3, 6, 9, 41);

void _phone(WidgetTester tester) {
  tester.view.physicalSize = const Size(1170, 2532);
  tester.view.devicePixelRatio = 3.0;
  addTearDown(tester.view.reset);
}

Widget _host(Widget child, {Locale locale = const Locale('en')}) {
  return MaterialApp(
    locale: locale,
    localizationsDelegates: AppL10n.localizationsDelegates,
    supportedLocales: AppL10n.supportedLocales,
    theme: buildTheme(locale),
    home: child,
  );
}

PeriodEntry _periodStartingOn(DateTime start) {
  final result = PeriodEntry.validate(start: start, today: _today);
  return (result as PeriodValid).entry;
}

CycleDocument _cycle({
  CycleMode mode = CycleMode.datesAndSymptoms,
  bool workoutSuggestions = true,
  bool mealSuggestions = true,
  Set<CycleContextFlag> flags = const <CycleContextFlag>{},
}) {
  return CycleDocument(
    mode: mode,
    contextFlags: flags,
    adaptation: CycleAdaptation(
      workoutSuggestions: workoutSuggestions,
      mealSuggestions: mealSuggestions,
      homeCard: true,
    ),
  );
}

void main() {
  group('P0-CYC-06 / P1-RULE-05 — severe removes the workout entirely', () {
    testWidgets('no workout affordance appears anywhere on the screen', (
      tester,
    ) async {
      _phone(tester);
      await tester.pumpWidget(
        _host(
          CycleHubView(
            cycle: _cycle(),
            // Severe cramps with HIGH energy: nothing else on this check-in
            // would soften anything, so a gentler card appearing could only
            // come from the severe path being mishandled.
            checkIn: const TodayCheckIn(
              energy: Energy.high,
              cramps: Cramps.severe,
            ),
            now: _today,
          ),
        ),
      );
      await tester.pumpAndSettle();

      // The guidance and the route to care are present.
      expect(
        find.text('This needs more than a workout change'),
        findsOneWidget,
      );
      // What to do, said plainly, in place of two buttons that opened
      // nothing ("we do not have that yet").
      expect(
        find.text(
          'If the pain is severe or sudden, see a doctor today. In an '
          'emergency call 123.',
        ),
        findsOneWidget,
      );
      expect(find.text('Find care near you'), findsNothing);

      // And nothing that could start, swap or suggest a session is.
      for (final forbidden in [
        'A gentler option today',
        'View option',
        'Keep mine',
        'Use this option',
        'Keep my workout',
        'Option: gentle mobility',
        'Your planned workout',
        'Full-body strength, 35 min',
      ]) {
        expect(
          find.text(forbidden),
          findsNothing,
          reason:
              '§2.5: severe symptoms REMOVE the workout. Found "$forbidden"',
        );
      }
    });

    testWidgets('no meal-based answer either', (tester) async {
      _phone(tester);
      await tester.pumpWidget(
        _host(
          CycleHubView(
            cycle: _cycle(),
            checkIn: const TodayCheckIn(cramps: Cramps.severe),
            now: _today,
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Y11's note: "never a meal-based answer".
      expect(find.text('Lentil soup and toast'), findsNothing);
    });

    testWidgets('a rest row is offered and is not framed as a failure', (
      tester,
    ) async {
      _phone(tester);
      await tester.pumpWidget(
        _host(
          CycleHubView(
            cycle: _cycle(),
            checkIn: const TodayCheckIn(cramps: Cramps.severe),
            now: _today,
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Rest today'), findsOneWidget);

      // And it does NOT claim the rest is free. `DECISIONS.md` D5a requires a
      // capped WeeklyGoalService.markPlannedRest(date) to make that true, and
      // no such method exists — so the sentence is absent rather than false.
      expect(
        find.text('Marked as planned rest, it costs you nothing'),
        findsNothing,
        reason:
            'OQ-7: a false promise on the severe-symptom screen is the worst '
            'place in the product to have one',
      );
    });

    testWidgets('suppression is not gated by her workout-suggestion switch', (
      tester,
    ) async {
      // The dangerous defect: if suppression travelled through
      // adaptation.workoutSuggestions, turning that switch off would turn
      // suppression off with it.
      _phone(tester);
      await tester.pumpWidget(
        _host(
          CycleHubView(
            cycle: _cycle(workoutSuggestions: false),
            checkIn: const TodayCheckIn(cramps: Cramps.severe),
            now: _today,
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(
        find.text('This needs more than a workout change'),
        findsOneWidget,
      );
    });
  });

  group('P0-CYC-06 — heavy bleeding suppresses exactly as severe cramps do', () {
    // Y04 could not log bleeding until the seven "More to log" strings existed,
    // so this arm of §2.5's gate had never been exercised through the screens.
    // It is the same suppression, reached by the other half of the rule.

    testWidgets('no workout affordance anywhere, the Train row included', (
      tester,
    ) async {
      _phone(tester);
      await tester.pumpWidget(
        _host(
          CycleHubView(
            cycle: _cycle(),
            // High energy, NO cramps at all. Nothing on this check-in could
            // suppress anything except the bleeding.
            checkIn: const TodayCheckIn(
              energy: Energy.high,
              cramps: Cramps.none,
              bleeding: Bleeding.heavy,
            ),
            periods: [_periodStartingOn(DateTime(2027, 3, 5))],
            now: _today,
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(
        find.text('This needs more than a workout change'),
        findsOneWidget,
      );
      // What to do, said plainly, in place of two buttons that opened
      // nothing ("we do not have that yet").
      expect(
        find.text(
          'If the pain is severe or sudden, see a doctor today. In an '
          'emergency call 123.',
        ),
        findsOneWidget,
      );
      expect(find.text('Find care near you'), findsNothing);
      expect(find.text('Rest today'), findsOneWidget);

      for (final forbidden in [
        'A gentler option today',
        'View option',
        'Keep mine',
        'Use this option',
        'Keep my workout',
        'Option: gentle mobility',
        'Your planned workout',
        'Full-body strength, 35 min',
        // The Train ENTRY ROW — the row on this screen that opens a session —
        // and the meal-based answer, both named by P0-CYC-06 and Y11's note.
        // Not the word "Train": that is the bottom navigation destination,
        // which is on every screen in the app and is not an offer of a
        // workout today.
        'Start workout',
        'Lentil soup and toast',
      ]) {
        expect(
          find.text(forbidden),
          findsNothing,
          reason:
              '§2.5: heavy bleeding REMOVES the workout. Found "$forbidden"',
        );
      }
    });

    testWidgets('the pill names the bleeding, not cramps she never logged', (
      tester,
    ) async {
      _phone(tester);
      await tester.pumpWidget(
        _host(
          CycleHubView(
            cycle: _cycle(),
            checkIn: const TodayCheckIn(bleeding: Bleeding.heavy),
            now: _today,
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Bleeding: Heavy'), findsOneWidget);
      expect(
        find.text('Severe cramps noted'),
        findsNothing,
        reason:
            'she logged no cramps — stating the mockup\'s reason as hers is '
            'PHASE1-FIXES.md #13',
      );
    });

    testWidgets('severe cramps still say severe cramps', (tester) async {
      _phone(tester);
      await tester.pumpWidget(
        _host(
          CycleHubView(
            cycle: _cycle(),
            checkIn: const TodayCheckIn(cramps: Cramps.severe),
            now: _today,
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Severe cramps noted'), findsOneWidget);
      expect(find.text('Bleeding: Heavy'), findsNothing);
    });

    testWidgets('and it is not gated by her workout-suggestion switch', (
      tester,
    ) async {
      _phone(tester);
      await tester.pumpWidget(
        _host(
          CycleHubView(
            cycle: _cycle(workoutSuggestions: false, mealSuggestions: true),
            checkIn: const TodayCheckIn(bleeding: Bleeding.heavy),
            now: _today,
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(
        find.text('This needs more than a workout change'),
        findsOneWidget,
      );
      expect(find.text('Lentil soup and toast'), findsNothing);
    });
  });

  group('the period day is true on every day, not only on day 2', () {
    testWidgets('day 4 says day 4', (tester) async {
      // The fixed `periodDay2` rendered a bare "4" here rather than lie. The
      // placeholder form makes the sentence true, and this fixture is the day
      // the mockup's constant cannot pass.
      _phone(tester);
      await tester.pumpWidget(
        _host(
          CycleHubView(
            cycle: _cycle(),
            periods: [_periodStartingOn(DateTime(2027, 3, 5))],
            now: DateTime(2027, 3, 8, 9, 41),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Period day 4'), findsOneWidget);
      expect(find.text('Period day 2'), findsNothing);
      expect(
        find.text('4'),
        findsNothing,
        reason: 'the number alone is not a sentence',
      );
    });

    testWidgets('and the severe rendering counts the same way', (tester) async {
      _phone(tester);
      await tester.pumpWidget(
        _host(
          CycleHubView(
            cycle: _cycle(),
            checkIn: const TodayCheckIn(cramps: Cramps.severe),
            periods: [_periodStartingOn(DateTime(2027, 3, 5))],
            now: DateTime(2027, 3, 9, 9, 41),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Period day 5'), findsOneWidget);
    });
  });

  group('P0-CYC-02 — symptom-only mode', () {
    testWidgets('no calendar tab, no estimate, no phase name', (tester) async {
      _phone(tester);
      await tester.pumpWidget(
        _host(
          CycleHubView(
            cycle: _cycle(mode: CycleMode.symptomsOnly),
            now: _today,
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Your check-in guides today'), findsOneWidget);
      expect(
        find.text('Calendar'),
        findsNothing,
        reason: 'Y14 has no calendar tab',
      );
      expect(find.text('Period day 2'), findsNothing);
    });

    testWidgets('her planned workout is shown unchanged', (tester) async {
      _phone(tester);
      await tester.pumpWidget(
        _host(
          CycleHubView(
            cycle: _cycle(mode: CycleMode.symptomsOnly),
            now: _today,
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Your planned workout'), findsOneWidget);
      expect(
        find.text('Nothing changes until you tell us how you feel.'),
        findsOneWidget,
      );
    });
  });

  group('P0-CYC-05 — a logged symptom changes the suggestion', () {
    testWidgets('a qualifying symptom offers the gentler card', (tester) async {
      _phone(tester);
      await tester.pumpWidget(
        _host(
          CycleHubView(
            cycle: _cycle(),
            checkIn: const TodayCheckIn(
              energy: Energy.low,
              cramps: Cramps.mild,
            ),
            now: _today,
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('A gentler option today'), findsOneWidget);
      expect(find.text('View option'), findsOneWidget);
      expect(find.text('Keep mine'), findsOneWidget);

      // Labelled as the app's, never as the coach's — G2 publishes no
      // workout.easierOption, so no coach has approved anything (OQ-4).
      expect(find.text('App suggestion'), findsOneWidget);
    });

    testWidgets('a date alone never offers one', (tester) async {
      // P1-RULE-04: high energy, no cramps, and she is on day 2 of a period.
      // The period is real and the card must still be absent.
      _phone(tester);
      await tester.pumpWidget(
        _host(
          CycleHubView(
            cycle: _cycle(),
            checkIn: const TodayCheckIn(
              energy: Energy.high,
              cramps: Cramps.none,
            ),
            periods: [_periodStartingOn(DateTime(2027, 3, 5))],
            now: _today,
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(
        find.text('A gentler option today'),
        findsNothing,
        reason: 'a date is not an input to any suggestion',
      );
      // The period day is still stated as a FACT — that is allowed, and is the
      // distinction the rule draws. It is day 2, so the fixed string is true.
      expect(find.text('Period day 2'), findsOneWidget);
    });

    testWidgets('the gentler card respects her adaptation switch', (
      tester,
    ) async {
      _phone(tester);
      await tester.pumpWidget(
        _host(
          CycleHubView(
            cycle: _cycle(workoutSuggestions: false),
            checkIn: const TodayCheckIn(
              energy: Energy.low,
              cramps: Cramps.mild,
            ),
            now: _today,
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('A gentler option today'), findsNothing);
    });

    testWidgets('nothing logged is never a suggestion', (tester) async {
      _phone(tester);
      await tester.pumpWidget(
        _host(CycleHubView(cycle: _cycle(), now: _today)),
      );
      await tester.pumpAndSettle();

      expect(find.text('How are you feeling?'), findsOneWidget);
      expect(find.text('A gentler option today'), findsNothing);
    });
  });

  group('the branch is chosen from the data, not navigated to', () {
    test('the view model picks the branch', () {
      const viewModel = CycleHubViewModel();

      expect(
        viewModel.build(cycle: null, today: _today).branch,
        HubBranch.notSetUp,
      );
      expect(
        viewModel.build(cycle: _cycle(), today: _today).branch,
        HubBranch.today,
      );
      expect(
        viewModel
            .build(
              cycle: _cycle(mode: CycleMode.symptomsOnly),
              today: _today,
            )
            .branch,
        HubBranch.symptomsOnly,
      );
      expect(
        viewModel
            .build(
              cycle: _cycle(),
              checkIn: const TodayCheckIn(cramps: Cramps.severe),
              today: _today,
            )
            .branch,
        HubBranch.severe,
      );
    });

    test('severe wins over symptom-only', () {
      // A woman in symptom-only mode who logs severe cramps must still get the
      // medical guidance. If the branch order were reversed she would get Y14
      // and no route to care.
      const viewModel = CycleHubViewModel();

      final snapshot = viewModel.build(
        cycle: _cycle(mode: CycleMode.symptomsOnly),
        checkIn: const TodayCheckIn(bleeding: Bleeding.heavy),
        today: _today,
      );

      expect(snapshot.branch, HubBranch.severe);
      expect(snapshot.suppressesWorkout, isTrue);
    });

    test('symptom-only never computes a period day', () {
      const viewModel = CycleHubViewModel();

      final snapshot = viewModel.build(
        cycle: _cycle(mode: CycleMode.symptomsOnly),
        periods: [_periodStartingOn(DateTime(2027, 3, 5))],
        today: _today,
      );

      expect(
        snapshot.periodDay,
        isNull,
        reason: 'no dates in symptom-only mode, even when periods exist',
      );
      expect(snapshot.showEstimates, isFalse);
      expect(snapshot.showCalendarTab, isFalse);
    });

    test('the period day is counted, not assumed', () {
      const viewModel = CycleHubViewModel();

      // Day 2 of a period that started on the 5th, read on the 6th.
      expect(
        viewModel
            .build(
              cycle: _cycle(),
              periods: [_periodStartingOn(DateTime(2027, 3, 5))],
              today: _today,
            )
            .periodDay,
        2,
      );

      // And day 4 two days later — a constant could not do this.
      expect(
        viewModel
            .build(
              cycle: _cycle(),
              periods: [_periodStartingOn(DateTime(2027, 3, 5))],
              today: DateTime(2027, 3, 8),
            )
            .periodDay,
        4,
      );
    });
  });
}
