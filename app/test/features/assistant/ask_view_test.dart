// X01 — the six states of the one route, as they actually reach a screen.
//
// The view-model tests in `assistant_screens_test.dart` prove what the states
// ARE. These prove what a woman sees in each of them, which is a different
// failure: a perfectly correct `capped` state can still be rendered with a
// spinner, an invented sentence, or an *Ask Sara* button that is disabled
// precisely when it is the only thing that would work.
//
// The sharpest assertions here are still the negative ones. Three of the four
// missing lines have since been minted, so those states now say their own
// sentence — and every one of these tests keeps checking that the near-miss
// strings are STILL absent, because the reason they were refused has not
// changed: each of them promises a queue this feature does not have. The kill
// switch has no line yet and stays silent.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:own_hub/features/assistant/domain/assistant_provider.dart';
import 'package:own_hub/features/assistant/domain/assistant_quota.dart';
import 'package:own_hub/features/assistant/domain/assistant_service.dart';
import 'package:own_hub/features/assistant/domain/assistant_wire.dart';
import 'package:own_hub/features/assistant/domain/safety_classifier.dart';
import 'package:own_hub/features/assistant/presentation/ask_view.dart';
import 'package:own_hub/features/assistant/presentation/ask_view_model.dart';
import 'package:own_hub/ui/app_log_button.dart';

import 'assistant_test_host.dart';

final AskViewModel _view = AskViewModel(pack);

AssistantAnswer _twoAlternatives({String? swapFrom}) => AssistantAnswer(
  answerKey: AnswerKey.groundedAlternatives,
  swapFromExerciseId: swapFrom,
  picks: const [
    AssistantPick(
      kind: PickKind.exercise,
      id: 'fx_9112_bridge',
      source: PickSource.herPlan,
    ),
    AssistantPick(
      kind: PickKind.exercise,
      id: 'fx_9112_box_squat',
      source: PickSource.moveLibrary,
    ),
  ],
);

Future<void> _pump(
  WidgetTester tester,
  AskScreen screen, {
  String? question,
  ValueChanged<SwapProposal>? onSwap,
  VoidCallback? onAskSara,
}) async {
  phone(tester);
  await tester.pumpWidget(
    host(
      AskView(
        screen: screen,
        question: question,
        onSwap: onSwap,
        onAskSara: onAskSara,
        onAsk: (_) {},
      ),
    ),
  );
  await tester.pumpAndSettle();
}

bool _composerEnabled(WidgetTester tester) =>
    tester.widget<TextField>(find.byType(TextField)).enabled ?? true;

bool _askSaraEnabled(WidgetTester tester) {
  final button = find.ancestor(
    of: find.text(l10n.askSaraInstead),
    matching: find.byType(InkWell),
  );
  return tester.widget<InkWell>(button.first).onTap != null;
}

