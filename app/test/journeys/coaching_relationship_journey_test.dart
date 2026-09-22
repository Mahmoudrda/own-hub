// One relationship, walked from both sides, in the real app.
//
// The coach's desk and her planner were the largest shell left: `W01` was
// handed `const []` so `W02`, `W06`, `W09`, `K16` and `K27` were unreachable;
// `W03` built a **new** empty `PlanDraft` on every build, so nothing planned
// survived a rebuild; `W08` had no builder at all, so every Publish button
// landed on `NotBuiltYet`; and the coached screens fell back to "Sara Hany",
// "Full body strength" and preview days dated 2026-09-08.
//
// Nothing here seeds any of that. The coach is the one the tester sets up and
// publishes, the client is the tester enquiring through `H04`, the plan is
// what the tester types on `W04`, and the conversation is what she sends from
// both sides.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:own_hub/app_state/coach_portfolio_state.dart';
import 'package:own_hub/app_state/coach_profile_state.dart';
import 'package:own_hub/app_state/coached_life_state.dart';
import 'package:own_hub/app_state/coaching_desk_state.dart';
import 'package:own_hub/app_state/coaching_link_state.dart';
import 'package:own_hub/domain/flags/feature_flags.dart';
import 'package:own_hub/domain/format/day_key.dart';
import 'package:own_hub/domain/safety/life_stage_safety_policy.dart';
import 'package:own_hub/features/coach/domain/coach_profile.dart';
import 'package:own_hub/features/coach/domain/offer.dart';
import 'package:own_hub/features/coach/presentation/coach_earnings_view.dart';
import 'package:own_hub/features/coach/presentation/coach_enquiry_view.dart';
import 'package:own_hub/features/coachbrand/domain/portfolio_block.dart';
import 'package:own_hub/features/coached/presentation/coaching_plan_view.dart';
import 'package:own_hub/features/coached/presentation/preparing_view.dart';
import 'package:own_hub/features/coached/presentation/thirty_days_view.dart';
import 'package:own_hub/features/coaching/domain/coaching_repository.dart';
import 'package:own_hub/features/coaching/domain/marketplace_stage.dart';
import 'package:own_hub/features/coaching/domain/payment_state_machine.dart';
import 'package:own_hub/features/coaching/presentation/my_coach_view.dart';
import 'package:own_hub/features/coachplan/domain/plan/plan_draft.dart';
import 'package:own_hub/features/coachplan/presentation/client_overview_view.dart';
import 'package:own_hub/features/coachplan/presentation/clients_view.dart';
import 'package:own_hub/features/coachplan/presentation/coachplan_widgets.dart';
import 'package:own_hub/features/coachplan/presentation/workout_planner_view.dart';
import 'package:own_hub/main.dart';
import 'package:own_hub/routing/app_router.dart';
import 'package:own_hub/ui/app_button.dart';
import 'package:own_hub/ui/app_field.dart';

const String _coachUid = 'coach-1';
const String _clientUid = CoachingLinkState.clientUid;

