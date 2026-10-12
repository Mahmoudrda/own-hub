// A coach setting herself up and building her page, in the real app.
//
// Every screen here has its own widget test already. What none of them can
// catch is the thing that was actually broken: the screens worked and nothing
// held what they produced, so her name from `K01` never reached the profile
// `K18` renders and every block editor dropped her words the moment she left
// it. These walks push the real routes and assert against the shared state
// afterwards, which is the only place that gap is visible.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:own_hub/app_state/coach_portfolio_state.dart';
import 'package:own_hub/app_state/coach_profile_state.dart';
import 'package:own_hub/app_state/coaching_link_state.dart';
import 'package:own_hub/app_state/pledge.dart';
import 'package:own_hub/domain/flags/feature_flags.dart';
import 'package:own_hub/features/coachbrand/domain/portfolio_block.dart';
import 'package:own_hub/features/coachbrand/presentation/canvas_view.dart';
import 'package:own_hub/features/coachbrand/presentation/insights_view.dart';
import 'package:own_hub/features/coachbrand/presentation/portfolio_home_view.dart';
import 'package:own_hub/features/coachbrand/presentation/preview_view.dart';
import 'package:own_hub/features/coach/domain/coach_profile.dart';
import 'package:own_hub/features/coach/domain/coach_verification.dart';
import 'package:own_hub/features/coach/domain/offer.dart';
import 'package:own_hub/main.dart';
import 'package:own_hub/routing/app_router.dart';
import 'package:own_hub/ui/app_button.dart';
import 'package:own_hub/ui/app_field.dart';

