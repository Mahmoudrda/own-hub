// K26 — a draft that looks like a draft, counts itself, and cannot publish.
//
// Two failures are being guarded against, and they pull in opposite directions.
// A screen that renders too little loses the coach's ability to see what she is
// about to accept. A screen that renders too much states a figure nobody
// counted — the design's header says "30 · 18 sessions, 8 rest" whatever the
// draft actually contains. So the counts here are asserted against a fixture
// whose numbers are deliberately not the mockup's.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:own_hub/features/assistant/domain/assistant_wire.dart';
import 'package:own_hub/features/assistant/presentation/draft_view_model.dart';
import 'package:own_hub/features/assistant/presentation/plan_draft_view.dart';
import 'package:own_hub/ui/app_split_row.dart';

import 'assistant_test_host.dart';

final DraftViewModel _drafts = DraftViewModel(pack, l10n: l10n);

/// Four days: two sessions, one rest, and one whose only move is an id the pack
/// does not know.
const PlanDraft _draft = PlanDraft(
  days: [
    PlanDraftDay(kind: PlanDayKind.training, exerciseIds: ['fx_9112_bridge']),
    PlanDraftDay(kind: PlanDayKind.rest),
    PlanDraftDay(
      kind: PlanDayKind.training,
      exerciseIds: ['fx_9112_box_squat'],
    ),
    PlanDraftDay(kind: PlanDayKind.training, exerciseIds: ['fx_9112_invented']),
  ],
);

Future<void> _pump(
  WidgetTester tester,
  PlanDraftScreen screen, {
  VoidCallback? onDiscard,
  VoidCallback? onOpen,
}) async {
  phone(tester);
  await tester.pumpWidget(
    host(
      PlanDraftView(
        screen: screen,
        onDiscard: onDiscard ?? () {},
        onOpenInPlanner: onOpen ?? () {},
      ),
    ),
  );
  await tester.pumpAndSettle();
}

Finder _count(String value) =>
    find.descendant(of: find.byType(AppSplitRow), matching: find.text(value));

void main() {
  group('P0-ASK-11 — it is held, and it says so', () {
    testWidgets('the badge, the warning and the two ways out', (tester) async {
      await _pump(tester, _drafts.plan(_draft));

      expect(find.text(l10n.draft), findsOneWidget);
      expect(find.text(l10n.nothingIsPublishedThisOpensAsA), findsOneWidget);
      expect(find.text(l10n.openInMyPlanner), findsOneWidget);
      expect(find.text(l10n.discardTheDraft), findsOneWidget);
    });

    testWidgets('no control on the screen publishes anything', (tester) async {
      await _pump(tester, _drafts.plan(_draft));

      // The only sentence on screen that may contain the word is the one that
      // says nothing was published.
      for (final line in renderedText(tester)) {
        if (RegExp('publish', caseSensitive: false).hasMatch(line)) {
          expect(
            line,
            l10n.nothingIsPublishedThisOpensAsA,
            reason: 'a publish affordance reached K26: "$line"',
          );
        }
      }
      for (final forbidden in [
        l10n.publishPlan,
        l10n.publishToNour,
        l10n.previewAndPublish,
        l10n.saveFeedbackAndPublishChanges,
      ]) {
        expect(find.text(forbidden), findsNothing);
      }
    });

    testWidgets('discarding is undo, not confirmation — no dialog', (
      tester,
    ) async {
      var discarded = 0;
      await _pump(tester, _drafts.plan(_draft), onDiscard: () => discarded++);

      await tester.tap(find.text(l10n.discardTheDraft));
      await tester.pumpAndSettle();

      expect(discarded, 1);
      expect(find.byType(AlertDialog), findsNothing);
      expect(find.byType(Dialog), findsNothing);
    });
  });

  group('every figure is counted from the structure', () {
    testWidgets(
      'days, sessions and rest are the fixture\'s, not the mockup\'s',
      (tester) async {
        await _pump(tester, _drafts.plan(_draft));

        expect(find.text(l10n.days), findsOneWidget);
        expect(find.text(l10n.sessions), findsOneWidget);

        expect(_count('4'), findsOneWidget, reason: 'four days');
        expect(_count('3'), findsOneWidget, reason: 'three sessions');
        expect(_count('1'), findsOneWidget, reason: 'one rest day');

        // The prototype's header, which states its own numbers to everyone.
        expect(find.text(l10n.n18Sessions8RestDays), findsNothing);
        expect(find.text(l10n.n30Days8SepTo7Oct), findsNothing);
      },
    );

    testWidgets('an empty draft counts nothing and claims nothing', (
      tester,
    ) async {
      await _pump(tester, PlanDraftScreen.empty);

      expect(_count('0'), findsNWidgets(3));
      expect(find.text('fixture bridge'), findsNothing);
      // Still honest about what it is.
      expect(find.text(l10n.nothingIsPublishedThisOpensAsA), findsOneWidget);
    });
  });

  group('the days themselves', () {
    testWidgets('moves are read from the pack, rest days name themselves', (
      tester,
    ) async {
      await _pump(tester, _drafts.plan(_draft));

      expect(find.text('fixture bridge'), findsOneWidget);
      expect(find.text('fixture box squat'), findsOneWidget);
      expect(find.text(l10n.restDay), findsWidgets);
    });

    testWidgets('a day whose moves did not resolve keeps its place, empty', (
      tester,
    ) async {
      final screen = _drafts.plan(_draft);
      await _pump(tester, screen);

      // Four days on screen, numbered 1 to 4. Dropping the fourth would
      // silently shorten the plan and nobody would see it happen.
      expect(screen.dayCount, 4);
      expect(find.text('4'), findsWidgets);
      expect(screen.days.last.moves, isEmpty);
      // And nothing was invented to fill it.
      expect(find.text('fx_9112_invented'), findsNothing);
    });

    testWidgets('only the first week is shown', (tester) async {
      final long = PlanDraftScreen(
        days: [
          for (var i = 0; i < 30; i++)
            PlanDayRow(
              position: i,
              kind: PlanDayKind.training,
              moves: const ['fixture bridge'],
            ),
        ],
        sessionCount: 30,
        restCount: 0,
      );
      await _pump(tester, long);

      expect(long.firstWeek, hasLength(7));
      expect(find.text('fixture bridge'), findsNWidgets(7));
    });
  });

  testWidgets('P0-ASK-18 — the word stays off the screen', (tester) async {
    await _pump(tester, _drafts.plan(_draft));
    for (final line in renderedText(tester)) {
      expect(RegExp(r'\bAI\b').hasMatch(line), isFalse, reason: line);
    }
  });
}
