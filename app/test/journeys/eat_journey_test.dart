// Eating, walked through the real app.
//
// Every Eat screen had its own test and passed it while the tab did not work:
// each screen held its own `LogCommandBus`, so the meal E02 logged was still
// sitting in E02 five seconds after E04 had opened on the day-one branch —
// empty, with no undo bar, and then an undo bar that did nothing. `recordPlate`
// was never called, so "your usual" stayed empty forever. Home's meal card never
// heard about Eat at all, and its plates were a link rather than a log.
//
// These tests walk the thread instead of the screens: type a meal, undo it, log
// it, and then check that E04, E01 and Home agree about what she ate.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:own_hub/app_state/eat_state.dart';
import 'package:own_hub/domain/flags/feature_flags.dart';
import 'package:own_hub/features/account/domain/dietary_profile.dart';
import 'package:own_hub/features/eat/domain/meal_repository.dart';
import 'package:own_hub/features/eat/presentation/eat_sample_library.dart';
import 'package:own_hub/features/today/domain/today_repository.dart';
import 'package:own_hub/domain/week/week_key.dart';
import 'package:own_hub/main.dart';
import 'package:own_hub/routing/app_router.dart';
import 'package:own_hub/ui/app_nav_bar.dart';
import 'package:own_hub/ui/app_undo_bar.dart';
import 'package:own_hub/ui/hand/hand.dart';

void _phone(WidgetTester tester) {
  tester.view.physicalSize = const Size(1170, 2532);
  tester.view.devicePixelRatio = 3.0;
  addTearDown(tester.view.reset);
}

Future<void> _boot(WidgetTester tester) async {
  await tester.pumpWidget(OwnHubApp(key: UniqueKey()));
  await tester.pumpAndSettle();
}

NavigatorState _nav(WidgetTester tester) =>
    tester.state<NavigatorState>(find.byType(Navigator).first);

Future<void> _open(WidgetTester tester, String id) async {
  _nav(tester).pushNamed(appDestinations[id]!.name);
  await tester.pumpAndSettle();
}

Future<void> _home(WidgetTester tester) async {
  _nav(tester).popUntil((route) => route.isFirst);
  await tester.pumpAndSettle();
}

/// Puts Home's meal card back to the day the fake opens with, so a meal one
/// test logged is not still on the card in the next one.
void _resetHome() {
  final base = InMemoryTodayRepository.defaultDay();
  AppRouter.todayRepository.recordMeal(
    at: base.mealLoggedAt!,
    plates: base.plates,
  );
}

/// Lets the five seconds close and the write land.
Future<void> _windowCloses(WidgetTester tester) async {
  await tester.pump(const Duration(seconds: 6));
  await tester.pumpAndSettle();
}

/// Types a sentence into E02 and logs it. Lands on E04.
Future<void> _typeAndLog(WidgetTester tester, String sentence) async {
  await _open(tester, 'E02');
  await tester.enterText(find.byType(TextField).first, sentence);
  await tester.pumpAndSettle();
  await tester.tap(find.text('Add it'));
  await tester.pumpAndSettle();
}

String get _todayId {
  final now = DateTime.now();
  return '${now.year.toString().padLeft(4, '0')}-'
      '${now.month.toString().padLeft(2, '0')}-'
      '${now.day.toString().padLeft(2, '0')}';
}

// The cast this used to need is gone: `AppRouter.mealRepository` is declared
// as the in-memory repository now, because account deletion has to reach the
// store behind it.
MealStore get _store => AppRouter.mealRepository.store;

List<MealItem> get _written =>
    _store.days[_todayId]?.allItems.toList() ?? const <MealItem>[];