void main() {
  final savedFlags = AppRouter.featureFlags;

  setUp(() {
    AppRouter.featureFlags = FeatureFlags.allOff.with_({
      for (final f in Feature.values) f: f != Feature.accountRequired,
    });
    _resetEverything();
  });

  tearDown(() {
    _resetEverything();
    AppRouter.featureFlags = savedFlags;
  });

  // ─────────────────────────────────────────── 5. day one stays honest

  testWidgets('with no client, the desk and the roster both say so', (
    tester,
  ) async {
    await _publishACoach();
    await _boot(tester);

    // K24 — the day-one branch of K07, chosen from her roster and not from a
    // route. Nothing on it claims a client, a review or a figure.
    await _open(tester, 'K07');
    expect(find.text('No clients yet'), findsOneWidget);

    // W11 — the same thing for the list: loaded, and holding nobody.
    await _open(tester, 'W01');
    expect(find.byKey(CoachPlanKeys.clientsEmpty), findsOneWidget);
    expect(find.byKey(CoachPlanKeys.clientsList), findsNothing);
    expect(AppRouter.coachPlanClients, isEmpty);
  });

  // ───────────────────────────────── 1. the enquiry, the desk, the accept

  testWidgets('an enquiry reaches her desk, K09 shows her own words, and '
      'accepting makes her a client', (tester) async {
    await _publishACoach();
    await _boot(tester);
    await _enquireThroughTheApp(tester, 'I had a baby four months ago.');

    // It is on her desk — on day one too, which is the only day the first
    // enquiry can arrive on.
    await _open(tester, 'K07');
    expect(find.text('New enquiry'), findsOneWidget);
    await _tap(tester, 'New enquiry');

    // K09 is the real enquiry, not the empty one the router used to fabricate.
    expect(find.byType(CoachEnquiryView), findsOneWidget);
    expect(
      find.textContaining('I had a baby four months ago.'),
      findsOneWidget,
    );

    await _tap(tester, 'Accept and send a welcome');

    final relId = CoachingLinkState.instance.relIdWith(_coachUid);
    expect(
      CoachingLinkState.instance.stageWith(_coachUid),
      MarketplaceStage.acceptedAwaitingPayment,
    );
    expect(CoachingDeskState.instance.clients, hasLength(1));

    // W01 now lists her, and W02 opens her overview — both were unreachable
    // while the roster was `const []`.
    expect(find.byType(ClientsView), findsOneWidget);
    expect(find.byKey(Key('client:$_clientUid')), findsOneWidget);
    await tester.tap(find.byKey(Key('client:$_clientUid')));
    await tester.pumpAndSettle();
    expect(find.byType(ClientOverviewView), findsOneWidget);
    expect(AppRouter.coachPlanClient.clientUid, _clientUid);
    expect(relId, isNotEmpty);
  });

  testWidgets('declining takes her off the desk and off the roster', (
    tester,
  ) async {
    await _publishACoach();
    await _boot(tester);
    await _enquireThroughTheApp(tester, 'Can we start in October?');

    await _open(tester, 'K07');
    await _tap(tester, 'New enquiry');
    await _tap(tester, 'Not a fit for me');

    expect(
      CoachingLinkState.instance.stageWith(_coachUid),
      MarketplaceStage.enquiryDeclined,
    );
    expect(CoachingDeskState.instance.clients, isEmpty);
    expect(find.text('New enquiry'), findsNothing);
  });

  // ────────────────────────────────────────────── 2. planning a month

  testWidgets('W03 keeps what she plans, and W04 saves a session', (
    tester,
  ) async {
    await _aClient();
    await _boot(tester);
    await _open(tester, 'W01');
    await tester.tap(find.byKey(Key('client:$_clientUid')));
    await tester.pumpAndSettle();

    // W02 → W03. The planner opens on the month, with every day a gap.
    await _tap(tester, 'Plan');
    expect(find.byType(WorkoutPlannerView), findsOneWidget);
    // Week one is what the planner opens on, so the day it can reach is the
    // month's first — the planner is a month, not a rolling seven days.
    final today = CoachingDeskState.monthDays(
      CoachingDeskState.instance.draftFor(_clientUid).month,
    ).first;
    expect(find.byKey(CoachPlanKeys.dayRow(today)), findsOneWidget);

    // W04, from the day she tapped.
    await tester.tap(find.byKey(CoachPlanKeys.dayRow(today)));
    await tester.pumpAndSettle();
    await _type(tester, 'Session name', 'Back to the floor');
    await _tap(tester, '30');
    await _tap(tester, 'Save');

    // The draft held it — this is the whole of what `coachPlanDraft` building
    // a new empty PlanDraft on every build used to throw away.
    final draft = CoachingDeskState.instance.draftFor(_clientUid);
    expect(draft.dayAt(today)?.workout?.title, 'Back to the floor');
    expect(draft.dayAt(today)?.workout?.minutes, 30);
    expect(draft.workoutDayCount, 1);

    // And W03 renders it back rather than "Nothing assigned".
    expect(find.text('Back to the floor'), findsWidgets);
  });

  testWidgets('W05 copies a week onto another one', (tester) async {
    await _aClient();
    final desk = CoachingDeskState.instance;
    final month = CoachingDeskState.monthDays(desk.draftFor(_clientUid).month);
    desk.editSession(_clientUid, month.first, title: 'Week one', minutes: 20);

    await _boot(tester);
    await _open(tester, 'W05');
    // Week 2 is the destination; week 1 is what W03 is showing.
    final weeks = desk.weekCountFor(_clientUid);
    await _tap(tester, 'Week 2 of $weeks');
    await _tap(tester, 'Copy this week');

    expect(
      desk.draftFor(_clientUid).dayAt(month[7])?.workout?.title,
      'Week one',
    );
    // Copied **by value**: the two days are different objects.
    expect(
      identical(
        desk.draftFor(_clientUid).dayAt(month.first),
        desk.draftFor(_clientUid).dayAt(month[7]),
      ),
      isFalse,
    );
  });

  testWidgets('a split she builds on K20 applies to her client', (
    tester,
  ) async {
    await _aClient();
    await _boot(tester);
    await _open(tester, 'K19');
    await _tap(tester, 'Build a split');

    await _type(tester, 'Name it', 'Three days');
    // One tap turns a rest day into a training day named after the split.
    await tester.tap(find.byKey(const Key('slot:1')));
    await tester.pumpAndSettle();
    // Saving and applying are one tap, and applying writes the template
    // across her month **by value** — nothing in the draft is the template.
    await _tap(tester, 'Save and apply');

    final desk = CoachingDeskState.instance;
    expect(desk.splits, hasLength(1));
    expect(desk.splits.single.name, 'Three days');
    expect(desk.splits.single.sessionDayCount, 1);

    expect(find.byType(WorkoutPlannerView), findsOneWidget);
    expect(desk.draftFor(_clientUid).days, isNotEmpty);
    expect(desk.draftFor(_clientUid).workoutDayCount, greaterThan(0));
    expect(desk.draftFor(_clientUid).origin, DraftOrigin.split);
    // The days it wrote carry her split's own name — nothing here authored a
    // session title.
    expect(
      desk
          .draftFor(_clientUid)
          .days
          .values
          .any((day) => day.workout?.title == 'Three days'),
      isTrue,
    );
  });

  testWidgets('K21 and K23 record one assessment, and W02 and K22 read it', (
    tester,
  ) async {
    await _aClient();
    await _boot(tester);
    await _open(tester, 'W01');
    await tester.tap(find.byKey(Key('client:$_clientUid')));
    await tester.pumpAndSettle();
    await _tap(tester, 'Assessment');

    final desk = CoachingDeskState.instance;
    expect(desk.form.clientUid, _clientUid);
    desk.setLifeStage(LifeStage.postpartum6wTo1y);
    desk.setClearance(true);
    await tester.pumpAndSettle();

    await _tap(tester, 'Continue');
    await _tap(tester, 'Save assessment');

    expect(desk.assessments[_clientUid], isNotNull);
    expect(
      desk.assessments[_clientUid]!.assessment.lifeStage,
      LifeStage.postpartum6wTo1y,
    );
    // Her constraints resolve from it — no longer the fail-closed value.
    expect(desk.constraintsFor(_clientUid).isResolved, isTrue);

    // The same row now opens the re-assessment, which is pre-filled from the
    // record and has a parent to hang off.
    expect(find.byType(ClientOverviewView), findsOneWidget);
    await _tap(tester, 'Assessment');
    expect(
      desk.form.parentAssessmentId,
      desk.assessments[_clientUid]!.assessmentId,
    );
    expect(desk.form.lifeStage, LifeStage.postpartum6wTo1y);
  });

  // ──────────────────────────────────── 3. publishing reaches the client

  testWidgets('W08 publishes, and the plan her coach wrote is what G04, G05 '
      'and G06 show her', (tester) async {
    await _aClient();
    final desk = CoachingDeskState.instance;
    final today = dayKey(DateTime.now());
    desk.editSession(
      _clientUid,
      today,
      title: 'Back to the floor',
      minutes: 30,
      note: 'Keep it slow, stop if anything pulls.',
    );

    await _boot(tester);
    await _open(tester, 'W08');
    // Nothing is on file about her, and the screen says so rather than
    // pretending the gate looked.
    expect(find.byKey(const Key('W08.noAssessment')), findsOneWidget);
    await _tap(tester, 'Publish plan');
    await tester.pumpAndSettle();

    expect(desk.published[_clientUid], isNotNull);
    expect(desk.published[_clientUid]!.version, 'v1');
    expect(desk.lastPublish!.isPublished, isTrue);

    // Her side. Her coach's own title and her coach's own words.
    await _open(tester, 'G04');
    expect(find.byType(CoachingPlanView), findsOneWidget);
    expect(find.text('Back to the floor'), findsOneWidget);
    expect(find.text('Keep it slow, stop if anything pulls.'), findsOneWidget);
    expect(find.text('Full body strength'), findsNothing);

    // The month, counted from the plan rather than drawn from preview days.
    await _open(tester, 'G05');
    expect(find.byType(ThirtyDaysView), findsOneWidget);
    expect(CoachedLifeState.instance.calendar, hasLength(1));

    // G06 is the session, G09 records that she did it — in her logs, never in
    // the plan.
    await _open(tester, 'G06');
    expect(find.text('Back to the floor'), findsWidgets);
    await _open(tester, 'G09');
    await _tap(tester, 'Save and send to Sara');
    expect(desk.sessionsDone, contains(today));
    expect(
      desk.published[_clientUid]!.dayAt(today)!.workout!.title,
      'Back to the floor',
    );
  });

  testWidgets('a meal her coach planned is what G10 offers and G11 logs', (
    tester,
  ) async {
    await _aClient();
    final desk = CoachingDeskState.instance;
    final today = dayKey(DateTime.now());
    desk.editSession(
      _clientUid,
      today,
      title: 'Back to the floor',
      minutes: 30,
    );

    await _boot(tester);
    // Her food step first: a coach may not plan food for a woman whose
    // allergies cannot be read, and "asked, named nothing" is what makes them
    // readable. G17 is the only writer of that list.
    await _open(tester, 'G17');
    await _tap(tester, 'Continue');
    expect(desk.declaredAllergies, isEmpty);

    // W06: one tap on a slot states a free choice — an answer, never a gap.
    await _open(tester, 'W06');
    await tester.tap(find.byKey(CoachPlanKeys.slotRow('lunch')));
    await tester.pumpAndSettle();
    expect(find.text('Her choice'), findsWidgets);

    // W07 writes one of her own dishes, and it lands in the slot she had open.
    await _tap(tester, 'Create meal');
    await _type(tester, 'Name', 'Lentil soup and eggs');
    await _tap(tester, 'Save to my meals and assign');
    expect(desk.meals, hasLength(1));
    expect(
      desk
          .draftFor(_clientUid)
          .dayAt(today)!
          .meal!
          .slots[PlanMealSlot.lunch]!
          .coachMealId,
      isNotNull,
    );

    await _open(tester, 'W08');
    await _tap(tester, 'Publish plan');
    await tester.pumpAndSettle();

    // Her side: the dish her coach wrote, logged with one tap and undoable.
    CoachedLifeState.instance.openSlot(PlanMealSlot.lunch);
    await _open(tester, 'G10');
    expect(find.text('Lentil soup and eggs'), findsWidgets);
    await _tap(tester, 'Ate this');
    expect(
      CoachedLifeState.instance.isLogged(today, PlanMealSlot.lunch),
      isTrue,
    );
    expect(desk.mealDays, contains(today));
  });

  // ───────────────────────────────────────────── 4. the relationship

  testWidgets('K16 and G14 are one conversation, written from both sides', (
    tester,
  ) async {
    await _aClient();
    await _boot(tester);

    final relId = CoachingLinkState.instance.relIdWith(_coachUid);
    await _open(tester, 'G14');
    await _write(tester, 'Thursday is short for me — I have 20 minutes.');
    expect(CoachingDeskState.instance.threadFor(relId), hasLength(1));

    await _open(tester, 'K16');
    expect(
      find.text('Thursday is short for me — I have 20 minutes.'),
      findsOneWidget,
    );
    await _write(tester, 'Then we make Thursday twenty minutes.');

    final thread = CoachingDeskState.instance.threadFor(relId);
    expect(thread, hasLength(2));
    expect(thread.first.senderUid, _clientUid);
    expect(thread.last.senderUid, _coachUid);

    await _open(tester, 'G14');
    expect(find.text('Then we make Thursday twenty minutes.'), findsOneWidget);
  });

  testWidgets('her weekly review is answered on W09 and read on G12 and G13', (
    tester,
  ) async {
    await _aClient();
    await _boot(tester);
    final relId = CoachingLinkState.instance.relIdWith(_coachUid);

    await _open(tester, 'G12');
    await _type(tester, 'What worked well? Optional', 'Mornings, before work.');
    await _tap(tester, 'Send to Sara');
    expect(CoachingDeskState.instance.reviewFor(relId)!.isSubmitted, isTrue);
    expect(
      CoachingDeskState.instance.reviewFor(relId)!.worked,
      'Mornings, before work.',
    );

    // The coach reads her sentence and answers it. Saving feedback publishes
    // nothing — the domain cannot, and nor can the screen.
    await _open(tester, 'W09');
    expect(find.text('Mornings, before work.'), findsOneWidget);
    await _type(tester, 'Message', 'Then keep mornings. Same plan this week.');
    await _tap(tester, 'Save feedback');

    final review = CoachingDeskState.instance.reviewFor(relId)!;
    expect(review.coachWords, 'Then keep mornings. Same plan this week.');
    expect(CoachingDeskState.instance.published[_clientUid], isNull);

    await _open(tester, 'G13');
    expect(
      find.text('Then keep mornings. Same plan this week.'),
      findsOneWidget,
    );
  });

  testWidgets('K17 shows the test payments that were actually made', (
    tester,
  ) async {
    await _publishACoach();
    await _boot(tester);

    // Nothing has been paid: unavailable, never a zero.
    expect(CoachingDeskState.instance.earnings.statementOrNull, isNull);

    await _aClientWhoPaid();
    final statement = CoachingDeskState.instance.earnings.statementOrNull;
    expect(statement, isNotNull);
    expect(statement!.grossPiastres, 180000);
    // Her 80%, from the same arithmetic the row beside it uses.
    expect(statement.sharePiastres, 144000);

    await _open(tester, 'K17');
    expect(find.byType(CoachEarningsView), findsOneWidget);
  });

  testWidgets('ending the coaching leaves H05 telling the truth', (
    tester,
  ) async {
    await _aClientWhoPaid();
    await _boot(tester);

    await _open(tester, 'H05');
    expect(find.text('Hala Mansour'), findsWidgets);

    // G05's subscription row is what ends it in this build — there is no
    // renewal clock here — and it says so.
    await _open(tester, 'G05');
    await _tap(tester, 'End this coaching now (test)');

    expect(CoachingLinkState.instance.myCoachSnapshot, isNull);
    expect(
      CoachingLinkState.instance.stageWith(_coachUid),
      MarketplaceStage.coachingEnded,
    );

    await _open(tester, 'H05');
    expect(find.byType(MyCoachView), findsOneWidget);
    // Back to the empty state, which is the honest one: she has no coach.
    expect(find.textContaining('Every coach here'), findsOneWidget);

    // And her plan stays readable rather than vanishing.
    await _open(tester, 'G03');
    expect(find.byType(PreparingView), findsOneWidget);
  });
}

