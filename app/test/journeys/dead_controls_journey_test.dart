// Controls a tester taps and nothing happens.
//
// The tap crawler (`test/qa/tap_crawler_test.dart`) found no crashes and no
// unbuilt screens, and a list of controls that render, look live, and change
// nothing anyone could see. A control that looks tappable and does nothing
// reads as broken whatever the reason behind it, so each one here is either
// made to do the real thing or replaced by a screen that says plainly there is
// nothing to do yet.
//
// These walk the real app rather than the widgets: most of these controls were
// already correct in isolation and inert once routed, which is exactly the gap
// a view test cannot see. The assertions are made the way the crawler makes
// them — off the semantics tree — because "shows as chosen" has to be true for
// a woman who cannot see the ring.

import 'dart:ui' show Tristate;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:own_hub/app_state/coach_portfolio_state.dart';
import 'package:own_hub/app_state/coaching_desk_state.dart';
import 'package:own_hub/app_state/coaching_link_state.dart';
import 'package:own_hub/domain/flags/feature_flags.dart';
import 'package:own_hub/features/admin/domain/content_schema.dart';
import 'package:own_hub/features/coachbrand/domain/portfolio_block.dart';
import 'package:own_hub/features/coaching/domain/coaching_repository.dart'
    show EnquiryDraft;
import 'package:own_hub/features/coachbrand/domain/portfolio_theme.dart';
import 'package:own_hub/features/coachbrand/presentation/portfolio_view.dart';
import 'package:own_hub/features/coachplan/presentation/no_client_view.dart';
import 'package:own_hub/features/community/presentation/community_widgets.dart';
import 'package:own_hub/main.dart';
import 'package:own_hub/routing/app_router.dart';
import 'package:own_hub/ui/app_button.dart';

Future<void> _open(WidgetTester tester, String id) async {
  await tester.pumpWidget(OwnHubApp(key: UniqueKey()));
  await tester.pumpAndSettle();
  tester
      .state<NavigatorState>(find.byType(Navigator).first)
      .pushNamed(appDestinations[id]!.name);
  await tester.pumpAndSettle();
}

/// Whether the node a screen reader would land on says it is the chosen one.
///
/// `Tristate.none` would mean the control never says anything about being
/// chosen at all, which is the defect this file is about — so it is compared
/// against `isTrue` rather than read as a boolean.
bool _selected(WidgetTester tester, Pattern label) =>
    find.semantics
        .byLabel(label)
        .evaluate()
        .first
        .getSemanticsData()
        .flagsCollection
        .isSelected ==
    Tristate.isTrue;

/// Tapped the way the crawler taps: through the semantics action, so a control
/// that a screen reader cannot reach cannot pass this.
Future<void> _tap(WidgetTester tester, Pattern label) async {
  tester.semantics.tap(find.semantics.byLabel(label));
  await tester.pumpAndSettle();
}

