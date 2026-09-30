// R4-03. O04's rows and the programme selector, held together.
//
// **This file was an evidence artefact expected to FAIL. It is now the guard
// that keeps the defect closed**, which is what its author asked for: "invert it
// when done".
//
// What it found. The fix that closed the life-stage defect removed two clinical
// claims, which was right: "cleared from week six" told a woman when she is
// cleared, and "Safe movements" asserted safety about a body the app has never
// seen. What the commit then said of the replacements was "Both rows now
// describe the training". They did not describe this build's training:
//
//   O04 postpartum : "Pelvic floor first, once your doctor says you are ready"
//   O04 pregnant   : "Gentler movements, nothing on the belly"
//   O04 injury     : "We avoid what hurts, we do not diagnose"
//
// while `starting_program.dart:32-39` states the opposite in as many words:
// "Life stage is recorded here, not filtered here ... this client-side selector
// therefore takes no clinical decision at all." `selectStartingProgram` never
// read `intake.lifeStage`, `kStartingProgramCatalogue` held one entry, and every
// woman was handed `beginner_foundations`. So a pregnant woman was told the app
// would keep movements gentler and put nothing on her belly, and was then given
// the same eight-week beginner programme as everyone else. The old sentence was
// false about medicine; the new one was false about us.
//
// **How it was closed, and why this file no longer hard-codes the answer.**
// `lifeStageShapesTraining()` runs the selector once per life stage and reports
// whether any of them lands somewhere different. `life_stage_view.dart` shows
// the three sentences only while that is true, and shows "We save your answer
// with the rest of your setup. Nothing in your sessions changes from it yet."
// while it is false. The day a postpartum programme is authored and the selector
// reads the field, the promises come back on their own and this file goes on
// passing, because every assertion below is written as an IF AND ONLY IF rather
// than as "the promises are absent".
//
// That is the shape `care_links.dart` uses for Y11 and `statedLine` uses for
// every fixed figure in the product: the sentence is kept, and it is shown to
// the woman it is true of.
@Tags(['qa'])
library;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:own_hub/features/onboarding/domain/intake.dart';
import 'package:own_hub/features/onboarding/domain/starting_program.dart';
import 'package:own_hub/l10n/app_l10n.dart';
import 'package:own_hub/routing/app_router.dart';

import '../round1/round1_harness.dart';

void main() {
  useShippingApp();

  test('lifeStageShapesTraining reports what the selector actually does', () {
    final chosen = <LifeStage, String?>{};
    for (final stage in LifeStage.values) {
      final programme = selectStartingProgram(
        Intake(
          place: TrainingPlace.home,
          days: 3,
          minutes: 15,
          lifeStage: stage,
        ),
      );
      chosen[stage] = programme?.programId;
    }

    // ignore: avoid_print
    print('R4-03 programme by life stage:');
    for (final e in chosen.entries) {
      // ignore: avoid_print
      print('  ${e.key.name.padRight(12)} -> ${e.value}');
    }
    // ignore: avoid_print
    print('R4-03 catalogue size: ${kStartingProgramCatalogue.length}, '
        'lifeStageShapesTraining = ${lifeStageShapesTraining()}');

    // The predicate O04 is gated on has to agree with the table above, or the
    // gate is just another comment. Measured both ways, so neither a selector
    // that starts reading the field nor one that stops can slip past.
    expect(
      lifeStageShapesTraining(),
      chosen.values.toSet().length > 1,
      reason:
          'O04 shows "Pelvic floor first" and "Gentler movements, nothing on '
          'the belly" only while lifeStageShapesTraining() is true. It says '
          '${lifeStageShapesTraining()} and the selector hands out '
          '${chosen.values.toSet()}, so one of the two is lying to that screen.',
    );
  });

  for (final loc in <String>['en', 'ar']) {
    testWidgets('O04 promises training only when there is some, $loc', (t) async {
      phone(t);
      await open(t, appDestinations['O04']!.name, locale: Locale(loc));
      final painted = paintedText(t);

      // Matched by dictionary KEY, in both languages, so a row fixed in
      // English and left in Arabic is a failure rather than a half-pass.
      final shapes = lifeStageShapesTraining();
      final l10n = AppL10n.of(t.element(find.byType(Navigator).first));
      final promises = <String>[
        l10n.pelvicFloorFirstOnceYourDoctorSays,
        l10n.gentlerMovementsNothingOnTheBelly,
        l10n.weAvoidWhatHurtsWeDoNot,
      ];
      final shown = promises.where(painted.contains).toList();

      // ignore: avoid_print
      print('=== R4-03 O04 $loc: lifeStageShapesTraining = $shapes, '
          '${shown.length} of 3 promises painted ===');
      for (final line in painted) {
        // ignore: avoid_print
        print('  | $line');
      }

      if (shapes) {
        expect(
          shown.length,
          3,
          reason:
              'the selector reads her life stage now, so O04 may and must say '
              'what it does with it: ${promises.join(" / ")}',
        );
      } else {
        expect(
          shown,
          isEmpty,
          reason:
              'every life stage is handed the same programme, so these rows '
              'describe training that does not happen: ${shown.join(" / ")}',
        );
        // And the screen still answers the question it asked. An empty row
        // with no explanation is the other way to get this wrong.
        expect(
          painted.contains(l10n.weSaveYourAnswerWithTheRest),
          isTrue,
          reason:
              'O04 asks "Anything we should train around?" and then says '
              'nothing about what happens to the answer',
        );
      }
    });
  }
}