void main() {
  final savedFlags = AppRouter.featureFlags;

  setUp(() {
    AppRouter.featureFlags = FeatureFlags.allOff.with_({
      for (final f in Feature.values) f: f != Feature.accountRequired,
    });
    CoachProfileState.instance.reset();
    CoachPortfolioState.instance.reset();
    CoachingLinkState.instance.reset();
    PledgeState.instance.reset();
    AppRouter.marketplaceOpenCoachUid = '';
    AppRouter.marketplaceSelectedOfferId = null;
  });

  tearDown(() {
    CoachProfileState.instance.reset();
    CoachPortfolioState.instance.reset();
    CoachingLinkState.instance.reset();
    PledgeState.instance.reset();
    AppRouter.featureFlags = savedFlags;
  });

  testWidgets('K01 to K06: what she types reaches the one profile K18, K07 '
      'and the directory read', (tester) async {
    await _boot(tester);
    await _open(tester, 'K01');

    // K01: her photo is asked for, not demanded.
    await _tap(tester, 'Continue');

    // K08: her name and her city, on a screen of their own.
    await _type(tester, 'Name', 'Hala Mansour');
    await _type(tester, 'City', 'Tanta');
    await _tap(tester, 'Continue');

    // The save, and the whole point of the walk: the form is not the profile,
    // and before this the two never met.
    expect(
      AppRouter.coachRepository.profileUnbilled.displayName,
      'Hala Mansour',
    );
    expect(AppRouter.coachRepository.profileUnbilled.city, 'Tanta');

    // K03: one specialty, which is what lets the step advance.
    await _tap(tester, 'Postpartum');
    await _tap(tester, 'Continue');
    expect(
      AppRouter.coachRepository.profileUnbilled.specialties,
      isNotEmpty,
      reason: 'K03 saved her specialties into the profile K18 renders',
    );

    // K10: how she coaches.
    await _tap(tester, 'Continue');

    // K04: her capacity and one package she wrote herself.
    await _type(tester, 'Clients at once', '10');
    await _tap(tester, 'Add another offer');
    await _type(tester, 'Name', 'Monthly coaching');
    await _type(tester, 'Price a month', '1800');
    await _tap(tester, 'Save');
    expect(AppRouter.coachRepository.allOffers(), hasLength(1));
    expect(AppRouter.coachRepository.allOffers().single.pricePiastres, 180000);
    await _tap(tester, 'Continue');
    expect(AppRouter.coachRepository.profileUnbilled.capacity.max, 10);

    // K11 and K12: the shape of her clients' results and words. Nothing to
    // add yet; only a client can.
    await _tap(tester, 'Continue');
    await _tap(tester, 'Continue');

    // K02: a certificate recorded without a photo, labelled as a test and as
    // read by nobody.
    await _tap(tester, 'Continue');

    // K13: the community's three rules are agreed here, not on C16 (R1-P16).
    await _tap(tester, 'I agree to these three rules');
    await _tap(tester, 'Continue');
    expect(
      PledgeState.instance.agreed,
      isTrue,
      reason: 'her agreement is recorded as C16 records it',
    );

    // K05: the test rail records where she would be paid and pays nobody.
    await _type(tester, 'Full name as on the account', 'Hala Mansour');
    await _type(tester, 'Wallet or account number', '01000000000');
    await _tap(tester, 'Continue');

    // K06 states the honest version of "checked": nobody looked.
    expect(CoachProfileState.instance.isTestCoach, isTrue);
    expect(
      AppRouter.coachRepository.profileUnbilled.verification,
      CoachVerificationState.verified,
    );
    expect(
      find.textContaining('Nobody has looked at your certificates'),
      findsOneWidget,
    );
    // A test coach is counted as checked. Her certificate is not: no badge is
    // claimed anywhere, because nothing cleared one.
    expect(
      CoachProfileState.instance
          .publicProfileModel(DateTime.now())
          .showsVerifiedBadge,
      isFalse,
    );
    // Her package went live with her, through the same editor.
    expect(AppRouter.coachRepository.publicOffers(), hasLength(1));
  });

  testWidgets('B01 to B11: every editor saves, the preview shows it, and '
      'publishing makes a live version', (tester) async {
    await _setUpCoach();
    await _boot(tester);

    // Day one: the page is empty and the one action starts the cover.
    await _open(tester, 'B01');
    expect(find.byType(PortfolioHomeView), findsOneWidget);
    expect(CoachPortfolioState.instance.home.isDayOne, isTrue);
    await _tap(tester, 'Start with a cover');

    // B04. The cover editor had nowhere to save and the page stayed empty.
    // "No photo" first: there is no picker in this build, and a cover laid out
    // over a photo it has not got is refused at publish — correctly.
    await _tap(tester, 'No photo');
    await _type(tester, 'Headline', 'Back to lifting, gently');
    await _tap(tester, 'Done');
    final cover = CoachPortfolioState.instance.draft.blocks.single;
    expect(cover.type, BlockType.cover);
    expect((cover.payload as CoverPayload).headline, 'Back to lifting, gently');
    expect(CoachPortfolioState.instance.home.isDayOne, isFalse);

    // B02 → B03 → a second section, then its editor.
    await _open(tester, 'B02');
    expect(find.byType(PortfolioCanvasView), findsOneWidget);
    await _tap(tester, 'Add a section');
    await _tap(tester, 'How I work');
    expect(CoachPortfolioState.instance.draft.blocks, hasLength(2));

    // B07, reached as its own screen, saves onto the block she opened.
    CoachPortfolioState.instance.editing =
        CoachPortfolioState.instance.draft.blocks.last;
    await _open(tester, 'B07');
    await _tap(tester, 'Add a step');
    // The step fields carry no label — the number beside them is the label —
    // so this one is found by position rather than by a string.
    await tester.enterText(
      find.byType(EditableText).first,
      'We start where you are',
    );
    await tester.pumpAndSettle();
    await _tap(tester, 'Done');
    final method =
        CoachPortfolioState.instance.draft.blocks.last.payload as MethodPayload;
    expect(method.steps.first.title, 'We start where you are');

    // B06: her own packages, switched on by id. The block never holds a price.
    CoachPortfolioState.instance.editing = null;
    await _open(tester, 'B03');
    await _tap(tester, 'What I offer');
    CoachPortfolioState.instance.editing =
        CoachPortfolioState.instance.draft.blocks.last;
    await _open(tester, 'B06');
    await _tap(tester, 'Monthly coaching');
    await _tap(tester, 'Done');
    final offers =
        CoachPortfolioState.instance.draft.blocks.last.payload as OffersPayload;
    expect(offers.offerIds, ['offer-1']);

    // B05: her look is one of the three knobs, validated on the way in and
    // saved onto the same draft. It had no `onThemeChanged` at all before.
    final wasType = CoachPortfolioState.instance.draft.theme.type;
    await _open(tester, 'B05');
    await _tap(tester, 'Strong and wide');
    await _tap(tester, 'Done');
    expect(
      CoachPortfolioState.instance.draft.theme.type,
      isNot(wasType),
      reason: 'B05 saved her look',
    );

    // B10 renders what she built, through the same resolver H02 uses.
    await _open(tester, 'B10');
    expect(find.byType(PreviewView), findsOneWidget);
    expect(find.text('Back to lifting, gently'), findsWidgets);

    // Hiding a block takes it out of the preview and out of a client's page,
    // because both read `visibleBlocks`.
    CoachPortfolioState.instance.setVisible(cover.id, false);
    expect(CoachPortfolioState.instance.draft.visibleBlocks, hasLength(2));
    CoachPortfolioState.instance.setVisible(cover.id, true);

    // B11 publishes, and `live` is written for the first time.
    await _open(tester, 'B11');
    await _tap(tester, 'Publish');
    await tester.pumpAndSettle();
    expect(CoachPortfolioState.instance.refusals, isEmpty);
    expect(CoachPortfolioState.instance.live, isNotNull);
    expect(CoachPortfolioState.instance.live!.version, 1);
    // Publishing is what puts her in the directory, and nothing else does.
    expect(CoachingLinkState.instance.isPublished('coach-1'), isTrue);
  });

  testWidgets('deleting a section can be undone, and reordering is a '
      'permutation', (tester) async {
    await _setUpCoach();
    await _boot(tester);

    final state = CoachPortfolioState.instance;
    final first = state.addSection(BlockType.cover);
    final second = state.addSection(BlockType.method);
    state.reorder(0, 1);
    expect(state.draft.blocks.map((b) => b.id), [second, first]);

    final removed = state.deleteBlock(second);
    expect(state.draft.blocks.map((b) => b.id), [first]);
    state.undoDelete(removed!);
    expect(state.draft.blocks.map((b) => b.id), [
      second,
      first,
    ], reason: 'undo puts her section back where it was, not at the bottom');
  });

  testWidgets('B12 says what it knows, which is nothing, and draws no zeros', (
    tester,
  ) async {
    await _setUpCoach();
    await _boot(tester);
    await _open(tester, 'B12');

    expect(find.byType(InsightsView), findsOneWidget);
    expect(find.textContaining('not measured in this version'), findsOneWidget);
    expect(find.text('0'), findsNothing);
  });
}

