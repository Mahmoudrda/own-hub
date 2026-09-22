// X03 — the screen that has to render when nothing else does.
//
// Every other assistant test can be made to pass by a widget that quietly needs
// a service. This one cannot: `BoundariesView` is handed an
// `AssistantBoundaries` and nothing else, and the test that matters most pumps
// it with the feature switched off and expects the content — all eight lines —
// to be identical.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:own_hub/features/assistant/presentation/assistant_boundaries.dart';
import 'package:own_hub/features/assistant/presentation/boundaries_view.dart';

import 'assistant_test_host.dart';

final AssistantBoundaries _boundaries = assistantBoundaries(l10n);

Future<void> _pump(WidgetTester tester, {bool switchedOff = false}) async {
  phone(tester);
  await tester.pumpWidget(
    host(
      BoundariesView(
        boundaries: _boundaries,
        switchedOff: switchedOff,
        onAsk: () {},
        onAskSara: () {},
      ),
    ),
  );
  await tester.pumpAndSettle();
}

void main() {
  group('two lists, both on screen', () {
    testWidgets('every ability and every limit is rendered', (tester) async {
      await _pump(tester);

      expect(find.text(_boundaries.canHeading), findsOneWidget);
      expect(find.text(_boundaries.cannotHeading), findsOneWidget);

      for (final ability in AssistantAbility.values) {
        expect(
          find.text(_boundaries.can[ability]!),
          findsOneWidget,
          reason: '${ability.name} was not rendered',
        );
      }
      for (final limit in AssistantLimit.values) {
        expect(
          find.text(_boundaries.cannot[limit]!),
          findsOneWidget,
          reason: '${limit.name} was not rendered',
        );
      }

      expect(find.text(_boundaries.whatLeavesYourPhoneHeading), findsOneWidget);
      expect(find.text(_boundaries.whatLeavesYourPhoneBody), findsOneWidget);
    });

    testWidgets('the cannot list is drawn with crosses, the can with ticks', (
      tester,
    ) async {
      await _pump(tester);
      expect(
        find.byIcon(Icons.check),
        findsNWidgets(AssistantAbility.values.length),
      );
      expect(
        find.byIcon(Icons.close),
        findsNWidgets(AssistantLimit.values.length),
      );
    });
  });

  group('G15 §2.4 — it stays readable at the off rung', () {
    testWidgets('switched off, every line is still there', (tester) async {
      await _pump(tester, switchedOff: true);

      for (final ability in AssistantAbility.values) {
        expect(find.text(_boundaries.can[ability]!), findsOneWidget);
      }
      for (final limit in AssistantLimit.values) {
        expect(find.text(_boundaries.cannot[limit]!), findsOneWidget);
      }
      expect(find.text(_boundaries.whatLeavesYourPhoneBody), findsOneWidget);
    });

    testWidgets('only the action changes: Ask Sara replaces Ask something', (
      tester,
    ) async {
      await _pump(tester);
      expect(find.text(_boundaries.askCta), findsOneWidget);
      expect(find.text(l10n.askSaraInstead), findsNothing);

      await _pump(tester, switchedOff: true);
      // X01's entry point is replaced by the human path; a CTA that opened a
      // screen which cannot answer would be the dishonest half of the ladder.
      expect(find.text(_boundaries.askCta), findsNothing);
      expect(find.text(l10n.askSaraInstead), findsOneWidget);
    });

    testWidgets('it asks nothing of the network', (tester) async {
      // Asserted on the model the widget is built from: no service, no pack,
      // no connectivity is reachable from this screen.
      expect(_boundaries.needsNetwork, isFalse);
      expect(_boundaries.readableWhenSwitchedOff, isTrue);
      expect(_boundaries.cannotListIsNotShorter, isTrue);

      await _pump(tester, switchedOff: true);
      expect(find.byType(CircularProgressIndicator), findsNothing);
    });
  });

  testWidgets('P0-ASK-18 — nothing it renders names the feature that way', (
    tester,
  ) async {
    await _pump(tester);
    for (final line in renderedText(tester)) {
      expect(RegExp(r'\bAI\b').hasMatch(line), isFalse, reason: line);
      expect(RegExp(r'A\.\s*I\.').hasMatch(line), isFalse, reason: line);
    }
  });
}