void main() {
  final saved = AppRouter.featureFlags;

  void reset() {
    CoachPortfolioState.instance.reset();
    CoachingDeskState.instance.reset();
    CoachingLinkState.instance.reset();
    AppRouter.adminImportCollection = ContentCollection.foods;
  }

  setUp(() {
    AppRouter.featureFlags = FeatureFlags.allOff.with_({
      for (final f in Feature.values) f: f != Feature.accountRequired,
    });
    reset();
  });

  tearDown(() {
    AppRouter.featureFlags = saved;
    reset();
  });

  group('B05 — her look is a choice that is recorded', () {
    testWidgets('a palette, a typeface and a corner each show as chosen', (
      tester,
    ) async {
      final semantics = tester.ensureSemantics();
      await _open(tester, 'B05');

      // The starter: the product's own primary, calm type, soft corners. Each
      // swatch is named, or the six palettes are six identical circles to
      // anyone listening to the screen.
      expect(_selected(tester, 'Rose'), isTrue);
      expect(_selected(tester, 'Teal'), isFalse);

      await _tap(tester, 'Teal');
      expect(_selected(tester, 'Teal'), isTrue);
      expect(_selected(tester, 'Rose'), isFalse);

      await _tap(tester, RegExp('Strong and wide'));
      expect(_selected(tester, RegExp('Strong and wide')), isTrue);
      expect(_selected(tester, RegExp('Calm and plain')), isFalse);

      await _tap(tester, RegExp(r'^Sharp$'));
      expect(_selected(tester, RegExp(r'^Sharp$')), isTrue);
      expect(_selected(tester, RegExp(r'^Soft$')), isFalse);

      semantics.dispose();
    });

    testWidgets('and it is her page that changed, not the screen', (
      tester,
    ) async {
      final semantics = tester.ensureSemantics();
      await _open(tester, 'B05');

      await _tap(tester, 'Purple');
      await _tap(tester, RegExp('Soft and round'));
      await _tap(tester, RegExp(r'^Round$'));

      // Written onto the draft through the canvas, not held in the screen.
      final draft = CoachPortfolioState.instance.draft;
      expect(draft.theme.seed.toUpperCase(), '#7A4A7E');
      expect(draft.theme.type, PortfolioType.soft);
      expect(draft.theme.corners, PortfolioCorners.round);

      // And it is still hers when she comes back to the editor.
      await _open(tester, 'B05');
      expect(_selected(tester, 'Purple'), isTrue);
      expect(_selected(tester, RegExp(r'^Round$')), isTrue);

      semantics.dispose();
    });

    testWidgets('the page a client would see is drawn in it', (tester) async {
      final semantics = tester.ensureSemantics();
      // A page with something on it, so the preview has a block to draw.
      CoachPortfolioState.instance.addSection(BlockType.cover);

      await _open(tester, 'B05');
      await _tap(tester, 'Blue');
      await _tap(tester, RegExp(r'^Sharp$'));

      await _open(tester, 'B10');
      final view = tester.widget<PortfolioView>(find.byType(PortfolioView));
      expect(view.portfolio.page.theme.seed.toUpperCase(), '#4A5B8C');
      expect(view.portfolio.page.theme.corners, PortfolioCorners.sharp);

      semantics.dispose();
    });
  });

  group('the planner opened without a client', () {
    testWidgets('W03, W04 and W06 say she has no clients yet', (tester) async {
      expect(CoachingDeskState.instance.clients, isEmpty);

      for (final id in ['W03', 'W04', 'W06']) {
        await _open(tester, id);
        expect(
          find.byType(NoClientYetView),
          findsOneWidget,
          reason: '$id has no month to write, so it offers no chips',
        );
        expect(find.text('No clients yet'), findsOneWidget, reason: id);
      }
    });

    testWidgets('and the empty state leads to her roster', (tester) async {
      await _open(tester, 'W04');
      await tester.tap(find.text('No clients yet'));
      await tester.pumpAndSettle();

      expect(find.text('Worth doing before your first client'), findsOneWidget);
    });

    testWidgets('with a woman on the roster the chips write her month', (
      tester,
    ) async {
      final desk = CoachingDeskState.instance;
      final link = CoachingLinkState.instance;
      link.send(
        EnquiryDraft(
          coachUid: desk.coachUid,
          clientUid: CoachingLinkState.clientUid,
          herWords: 'I had a baby four months ago.',
        ),
      );
      desk.acceptEnquiry(link.relIdWith(desk.coachUid));
      expect(desk.clients, isNotEmpty);
      expect(desk.openClient, isNull, reason: 'nobody has been tapped');

      await _open(tester, 'W04');
      expect(find.byType(NoClientYetView), findsNothing);

      // 35 is only on the minutes row and 60 only on the rest row, so neither
      // tap can land on the other.
      await tester.tap(find.text('35'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('60'));
      await tester.pumpAndSettle();

      final workout = desk
          .draftFor(desk.client.clientUid)
          .dayAt(AppRouter.coachPlanDayKey)
          ?.workout;
      expect(workout?.minutes, 35);
      expect(workout?.restBetweenSetsSec, 60);
    });
  });

  group('Z08 — the import tabs switch the collection', () {
    testWidgets('the expected columns follow the tab', (tester) async {
      await _open(tester, 'Z08');

      // Foods is where the console opens, and the table under the tabs is read
      // off that collection's schema.
      expect(find.text('kcal'), findsOneWidget);
      expect(find.text('equipment'), findsNothing);

      await tester.tap(find.text('Exercises'));
      await tester.pumpAndSettle();

      expect(AppRouter.adminImportCollection, ContentCollection.exercises);
      expect(find.text('equipment'), findsOneWidget);
      expect(find.text('kcal'), findsNothing);
    });
  });

  group('Z11 — export says what it actually did', () {
    testWidgets('it copies the CSVs and reports how many', (tester) async {
      await _open(tester, 'Z11');

      await tester.tap(find.text('Export the content library'));
      await tester.pumpAndSettle();

      // Four collections ticked by default, so four CSVs — and it says the
      // part that is missing rather than implying a file landed somewhere.
      expect(find.byType(SnackBar), findsOneWidget);
      expect(
        find.textContaining('CSV files copied to the clipboard: 4'),
        findsOneWidget,
      );
      expect(
        find.textContaining('Saving files is not connected'),
        findsOneWidget,
      );
    });
  });

  group('C07 — the code screen answers', () {
    AppButton buttonNamed(WidgetTester tester, String label) =>
        tester.widget<AppButton>(find.widgetWithText(AppButton, label));

    testWidgets('Continue is offered only once six digits are in', (
      tester,
    ) async {
      await _open(tester, 'C07');

      expect(
        buttonNamed(tester, 'Continue').onPressed,
        isNull,
        reason: 'an empty code is not something to continue with',
      );

      await tester.enterText(find.byType(TextField), '4172');
      await tester.pumpAndSettle();
      expect(buttonNamed(tester, 'Continue').onPressed, isNull);

      await tester.enterText(find.byType(TextField), '417293');
      await tester.pumpAndSettle();

      // Six digits still check themselves without her pressing anything — that
      // half of the screen's promise is unchanged, and it is pinned against
      // the fake in the C07 view test.
      //
      // What the check ANSWERS changed when the router's auth became
      // `FirebaseAuthRepository`. Pushed straight to C07 in a widget test
      // there is no Firebase behind it and no message was ever sent, so the
      // repository holds nothing to check these digits against and refuses
      // them. Staying here is therefore the correct outcome: advancing on a
      // code that was never sent is the defect, not the fix.
      expect(find.text('Type the code'), findsOneWidget);

      // And the refusal is VISIBLE, which is what this file exists to catch.
      // C07 carries no wrong-code copy yet, so the boxes emptying is the whole
      // answer: six digits went in and were handed back. A screen that still
      // showed them would be precisely the inert control this journey hunts.
      for (final digit in ['4', '1', '7', '2', '9', '3']) {
        expect(find.text(digit), findsNothing, reason: digit);
      }
      expect(
        buttonNamed(tester, 'Continue').onPressed,
        isNull,
        reason: 'the gate holds: emptied boxes are not something to continue with',
      );
    });

    testWidgets('"Send it again" answers, and names no code', (tester) async {
      await _open(tester, 'C07');

      // This asserted the opposite until the router's auth became
      // `FirebaseAuthRepository`: the screen printed the one code the fake
      // accepts, and the test pinned it, because without it the sign-up chain
      // could not be walked by hand.
      //
      // That card was never a feature. It comes from `testCodeOf`, which names
      // a code only for `FakeAuthRepository` and answers null for anything
      // else — against a real provider there is no such code, only the one in
      // the message she was sent. So nothing is printed here even with the
      // testing aids switched on, which is the seam, not the flag, and it is
      // what `release_readiness_test.dart` demands of a shipped build. The
      // fake's own code is still pinned, against the fake, in
      // `test/features/signup/firebase_auth_repository_test.dart`.
      expect(find.textContaining('Test build'), findsNothing);
      expect(find.textContaining('417293'), findsNothing);

      await tester.tap(find.text('Send it again'));
      await tester.pumpAndSettle();

      // The control answers, which is this file's whole subject.
      expect(find.byType(SnackBar), findsOneWidget);

      final said = find
          .descendant(of: find.byType(SnackBar), matching: find.byType(Text))
          .evaluate()
          .map((element) => (element.widget as Text).data ?? '')
          .where((line) => line.trim().isNotEmpty);
      expect(
        said,
        isNotEmpty,
        reason: 'a notice with no words in it is a control that did nothing',
      );

      // And it does not lie. Pushed straight to C07 there is no number behind
      // the screen and nothing has been sent, so a notice promising a code is
      // on its way would be the worse defect of the two: she would sit waiting
      // for a message that cannot arrive.
      expect(
        find.descendant(
          of: find.byType(SnackBar),
          matching: find.textContaining('on its way'),
        ),
        findsNothing,
      );
    });
  });

  group('the two the crawler found last', () {
    testWidgets('X01 offers no composer while nothing is connected', (
      tester,
    ) async {
      await _open(tester, 'X01');

      // The assistant is not wired to anything in this build, so a live
      // composer would take a question that has nowhere to go. The send
      // control is named as well as disabled, because an icon reads as
      // nothing at all.
      final send = tester.widget<IconButton>(
        find.widgetWithIcon(IconButton, Icons.send),
      );
      expect(send.onPressed, isNull);
      expect(send.tooltip, 'Send');
      expect(tester.widget<TextField>(find.byType(TextField)).enabled, isFalse);

      // And the path that does work is untouched.
      expect(find.text('Ask Sara instead'), findsOneWidget);
    });

    testWidgets('M12 offers no like or save when there is no moment', (
      tester,
    ) async {
      await _open(tester, 'M12');

      final bar = tester.widget<PostActionBar>(find.byType(PostActionBar));
      expect(bar.onLike, isNull, reason: 'there is no parent post to like');
      expect(bar.onSave, isNull);
      // Named all the same, so the two controls are not "0" and nothing.
      expect(bar.likeLabel, 'Like');
      expect(bar.saveLabel, 'Save');
    });
  });
}