void main() {
  final saved = AppRouter.featureFlags;

  setUp(() {
    AppRouter.featureFlags = FeatureFlags.allOff.with_({
      for (final f in Feature.values) f: f != Feature.accountRequired,
    });
    EatAppState.instance.reset();
    _resetHome();
    _store.days.clear();
    _store.prefs = const EatPrefs();
    _store.plans[WeekKey.of(DateTime.now()).id] = sampleMealPlan(
      WeekKey.of(DateTime.now()).id,
    );
  });

  tearDown(() async {
    AppRouter.featureFlags = saved;
    EatAppState.instance.reset();
    _store.days.clear();
    _store.prefs = const EatPrefs();
    // "Asked, and named nothing" — the value the router treats exactly as an
    // unasked woman, so an allergy set by one test cannot leak into the next.
    await AppRouter.dietaryRepository.save(
      allergies: const <AllergenTag>{},
      dietary: const <DietaryTag>{},
    );
  });

  group('one log, one undo', () {
    testWidgets('logging a meal offers exactly one way back', (tester) async {
      // Both were on screen at once: E02 raised a floating `AppUndoSnackbar`
      // and then pushed E04, which drew the in-page `AppUndoBar` for the same
      // handle. Two offers, the same sentence, closing half a second apart —
      // and a woman who tapped the one that had already expired got nothing.
      _phone(tester);
      await _boot(tester);
      await _typeAndLog(tester, 'koshari');

      expect(find.byType(AppUndoBar), findsOneWidget);
      expect(
        find.byType(SnackBar),
        findsNothing,
        reason: 'the in-page bar is the one this screen shows',
      );
      expect(
        find.text('Undo'),
        findsOneWidget,
        reason: 'one meal, one way back — anywhere on the screen',
      );

      // And its five seconds are honest: the offer is still there at three
      // seconds and gone once the write has landed.
      await tester.pump(const Duration(seconds: 3));
      expect(find.text('Undo'), findsOneWidget);

      await _windowCloses(tester);
      expect(find.text('Undo'), findsNothing);
      expect(
        find.byType(AppUndoBar),
        findsOneWidget,
        reason: 'the bar stays, saying what was saved',
      );
    });
  });

  group('one meal, typed', () {
    testWidgets('E02 logs it, E04 shows it, and it is written after five '
        'seconds', (tester) async {
      _phone(tester);
      await _boot(tester);
      await _typeAndLog(tester, 'koshari');

      // E04, with the meal already on it — the row appears immediately and the
      // day total moves, before anything has been written (§4.3).
      // And it names the food and the slot, not "Meal added".
      expect(
        find.descendant(
          of: find.byType(AppUndoBar),
          matching: find.textContaining(' added to '),
        ),
        findsOneWidget,
        reason: 'E04 offers the undo the moment it opens, not five seconds in',
      );
      expect(find.text('18 of 95 g'), findsOneWidget);
      expect(
        find.text('No plates yet'),
        findsNothing,
        reason: 'the day-one branch, drawn over a meal she has just logged',
      );
      expect(_written, isEmpty, reason: 'the write is still being held');

      await _windowCloses(tester);
      expect(_written.map((i) => i.foodId), ['koshari_bowl']);

      // The bar stays, saying what was saved; the button that has stopped
      // being true is the part that goes.
      expect(find.byType(AppUndoBar), findsOneWidget);
      expect(
        find.descendant(
          of: find.byType(AppUndoBar),
          matching: find.text('Undo'),
        ),
        findsNothing,
      );
      expect(find.text('18 of 95 g'), findsOneWidget);
    });

    testWidgets('E01 shows the same day, and Home shows the meal', (
      tester,
    ) async {
      _phone(tester);
      await _boot(tester);
      await _typeAndLog(tester, 'koshari');
      await _windowCloses(tester);

      await _open(tester, 'E01');
      expect(find.text('18 of 95 g'), findsOneWidget);
      expect(find.text('18 of 95 g'), findsOneWidget);

      await _home(tester);
      expect(
        find.text('Koshari bowl'),
        findsOneWidget,
        reason: "Home's meal card lists the plate she actually logged",
      );
      expect(find.text('540 kcal'), findsOneWidget);
    });

    testWidgets('undo inside the window takes it back everywhere', (
      tester,
    ) async {
      _phone(tester);
      await _boot(tester);
      await _typeAndLog(tester, 'koshari');

      await tester.tap(
        find.descendant(
          of: find.byType(AppUndoBar),
          matching: find.text('Undo'),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('18 of 95 g'), findsNothing);
      expect(
        find.byType(AppUndoBar),
        findsNothing,
        reason: 'the bar read "Meal added" over a day that no longer held it',
      );
      await _windowCloses(tester);
      expect(_written, isEmpty, reason: 'an undone meal is never written');

      await _open(tester, 'E01');
      expect(find.text('No plates yet'), findsOneWidget);

      await _home(tester);
      expect(find.text('Koshari bowl'), findsNothing);
    });
  });

  group('one tap logs a plate', () {
    testWidgets('logged twice, it becomes a one-tap row on E01', (
      tester,
    ) async {
      _phone(tester);
      await _boot(tester);

      await _typeAndLog(tester, 'koshari');
      await _windowCloses(tester);
      await _typeAndLog(tester, 'koshari');
      await _windowCloses(tester);

      await _open(tester, 'E01');
      expect(
        find.text('Koshari bowl'),
        findsOneWidget,
        reason: 'log something twice and it becomes a plate — E09 says so',
      );
      expect(find.text('18 g protein'), findsOneWidget);

      await tester.tap(find.text('I ate this'));
      await tester.pumpAndSettle();
      expect(find.byType(AppUndoBar), findsOneWidget);
      expect(find.text('54 of 95 g'), findsOneWidget);

      await _windowCloses(tester);
      expect(_written.length, 3);
    });

    testWidgets("Home's plate logs, with the five seconds", (tester) async {
      _phone(tester);
      await _boot(tester);
      await _typeAndLog(tester, 'koshari');
      await _windowCloses(tester);
      await _home(tester);

      // Home is a scrolling page and its bottom bar sits over the foot of it,
      // so the plate has to be clear of the bar before it can be pressed.
      await tester.drag(find.byType(Scrollable).first, const Offset(0, -240));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Koshari bowl'));
      await tester.pumpAndSettle();

      // It logged, and it landed on the logged day rather than merely
      // navigating there.
      expect(find.byType(AppUndoBar), findsOneWidget);
      // One offer, here too: Home used to raise a snackbar of its own and then
      // carry the same handle to E04's bar.
      expect(find.byType(SnackBar), findsNothing);
      expect(find.text('Undo'), findsOneWidget);
      expect(find.text('36 of 95 g'), findsOneWidget);

      await _windowCloses(tester);
      expect(_written.length, 2);
    });
  });

  group('recipes', () {
    testWidgets('the filters filter, and the row she taps is the page she '
        'gets', (tester) async {
      _phone(tester);
      await _boot(tester);
      await _open(tester, 'E05');

      expect(find.text('Koshari, portioned'), findsOneWidget);
      await tester.tap(find.text('High protein'));
      await tester.pumpAndSettle();
      expect(find.text('Molokhia with chicken'), findsOneWidget);
      expect(
        find.text('Koshari, portioned'),
        findsNothing,
        reason: '18 g is not high protein',
      );

      await tester.tap(find.text('Ramadan'));
      await tester.pumpAndSettle();
      expect(find.text('No recipe carries a Ramadan tag yet.'), findsOneWidget);

      await tester.tap(find.text('Ramadan'));
      await tester.pumpAndSettle();
      expect(find.text('Koshari, portioned'), findsOneWidget);

      await tester.tap(find.text('Molokhia with chicken'));
      await tester.pumpAndSettle();
      expect(
        find.text('Molokhia with chicken'),
        findsWidgets,
        reason: 'E06 opens on the dish she tapped, not on koshari',
      );
    });

    testWidgets('saving, the steps, and cooking it', (tester) async {
      _phone(tester);
      await _boot(tester);
      await _open(tester, 'E05');
      await tester.tap(find.text('Molokhia with chicken'));
      await tester.pumpAndSettle();

      expect(find.byIcon(Icons.bookmark_border), findsOneWidget);
      await tester.tap(find.byIcon(Icons.bookmark_border));
      await tester.pumpAndSettle();
      expect(find.text('Saved'), findsOneWidget);
      expect(
        find.byIcon(Icons.bookmark),
        findsOneWidget,
        reason: 'the control says what it did',
      );

      // The notice is a floating bar over the footer, so it has to clear
      // before the buttons underneath it can be tapped.
      await tester.pump(const Duration(seconds: 5));
      await tester.pumpAndSettle();

      // No steps exist for this dish, so there is no button that would only
      // say so.
      expect(find.text('See the steps'), findsNothing);
      await tester.tap(find.text('I cooked it and ate a bowl'));
      await tester.pumpAndSettle();
      expect(find.byType(AppUndoBar), findsOneWidget);
      await _windowCloses(tester);
      expect(_written.map((i) => i.foodId), ['molokhia_chicken']);
    });
  });

  testWidgets('the week plan and the grocery list keep what she ticked', (
    tester,
  ) async {
    _phone(tester);
    await _boot(tester);
    await _open(tester, 'E07');
    expect(find.text('Molokhia with chicken'), findsOneWidget);

    await tester.tap(find.text('See the grocery list'));
    await tester.pumpAndSettle();

    // The sample week opens with one line already ticked.
    expect(find.byType(HandTick), findsOneWidget);
    await tester.tap(find.text('Onions 1 kg'));
    await tester.pumpAndSettle();
    expect(find.byType(HandTick), findsNWidgets(2));

    // Away and back — through E07, which reads the same document.
    _nav(tester).pop();
    await tester.pumpAndSettle();
    await tester.tap(find.text('See the grocery list'));
    await tester.pumpAndSettle();
    expect(
      find.byType(HandTick),
      findsNWidgets(2),
      reason: 'a shop survives being closed mid-market',
    );
  });

  testWidgets('every tab stays live on a screen that is not a tab', (
    tester,
  ) async {
    // E05 and E08 both claimed `activeScreenId: 'E01'`, and `AppNavBar` gives
    // the active tab no `onTap` — a tab is not a link to itself. So the Eat tab
    // rendered as the page she was already on and did nothing, from two screens
    // that are not the Eat tab.
    _phone(tester);
    await _boot(tester);
    await _open(tester, 'E07');
    await tester.tap(find.text('See the grocery list'));
    await tester.pumpAndSettle();
    expect(find.text('Onions 1 kg'), findsOneWidget, reason: 'E08 is open');

    await tester.tap(
      find.descendant(of: find.byType(AppNavBar), matching: find.text('Eat')),
    );
    await tester.pumpAndSettle();
    expect(
      find.text('Onions 1 kg'),
      findsNothing,
      reason: 'the Eat tab went somewhere',
    );

    // And Home, from the grocery list, reaches Home.
    await _open(tester, 'E07');
    await tester.tap(find.text('See the grocery list'));
    await tester.pumpAndSettle();
    await tester.tap(
      find.descendant(of: find.byType(AppNavBar), matching: find.text('Home')),
    );
    await tester.pumpAndSettle();
    expect(find.text('Onions 1 kg'), findsNothing);
  });

  testWidgets('the week rearranges rather than pretending to regenerate', (
    tester,
  ) async {
    _phone(tester);
    await _boot(tester);
    await _open(tester, 'E07');

    final before = tester
        .widgetList<Text>(find.byType(Text))
        .map((t) => t.data)
        .toList();
    expect(before, contains('Molokhia with chicken'));

    await tester.tap(find.byIcon(Icons.autorenew));
    await tester.pumpAndSettle();

    // The same five dinners, one day on: Monday now holds what Tuesday had.
    expect(find.text('Koshari, portioned'), findsOneWidget);
    expect(find.text('Molokhia with chicken'), findsOneWidget);
  });

  group('what she told us she avoids', () {
    testWidgets('an allergy saved on A02 changes what Eat offers and '
        'refuses', (tester) async {
      _phone(tester);
      await _boot(tester);

      // Before: the pack is offered and a meal logs.
      await _open(tester, 'E01');
      expect(find.text('Ful and baladi'), findsWidgets);
      await _home(tester);

      await _open(tester, 'A02');
      await tester.tap(find.text('Allergies and dietary preferences'));
      await tester.pumpAndSettle();
      // "No nuts" until `AllergenTag` grew from four members to sixteen for
      // Rahma's recipe book. `nuts` split into `tree_nuts` and `peanuts`,
      // because they are two allergies and folding them either hides peanuts
      // from a woman who reacts to them or takes every nut dish from a woman
      // who does not. The chips are plain names now, for the same reason: a
      // sixteen-item list of "No x" reads as a list of refusals.
      await tester.tap(find.text('Tree nuts'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Save'));
      await tester.pumpAndSettle();

      expect(AppRouter.eatConstraints.allergies, {
        'tree_nuts',
      }, reason: 'Eat reads the profile A02 wrote, not a constant');
      // A safety setting is never saved in silence.
      expect(
        find.text('Saved. Dishes with Tree nuts are hidden now.'),
        findsOneWidget,
      );
      // The notice floats over the footer; let it clear.
      await tester.pump(const Duration(seconds: 5));
      await tester.pumpAndSettle();

      await _home(tester);
      await _open(tester, 'E01');
      expect(
        find.text(
          'We cannot check these dishes for what you avoid yet, so '
          'none are suggested.',
        ),
        findsOneWidget,
        reason: 'no dish lists its allergens, so unknown reads as unsafe',
      );
      expect(find.text('Ful and baladi'), findsNothing);

      // And the guard holds at the moment of the log, not only in the list.
      await _typeAndLog(tester, 'koshari');
      await tester.pumpAndSettle();
      expect(
        find.text(
          'Nobody has listed what is in Koshari bowl yet, so we '
          'cannot check it against what you avoid.',
        ),
        findsOneWidget,
      );
      await _windowCloses(tester);
      expect(_written, isEmpty);
    });
  });
}
