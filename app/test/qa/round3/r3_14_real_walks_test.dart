// ignore_for_file: avoid_print
//
// R3-14. Two walks taken the way she takes them, not by writing to a
// repository.
//
//  1. **E10 by hand.** R3-01 drove `dietaryRepository.save` directly. The
//     headline defect of round one was a promise made on E10 and broken on
//     E05, so the promise has to be read on E10 and the consequence seen on
//     E05 in one continuous walk, with a finger on the chip.
//
//  2. **Y11**, which is not a route: it is the severe branch of Y03, and the
//     only way to read its copy is to log severe symptoms and arrive.
@Tags(['qa'])
library;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:own_hub/routing/app_router.dart';

import '../round1/round1_harness.dart';

void main() {
  useShippingApp();

  for (final loc in <String>['en', 'ar']) {
    testWidgets('E10 by hand, then E05, $loc', (t) async {
      phone(t);
      final s = t.ensureSemantics();

      await open(t, appDestinations['E10']!.name, locale: Locale(loc));
      print('=== R3-14 E10 $loc, the promise she reads ===');
      for (final line in paintedText(t)) {
        print('  | $line');
      }

      // A finger on the tree-nut chip, at its own painted pixel.
      final chipLabel = loc == 'en' ? 'Tree nuts' : 'المكسرات';
      var chip = find.text(chipLabel);
      if (chip.evaluate().isEmpty) {
        // Print what is on offer so the report can name the real label.
        print('  chips on offer: ${paintedText(t).join(" // ")}');
        chip = find.textContaining(loc == 'en' ? 'nut' : 'مكسّر');
      }
      expect(chip.evaluate(), isNotEmpty, reason: 'no tree-nut chip on E10');
      await t.tapAt(t.getRect(chip.first).center);
      await settle(t);

      final saved = await tapControl(
        t,
        RegExp(loc == 'en' ? 'Save what I avoid' : 'احفظي ما أتجنّبه'),
      );
      print('  saved by hand? $saved');
      print('  repository now: '
          '${AppRouter.dietaryRepository.read().allergies?.map((e) => e.name)}');
      expect(
        AppRouter.dietaryRepository.read().asked,
        isTrue,
        reason: 'her answer on E10 did not reach the profile',
      );

      // Straight to the recipes, the way E10's own link sends her.
      await open(t, appDestinations['E05']!.name, locale: Locale(loc));
      final painted = paintedText(t);
      final taps = tappables(t).map((e) => e.label).toList();
      print('  E05 after: ${painted.length} lines, ${taps.length} controls');
      for (final line in painted) {
        print('  > $line');
      }
      expect(
        painted.where((e) => e.contains('Yoghurt') || e.contains('زبادي')),
        isEmpty,
        reason: 'the nut dish survived a hand-made tree-nut declaration',
      );
      expect(
        taps.where((e) => e.contains('kcal') || e.contains('سعر')),
        isEmpty,
        reason: 'an unchecked dish is still tappable',
      );
      s.dispose();
    });
  }

  for (final loc in <String>['en', 'ar']) {
    testWidgets('Y11: she logs severe symptoms, $loc', (t) async {
      phone(t);
      final s = t.ensureSemantics();

      await open(t, appDestinations['Y01']!.name, locale: Locale(loc));
      await tapControl(
        t,
        RegExp(loc == 'en' ? 'Track periods and symptoms' : 'تتبّع'),
      );
      await tapControl(t, RegExp(loc == 'en' ? 'Continue' : 'متابعة'));
      if (topScreen(t) == 'Y02') {
        await tapControl(
          t,
          RegExp(loc == 'en' ? 'Save preferences' : 'احفظي'),
        );
      }
      nav(t).pushNamed(appDestinations['Y04']!.name);
      await settle(t);
      await tapControl(t, RegExp(loc == 'en' ? 'Severe' : 'شديد'));
      await tapControl(t, RegExp(loc == 'en' ? 'Save check-in' : 'احفظي'));
      print('=== R3-14 Y11 (severe branch) $loc, on ${topScreen(t)} ===');
      for (final line in paintedText(t)) {
        print('  | $line');
      }
      print('  CONTROLS: ${tappables(t).map((e) => e.label).join(" // ")}');

      // The two routes to care, tapped. This is the screen a woman reaches in
      // severe pain, so what these two actually do is the highest-consequence
      // fact in the product.
      for (final care in <String>[
        loc == 'en' ? 'Find care near you' : 'ابحثي عن رعاية قريبة منك',
        loc == 'en' ? 'Read NHS guidance on period pain'
            : 'اقرئي إرشادات NHS عن ألم الدورة',
      ]) {
        final before = paintedText(t).toSet();
        await tapControl(t, care);
        t.takeException();
        final after = paintedText(t).where((e) => !before.contains(e)).toList();
        print('  TAP "$care" -> ${topScreen(t)}  new on screen: '
            '${after.join(" // ")}');
      }
      s.dispose();
    });
  }

  // The day, everywhere, in one pass: no screen may name a different one.
  testWidgets('every screen names the same day', (t) async {
    phone(t);
    final days = <String, Set<String>>{};
    const names = <String>[
      'Monday', 'Tuesday', 'Wednesday', 'Thursday', 'Friday', 'Saturday',
      'Sunday',
    ];
    for (final id in <String>[
      'T01', 'T02', 'T03', 'T04', 'T05', 'R10', 'R12', 'P01', 'E01',
    ]) {
      await open(t, appDestinations[id]!.name, locale: const Locale('en'));
      for (final line in paintedText(t)) {
        for (final n in names) {
          if (line.contains(n)) (days[n] ??= <String>{}).add(id);
        }
      }
    }
    print('=== R3-14 weekday names on screen: '
        '${DateTime.now().weekday} is today ===');
    days.forEach((k, v) => print('  $k: ${v.join(", ")}'));
    expect(days.keys.length, lessThanOrEqualTo(1),
        reason: 'two screens name two different days');
  });
}
