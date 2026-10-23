// The coaching screens are reachable from the places the plan names, open the
// right view, and the screens that take money are not reachable at all.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:own_hub/app_state/private_coaching_state.dart';
import 'package:own_hub/domain/flags/feature_flags.dart';
import 'package:own_hub/features/private_coaching/domain/coach_plan.dart';
import 'package:own_hub/features/private_coaching/domain/coaching_contract.dart';
import 'package:own_hub/features/private_coaching/domain/subscription.dart';
import 'package:own_hub/features/private_coaching/presentation/apply/application_status_view.dart';
import 'package:own_hub/features/private_coaching/presentation/apply/apply_flow_view.dart';
import 'package:own_hub/features/private_coaching/presentation/apply/apply_intro_view.dart';
import 'package:own_hub/features/private_coaching/presentation/chat/chat_thread_view.dart';
import 'package:own_hub/features/private_coaching/presentation/client/coach_home_card.dart';
import 'package:own_hub/features/private_coaching/presentation/client/from_your_coach_section.dart';
import 'package:own_hub/features/private_coaching/presentation/client/my_coach_view.dart';
import 'package:own_hub/features/private_coaching/presentation/coach/coach_space_view.dart';
import 'package:own_hub/features/private_coaching/presentation/desk/client_detail_view.dart';
import 'package:own_hub/features/private_coaching/presentation/desk/clients_view.dart';
import 'package:own_hub/features/private_coaching/presentation/desk/coach_desk_view.dart';
import 'package:own_hub/features/private_coaching/presentation/member/coach_portfolio_view.dart';
import 'package:own_hub/features/private_coaching/presentation/member/find_coach_view.dart';
import 'package:own_hub/features/private_coaching/presentation/plans/share_workout_view.dart';
import 'package:own_hub/features/signup/domain/verification.dart';
import 'package:own_hub/features/train/domain/my_plan.dart';
import 'package:own_hub/l10n/app_l10n.dart';
import 'package:own_hub/main.dart';
import 'package:own_hub/routing/app_router.dart';
import 'package:own_hub/routing/coaching_wiring.dart'
    show activeCoachWorkoutPlan, currentCoachingAsClient;

import '../features/private_coaching/plans/plans_support.dart'
    show mealBody, workoutPlan;
import '../features/private_coaching/support/fake_coaching_repository.dart';
import '../features/private_coaching/support/fixtures.dart';
import 'offline_verification_launch_test.dart' show FakeBackend;

late FakeCoachingRepository _repo;

Relationship _rel() => const Relationship(
  id: 'me__c1',
  coachUid: 'me',
  clientUid: 'c1',
  status: RelationshipStatus.active,
  chatOpen: true,
  activeSubId: 's1',
);

Future<void> _open(WidgetTester tester, String id, {Object? arguments}) async {
  tester
      .state<NavigatorState>(find.byType(Navigator).first)
      .pushNamed(appDestinations[id]!.name, arguments: arguments);
  await tester.pumpAndSettle();
}

Future<void> _boot(WidgetTester tester) async {
  tester.view.physicalSize = const Size(900, 1800);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(OwnHubApp(key: UniqueKey()));
  await tester.pumpAndSettle();
}

