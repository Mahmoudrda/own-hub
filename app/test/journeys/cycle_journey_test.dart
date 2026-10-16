// My cycle, walked through the real app — the symptom-only path in particular.
//
// Every cycle widget test hands `CycleHubView` a `cycle:` and a `checkIn:`, and
// all of them passed while Y14 — the branch a woman who tracks symptoms and no
// dates lands on — rendered **no gentler option at all**. She could report no
// energy and moderate cramps and the screen would answer with her planned
// session and the line "Nothing changes until you tell us how you feel", which
// she just had.
//
// Two things were wrong and both are walked here rather than constructed:
//
//   * the branch drew no card, however she felt; and
//   * `completeSetup` writes `CycleAdaptation.allOff`, so the card is gated on
//     a consent that **only Y02 asks for** — and the symptom-only path goes
//     Y01 → Y03, never through Y02. The consent could not be given.
//
// The negative control at the bottom is the important one: severe cramps must
// still produce the care branch and no workout anywhere, symptom-only or not.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:own_hub/app_state/cycle_state.dart';
import 'package:own_hub/domain/flags/feature_flags.dart';
import 'package:own_hub/main.dart';
import 'package:own_hub/routing/app_router.dart';
import 'package:own_hub/ui/app_toggle.dart';

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

Future<void> _tap(WidgetTester tester, Finder target) async {
  await tester.ensureVisible(target.first);
  await tester.pumpAndSettle();
  await tester.tap(target.first);
  await tester.pumpAndSettle();
}

/// Y01, choosing symptoms only — the whole path, not a repository call.
Future<void> _setUpSymptomsOnly(WidgetTester tester) async {
  await _open(tester, 'Y01');
  await _tap(tester, find.text('Track symptoms only'));
  await _tap(tester, find.text('Continue'));
  expect(
    find.text('Your check-in guides today'),
    findsOneWidget,
    reason: 'symptom-only setup lands on Y14, the branch of Y03',
  );
}

/// Y04, logging what she feels and saving it.
Future<void> _checkIn(
  WidgetTester tester, {
  required String energy,
  required String cramps,
}) async {
  await _tap(tester, find.text('How are you feeling?'));
  await _tap(tester, find.text(energy));
  await _tap(tester, find.text('Cramps, appetite, sleep and more'));
  await _tap(tester, find.text(cramps).first);
  await _tap(tester, find.text('Save check-in'));
}

void main() {
  final saved = AppRouter.featureFlags;

  setUp(() {
    AppRouter.featureFlags = FeatureFlags.allOff.with_({
      for (final f in Feature.values) f: f != Feature.accountRequired,
    });
    CycleAppState.instance.reset();
  });

  tearDown(() {
    CycleAppState.instance.reset();
    AppRouter.featureFlags = saved;
  });

  group('symptom-only mode', () {
    testWidgets('a bad day is offered the gentler option, once she has '
        'been asked', (tester) async {
      _phone(tester);
      await _boot(tester);
      await _setUpSymptomsOnly(tester);

      // Nothing logged: there is nothing to suggest, and the screen says so
      // rather than offering an easier session to a woman who feels fine.
      expect(find.text('A gentler option today'), findsNothing);
      expect(
        find.text('Show workout suggestions'),
        findsOneWidget,
        reason: 'Y02 asks this on the dates path; Y14 is where this path can',
      );

      await _checkIn(tester, energy: 'Low', cramps: 'Moderate');

      // Still nothing, and for the right reason: she has not said the app may
      // change her training. The product does not adapt unasked.
      expect(
        find.text('A gentler option today'),
        findsNothing,
        reason: 'adaptation is off until she turns it on',
      );

      await _tap(tester, find.byType(AppToggle));

      expect(
        find.text('A gentler option today'),
        findsOneWidget,
        reason: 'the same card the dates path draws, from the same suggestion',
      );
      expect(
        find.text('Energy: Low · Cramps: Moderate'),
        findsOneWidget,
        reason: 'the card names what SHE logged, not the mockup pair',
      );
      expect(
        find.text('Show workout suggestions'),
        findsNothing,
        reason: 'answered; the row stops asking',
      );

      // The same three choices, and the same explanation, as anyone else.
      await _tap(tester, find.text('View option'));
      expect(find.text('Use this option'), findsOneWidget);
      expect(find.text('Keep my workout'), findsOneWidget);
      expect(find.text('Rest today'), findsOneWidget);

      await _tap(tester, find.text('Why this suggestion?'));
      expect(
        find.text('Energy: Low · Cramps: Moderate'),
        findsWidgets,
        reason: 'Y05 reads back her symptoms, not nobody\'s',
      );
    });

    testWidgets('keeping her own workout stops the card asking', (
      tester,
    ) async {
      _phone(tester);
      await _boot(tester);
      await _setUpSymptomsOnly(tester);
      await _checkIn(tester, energy: 'Low', cramps: 'Moderate');
      await _tap(tester, find.byType(AppToggle));

      expect(find.text('A gentler option today'), findsOneWidget);
      await _tap(tester, find.text('Keep mine'));

      expect(
        find.text('A gentler option today'),
        findsNothing,
        reason: 'she answered; asking again is nagging',
      );
      expect(
        find.text('Your planned workout'),
        findsOneWidget,
        reason: 'her session stands, unchanged',
      );
    });

    testWidgets('severe cramps go to care, not to a gentler option', (
      tester,
    ) async {
      // The negative control for the fix above. §2.5: severe is severe in
      // every mode, and no workout affordance may appear anywhere.
      _phone(tester);
      await _boot(tester);
      await _setUpSymptomsOnly(tester);
      await _checkIn(tester, energy: 'Low', cramps: 'Severe');

      expect(
        find.text('This needs more than a workout change'),
        findsOneWidget,
      );
      expect(find.text('Find care near you'), findsOneWidget);
      for (final forbidden in [
        'A gentler option today',
        'View option',
        'Your planned workout',
        'Show workout suggestions',
      ]) {
        expect(
          find.text(forbidden),
          findsNothing,
          reason: 'severe removes the workout entirely. Found "$forbidden"',
        );
      }
    });
  });
}
