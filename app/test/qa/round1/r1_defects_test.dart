// Round one's findings, as a red suite.
//
// Every test in this file asserts the behaviour the product should have and
// fails on the behaviour it has today. It is the regression suite for the
// fixing agent: make these green and the S1s in the round-one report are gone.
// Run it with `flutter test --tags qa test/qa/round1/r1_defects_test.dart`.
@Tags(['qa'])
library;

import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:own_hub/app_state/eat_state.dart';
import 'package:own_hub/features/account/domain/dietary_profile.dart';
import 'package:own_hub/features/eat/data/seeded_recipe_library.dart';
import 'package:own_hub/routing/app_router.dart';
import 'package:own_hub/ui/app_nav_bar.dart';

import 'round1_harness.dart';

int get _sessions => AppRouter.todayRepository.day.week.sessionsLogged;

RecipeBook _book() => RecipeBook.fromJson(
  (jsonDecode(File('assets/content/rahma_recipes.json').readAsStringSync())
          as Map)
      .cast<String, Object?>(),
);

void main() {
  useShippingApp();

  // ---------------------------------------------------------------- S1
  testWidgets(
    'R1-23a a declared tree-nut allergy hides the nut dish',
    (t) async {
      phone(t);
      final s = t.ensureSemantics();
      EatAppState.instance.seedRecipeBook(_book());
      await AppRouter.dietaryRepository.save(allergies: {AllergenTag.treeNuts});
      await open(t, appDestinations['E05']!.name, locale: const Locale('en'));
      expect(
        paintedText(t),
        isNot(contains('Yoghurt, dates and nuts')),
        reason:
            'E10 told her "Dishes that contain it are hidden from your '
            'recipes". recipes_view.dart:186 draws this row from a RecipeRow '
            'that carries no allergen field at all, so no guard can filter it.',
      );
      s.dispose();
    },
  );

  testWidgets('R1-23b a recipe row opens the recipe it names', (t) async {
    phone(t);
    final s = t.ensureSemantics();
    EatAppState.instance.seedRecipeBook(_book());
    await open(t, appDestinations['E05']!.name, locale: const Locale('en'));
    await tapLabel(t, RegExp('Yoghurt, dates and nuts'));
    expect(
      paintedText(t).first,
      isNot('Koshari bowl'),
      reason: 'all four RecipeRows open the same prototype page',
    );
    s.dispose();
  });

  testWidgets('R1-07 Undo is gone once the write has landed', (t) async {
    phone(t);
    final s = t.ensureSemantics();
    AppRouter.intakeRepository.markSetupDone();
    await open(t, appDestinations['T02']!.name, locale: const Locale('en'));
    await tapLabel(t, RegExp("Legs and glutes, today's plan"));
    await t.pump(const Duration(milliseconds: 5000));
    expect(
      _sessions == 1 && hasLabel(t, RegExp('Undo')),
      isFalse,
      reason:
          'the session is written at about 4.5s and the bar closes at about '
          '5.5s, so for a second she can tap an Undo that does nothing',
    );
    s.dispose();
  });

  testWidgets('R1-49a T02 draws no bar a finger cannot reach', (t) async {
    phone(t);
    await open(t, appDestinations['T02']!.name, locale: const Locale('en'));
    final bar = find.byType(AppNavBar);
    if (bar.evaluate().isEmpty) return;
    final r = t.getRect(
      find.descendant(of: bar, matching: find.text('Train')).first,
    );
    await t.tapAt(r.center);
    await settle(t);
    expect(
      topScreen(t),
      'R01',
      reason:
          'already_did_it_view.dart:200 lays a Positioned.fill ColoredBox over '
          'the whole Stack, including the AppNavBar drawn at line 183',
    );
  });

  testWidgets('R1-49b E04 marks its own screen active, not E01', (t) async {
    phone(t);
    await open(t, appDestinations['E04']!.name, locale: const Locale('en'));
    final bar = find.byType(AppNavBar);
    expect(
      t.widget<AppNavBar>(bar.first).activeScreenId,
      'E04',
      reason: 'eat_view.dart:408 hardcodes E01, which kills the Eat tab on E04',
    );
  });

  testWidgets('R1-06a T04 and T05 greet her with today', (t) async {
    phone(t);
    final today = DateTime.now();
    const names = [
      'Monday', 'Tuesday', 'Wednesday', 'Thursday', 'Friday', 'Saturday',
      'Sunday',
    ];
    final expected = names[today.weekday - 1];
    for (final id in ['T04', 'T05']) {
      await open(t, appDestinations[id]!.name, locale: const Locale('en'));
      expect(
        paintedText(t),
        contains(expected),
        reason:
            '$id defaults its date to DateTime(2026, 9, 14) '
            '(quiet_week_view.dart:105, tier_slip_view.dart:125) and the '
            'router never passes one',
      );
    }
  });

  testWidgets('R1-12a R12 names today, not Tuesday', (t) async {
    phone(t);
    await open(t, appDestinations['R12']!.name, locale: const Locale('en'));
    // With no session, R12 names the day it is opened. Asserting today's name
    // (rather than "not Tuesday") keeps the check true on every day of the week.
    const names = [
      'Monday', 'Tuesday', 'Wednesday', 'Thursday', 'Friday', 'Saturday',
      'Sunday',
    ];
    final today = names[DateTime.now().weekday - 1];
    expect(
      paintedText(t),
      anyElement(contains("That's $today done")),
      reason: 'the exact defect commit 5e78faa fixed elsewhere',
    );
  });

  testWidgets('R1-11a T07 claims no meal she has not logged', (t) async {
    phone(t);
    await open(t, appDestinations['T07']!.name, locale: const Locale('en'));
    expect(
      paintedText(t),
      isNot(contains('You did · ful and baladi')),
      reason:
          'first_week_view.dart:152. The identical defect one line above, on '
          'the logSet step, was already fixed to an empty subtitle.',
    );
  });

  testWidgets('R1-11b T07 does not say five when it offers three', (t) async {
    phone(t);
    await open(t, appDestinations['T07']!.name, locale: const Locale('en'));
    expect(
      paintedText(t).where((s) => s.contains('all five')),
      isEmpty,
      reason: 'the ring, the heading and the rows all say three',
    );
  });

  testWidgets('R1-40a R10 draws no trophy she has not earned', (t) async {
    phone(t);
    await open(t, appDestinations['R10']!.name, locale: const Locale('en'));
    expect(
      paintedText(t),
      isNot(contains('A personal best')),
      reason:
          'finished_view.dart:101 reads `session == null || eligible`, and '
          'app_router.dart:1265 never passes a session, so the card is '
          'unconditional. P03 one tap away says "Nothing saved yet".',
    );
  });

  testWidgets('R1-39a P04 makes no encryption claim', (t) async {
    phone(t);
    await open(t, appDestinations['P04']!.name, locale: const Locale('en'));
    expect(
      paintedText(t).where((s) => s.contains('encrypted')),
      isEmpty,
      reason:
          'account_data.dart:212 says there is no encrypted photo store in '
          'this build and no key to destroy',
    );
  });

  testWidgets('R1-13a no kilogram prescription on a no-equipment plan', (
    t,
  ) async {
    phone(t);
    await open(t, appDestinations['R03']!.name, locale: const Locale('en'));
    expect(paintedText(t), contains('Quiet · no equipment · floor'));
    await open(t, appDestinations['R07']!.name, locale: const Locale('en'));
    expect(
      paintedText(t).where((s) => s.contains('kg')),
      isEmpty,
      reason: 'R07 prescribes 12 kg inside a session whose own subtitle says '
          'no equipment, on a fresh install with no history',
    );
  });

  // The one case in this file that had to be re-pointed, and why.
  //
  // As written it tapped the 5 chip and demanded a target of 5. That is one of
  // the two ways out of R1-02, and the owner took the other one: O03 no longer
  // offers a 5 at all (`Intake.allowedDays` is 2, 3, 4) because
  // `kMaxSessionsTarget` is a product rule — this app counts weeks rather than
  // days and will not set a target it expects her to miss. With the chip gone,
  // `tapLabel(t, '5')` has nothing to tap and the case could not run at all.
  //
  // The rule in the name is untouched and is still asserted at the top of the
  // range: she taps the biggest number the screen offers, O05 reads that number
  // back to her, and that is the number her week is measured against. Nothing
  // is clamped, defaulted or discarded on the way. The original defect — a
  // chip whose value the rewards system silently replaced — fails this case
  // exactly as before, because 4 is now the number that can be silently
  // replaced by 3.
  testWidgets('R1-02a the days she picks are the days she is measured against',
      (t) async {
    phone(t);
    final s = t.ensureSemantics();
    await boot(t, locale: const Locale('en'));
    await tapLabel(t, 'Continue');
    await tapLabel(t, 'Continue');
    // On O03 now.
    expect(
      hasLabel(t, '5'),
      isFalse,
      reason: 'a chip the rewards system would refuse must not be offered',
    );
    await tapLabel(t, '4');
    await tapLabel(t, 'Continue');
    await tapLabel(t, 'Continue');
    expect(paintedText(t).any((e) => e.contains('Days a week: 4')), isTrue);
    await tapLabel(t, 'Start day 1 now');
    expect(
      AppRouter.todayRepository.day.week.sessionsTarget,
      4,
      reason:
          'O03 says "this becomes your weekly goal" and O05 reads the number '
          'back to her; the week she is measured against must be that number',
    );
    s.dispose();
  });

  testWidgets('R1-10a no shipping route renders the not-built panel', (
    t,
  ) async {
    phone(t);
    await open(t, appDestinations['T08']!.name, locale: const Locale('en'));
    expect(find.byType(NotBuiltYet), findsNothing);
  });

  testWidgets('R1-25a Rahma\'s letter has a body', (t) async {
    phone(t);
    EatAppState.instance.seedRecipeBook(_book());
    await open(t, appDestinations['E11']!.name, locale: const Locale('ar'));
    expect(
      paintedText(t).length,
      greaterThan(1),
      reason: 'E11 renders one English string, "A message to you :)", in both '
          'locales and nothing else',
    );
  });
}