void main() {
  final savedFlags = AppRouter.featureFlags;
  final savedBackend = AppRouter.verificationBackend;
  final savedFactory = AppRouter.coachingRepositoryFactory;
  final savedClaim = AppRouter.coachClaimReader;

  setUp(() {
    AppRouter.featureFlags = FeatureFlags.shipped;
    AppRouter.lastVerification = VerificationResult(
      method: VerificationMethod.automatic,
      decidedAt: DateTime(2026, 10, 2),
      imagesDeletedAt: DateTime(2026, 10, 2),
    );
    _repo = FakeCoachingRepository(uid: 'me');
  });

  tearDown(() {
    AppRouter.featureFlags = savedFlags;
    AppRouter.verificationBackend = savedBackend;
    AppRouter.coachingRepositoryFactory = savedFactory;
    AppRouter.coachClaimReader = savedClaim;
    AppRouter.lastVerification = null;
    PrivateCoachingState.instance.stop();
  });

  group('becoming a coach', () {
    testWidgets('Profile -> Coach women -> status -> intro', (tester) async {
      PrivateCoachingState.instance.start(_repo);
      await _boot(tester);
      await _open(tester, 'A02');
      final l10n = await AppL10n.delegate.load(const Locale('en'));
      await tester.tap(find.text(l10n.coachWomenOnOwnHub));
      await tester.pumpAndSettle();
      expect(find.byType(ApplicationStatusScreen), findsOneWidget);
      await tester.tap(find.text(l10n.startMyApplication));
      await tester.pumpAndSettle();
      expect(find.byType(ApplyIntroView), findsOneWidget);
    });

    testWidgets('Back from the first step leaves the application', (
      tester,
    ) async {
      PrivateCoachingState.instance.start(_repo);
      await _boot(tester);
      await _open(tester, 'K08', arguments: 1);
      expect(find.byType(ApplyFlowView), findsOneWidget);
      await tester.tap(find.byTooltip('Back'));
      await tester.pumpAndSettle();
      expect(find.byType(ApplyFlowView), findsNothing);
    });

    testWidgets('an approved coach finds her space on Profile', (tester) async {
      PrivateCoachingState.instance.start(_repo, isCoach: true);
      await _boot(tester);
      await _open(tester, 'A02');
      final l10n = await AppL10n.delegate.load(const Locale('en'));
      expect(find.text(l10n.coachWomenOnOwnHub), findsNothing);
      await tester.tap(find.text(l10n.myCoachSpace));
      await tester.pumpAndSettle();
      expect(find.byType(CoachSpaceView), findsOneWidget);
    });
  });

  group('the coach desk', () {
    testWidgets('desk, clients, client, chat', (tester) async {
      _repo.coachSubs.value = [
        sub('s1', SubscriptionStatus.active, coachUid: 'me', clientUid: 'c1'),
      ];
      _repo.relationships.value = [_rel()];
      PrivateCoachingState.instance.start(_repo, isCoach: true);
      await _boot(tester);
      await _open(tester, 'K07');
      expect(find.byType(CoachDeskView), findsOneWidget);
      await _open(tester, 'W01');
      expect(find.byType(ClientsView), findsOneWidget);
      await _open(tester, 'W02', arguments: 's1');
      expect(find.byType(ClientDetailView), findsOneWidget);
      await _open(tester, 'K16', arguments: 'me__c1');
      expect(find.byType(ChatThreadView), findsOneWidget);
      await _open(tester, 'W03', arguments: 's1');
      expect(find.byType(ShareWorkoutView), findsOneWidget);
    });
  });

  group('the member side', () {
    testWidgets('Train -> Find a coach -> portfolio', (tester) async {
      _repo.coaches.value = [coach('c9', 'Coach Nour')];
      PrivateCoachingState.instance.start(_repo);
      await _boot(tester);
      await _open(tester, 'R01');
      final l10n = await AppL10n.delegate.load(const Locale('en'));
      await tester.scrollUntilVisible(
        find.text(l10n.findACoach),
        300,
        scrollable: find.byType(Scrollable).first,
      );
      await tester.tap(find.text(l10n.findACoach));
      await tester.pumpAndSettle();
      expect(find.byType(FindCoachView), findsOneWidget);
      await _open(tester, 'H02', arguments: 'c9');
      expect(find.byType(LiveCoachPortfolioView), findsOneWidget);
    });

    testWidgets('My coach: none yet, then a running coaching with a chat', (
      tester,
    ) async {
      PrivateCoachingState.instance.start(_repo);
      await _boot(tester);
      await _open(tester, 'H05');
      expect(find.byType(NoCoachView), findsOneWidget);

      _repo.clientSubs.value = [
        sub('s1', SubscriptionStatus.active, coachUid: 'c1'),
      ];
      _repo.relationships.value = [
        const Relationship(
          id: 'c1__me',
          coachUid: 'c1',
          clientUid: 'me',
          status: RelationshipStatus.active,
          chatOpen: true,
          activeSubId: 's1',
        ),
      ];
      await tester.pumpAndSettle();
      await _open(tester, 'H06', arguments: 'c1__me');
      expect(find.byType(ChatThreadView), findsOneWidget);
    });

    testWidgets('a declined request shows on My coach with a way on', (
      tester,
    ) async {
      _repo.clientSubs.value = [sub('s1', SubscriptionStatus.declined)];
      PrivateCoachingState.instance.start(_repo);
      await _boot(tester);
      expect(currentCoachingAsClient()?.status, SubscriptionStatus.declined);
      await _open(tester, 'H05');
      expect(find.byKey(const ValueKey('find-another-coach')), findsOneWidget);
    });

    testWidgets('Home carries her coach card; Train follows the coach plan', (
      tester,
    ) async {
      _repo.clientSubs.value = [
        sub('s1', SubscriptionStatus.active, coachUid: 'c1'),
      ];
      _repo.plans.value = [
        CoachPlan(
          id: 'w1',
          kind: PlanKind.workout,
          coachUid: 'c1',
          name: 'Strength',
          workout: workoutPlan(),
        ),
      ];
      PrivateCoachingState.instance.start(_repo);
      await _boot(tester);
      await _open(tester, 'T01');
      expect(find.byType(CoachHomeCard), findsOneWidget);
      final plan = activeCoachWorkoutPlan();
      expect(plan, isNotNull);
      final programme = coachPlanProgramme(plan!.workout, name: plan.name);
      expect(programme?.programId, kCoachPlanId);
      expect(isMyPlanProgramme(programme!), isFalse);
    });

    testWidgets('Eat shows what the coach planned', (tester) async {
      _repo.clientSubs.value = [
        sub('s1', SubscriptionStatus.active, coachUid: 'c1'),
      ];
      _repo.plans.value = [
        CoachPlan(
          id: 'm1',
          kind: PlanKind.meal,
          coachUid: 'c1',
          name: 'Week',
          meal: mealBody(),
          publishedAt: DateTime.now(),
        ),
      ];
      PrivateCoachingState.instance.start(_repo);
      await _boot(tester);
      await _open(tester, 'E01');
      final l10n = await AppL10n.delegate.load(const Locale('en'));
      await tester.tap(find.text(l10n.plan));
      await tester.pumpAndSettle();
      expect(find.byType(FromYourCoachSection), findsOneWidget);
    });
  });

  group('money', () {
    testWidgets('the payment screens are dark', (tester) async {
      PrivateCoachingState.instance.start(_repo, isCoach: true);
      await _boot(tester);
      for (final id in ['H04', 'K05', 'K17']) {
        expect(AppRouter.screenIsOn(id), isFalse, reason: id);
        await _open(tester, id);
        expect(find.byType(FeatureOff), findsOneWidget, reason: id);
        tester.state<NavigatorState>(find.byType(Navigator).first).pop();
        await tester.pumpAndSettle();
      }
    });

    test('the old demo coach screens have no builder', () {
      for (final id in [
        'K03',
        'K04',
        'K05',
        'K09',
        'K10',
        'K11',
        'K12',
        'K13',
        'K25',
        'H04',
      ]) {
        expect(AppRouter.isBuilt(id), isFalse, reason: id);
      }
    });
  });

  group('the state follows the verified woman', () {
    testWidgets('started with her claim, stopped when she is forgotten', (
      tester,
    ) async {
      SharedPreferences.setMockInitialValues({});
      AppRouter.verificationBackend = FakeBackend(uid: 'me');
      AppRouter.coachingRepositoryFactory = () => _repo;
      AppRouter.coachClaimReader = ({bool refresh = false}) async => true;
      await AppRouter.syncPrivateCoaching();
      expect(PrivateCoachingState.instance.isStarted, isTrue);
      expect(PrivateCoachingState.instance.isCoach, isTrue);
      await AppRouter.forgetVerification();
      expect(PrivateCoachingState.instance.isStarted, isFalse);
    });
  });
}
