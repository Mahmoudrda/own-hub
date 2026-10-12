// "Not fetched yet" is not "she has nothing".
//
// Every repository in this app answers out of memory, so an unread store and an
// empty store look the same, and two screens turn that silence into a sentence:
// `T06` says "Day 1" and `E09` says "No plates yet". A woman two months into
// training who signs in on a new handset has an empty store and a full cloud,
// and `CloudStore` pulls the cloud AFTER the first frame.
//
// This is the tri-state that stops the app saying the wrong thing confidently,
// and the two screens holding their tongue until something has answered.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:own_hub/app_state/app_changes.dart';
import 'package:own_hub/data/pending_answers.dart';
import 'package:own_hub/features/eat/domain/meal_repository.dart';
import 'package:own_hub/features/eat/presentation/eat_view.dart';
import 'package:own_hub/features/today/domain/today_repository.dart';
import 'package:own_hub/features/today/presentation/today_view.dart';
import 'package:own_hub/l10n/app_l10n.dart';
import 'package:own_hub/theme/app_tokens.dart';
import 'package:own_hub/domain/week/week_key.dart';
import 'package:own_hub/features/eat/domain/allergy_guard.dart';

final DateTime _tuesday = DateTime(2026, 9, 15, 9, 41);

/// The screen under the same `RedrawOnChange` the router puts it under, so a
/// bump reaches it here the way it reaches it in the app. [build] is called
/// afresh on every redraw, because `Element.updateChild` skips a child that is
/// identical to the one already there.
Widget _host(WidgetBuilder build, {Locale locale = const Locale('en')}) =>
    MaterialApp(
      locale: locale,
      localizationsDelegates: AppL10n.localizationsDelegates,
      supportedLocales: AppL10n.supportedLocales,
      theme: buildTheme(locale),
      home: RedrawOnChange(builder: build),
    );

void _phone(WidgetTester tester) {
  tester.view.physicalSize = const Size(1170, 2532);
  tester.view.devicePixelRatio = 3.0;
  addTearDown(tester.view.reset);
}

/// A meal store holding one logged item, so the Eat repository has data.
MealStore _storeWithAMeal() {
  final store = MealStore();
  store.apply(
    MealWrite.transform(
      dayId: '2026-09-15',
      slot: MealSlot.lunch,
      tz: WeekKey.fallbackTimezone,
      libVersion: 1,
      added: [
        MealItem(
          itemId: 'item-1',
          foodId: 'koshari_bowl',
          servings: 1,
          size: 'M',
          loggedAt: _tuesday,
          source: MealSource.search,
          origin: MealOrigin.search,
          kcal: 540,
          proteinG: 18,
        ),
      ],
    ),
  );
  return store;
}

