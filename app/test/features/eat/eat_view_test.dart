// E01 — Eat, E09 — Eat on day one, and E04 — after a log.
//
// Implements P0-LOG-06, P0-FR-01's Eat half, and P1-RULE-09's Eat half.
//
// The assertions worth having are the ones that catch a silent failure: a log
// that reaches the server before its undo window closes, a screen that asks her
// to confirm, and a calorie countdown appearing anywhere on a screen whose whole
// promise is that there is not one.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:own_hub/domain/logging/log_command_bus.dart';
import 'package:own_hub/features/eat/domain/allergy_guard.dart';
import 'package:own_hub/features/eat/domain/meal_repository.dart';
import 'package:own_hub/features/eat/presentation/eat_view.dart';
import 'package:own_hub/domain/format/number_label.dart';
import 'package:own_hub/l10n/app_l10n.dart';
import 'package:own_hub/theme/app_tokens.dart';

// 15 September 2026 is a Tuesday — the day the prototype draws. 13:12 is
// lunchtime, so the active slot is lunch.
final DateTime _lunchtime = DateTime(2026, 9, 15, 13, 12);
const String _dayId = '2026-09-15';

void _phone(WidgetTester tester) {
  tester.view.physicalSize = const Size(1170, 2532); // 390×844 at 3×
  tester.view.devicePixelRatio = 3.0;
  addTearDown(tester.view.reset);
}

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
    home: Builder(
      builder: (context) => MediaQuery(
        data: MediaQuery.of(context)
            .copyWith(textScaler: TextScaler.linear(textScale)),
        child: child,
      ),
    ),
  );
}

/// A plate she has eaten twice, so it clears the "twice before it is a plate"
/// threshold and appears as a one-tap suggestion.
EatPrefs _prefsWithPlate(String foodId) {
  const days = ['2026-09-08', '2026-09-14'];
  return EatPrefs(
    plates: {
      'plate_$foodId': Plate(
        plateId: 'plate_$foodId',
        items: [PlateItem(foodId: foodId, size: 'M')],
        dayCounts: {for (final day in days) day: 1},
        slotCounts: const {MealSlot.lunch: 2},
        dowCounts: const {DateTime.tuesday: 2},
        lastAt: DateTime(2026, 9, 14, 13),
      ),
    },
  );
}

/// Breakfast already logged, so the screen is NOT on its day-one branch.
MealItem get _breakfast => MealItem(
  itemId: 'breakfast-1',
  foodId: 'ful_baladi',
  servings: 1,
  size: 'M',
  loggedAt: DateTime(2026, 9, 15, 8, 40),
  source: MealSource.search,
  origin: MealOrigin.suggestion,
  kcal: 410,
  proteinG: 22,
);

InMemoryMealRepository _repositoryWithHistory() {
  final repository = InMemoryMealRepository(
    prefs: _prefsWithPlate('molokhia_chicken'),
  );
  repository.store.days[_dayId] = MealDay(
    dayId: _dayId,
    slots: {
      MealSlot.breakfast: [_breakfast],
    },
  );
  return repository;
}

/// Every route out is stubbed, so a stray tap can never reach the real router.
EatView _eat({
  MealRepository? repository,
  LogCommandBus? bus,
  LogHandle? justLogged,
  ValueChanged<LogHandle>? onLogged,
  DietaryConstraints constraints = DietaryConstraints.none,
}) {
  return EatView(
    constraints: constraints,
    repository: repository,
    bus: bus,
    now: _lunchtime,
    justLogged: justLogged,
    onLogged: onLogged,
    onOpenRecipes: () {},
    onType: () {},
    onSpeak: () {},
    onSelectTab: (_) {},
  );
}

