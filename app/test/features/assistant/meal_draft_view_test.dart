// K27 — 0 invented quantities, asserted at the pixel rather than at the type.
//
// `draft_view_model.dart` already makes an unverified dish carry no figure:
// `kcal`, `proteinG` and `totals` are null, so there is nothing for a widget to
// render even if it tried. This file checks the other half — that the widget
// does not manufacture one anyway, from a zero, a dash, an "about", or a total
// summed across the dishes on screen.
//
// The unverified fixture's numbers (404, 13) exist precisely so their ABSENCE
// can be asserted: the pack knows them, and the screen still must not say them.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:own_hub/features/assistant/domain/assistant_wire.dart';
import 'package:own_hub/features/assistant/presentation/draft_view_model.dart';
import 'package:own_hub/features/assistant/presentation/meal_draft_view.dart';

import 'assistant_test_host.dart';

final DraftViewModel _drafts = DraftViewModel(pack, l10n: l10n);

const MealDraft _draft = MealDraft(
  days: [
    MealDraftDay(
      slots: {
        MealSlot.lunch: ['fx_9112_lentils'],
        MealSlot.dinner: ['fx_9112_unverified'],
      },
    ),
  ],
);

Future<void> _pump(
  WidgetTester tester,
  MealDraftScreen screen, {
  VoidCallback? onDiscard,
}) async {
  phone(tester);
  await tester.pumpWidget(
    host(
      MealDraftView(
        screen: screen,
        onDiscard: onDiscard ?? () {},
        onOpenInPlanner: () {},
      ),
    ),
  );
  await tester.pumpAndSettle();
}

void main() {
  group('P0-ASK-10 — every number came from the food library', () {
    testWidgets('a verified dish renders the pack row\'s own figures', (
      tester,
    ) async {
      await _pump(tester, _drafts.meal(_draft));

      expect(find.text(l10n.lunch), findsOneWidget);
      expect(find.text('fixture lentils'), findsOneWidget);
      // The parameterised dictionary form, filled from the row this dish
      // resolved to — never a fixed string with a number baked into it.
      expect(
        find.text(l10n.kcalKcalProteinGProtein('193', '17')),
        findsOneWidget,
      );
    });

    testWidgets('an unverified dish is offered, and carries no figure', (
      tester,
    ) async {
      await _pump(tester, _drafts.meal(_draft));

      expect(find.text(l10n.dinner), findsOneWidget);
      expect(find.text('fixture unverified dish'), findsOneWidget);
      expect(
        find.text(l10n.kcalKcalProteinGProtein('404', '13')),
        findsNothing,
      );
      for (final line in renderedText(tester)) {
        expect(line.contains('404'), isFalse, reason: line);
        expect(
          RegExp(r'^\s*[-–—]\s*$').hasMatch(line),
          isFalse,
          reason: 'a dash stood in for a figure nobody verified',
        );
      }
    });

    testWidgets('nothing is summed across the dishes', (tester) async {
      await _pump(tester, _drafts.meal(_draft));

      // 193 + 404 = 597, and 17 + 13 = 30. Neither is a number the food
      // library ever stated, so neither may appear.
      for (final line in renderedText(tester)) {
        for (final total in ['597', '30', '92 g', '46 EGP']) {
          expect(
            line.contains(total),
            isFalse,
            reason: 'a total was computed on the model\'s behalf: "$line"',
          );
        }
      }
      expect(find.text(l10n.everyNumberCameFromTheFoodLibrary), findsOneWidget);
      expect(
        find.text(l10n.nothingWasCalculatedADishWithoutVerified),
        findsOneWidget,
      );
    });

    testWidgets('a dish the pack does not know leaves no empty slot', (
      tester,
    ) async {
      await _pump(
        tester,
        _drafts.meal(
          const MealDraft(
            days: [
              MealDraftDay(
                slots: {
                  MealSlot.breakfast: ['fx_9112_invented'],
                },
              ),
            ],
          ),
        ),
      );

      // A "Breakfast" heading with nothing under it tells a coach something was
      // chosen and gives her no way to know what.
      expect(find.text(l10n.breakfast), findsNothing);
      expect(find.text('fx_9112_invented'), findsNothing);
    });
  });

  group('P0-ASK-11 — it is held, and it says so', () {
    testWidgets('the badge, the warning and the two ways out', (tester) async {
      await _pump(tester, _drafts.meal(_draft));

      expect(find.text(l10n.draft), findsOneWidget);
      expect(find.text(l10n.nothingIsPublishedThisOpensAsA), findsOneWidget);
      expect(find.text(l10n.openInTheMealPlanner), findsOneWidget);
      expect(find.text(l10n.discardTheDraft), findsOneWidget);
    });

    testWidgets('no control on the screen publishes anything', (tester) async {
      await _pump(tester, _drafts.meal(_draft));

      for (final line in renderedText(tester)) {
        if (RegExp('publish', caseSensitive: false).hasMatch(line)) {
          expect(line, l10n.nothingIsPublishedThisOpensAsA, reason: line);
        }
      }
    });

    testWidgets('discarding opens no dialog', (tester) async {
      var discarded = 0;
      await _pump(tester, _drafts.meal(_draft), onDiscard: () => discarded++);

      await tester.tap(find.text(l10n.discardTheDraft));
      await tester.pumpAndSettle();

      expect(discarded, 1);
      expect(find.byType(AlertDialog), findsNothing);
    });

    testWidgets('an empty draft shows no slot and still says what it is', (
      tester,
    ) async {
      await _pump(tester, MealDraftScreen.empty);

      for (final slot in [
        l10n.breakfast,
        l10n.lunch,
        l10n.dinner,
        l10n.snack,
      ]) {
        expect(find.text(slot), findsNothing);
      }
      expect(find.text(l10n.nothingIsPublishedThisOpensAsA), findsOneWidget);
    });
  });

  testWidgets('P0-ASK-18 — the word stays off the screen', (tester) async {
    await _pump(tester, _drafts.meal(_draft));
    for (final line in renderedText(tester)) {
      expect(RegExp(r'\bAI\b').hasMatch(line), isFalse, reason: line);
    }
  });
}
