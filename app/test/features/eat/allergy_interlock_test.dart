// The interlock between "we have allergen data" and "we have asked her".
//
// `AppRouter.eatConstraints` is `DietaryConstraints.none`, which does not mean
// "unknown" — it means **asked, and named nothing**. `AllergyGuard.assess()
// short-circuits on it: `if (allergies.isEmpty) return AllergyAssessment.clear`,
// so every food clears unconditionally, including foods whose allergens are
// unknown.
//
// Today that is harmless, and deliberately so: no food in the shipped pack
// carries an allergen, so `unknown` would block everything and `none` blocks
// nothing, and neither is informative. The router documents the trade-off and
// keeps the Eat tab usable.
//
// **The hazard is ordering, not the value.** The moment `foods.allergens[]`
// lands — D12's admin console is explicitly the mechanism, and it is on the
// Phase 2 critical path — but *before* any screen asks her, the guard holds real
// allergen data plus a fabricated claim that she has no allergies. At that
// instant it will clear a dish containing nuts for a woman with a nut allergy,
// silently, with no sheet. That is strictly worse than today, because the guard
// now *looks* live.
//
// The router's comment says fail-closed "goes live with no other change" once a
// capture surface exists. True only if the capture surface lands FIRST, and D3
// assigns that to sign-up / My Profile where nothing implements it yet. The
// dangerous ordering is the likely one.
//
// So this converts an invisible safety regression into a red build. It expires
// by itself: the day `eatConstraints` stops being `none`, it stops asserting
// anything — the same technique `_awaitingInboundScreen` uses in
// `nav_reachability_test.dart`.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:own_hub/features/eat/domain/allergy_guard.dart';
import 'package:own_hub/features/eat/presentation/eat_sample_library.dart';
import 'package:own_hub/l10n/app_l10n.dart';
import 'package:own_hub/routing/app_router.dart';

void main() {
  testWidgets('allergen content and an unasked woman must never ship together', (
    tester,
  ) async {
    // The library is built from the dictionary, so it needs a real AppL10n.
    late AppL10n l10n;
    await tester.pumpWidget(
      MaterialApp(
        localizationsDelegates: AppL10n.localizationsDelegates,
        supportedLocales: AppL10n.supportedLocales,
        home: Builder(
          builder: (context) {
            l10n = AppL10n.of(context);
            return const SizedBox();
          },
        ),
      ),
    );

    final tagged = eatSampleLibrary(l10n).foods
        .where((f) => f.allergens != null)
        .map((f) => f.foodId)
        .toList();

    // `none` is a CLAIM — asked, and named nothing — not an absence.
    final claimsSheWasAsked =
        AppRouter.eatConstraints.allergies?.isEmpty ?? false;

    if (!claimsSheWasAsked) {
      // She is either genuinely asked (real constraints) or explicitly
      // unknown, in which case the guard fails closed on its own and this
      // interlock has nothing left to protect. It has expired.
      return;
    }

    expect(
      tagged,
      isEmpty,
      reason:
          'AppRouter.eatConstraints is DietaryConstraints.none, which asserts '
          'she was asked about allergies and named none — true of nobody, '
          'because no screen collects them. These foods now carry allergen '
          'data: ${tagged.join(', ')}.\n\n'
          'AllergyGuard.assess() short-circuits on an empty allergy set and '
          'clears every food unconditionally, so it will pass a dish '
          'containing an allergen to a woman who has one, with no sheet and '
          'no warning.\n\n'
          'Fix the ORDER, not this test: ship the allergy capture surface '
          '(D3 assigns it to sign-up / My Profile) and feed her real profile '
          'into eatConstraints. Switching eatConstraints to '
          'DietaryConstraints.unknown also clears this, because the guard '
          'then fails closed — at the cost of the acknowledgement sheet, '
          'whose copy now exists (l10n.thisDishHasAllergenYouToldUs, '
          'l10n.notThis, l10n.logItAnyway).',
    );
  });

  test('DietaryConstraints.none is a claim, and unknown is an absence', () {
    // The distinction the interlock above rests on. If these ever collapse into
    // each other, the guard silently stops being able to fail closed.
    expect(DietaryConstraints.none.allergies, isEmpty);
    expect(
      DietaryConstraints.unknown.allergies,
      isNull,
      reason: 'null is unreadable — an empty set is a statement about her',
    );
  });
}