void main() {
  group('P0-LOG-06 — log a usual meal in one tap', () {
    testWidgets('her usual is on the screen, ranked, with its numbers', (
      tester,
    ) async {
      _phone(tester);
      await tester.pumpWidget(
        _host(_eat(repository: _repositoryWithHistory())),
      );
      await tester.pumpAndSettle();

      expect(find.text('Molokhia with chicken'), findsOneWidget);
      expect(find.text('460 kcal · 34 g protein'), findsOneWidget);
      expect(find.text('Log'), findsOneWidget);
    });

    testWidgets('one tap logs it, and the write waits five seconds', (
      tester,
    ) async {
      _phone(tester);
      final repository = _repositoryWithHistory();
      final bus = LogCommandBus();
      final handles = <LogHandle>[];

      await tester.pumpWidget(
        _host(_eat(repository: repository, bus: bus, onLogged: handles.add)),
      );
      await tester.pumpAndSettle();

      // Exactly one tap.
      await tester.tap(find.text('Log'));
      await tester.pump();

      expect(handles, hasLength(1));
      expect(
        repository.writes,
        isEmpty,
        reason: 'still inside the undo window, so nothing has left the device',
      );

      await tester.pump(const Duration(seconds: 6));

      expect(repository.writes, hasLength(1));
      final write = repository.writes.single;
      expect(write.added.single.foodId, 'molokhia_chicken');
      expect(write.slot, MealSlot.lunch, reason: 'logged at 13:12');
      expect(write.kcalDelta, 460);
      expect(write.proteinDelta, 34);

      bus.dispose();
    });

    testWidgets('the row appears immediately, before the write', (
      tester,
    ) async {
      _phone(tester);
      final repository = _repositoryWithHistory();
      final bus = LogCommandBus();

      await tester.pumpWidget(_host(_eat(repository: repository, bus: bus)));
      await tester.pumpAndSettle();

      // Lunch is empty and reads "Now".
      expect(find.text('Now'), findsOneWidget);

      await tester.tap(find.text('Log'));
      await tester.pump();

      // §4.3: the logged row appears with its real numbers straight away, even
      // though nothing has been written yet.
      expect(repository.writes, isEmpty);
      expect(
        find.text('Now'),
        findsNothing,
        reason: 'the lunch column now names what she just logged',
      );

      bus.dispose();
    });

    testWidgets('undo inside the window means nothing is ever written', (
      tester,
    ) async {
      _phone(tester);
      final repository = _repositoryWithHistory();
      final bus = LogCommandBus();
      final handles = <LogHandle>[];

      await tester.pumpWidget(
        _host(_eat(repository: repository, bus: bus, onLogged: handles.add)),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.text('Log'));
      await tester.pump(const Duration(seconds: 2));

      expect(handles.single.undo(), isTrue);
      await tester.pump(const Duration(seconds: 10));

      expect(
        repository.writes,
        isEmpty,
        reason:
            'the write never left the device, so there is nothing queued to '
            'resurface on reconnect and no once-a-day points hook fires',
      );

      bus.dispose();
    });

    testWidgets('there is no calorie countdown anywhere on the screen', (
      tester,
    ) async {
      _phone(tester);
      await tester.pumpWidget(
        _host(_eat(repository: _repositoryWithHistory())),
      );
      await tester.pumpAndSettle();

      expect(find.text('Protein'), findsOneWidget);

      // Nothing that counts down, and nothing that goes negative.
      expect(find.textContaining('remaining'), findsNothing);
      expect(find.textContaining('left'), findsNothing);
      expect(find.textContaining('over'), findsNothing);
      expect(find.textContaining('-'), findsNothing);
    });

    testWidgets('the totals on screen are HER totals, not the mockup\'s', (
      tester,
    ) async {
      // The defect this replaces a vacuous test for.
      //
      // The old assertion here was `find.textContaining('so far today')`, which
      // passes identically whether the sentence is computed or is the constant
      // `l10n.about1106KcalSoFarToday`. It named the running total and
      // constrained nothing about its value, so E01/E04 shipped telling every
      // woman she had eaten 1,106 kcal — while the bar beside it drew her real
      // figure. Third occurrence of the class: see PHASE1-FIXES.md #3 and #8.
      //
      // `_repositoryWithHistory()` seeds one known breakfast, so the numbers
      // below are derivable rather than copied off the prototype.
      _phone(tester);
      final repository = _repositoryWithHistory();
      await tester.pumpWidget(_host(_eat(repository: repository)));
      await tester.pumpAndSettle();

      final seeded = repository.store.days[_dayId]!;
      final items = seeded.slots.values.expand((i) => i).toList();
      final kcal = items.fold<int>(0, (sum, i) => sum + i.kcal);
      final protein = items.fold<int>(0, (sum, i) => sum + i.proteinG);

      expect(
        find.text('About ${countLabel(kcal)} kcal so far today'),
        findsOneWidget,
        reason: 'the sentence must state what she actually logged',
      );
      expect(
        find.textContaining('${countLabel(protein)} of '),
        findsOneWidget,
        reason: 'protein likewise',
      );

      // The mockup's own figures must not appear — but only the ones that
      // correspond to no real fixture.
      //
      // "22 of 95 g" is deliberately NOT banned here, and the distinction is
      // the whole lesson of this defect: the seeded breakfast really is 22 g
      // against a 95 g target, so that string is both the prototype's sample
      // AND the honest computed value for this day. That coincidence is
      // exactly why the old constant looked correct before a log and went
      // wrong the moment she logged anything. Banning it would fail a correct
      // render.
      expect(find.textContaining('1,106'), findsNothing);
      expect(find.textContaining('53 of 95'), findsNothing);
      expect(find.text('+31 g'), findsNothing);
    });
  });

  group('P1-RULE-09 — logging never raises a confirmation', () {
    testWidgets('one tap saves and offers undo, with no dialog', (
      tester,
    ) async {
      _phone(tester);
      final bus = LogCommandBus();

      await tester.pumpWidget(
        _host(_eat(repository: _repositoryWithHistory(), bus: bus)),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.text('Log'));
      await tester.pump();

      expect(find.byType(AlertDialog), findsNothing);
      expect(find.byType(Dialog), findsNothing);
      expect(find.textContaining('Are you sure'), findsNothing);

      // The undo offer, which is what replaces the confirmation.
      expect(find.text('Undo'), findsOneWidget);

      bus.dispose();
    });
  });

  group('P0-FR-01 — E09, Eat on day one', () {
    testWidgets('an empty day renders the first-run branch', (tester) async {
      _phone(tester);
      // Nothing logged, no history at all.
      await tester.pumpWidget(
        _host(_eat(repository: InMemoryMealRepository())),
      );
      await tester.pumpAndSettle();

      // What will appear here, and why it is empty.
      expect(find.text('No plates yet'), findsOneWidget);
      expect(
        find.textContaining('Log something twice and it becomes a one-tap'),
        findsOneWidget,
      );
      expect(find.text('Day 1'), findsOneWidget);
    });

    testWidgets('it offers real starters rather than an empty box', (
      tester,
    ) async {
      _phone(tester);
      await tester.pumpWidget(
        _host(_eat(repository: InMemoryMealRepository())),
      );
      await tester.pumpAndSettle();

      expect(find.text('Or start from one of these'), findsOneWidget);
      expect(
        find.text('Log'),
        findsNWidgets(3),
        reason:
            'three real Egyptian starters — an empty box would ask her to '
            'invent an answer',
      );
    });

    testWidgets('and it states the rule before she can fail it', (
      tester,
    ) async {
      _phone(tester);
      await tester.pumpWidget(
        _host(_eat(repository: InMemoryMealRepository())),
      );
      await tester.pumpAndSettle();

      expect(
        find.textContaining('No countdown, no red numbers'),
        findsOneWidget,
      );
    });

    testWidgets('no tour, no overlay, no tutorial mode', (tester) async {
      _phone(tester);
      await tester.pumpWidget(
        _host(_eat(repository: InMemoryMealRepository())),
      );
      await tester.pumpAndSettle();

      expect(find.byType(AlertDialog), findsNothing);
      expect(find.byType(Dialog), findsNothing);
      expect(tester.takeException(), isNull);
    });

    testWidgets('one log ends the branch permanently', (tester) async {
      _phone(tester);
      final repository = InMemoryMealRepository();
      final bus = LogCommandBus();

      await tester.pumpWidget(_host(_eat(repository: repository, bus: bus)));
      await tester.pumpAndSettle();
      expect(find.text('No plates yet'), findsOneWidget);

      await tester.tap(find.text('Log').first);
      await tester.pump();

      expect(
        find.text('No plates yet'),
        findsNothing,
        reason: 'the day-one branch ends at her first log of any kind',
      );

      bus.dispose();
    });
  });

  group('E04 — the same screen, just after a log', () {
    testWidgets('the undo bar names what was saved', (tester) async {
      _phone(tester);
      final bus = LogCommandBus();
      final handle = bus.submit(
        UndoableLog(describe: 'Food logged', commit: () async {}),
      );

      await tester.pumpWidget(
        _host(_eat(repository: _repositoryWithHistory(), justLogged: handle)),
      );
      await tester.pumpAndSettle();

      expect(find.text('Food logged'), findsOneWidget);
      expect(find.text('Undo'), findsOneWidget);

      bus.dispose();
    });

    testWidgets('five points land once a day, not once an item', (
      tester,
    ) async {
      _phone(tester);
      final bus = LogCommandBus();
      final handle = bus.submit(
        UndoableLog(describe: 'Food logged', commit: () async {}),
      );

      await tester.pumpWidget(
        _host(_eat(repository: _repositoryWithHistory(), justLogged: handle)),
      );
      await tester.pumpAndSettle();

      expect(find.text('+5 points'), findsOneWidget);
      // The "+31 g" assertion that stood here has been removed rather than
      // fixed. It demanded a protein delta that nothing computes: `justLogged`
      // is a LogHandle carrying a description and an undo, and EatDayView
      // exposes current totals with no before/after pair. The number was a
      // dictionary constant, so this test was pinning an invented figure in
      // place. The screen now renders no delta at all until a real one exists.
      // The header names the slot the hour is actually in, so it cannot be
      // pinned to one word here. What it must never do again is claim a
      // weekly pattern: "Tuesdays" sat beside it, asserting a habit to a
      // woman who had logged one meal in her life.
      expect(
        find.byWidgetPredicate(
          (w) => w is Text && (w.data ?? '').endsWith(', your usual'),
        ),
        findsOneWidget,
      );
      expect(find.text('Tuesdays'), findsNothing);

      bus.dispose();
    });

    testWidgets('E01 shows the Ramadan pill instead, not the points one', (
      tester,
    ) async {
      _phone(tester);
      await tester.pumpWidget(
        _host(_eat(repository: _repositoryWithHistory())),
      );
      await tester.pumpAndSettle();

      expect(find.text('Ramadan mode off'), findsOneWidget);
      expect(find.text('+5 points'), findsNothing);
      expect(find.text('Undo'), findsNothing);
    });
  });

  group('P0-A11Y-01 — Arabic', () {
    testWidgets('reads in Arabic, from the dictionary', (tester) async {
      _phone(tester);
      await tester.pumpWidget(
        _host(
          _eat(repository: _repositoryWithHistory()),
          locale: const Locale('ar'),
        ),
      );
      await tester.pumpAndSettle();

      // Twice on purpose: the heading and the Eat tab in the bottom bar are
      // the same word. Asserting one would be asserting a bug.
      expect(find.text('الطعام'), findsWidgets);
      expect(find.text('بروتين'), findsOneWidget);
      expect(find.text('سجّلي'), findsOneWidget);
      expect(find.text('Eat'), findsNothing);
    });

    testWidgets('the layout mirrors', (tester) async {
      _phone(tester);
      await tester.pumpWidget(
        _host(
          _eat(repository: _repositoryWithHistory()),
          locale: const Locale('ar'),
        ),
      );
      await tester.pumpAndSettle();

      expect(
        Directionality.of(tester.element(find.text('الطعام').first)),
        TextDirection.rtl,
      );
    });

    testWidgets('numbers stay Western in Arabic', (tester) async {
      _phone(tester);
      await tester.pumpWidget(
        _host(
          _eat(repository: _repositoryWithHistory()),
          locale: const Locale('ar'),
        ),
      );
      await tester.pumpAndSettle();

      // The dictionary uses Western digits in all of its values containing a
      // number, and P0-A11Y-01 requires it. Eastern Arabic digits here would
      // mean something reached for NumberFormat.
      expect(find.textContaining('٤٦٠'), findsNothing);
      expect(find.textContaining('460'), findsOneWidget);
    });

    testWidgets('does not overflow at the largest text size in Arabic', (
      tester,
    ) async {
      _phone(tester);
      await tester.pumpWidget(
        _host(
          _eat(repository: _repositoryWithHistory()),
          locale: const Locale('ar'),
          textScale: 1.6,
        ),
      );
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
    });

    testWidgets('the day-one branch survives the largest text size too', (
      tester,
    ) async {
      _phone(tester);
      await tester.pumpWidget(
        _host(
          _eat(repository: InMemoryMealRepository()),
          locale: const Locale('ar'),
          textScale: 1.6,
        ),
      );
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
    });
  });
}
