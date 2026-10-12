// ignore_for_file: avoid_print
//
// R3-15. She declared an allergy. Can she still use the Eat tab?
//
// The guard now takes every dish off E05 for anyone who declares anything,
// because nothing in the pack has been checked. That is the right direction to
// be wrong in. The question this case asks is the other half: what is LEFT. If
// the log path is refused too, a woman who answers E10 honestly has an Eat tab
// that cannot do anything, and nobody has walked that.
@Tags(['qa'])
library;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:own_hub/features/account/domain/dietary_profile.dart';
import 'package:own_hub/routing/app_router.dart';

import '../round1/round1_harness.dart';

void main() {
  useShippingApp();

  for (final loc in <String>['en', 'ar']) {
    testWidgets('she declares sesame, then tries to log a meal, $loc', (t) async {
      phone(t);
      final s = t.ensureSemantics();
      await AppRouter.dietaryRepository.save(
        allergies: <AllergenTag>{AllergenTag.sesame},
      );

      for (final id in <String>['E01', 'E02', 'E03', 'E04', 'E07', 'E08']) {
        await open(t, appDestinations[id]!.name, locale: Locale(loc));
        print('=== R3-15 $id $loc ===');
        for (final line in paintedText(t)) {
          print('  | $line');
        }
        print('  CONTROLS: ${tappables(t).map((e) => e.label).join(" // ")}');
      }

      // The type-a-meal path, walked.
      await open(t, appDestinations['E02']!.name, locale: Locale(loc));
      final fields = find.byType(TextField);
      if (fields.evaluate().isNotEmpty) {
        await t.enterText(fields.first, loc == 'en' ? 'ful' : 'فول');
        await settle(t);
        print('  E02 after typing: '
            '${tappables(t).map((e) => e.label).join(" // ")}');
        for (final line in paintedText(t)) {
          print('  > $line');
        }
      } else {
        print('  E02 has no text field');
      }
      s.dispose();
    });
  }
}
