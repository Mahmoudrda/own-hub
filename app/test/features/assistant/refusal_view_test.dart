// X02 — the four categories, and the two things the screen must never do.
//
// It must not hedge, and it must not borrow. The first is easy to assert: no
// move, no partial answer, no "but generally". The second is the one this file
// exists for — copy C does not exist in the dictionary, and the medical
// sentence sits right next to it looking usable. A screen that reached for it
// would tell a woman asking for something intense despite an injury that her
// question was a medical one, which it is not.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:own_hub/features/assistant/domain/safety_classifier.dart';
import 'package:own_hub/features/assistant/presentation/assistant_copy.dart';
import 'package:own_hub/features/assistant/presentation/refusal_view.dart';

import 'assistant_test_host.dart';

Future<void> _pump(
  WidgetTester tester,
  RefusalCategory category, {
  String? question,
}) async {
  phone(tester);
  await tester.pumpWidget(
    host(
      RefusalView(
        category: category,
        question: question,
        onFindCare: () {},
        onMessageSara: () {},
        onBoundaries: () {},
      ),
    ),
  );
  await tester.pumpAndSettle();
}

void main() {
  group('the refusal itself', () {
    testWidgets('a diagnostic question is declined, not hedged', (
      tester,
    ) async {
      await _pump(
        tester,
        RefusalCategory.medicalDiagnostic,
        question: 'fixture question about a symptom',
      );

      expect(find.text(l10n.iAmNotAbleToAnswerThat), findsOneWidget);
      expect(find.text(l10n.thisNeedsADoctorNotAnApp), findsOneWidget);
      expect(find.text(l10n.findCareNearYou), findsOneWidget);
      expect(find.text(l10n.messageSara), findsOneWidget);

      // Her words, not the mockup's.
      expect(find.text('fixture question about a symptom'), findsOneWidget);
      expect(find.text(l10n.iHaveSharpPainLowDownAnd), findsNothing);

      // The general pain guidance is NOT shown here: she may not have
      // mentioned pain at all.
      expect(
        find.text(l10n.severeOrUnusualPainDeservesMedicalAdvice),
        findsNothing,
      );
    });

    testWidgets('a severe symptom gets the medical guidance too', (
      tester,
    ) async {
      await _pump(tester, RefusalCategory.severeSymptom);

      expect(find.text(l10n.iAmNotAbleToAnswerThat), findsOneWidget);
      expect(
        find.text(l10n.severeOrUnusualPainDeservesMedicalAdvice),
        findsOneWidget,
      );
      // The mockup's own symptom is never restated as though it were hers.
      expect(
        find.text(l10n.bleedingBetweenPeriodsWithSharpPainShould),
        findsNothing,
      );
    });

    testWidgets('nothing was logged and nothing was shared, on all four', (
      tester,
    ) async {
      for (final category in RefusalCategory.values) {
        await _pump(tester, category);
        expect(find.text(l10n.whatIDidWithThatMessage), findsOneWidget);
        expect(
          find.text(l10n.nothingWasLoggedAndNothingWasShared),
          findsOneWidget,
        );
        expect(find.text(l10n.messageSara), findsOneWidget);
      }
    });
  });

  group('P0-ASK-05 — the route to care leads on an emergency', () {
    testWidgets('care sits above the refusal', (tester) async {
      await _pump(tester, RefusalCategory.emergency);

      final care = tester.getTopLeft(find.text(l10n.thisNeedsADoctorNotAnApp));
      final refusal = tester.getTopLeft(find.text(l10n.iAmNotAbleToAnswerThat));
      expect(
        care.dy,
        lessThan(refusal.dy),
        reason: 'on an emergency the route to care leads',
      );
    });

    testWidgets('and follows it everywhere else', (tester) async {
      await _pump(tester, RefusalCategory.severeSymptom);

      final care = tester.getTopLeft(find.text(l10n.thisNeedsADoctorNotAnApp));
      final refusal = tester.getTopLeft(find.text(l10n.iAmNotAbleToAnswerThat));
      expect(care.dy, greaterThan(refusal.dy));
    });
  });

  group('copy C does not exist, and is not substituted', () {
    testWidgets('an unsafe request borrows no sentence and no clinic', (
      tester,
    ) async {
      await _pump(tester, RefusalCategory.unsafeRequest);

      // NOT the medical line: "it is a medical question" would be untrue.
      expect(find.text(l10n.iAmNotAbleToAnswerThat), findsNothing);
      expect(find.text(l10n.thisNeedsADoctorNotAnApp), findsNothing);
      expect(
        find.text(l10n.severeOrUnusualPainDeservesMedicalAdvice),
        findsNothing,
      );
      // Sending her to a clinic for a training request would be as wrong as
      // answering it.
      expect(find.text(l10n.findCareNearYou), findsNothing);

      // What she gets instead: the human path, and the screen that says what
      // this one will and will not do.
      expect(find.text(l10n.messageSara), findsOneWidget);
      expect(find.text(l10n.whatItCanAndCannotDo), findsOneWidget);
    });

    testWidgets('the recorded gap matches what actually resolves', (
      tester,
    ) async {
      for (final category in RefusalCategory.values) {
        expect(
          assistantRefusalLine(l10n, category) == null,
          kRefusalCategoriesWithNoDictionaryLine.contains(category),
          reason:
              '${category.name}: the set of categories with no dictionary '
              'line must match what resolves to null',
        );
      }
    });
  });

  group('what the screen cannot do', () {
    testWidgets('no move, no partial answer, no dialog', (tester) async {
      for (final category in RefusalCategory.values) {
        await _pump(tester, category);

        for (final absent in [
          'fixture bridge',
          'fixture box squat',
          'fixture squat',
        ]) {
          expect(find.text(absent), findsNothing);
        }
        expect(find.text(l10n.twoMovesInYourSessionWorkThe), findsNothing);
        expect(find.byType(AlertDialog), findsNothing);

        for (final line in renderedText(tester)) {
          expect(RegExp(r'\bAI\b').hasMatch(line), isFalse, reason: line);
        }
      }
    });
  });
}