void main() {
  group('P0-ASK-01 — a grounded answer, with its source on the row', () {
    testWidgets('both moves, their details and their provenance', (
      tester,
    ) async {
      await _pump(
        tester,
        _view.from(AssistantAnswered(_twoAlternatives())),
        question: 'fixture question about a knee',
      );

      expect(find.text('fixture bridge'), findsOneWidget);
      expect(find.text('fixture box squat'), findsOneWidget);
      expect(find.text('fixture detail bridge'), findsOneWidget);

      // "An assistant that cannot show its source is indistinguishable from one
      // that guessed."
      expect(find.text(l10n.fromYourPlan), findsOneWidget);
      expect(find.text(l10n.libraryLabel), findsOneWidget);

      // Her words, as she typed them — never the mockup's question.
      expect(find.text('fixture question about a knee'), findsOneWidget);
      expect(find.text(l10n.iHaveSharpPainLowDownAnd), findsNothing);
    });

    testWidgets('the sentence is withheld when its count is not hers', (
      tester,
    ) async {
      // `twoMovesInYourSessionWorkThe` states two. One surviving pick gets the
      // row and no sentence — say less rather than something untrue.
      await _pump(
        tester,
        _view.from(
          const AssistantAnswered(
            AssistantAnswer(
              answerKey: AnswerKey.groundedAlternatives,
              picks: [
                AssistantPick(
                  kind: PickKind.exercise,
                  id: 'fx_9112_bridge',
                  source: PickSource.herPlan,
                ),
              ],
            ),
          ),
        ),
      );

      expect(find.text('fixture bridge'), findsOneWidget);
      expect(find.text(l10n.twoMovesInYourSessionWorkThe), findsNothing);
    });

    testWidgets('the sentence is shown when it is', (tester) async {
      await _pump(tester, _view.from(AssistantAnswered(_twoAlternatives())));
      expect(find.text(l10n.twoMovesInYourSessionWorkThe), findsOneWidget);
    });

    testWidgets('a move with no authored prescription renders no detail', (
      tester,
    ) async {
      await _pump(
        tester,
        _view.from(
          const AssistantAnswered(
            AssistantAnswer(
              answerKey: AnswerKey.groundedAlternatives,
              picks: [
                AssistantPick(
                  kind: PickKind.exercise,
                  id: 'fx_9112_squat',
                  source: PickSource.moveLibrary,
                ),
              ],
            ),
          ),
        ),
      );

      expect(find.text('fixture squat'), findsOneWidget);
      // Nothing stands in for the missing phrase — no dash, no "3 × 10".
      for (final rendered in renderedText(tester)) {
        expect(
          RegExp(r'\d\s*[x×]\s*\d').hasMatch(rendered),
          isFalse,
          reason: 'a prescription nobody authored reached the screen',
        );
      }
    });
  });

  group('P0-ASK-03 — the swap is offered only where there is one', () {
    testWidgets('a control per row, and it proposes rather than applies', (
      tester,
    ) async {
      final proposed = <SwapProposal>[];
      await _pump(
        tester,
        _view.from(
          AssistantAnswered(_twoAlternatives(swapFrom: 'fx_9112_squat')),
        ),
        onSwap: proposed.add,
      );

      expect(find.text(l10n.swap), findsNWidgets(2));
      expect(
        find.text(l10n.swappingChangesTodayOnlyYourPlanFrom),
        findsOneWidget,
      );

      await tester.tap(find.byType(AppLogButton).first);
      await tester.pumpAndSettle();

      // A proposal left this screen. Nothing was written: R05 and G4's swap
      // service are what act on it, after her tap there.
      expect(proposed, hasLength(1));
      expect(proposed.single.fromExerciseId, 'fx_9112_squat');
      expect(proposed.single.toExerciseId, 'fx_9112_bridge');
    });

    testWidgets('no control at all when nothing is being replaced', (
      tester,
    ) async {
      await _pump(tester, _view.from(AssistantAnswered(_twoAlternatives())));

      expect(find.text(l10n.swap), findsNothing);
      expect(find.byType(AppLogButton), findsNothing);
      // And the promise that goes with it is absent too, rather than sitting
      // there being true and irrelevant.
      expect(
        find.text(l10n.swappingChangesTodayOnlyYourPlanFrom),
        findsNothing,
      );
    });
  });

  group('P0-ASK-02 — nothing found names no move and invents no sentence', () {
    testWidgets('no row, and no line stands in for the missing one', (
      tester,
    ) async {
      await _pump(
        tester,
        _view.from(const AssistantAnswered(AssistantAnswer.nothingFound)),
        question: 'fixture question with no answer',
      );

      for (final absent in [
        'fixture bridge',
        'fixture box squat',
        'fixture squat',
      ]) {
        expect(find.text(absent), findsNothing);
      }
      expect(find.text(l10n.twoMovesInYourSessionWorkThe), findsNothing);

      // The state P0-ASK-02 cares most about — "it returns nothing and says
      // so" — now has the sentence that says so. It used to be silent because
      // `kAnswerKeysWithNoDictionaryLine` held this key; the string has been
      // minted and the set is empty.
      expect(find.text(l10n.nothingFoundForThatIWouldRather), findsOneWidget);

      // And it is the minted one, not a borrowed near-miss.
      for (final borrowed in [
        l10n.somethingWentWrongAtOurEndNothing,
        l10n.theLibraryIsOpenAsUsual,
        l10n.tryAgain,
      ]) {
        expect(find.text(borrowed), findsNothing);
      }

      // What does still work is on screen.
      expect(find.text(l10n.askSaraInstead), findsOneWidget);
      expect(_composerEnabled(tester), isTrue);
    });
  });

  group('P0-ASK-07 — no signal, and the inversion that goes with it', () {
    testWidgets('the composer is disabled and Ask Sara is not', (tester) async {
      await _pump(tester, _view.idle(online: false), onAskSara: () {});

      expect(_composerEnabled(tester), isFalse);
      expect(_askSaraEnabled(tester), isTrue);
    });

    testWidgets('no spinner, and no sentence promising a queue', (
      tester,
    ) async {
      await _pump(tester, _view.idle(online: false));

      expect(find.byType(CircularProgressIndicator), findsNothing);
      expect(find.byType(LinearProgressIndicator), findsNothing);

      // "Asking needs a connection." — the asking route's own sentence, and it
      // promises nothing about later.
      expect(find.text(l10n.askingNeedsAConnection), findsOneWidget);
      // Not the drafting one: that belongs to K26/K27.
      expect(find.text(l10n.draftingNeedsAConnection), findsNothing);

      // Every nearby line promises that something was saved and will be sent,
      // and this feature queues nothing. None of them is used.
      for (final borrowed in [
        l10n.youAreOfflineEverythingYouAddIs,
        l10n.waitingForSignal,
        l10n.savedHereUntilYouHaveSignal,
        l10n.weCouldNotReachTheServerYour,
      ]) {
        expect(
          find.text(borrowed),
          findsNothing,
          reason: 'a queue was promised that does not exist',
        );
      }
    });

    testWidgets('today\'s allowance is spent: disabled, and it says so', (
      tester,
    ) async {
      await _pump(
        tester,
        _view.from(const AssistantCapped(QuotaRoute.question)),
        onAskSara: () {},
      );

      expect(_composerEnabled(tester), isFalse);
      expect(_askSaraEnabled(tester), isTrue);
      // The cap copy exists now, and says when it stops being true.
      expect(
        find.text(l10n.youHaveUsedTodaysQuestionsThereWill),
        findsOneWidget,
      );
      // It names no figure, so tightening the cap from 5 to 3 cannot make the
      // sentence a lie.
      expect(
        RegExp(r'\d').hasMatch(l10n.youHaveUsedTodaysQuestionsThereWill),
        isFalse,
        reason: 'a cap sentence that states its own number goes stale the day '
            'Remote Config tightens it',
      );
      // Still not a server error, and still not a spinner.
      expect(find.text(l10n.somethingWentWrongAtOurEndNothing), findsNothing);
      expect(find.byType(CircularProgressIndicator), findsNothing);
    });

    testWidgets('a server-side failure says so without a raw error', (
      tester,
    ) async {
      await _pump(
        tester,
        _view.from(
          const AssistantUnavailable(AssistantUnavailableReason.serverError),
        ),
      );
      expect(find.text(l10n.somethingWentWrongAtOurEndNothing), findsOneWidget);
    });

    testWidgets('the kill switch leaves the boundaries reachable', (
      tester,
    ) async {
      await _pump(
        tester,
        _view.from(
          const AssistantUnavailable(AssistantUnavailableReason.switchedOff),
        ),
      );

      expect(_composerEnabled(tester), isFalse);
      expect(find.text(l10n.askSaraInstead), findsOneWidget);
      // X03's entry point, which is the screen that still works when this one
      // does not.
      expect(find.text(l10n.someQuestionsItWillNotAnswerAnd), findsOneWidget);
      // The kill switch has no sentence, and it does not borrow the offline
      // one: a woman on full signal would be sent to fix the wrong thing.
      expect(find.text(l10n.askingNeedsAConnection), findsNothing);
    });

    testWidgets('Ask Sara is on screen and enabled on every state', (
      tester,
    ) async {
      final screens = <AskScreen>[
        _view.idle(),
        _view.idle(online: false),
        _view.from(AssistantAnswered(_twoAlternatives())),
        _view.from(const AssistantAnswered(AssistantAnswer.nothingFound)),
        _view.from(const AssistantCapped(QuotaRoute.question)),
        for (final category in RefusalCategory.values)
          _view.from(AssistantRefusal(category)),
        for (final reason in AssistantUnavailableReason.values)
          _view.from(AssistantUnavailable(reason)),
      ];

      for (final screen in screens) {
        await _pump(tester, screen, onAskSara: () {});
        expect(
          find.text(l10n.askSaraInstead),
          findsOneWidget,
          reason: '${screen.state.name} hid the human path',
        );
        expect(_askSaraEnabled(tester), isTrue);
      }
    });
  });

  group('rule 17 — the empty state is the onboarding', () {
    testWidgets('it shows what it can be asked, from X03\'s own list', (
      tester,
    ) async {
      await _pump(tester, _view.idle());

      expect(find.text(l10n.findAMoveForYourEquipmentAnd), findsOneWidget);
      expect(
        find.text(l10n.swapTodaysExerciseForAnApprovedAlternative),
        findsOneWidget,
      );
      expect(find.text(l10n.tellYouThePortionOfADish), findsOneWidget);
      expect(_composerEnabled(tester), isTrue);
      // No tour, no overlay.
      expect(find.byType(Dialog), findsNothing);
    });
  });

  group('X02 is a state of this route, not a destination', () {
    testWidgets('a refusal is rendered in the conversation', (tester) async {
      await _pump(
        tester,
        _view.from(const AssistantRefusal(RefusalCategory.medicalDiagnostic)),
        question: 'fixture medical question',
      );

      expect(find.text(l10n.iAmNotAbleToAnswerThat), findsOneWidget);
      expect(find.text(l10n.thisNeedsADoctorNotAnApp), findsOneWidget);
      expect(find.text(l10n.findCareNearYou), findsOneWidget);
      // No suggestion, on any refusal.
      for (final absent in ['fixture bridge', 'fixture box squat']) {
        expect(find.text(absent), findsNothing);
      }
    });
  });

  group('P0-ASK-18 — the word stays off the screen', () {
    testWidgets('nothing X01 renders names the feature that way', (
      tester,
    ) async {
      for (final screen in <AskScreen>[
        _view.idle(),
        _view.from(
          AssistantAnswered(_twoAlternatives(swapFrom: 'fx_9112_squat')),
        ),
        _view.from(const AssistantRefusal(RefusalCategory.emergency)),
        _view.from(const AssistantCapped(QuotaRoute.question)),
      ]) {
        await _pump(tester, screen);
        for (final line in renderedText(tester)) {
          expect(RegExp(r'\bAI\b').hasMatch(line), isFalse, reason: line);
          expect(RegExp(r'A\.\s*I\.').hasMatch(line), isFalse, reason: line);
        }
      }
    });
  });
}