void main() {
  tearDown(PendingAnswers.reset);

  group('the rule', () {
    test('a store holding something never waits for anybody', () {
      PendingAnswers.expect();
      expect(dataStateOf(holdsNothing: false), DataState.hasData);
    });

    test('a store holding nothing says so only once everything has answered', () {
      expect(dataStateOf(holdsNothing: true), DataState.empty);

      PendingAnswers.expect();
      expect(dataStateOf(holdsNothing: true), DataState.unknown);

      PendingAnswers.answered();
      expect(dataStateOf(holdsNothing: true), DataState.empty);
    });

    test('two sources are both waited for', () {
      PendingAnswers.expect();
      PendingAnswers.expect();
      PendingAnswers.answered();
      expect(PendingAnswers.settled, isFalse);
      PendingAnswers.answered();
      expect(PendingAnswers.settled, isTrue);
    });

    test('an answer nobody asked for changes nothing', () {
      PendingAnswers.answered();
      expect(PendingAnswers.waiting, 0);
      expect(PendingAnswers.settled, isTrue);
    });

    test('settling redraws the screens that were holding their tongue', () {
      var bumps = 0;
      void count() => bumps++;
      AppChanges.instance.addListener(count);
      addTearDown(() => AppChanges.instance.removeListener(count));

      PendingAnswers.expect();
      expect(bumps, 0, reason: 'nothing changed by starting to wait');
      PendingAnswers.answered();
      expect(bumps, 1);
    });

    testWidgets('a source that never answers is given up on', (tester) async {
      PendingAnswers.expect();
      expect(PendingAnswers.settled, isFalse);

      // A pull on a dead network does not fail, it hangs, and Firestore times
      // no read out on its own. A held tongue has to end.
      await tester.pump(PendingAnswers.deadline + const Duration(seconds: 1));

      expect(PendingAnswers.settled, isTrue);
      expect(dataStateOf(holdsNothing: true), DataState.empty);
    });
  });

  group('the repositories', () {
    test('Today: nothing logged, nothing answered', () {
      final repository = InMemoryTodayRepository(
        day: InMemoryTodayRepository.dayOne(date: _tuesday),
      );
      expect(repository.dataState, DataState.empty);

      PendingAnswers.expect();
      expect(repository.dataState, DataState.unknown);

      PendingAnswers.answered();
      expect(repository.dataState, DataState.empty);
    });

    test('Today: a woman with a history never waits', () {
      final repository = InMemoryTodayRepository(
        day: InMemoryTodayRepository.defaultDay(date: _tuesday),
      );
      PendingAnswers.expect();
      expect(repository.dataState, DataState.hasData);
    });

    test('Eat: nothing logged, nothing answered', () {
      final repository = InMemoryMealRepository();
      expect(repository.dataState, DataState.empty);

      PendingAnswers.expect();
      expect(repository.dataState, DataState.unknown);
    });

    test('Eat: a woman who has eaten here before never waits', () {
      final repository = InMemoryMealRepository(store: _storeWithAMeal());
      PendingAnswers.expect();
      expect(repository.dataState, DataState.hasData);
    });
  });

  group('T06 holds its tongue', () {
    Widget home({required Key key}) => TodayView(
      key: key,
      repository: InMemoryTodayRepository(
        day: InMemoryTodayRepository.dayOne(date: _tuesday),
      ),
      now: _tuesday,
      onStartSession: () {},
      onOpenFirstWeek: () {},
      onTellUsWhatYouEat: () {},
      onOpenBeginnersGroup: () {},
      onSelectTab: (_) {},
    );

    testWidgets('it says "Day 1" when the phone is the whole answer', (
      tester,
    ) async {
      _phone(tester);
      await tester.pumpWidget(_host((_) => home(key: const ValueKey('settled'))));
      await tester.pump();

      expect(find.text('Day 1'), findsOneWidget);
      expect(find.text('Start day 1'), findsOneWidget);
      expect(find.text('Looking for what you have added.'), findsNothing);
    });

    testWidgets('it says nothing of the kind while a read is in flight', (
      tester,
    ) async {
      _phone(tester);
      PendingAnswers.expect();
      await tester.pumpWidget(_host((_) => home(key: const ValueKey('waiting'))));
      await tester.pump();

      expect(
        find.text('Day 1'),
        findsNothing,
        reason: 'she may be two months in and nothing has looked',
      );
      expect(find.text('Start day 1'), findsNothing);
      expect(find.text('Nothing added yet'), findsNothing);
      expect(find.text('Looking for what you have added.'), findsOneWidget);
      expect(
        find.byType(CircularProgressIndicator),
        findsNothing,
        reason: 'there was no spinner here before and there is none now',
      );
      PendingAnswers.reset();
    });

    testWidgets('and it says it in Arabic, on the small end, without clipping', (
      tester,
    ) async {
      // 375x667 at 2x: the iPhone 7, the narrowest shape this app supports, in
      // the language most of its women read.
      tester.view.physicalSize = const Size(750, 1334);
      tester.view.devicePixelRatio = 2.0;
      addTearDown(tester.view.reset);

      PendingAnswers.expect();
      await tester.pumpWidget(
        _host(
          (_) => home(key: const ValueKey('arabic')),
          locale: const Locale('ar'),
        ),
      );
      await tester.pump();

      expect(find.text('بندوّر على اللي ضفتيه.'), findsOneWidget);
      expect(tester.takeException(), isNull);
      PendingAnswers.reset();
    });

    testWidgets('and says it the moment the read comes back empty', (
      tester,
    ) async {
      _phone(tester);
      PendingAnswers.expect();
      await tester.pumpWidget(_host((_) => home(key: const ValueKey('resolving'))));
      await tester.pump();
      expect(find.text('Day 1'), findsNothing);

      PendingAnswers.answered();
      await tester.pump();

      expect(find.text('Day 1'), findsOneWidget);
      expect(find.text('Looking for what you have added.'), findsNothing);
    });
  });

  group('E09 holds its tongue', () {
    Widget eat({required Key key, MealStore? store}) => EatView(
      key: key,
      constraints: DietaryConstraints.none,
      repository: InMemoryMealRepository(store: store),
      now: _tuesday,
      onSelectTab: (_) {},
    );

    testWidgets('it offers the first plate when nothing is in flight', (
      tester,
    ) async {
      _phone(tester);
      await tester.pumpWidget(_host((_) => eat(key: const ValueKey('settled'))));
      await tester.pumpAndSettle();

      expect(find.text('No plates yet'), findsOneWidget);
      expect(find.text('Looking for what you have added.'), findsNothing);
    });

    testWidgets('it says nothing of the kind while a read is in flight', (
      tester,
    ) async {
      _phone(tester);
      PendingAnswers.expect();
      await tester.pumpWidget(_host((_) => eat(key: const ValueKey('waiting'))));
      await tester.pumpAndSettle();

      expect(find.text('No plates yet'), findsNothing);
      expect(find.text('Day 1'), findsNothing);
      expect(find.text('Looking for what you have added.'), findsOneWidget);
      expect(find.byType(CircularProgressIndicator), findsNothing);
      PendingAnswers.reset();
    });

    testWidgets('a woman who has eaten here before sees her own screen', (
      tester,
    ) async {
      _phone(tester);
      PendingAnswers.expect();
      await tester.pumpWidget(
        _host(
          (_) => eat(key: const ValueKey('hasData'), store: _storeWithAMeal()),
        ),
      );
      await tester.pumpAndSettle();

      expect(
        find.text('Looking for what you have added.'),
        findsNothing,
        reason: 'a pull can only add to what she already has',
      );
      PendingAnswers.reset();
    });
  });
}