/// A coach who has finished setup, so the portfolio walk starts where it would.
Future<void> _setUpCoach() async {
  final setup = CoachProfileState.instance.setup
    ..displayName = 'Hala Mansour'
    ..city = 'Tanta'
    ..capacityMax = 10;
  setup.toggleSpecialty(Specialty.postpartum);
  CoachProfileState.instance.saveSetup();
  await CoachProfileState.instance.packagesEditor.save(
    OfferDraft.validate(
      id: 'offer-1',
      name: 'Monthly coaching',
      pricePiastres: 180000,
    ).draft!,
  );
  CoachProfileState.instance.completeSetup();
}

Future<void> _boot(WidgetTester tester) async {
  await tester.pumpWidget(OwnHubApp(key: UniqueKey()));
  await tester.pumpAndSettle();
}

Future<void> _open(WidgetTester tester, String screenId) async {
  tester
      .state<NavigatorState>(find.byType(Navigator).first)
      .pushNamed(appDestinations[screenId]!.name);
  await tester.pumpAndSettle();
}

/// Types into the field whose label is [label]. Labels rather than positions:
/// a field added above would silently move every index.
Future<void> _type(WidgetTester tester, String label, String text) async {
  final field = find.ancestor(
    of: find.text(label),
    matching: find.byType(AppField),
  );
  expect(field, findsWidgets, reason: 'no field labelled "$label"');
  await tester.ensureVisible(field.first);
  await tester.pumpAndSettle();
  await tester.enterText(
    find.descendant(of: field.first, matching: find.byType(EditableText)),
    text,
  );
  await tester.pumpAndSettle();
}

Future<void> _tap(WidgetTester tester, String label) async {
  // A button wins over a bare label: `B11` titles itself "Publish" and its
  // primary action says the same word, and tapping the title does nothing.
  final inButton = find.descendant(
    of: find.byType(AppButton),
    matching: find.text(label),
  );
  final target = inButton.evaluate().isEmpty ? find.text(label) : inButton;
  expect(target, findsWidgets, reason: 'nothing labelled "$label" on screen');
  await tester.ensureVisible(target.first);
  await tester.pumpAndSettle();
  await tester.tap(target.first, warnIfMissed: false);
  await tester.pumpAndSettle();
}
