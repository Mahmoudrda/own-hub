// Browsing, asking and paying, in the real app.
//
// The marketplace had no way of being anything but empty: `H01` was handed
// `DirectorySnapshot.unavailable()`, `H02` was handed `page: null`, `H03` had
// no offers and no coach who was accepting anyone, and `H04`'s send was
// unwired. Nothing here seeds a coach to fix that. The coach in these walks is
// the one the tester sets up and publishes herself — which is the only honest
// way a row can appear, and the reason `H01` is empty until she does.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:own_hub/app_state/coach_portfolio_state.dart';
import 'package:own_hub/app_state/coach_profile_state.dart';
import 'package:own_hub/app_state/coaching_link_state.dart';
import 'package:own_hub/domain/flags/feature_flags.dart';
import 'package:own_hub/features/coach/domain/coach_profile.dart';
import 'package:own_hub/features/coach/domain/offer.dart';
import 'package:own_hub/features/coachbrand/domain/portfolio_block.dart';
import 'package:own_hub/features/coaching/domain/coaching_repository.dart';
import 'package:own_hub/features/coaching/domain/marketplace_stage.dart';
import 'package:own_hub/features/coaching/domain/payment_provider.dart';
import 'package:own_hub/features/coaching/domain/payment_state_machine.dart';
import 'package:own_hub/features/coached/presentation/coaching_intake_view.dart';
import 'package:own_hub/features/coaching/presentation/coach_profile_view.dart';
import 'package:own_hub/features/coaching/presentation/find_a_coach_view.dart';
import 'package:own_hub/features/coaching/presentation/packages_view.dart';
import 'package:own_hub/main.dart';
import 'package:own_hub/routing/app_router.dart';
import 'package:own_hub/ui/app_button.dart';
import 'package:own_hub/ui/app_field.dart';

const String _coachUid = 'coach-1';