// ───────────────────────────────────────────────────────────── helpers

void _resetEverything() {
  CoachProfileState.instance.reset();
  CoachPortfolioState.instance.reset();
  CoachingLinkState.instance.reset();
  CoachingDeskState.instance.reset();
  CoachedLifeState.instance.reset();
  AppRouter.marketplaceOpenCoachUid = '';
  AppRouter.marketplaceSelectedOfferId = null;
  AppRouter.coachOpenRelId = '';
  AppRouter.coachPlanOpenClient = null;
  AppRouter.coachPlanOpenDayKey = null;
  AppRouter.coachPlanWeekIndex = 0;
}

/// A coach who set herself up and published a page — the only way a row exists.
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

/// Published, enquired and accepted: the state every planning journey starts
/// from, reached through the same calls the screens make.
Future<void> _aClient() async {
  await _publishACoach();
  CoachingLinkState.instance.send(
    EnquiryDraft(
      coachUid: _coachUid,
      clientUid: _clientUid,
      herWords: 'I had a baby four months ago.',
    ),
  );
  CoachingDeskState.instance.acceptEnquiry(
    CoachingLinkState.instance.relIdWith(_coachUid),
  );
}

/// The same, and she paid — the only way `K17` has a figure and `H05` a coach.
Future<void> _aClientWhoPaid() async {
  await _aClient();
  await CoachingLinkState.instance.pay(
    coachUid: _coachUid,
    offer: CoachingLinkState.instance.offersFor(_coachUid).single,
    rail: PaymentRail.card,
  );
}

Future<void> _enquireThroughTheApp(WidgetTester tester, String words) async {
  AppRouter.marketplaceOpenCoachUid = _coachUid;
  await _open(tester, 'H04');
  await _type(tester, 'Message', words);
  await _tap(tester, 'Send');
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

/// Types into a chat composer and sends it.
Future<void> _write(WidgetTester tester, String words) async {
  final field = find.byType(EditableText);
  expect(field, findsWidgets, reason: 'no composer on screen');
  await tester.enterText(field.last, words);
  await tester.pumpAndSettle();
  await tester.tap(find.byIcon(Icons.send).last);
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
