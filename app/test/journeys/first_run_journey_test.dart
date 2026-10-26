// The first sixty seconds, walked in the real app.
//
// The defect this guards is the worst one the product had: on a fresh install
// the first screen was not hers. `AppRouter.todayRepository` was built with no
// argument and the no-argument constructor handed back `defaultDay()` — the
// prototype's Tuesday, frozen at 15 September 2026, with a 32 minute walk she
// never took, "Week 3 of 8" of a programme called "Legs and glutes", one of
// three sessions already ticked, and a breakfast of ful and baladi logged at
// 08:40. One tap away, Eat said "Day 1, no plates yet".
//
// Two more failures followed from that one word. `T06`, Home on day one, is a
// branch of `T01` taken when `arc.hasAnyLog` is false, and the seed set it
// true — so the product's own first screen had never rendered in the running
// app. And `T07`, her first week, had its only door on that branch, so the
// self-guided tour was unreachable before her first log and would have
// vanished for ever at it.
//
// These tests boot the real app with no stored snapshot, which is exactly what
// an install is. The flags are the first release's: Community dark, so her arc
// is the three steps this build can actually offer.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:own_hub/domain/flags/feature_flags.dart';
import 'package:own_hub/features/today/domain/today_day.dart';
import 'package:own_hub/features/today/domain/today_repository.dart';
import 'package:own_hub/features/today/presentation/today_cards.dart';
import 'package:own_hub/ui/hand/hand.dart' show HandPressable;
import 'package:own_hub/l10n/app_l10n.dart';
import 'package:own_hub/main.dart';
import 'package:own_hub/routing/app_router.dart';
import 'package:own_hub/ui/app_avatar.dart';
import 'package:own_hub/ui/app_list_item.dart';

void _phone(WidgetTester tester) {
  tester.view.physicalSize = const Size(1170, 2532);
  tester.view.devicePixelRatio = 3.0;
  addTearDown(tester.view.reset);
}

/// Opens the app the way a woman who has just installed it does: no snapshot
/// on the phone, so nothing is restored and the repository is what she gets.
Future<void> _boot(WidgetTester tester) async {
  await tester.pumpWidget(OwnHubApp(key: UniqueKey()));
  await tester.pumpAndSettle();
}

NavigatorState _nav(WidgetTester tester) =>
    tester.state<NavigatorState>(find.byType(Navigator).first);

/// The subtitle of one named row, which is where the arc is counted.
Finder _rowSubtitle(String title, String subtitle) => find.descendant(
  of: find.widgetWithText(AppListItem, title),
  matching: find.text(subtitle),
);