void main() {
  final savedFlags = AppRouter.featureFlags;

  setUp(() {
    AppRouter.featureFlags = FeatureFlags.allOff.with_({
      for (final f in Feature.values) f: f != Feature.accountRequired,
    });
    CoachProfileState.instance.reset();
    CoachPortfolioState.instance.reset();
    CoachingLinkState.instance.reset();
    AppRouter.marketplaceOpenCoachUid = '';
    AppRouter.marketplaceSelectedOfferId = null;
  });

  tearDown(() {
    CoachProfileState.instance.reset();
    CoachPortfolioState.instance.reset();
    CoachingLinkState.instance.reset();
    AppRouter.featureFlags = savedFlags;
  });

  testWidgets('H01 lists nobody until a page is published, and says why', (
    tester,
  ) async {
    await _boot(tester);
    await _open(tester, 'H01');

    expect(find.byType(FindACoachView), findsOneWidget);
    expect(CoachingLinkState.instance.snapshot.rows, isEmpty);
    // Not "we could not load": the pack loaded and holds nobody, and the
    // screen says that coaches appear here once they publish.
    expect(
      find.textContaining('coaches set up on this phone appear here'),
      findsOneWidget,
    );
    // And it does not repeat the product's promise that every coach here has
    // been checked, because in this build nobody has.
    expect(
      find.textContaining('verified woman with checked certificates'),
      findsNothing,
    );
  });

  testWidgets('she finds her own published page, filters it, and reads it', (
    tester,
  ) async {
    await _publishACoach();
    await _boot(tester);
    await _open(tester, 'H01');

    expect(find.text('Hala Mansour'), findsOneWidget);
    expect(find.textContaining('1,800'), findsWidgets);

    // A facet she does not work in takes her out of the list; taking it off
    // brings her back. Filtering is local — the pack is fetched once.
    await _tap(tester, 'Strength');
    expect(find.text('Hala Mansour'), findsNothing);
    await _tap(tester, 'Strength');
    expect(find.text('Hala Mansour'), findsOneWidget);

    // Her own page, rendered from her own blocks through the resolver B10 uses.
    await _tap(tester, 'Hala Mansour');
    expect(find.byType(CoachProfileView), findsOneWidget);
    expect(AppRouter.marketplaceOpenCoachUid, _coachUid);
    expect(find.text('Back to lifting, gently'), findsWidgets);
    // Nobody rated her and nobody checked her papers, so neither is claimed.
    expect(find.textContaining('★'), findsNothing);
  });

  testWidgets('enquiry first, then the test rail, and she becomes her client', (
    tester,
  ) async {
    await _publishACoach();
    await _boot(tester);
    await _open(tester, 'H01');
    await _tap(tester, 'Hala Mansour');

    // H03 before anybody accepted: her package is readable, and there is no
    // way to pay for it. Reading a price is not buying.
    await _open(tester, 'H03');
    expect(find.byType(PackagesView), findsOneWidget);
    expect(find.text('Monthly coaching'), findsOneWidget);
    expect(AppRouter.packagesModel.mayPay, isFalse);
    expect(find.text('How would you like to pay?'), findsNothing);

    // H04: the one write the marketplace has.
    await _open(tester, 'H04');
    await _type(tester, 'Message', 'I had a baby four months ago.');
    await _tap(tester, 'Send');

    final relId = CoachingLinkState.instance.relIdWith(_coachUid);
    expect(CoachingLinkState.instance.enquiries, contains(relId));
    expect(
      CoachingLinkState.instance.enquiries[relId]!.herWords,
      'I had a baby four months ago.',
    );
    expect(
      CoachingLinkState.instance.stageWith(_coachUid),
      MarketplaceStage.enquirySent,
    );
    // The coach's own desk holds it too, because both women are this woman.
    expect(await AppRouter.coachRepository.enquiry(relId), isNotNull);

    // Sending twice lands on the same relationship rather than forking it.
    CoachingLinkState.instance.send(
      EnquiryDraft(
        coachUid: _coachUid,
        clientUid: CoachingLinkState.clientUid,
        herWords: 'I had a baby four months ago.',
      ),
    );
    expect(CoachingLinkState.instance.enquiries, hasLength(1));

    // Back on H03 the accept is offered, because this is her own coach page
    // and no account is required. It is labelled as the coach's act.
    await _open(tester, 'H03');
    expect(find.textContaining('this is your own coach page'), findsOneWidget);
    await _tap(tester, 'Accept as the coach (test)');
    expect(
      CoachingLinkState.instance.stageWith(_coachUid),
      MarketplaceStage.acceptedAwaitingPayment,
    );

    // Only now is there a rail, and it says what it is.
    expect(AppRouter.packagesModel.mayPay, isTrue);
    expect(find.textContaining('Test payment'), findsOneWidget);
    await _tap(tester, 'Card');
    await _tap(tester, 'Pay');
    await _tap(tester, 'Pay');
    await tester.pumpAndSettle();

    // The ledger settled it, she is that coach's client, and she landed on the
    // intake rather than on a receipt.
    expect(CoachingLinkState.instance.payments[relId], isNotNull);
    expect(
      CoachingLinkState.instance.stageWith(_coachUid),
      MarketplaceStage.coached,
    );
    expect(CoachingLinkState.instance.myCoachSnapshot, isNotNull);
    expect(
      CoachingLinkState.instance.myCoachSnapshot!.coachName,
      'Hala Mansour',
    );
    expect(find.byType(CoachingIntakeView), findsOneWidget);

    // Her place was taken, in the one document both sides read.
    expect(AppRouter.coachRepository.profileUnbilled.capacity.taken, 1);
  });

  testWidgets('H05 shows the coaching once she has it', (tester) async {
    await _publishACoach();
    await _boot(tester);

    CoachingLinkState.instance.send(
      EnquiryDraft(
        coachUid: _coachUid,
        clientUid: CoachingLinkState.clientUid,
        herWords: 'I had a baby four months ago.',
      ),
    );
    CoachingLinkState.instance.acceptEnquiry(
      CoachingLinkState.instance.relIdWith(_coachUid),
    );
    await CoachingLinkState.instance.pay(
      coachUid: _coachUid,
      offer: CoachingLinkState.instance.offersFor(_coachUid).single,
      rail: PaymentRail.card,
    );

    await _open(tester, 'H05');
    expect(find.text('Hala Mansour'), findsWidgets);
  });

  testWidgets('with an account required there is no test rail at all', (
    tester,
  ) async {
    await _publishACoach();
    AppRouter.featureFlags = FeatureFlags.allOff.with_({
      for (final f in Feature.values) f: true,
    });

    expect(CoachingLinkState.isTestMode, isFalse);
    expect(CoachingLinkState.instance.mayTestAccept(_coachUid), isFalse);
    expect(
      CoachingLinkState.instance.paymentProvider,
      isA<UnavailablePaymentProvider>(),
    );
  });
}

/// A coach who set herself up and published a page, the only way a row exists.
Future<void> _publishACoach() async {
  final setup = CoachProfileState.instance.setup
    ..displayName = 'Hala Mansour'
    ..city = 'Tanta'
    ..capacityMax = 10;
  setup.toggleSpecialty(Specialty.postpartum);
  setup.toggleLanguage(CoachLanguage.arabic);
  CoachProfileState.instance.saveSetup();
  await CoachProfileState.instance.packagesEditor.save(
    OfferDraft.validate(
      id: 'offer-1',
      name: 'Monthly coaching',
      pricePiastres: 180000,
    ).draft!,
  );
  CoachProfileState.instance.completeSetup();

  final page = CoachPortfolioState.instance;
  page.editing = null;
  page.replacePayload(
    const CoverPayload(
      layout: CoverLayout.noPhoto,
      headline: 'Back to lifting, gently',
    ),
  );
  final offers = page.addSection(BlockType.offers);
  page.editing = page.draft.blockById(offers);
  page.replacePayload(const OffersPayload(offerIds: <String>['offer-1']));
  page.publish();
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