void main() {
  final savedFlags = AppRouter.featureFlags;

  setUp(() {
    // The first release, stated rather than inherited: Today, Train, Eat,
    // Progress, Cycle and the privacy centre, with no account gate. Community
    // is dark, which is why her first week is three steps and not five.
    AppRouter.featureFlags = FeatureFlags.allOff.with_({
      Feature.today: true,
      Feature.firstWeek: true,
      Feature.quietWeek: true,
      Feature.tiers: true,
      Feature.lockScreenNudge: true,
      Feature.train: true,
      Feature.recordFromMemory: true,
      Feature.program: true,
      Feature.exerciseVideo: true,
      Feature.exerciseSwap: true,
      Feature.followAlong: true,
      Feature.workoutLibrary: true,
      Feature.trainingReminders: true,
      Feature.eat: true,
      Feature.recipes: true,
      Feature.weekPlan: true,
      Feature.groceryList: true,
      Feature.progress: true,
      Feature.milestones: true,
      Feature.personalBests: true,
      Feature.bodyPrivately: true,
      Feature.shareCard: true,
      Feature.cycle: true,
      Feature.cycleMeals: true,
      Feature.cycleCalendar: true,
      Feature.cyclePatterns: true,
      Feature.privacyCentre: true,
    });
    // The repository is a process-wide singleton, so another journey's meal
    // would otherwise be "her" history here. `reset()` is day one now, for the
    // same reason the constructor is.
    AppRouter.todayRepository.reset();
    // She has been through the four setup questions, so the first-run stack
    // opens Home alone and these tests are about Home. The walk itself is
    // covered where it lives; what is measured here is the screen underneath
    // it, which is the screen she comes back to every day after.
    AppRouter.intakeRepository.markSetupDone();
  });

  tearDown(() {
    AppRouter.todayRepository.reset();
    AppRouter.intakeRepository.reset();
    AppRouter.featureFlags = savedFlags;
  });

  group('a fresh install opens on HER day one', () {
    test('the repository is born on day one, dated today', () {
      final repo = InMemoryTodayRepository();

      expect(repo.day.state, DayState.dayOne);
      expect(repo.day.isDayOne, isTrue);
      expect(repo.day.arc.hasAnyLog, isFalse);
      expect(repo.day.arc.completed, isEmpty);

      // Nothing of the prototype's.
      expect(repo.day.week.sessionsLogged, 0);
      expect(repo.day.walkToCount, isFalse);
      expect(repo.day.walkMinutes, isNull);
      expect(repo.day.mealLoggedAt, isNull);
      expect(repo.day.plates, isEmpty);
      expect(repo.day.programWeek, isNull);
      expect(repo.day.programTotalWeeks, isNull);

      // Today's real date, not the frozen 15 September 2026.
      final now = DateTime.now();
      expect(repo.day.date.year, now.year);
      expect(repo.day.date.month, now.month);
      expect(repo.day.date.day, now.day);
    });

    test('the prototype day is still available, by name', () {
      // It is what the screenshots and a dozen widget tests are drawn against.
      // The fix was to stop it being the default, not to delete it.
      final demo = InMemoryTodayRepository(
        day: InMemoryTodayRepository.defaultDay(),
      );
      expect(demo.day.programWeek, 3);
      expect(demo.day.walkMinutes, 32);
      expect(demo.day.arc.hasAnyLog, isTrue);
    });

    testWidgets("Home shows none of another woman's week", (tester) async {
      _phone(tester);
      await _boot(tester);

      for (final line in const [
        'Walk this morning · 32 min',
        'Count it',
        'Week 3 of 8',
        'This week, 1 of 3',
        'Legs and glutes',
        'Breakfast, your usual',
        'Ful and baladi',
        'Eggs and tea',
        'I already did it',
      ]) {
        expect(
          find.text(line),
          findsNothing,
          reason: '"$line" is the prototype\'s, not hers',
        );
      }
    });

    testWidgets('and the day it names is the day she opened it', (
      tester,
    ) async {
      _phone(tester);
      await _boot(tester);

      final l10n = await AppL10n.delegate.load(const Locale('en'));
      expect(find.text(weekdayLabel(l10n, DateTime.now())), findsOneWidget);
      // 15 September 2026 was a Tuesday, and every install was told so.
      if (DateTime.now().weekday != DateTime.tuesday) {
        expect(find.text('Tuesday'), findsNothing);
      }
    });
  });

  group('T06 — the day-one Home finally renders', () {
    testWidgets('it is the first screen a new woman sees', (tester) async {
      _phone(tester);
      await _boot(tester);

      // Its own masthead, its cover, and the one thing to do.
      expect(find.text('Day 1'), findsOneWidget);
      expect(find.text('Your training, week by week'), findsOneWidget);
      expect(find.text('Start day 1'), findsOneWidget);

      // Rule 17: the empty state says what will appear and why it is empty.
      expect(find.text('Nothing added yet'), findsOneWidget);
      expect(find.textContaining('will sit here'), findsOneWidget);

      // The weekly rule, said once, before she can fail it, and stated
      // without a number because the number is hers.
      expect(
        find.text(
          'Hit your goal and the week counts. If you miss a week, a rest week you\'ve earned covers it.',
        ),
        findsOneWidget,
      );
      expect(find.textContaining('Three sessions'), findsNothing);

      // And no programme she never chose.
      expect(find.text('Beginner foundations'), findsNothing);
      expect(find.text('Legs and glutes'), findsNothing);
    });

    testWidgets('her first week is one tap from it, and counted', (
      tester,
    ) async {
      _phone(tester);
      await _boot(tester);

      expect(find.text('Your first week'), findsOneWidget);
      expect(_rowSubtitle('Your first week', '0 of 3'), findsOneWidget);

      // Below her week's line and "Start day 1" now, so it may sit under the
      // fold on a small phone: scrolled to, as she would.
      await tester.ensureVisible(find.text('Your first week'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Your first week'));
      await tester.pumpAndSettle();

      expect(find.text('Finish one set'), findsOneWidget);
      expect(find.text('Add one meal you ate'), findsOneWidget);
      expect(find.text('Finish one session'), findsOneWidget);
    });
  });

  group('T07 keeps a door on the ordinary Home', () {
    testWidgets('the row survives her first log, and still opens T07', (
      tester,
    ) async {
      _phone(tester);
      await _boot(tester);

      // One log of any kind ends the day-one branch for ever. Until now that
      // took the only Home entry to T07 with it.
      AppRouter.todayRepository.recordMeal(at: DateTime.now());
      await tester.pumpAndSettle();

      expect(
        find.text('Nothing added yet'),
        findsNothing,
        reason: 'one log leaves the day-one branch permanently',
      );

      // One line in the week block now, with its count (§15): one of the
      // three steps is done, counted off the same list T07 draws.
      expect(find.text('Your first week: 1 of 3 steps'), findsOneWidget);

      // The line is only a count now (Home keeps to five controls); the door
      // to T07 is the row on the week screen the strip opens.
      expect(find.byKey(const ValueKey('today-first-week')), findsOneWidget);
      final strip = find.byKey(const ValueKey('today-week-strip'));
      await tester.ensureVisible(strip);
      await tester.pumpAndSettle();
      await tester.tap(strip);
      await tester.pumpAndSettle();
      final more = find.byKey(const ValueKey('you-see-more'));
      await tester.ensureVisible(more);
      await tester.pumpAndSettle();
      await tester.tap(more);
      await tester.pumpAndSettle();
      final door = find.text('Your first week');
      await tester.ensureVisible(door);
      await tester.pumpAndSettle();
      await tester.tap(door);
      await tester.pumpAndSettle();
      expect(find.text('Finish one set'), findsOneWidget);
    });

    testWidgets('it goes of its own accord when the arc is finished', (
      tester,
    ) async {
      _phone(tester);
      await _boot(tester);

      // A meal first, because that is what takes her off the day-one branch
      // and onto the ordinary Home this row now lives on.
      AppRouter.todayRepository.recordMeal(at: DateTime.now());
      for (final step in offeredFirstWeekSteps()) {
        await AppRouter.todayRepository.completeStep(step);
      }
      await tester.pumpAndSettle();

      expect(
        find.text('Your first week'),
        findsNothing,
        reason: 'the tour is over, so the row takes itself off Home',
      );
    });
  });

  group('the two doors that were invisible', () {
    for (final scale in [1.0, 2.0]) {
      testWidgets('the week block says it opens something'
          '${scale == 1.0 ? '' : ' (text scale $scale)'}', (tester) async {
        _phone(tester);
        tester.platformDispatcher.textScaleFactorTestValue = scale;
        addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
        await _boot(tester);
        AppRouter.todayRepository.recordMeal(at: DateTime.now());
        await tester.pumpAndSettle();

        // A 358×159 point paragraph with no chevron, no card and no underline
        // was the only door to Progress, personal bests, milestones, body, the
        // rest-week explainer and the tier-slip explainer.
        // The strip is one tap target (a HandPressable) with the one week
        // on Home, not a paragraph with no door.
        final strip = find.byKey(const ValueKey('today-week-strip'));
        expect(find.byType(HomeWeekStrip), findsOneWidget);
        expect(strip, findsOneWidget);
        expect(tester.widget(strip), isA<HandPressable>());

        // Home grows with her training row, so the strip can sit under the
        // bottom bar until it is scrolled into the clear.
        await tester.ensureVisible(strip);
        await tester.pumpAndSettle();
        await tester.tap(strip);
        await tester.pumpAndSettle();
        // The week strip opens You, the last tab.
        expect(find.text('Sessions this week'), findsOneWidget);
      });
    }

    testWidgets(
      'Progress counts her first week instead of saying "All five done"',
      (tester) async {
        _phone(tester);
        await _boot(tester);

        _nav(tester).pushNamed(appDestinations['P07']!.name);
        await tester.pumpAndSettle();

        expect(find.text('Your first week'), findsOneWidget);
        expect(
          find.text('All five done'),
          findsNothing,
          reason: 'the one false line on an otherwise truthful screen',
        );
        // The arc offers three steps while Community is dark, and she has done
        // none of them.
        expect(_rowSubtitle('Your first week', '0 of 3'), findsOneWidget);
      },
    );

    testWidgets('her picture is big enough to hit', (tester) async {
      _phone(tester);
      await _boot(tester);

      final avatar = find.byType(AppAvatar);
      expect(avatar, findsOneWidget);
      // 32×32 against 44 (iOS HIG) and the 48 every other masthead control
      // measures, on the control that is the only door to My cycle, Language,
      // Privacy, the Safety Centre, allergies and "delete everything".
      final size = tester.getSize(avatar);
      expect(size.width, greaterThanOrEqualTo(44));
      expect(size.height, greaterThanOrEqualTo(44));
    });
  });
}
